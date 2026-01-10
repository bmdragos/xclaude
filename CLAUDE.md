# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**xclaude** is an MCP server that lets Claude Code build, sign, and deploy iOS/macOS/visionOS apps without Xcode project files. "Terraform for Apple development."

See `VISION.md` for full design principles and roadmap.

## Build Commands

```bash
swift build                    # Build
swift build -c release         # Release build
swift test                     # Run tests
swift test --filter <name>     # Run specific test
```

## Design Principles (Summary)

1. **Convention over configuration** - Files go in predictable places, no questions
2. **Progressive disclosure** - Minimal config that grows as needed
3. **Auto-discovery** - Scan environment, don't ask
4. **Structured errors** - JSON with `fixable` flag so Claude can auto-fix
5. **Single icon** - One 1024x1024 PNG, generate all sizes

## Project Conventions (for apps built with xclaude)

```
MyApp/
├── xclaude.toml          # Config (always here)
├── icon.png              # 1024x1024 icon (always here)
├── Package.swift
├── Sources/MyApp/
└── .xclaude/             # Generated (gitignored)
    ├── derived/          # Assets, plists, entitlements
    └── cache/            # Signing info
```

## Status: v3.9.0 Released

- [x] Fork Swift Bundler
- [x] Fix iOS app icons
- [x] Implement signing discovery
- [x] Create MCP server (60 tools, 61 capabilities)
- [x] Mint distribution (`mint install bmdragos/xclaude`)
- [x] Async-only builds (`build_start` + `build_status` + `build_logs`)
- [x] Clean entitlements architecture (regenerated fresh per build)
- [x] Multi-team signing support (team ID from certificate OU field)
- [x] App Store Connect API integration (24 tools for devices, profiles, certificates, TestFlight)

## Key Files

| File | Purpose |
|------|---------|
| `Sources/XClaudeCore/MCP/MCPTools.swift` | All 60 MCP tool implementations (5500+ lines) |
| `Sources/XClaudeCore/MCP/MCPServer.swift` | JSON-RPC 2.0 server |
| `Sources/XClaudeCore/ASC/AppStoreConnectClient.swift` | App Store Connect API client (JWT auth, REST calls) |
| `Sources/XClaudeCore/ASC/ASCCredentialStore.swift` | Persistent ASC credential storage (~/.xclaude/) |
| `Sources/XClaudeCore/Build/BuildRunner.swift` | Synchronous builds via swift-bundler |
| `Sources/XClaudeCore/Build/BuildManager.swift` | Async builds with buffered output |
| `Sources/XClaudeCore/Deploy/DeployRunner.swift` | Simulator/device deployment |
| `Sources/XClaudeCore/Discovery/SigningDiscovery.swift` | Keychain + profile discovery |
| `Sources/XClaudeCore/Config/XClaudeConfig.swift` | xclaude.toml parsing |
| `Sources/SwiftBundler/Bundler/ResourceBundler.swift` | Asset catalog compilation |
| `Sources/SwiftBundler/Bundler/DarwinBundler.swift` | macOS/iOS bundling |

## XClaudeCore Architecture (the MCP layer)

```
Sources/XClaudeCore/
├── MCP/
│   ├── MCPServer.swift     # JSON-RPC 2.0 server, tool dispatch
│   └── MCPTools.swift      # All 60 tools (LARGE - consider splitting)
├── ASC/
│   ├── AppStoreConnectClient.swift  # JWT auth, API calls
│   └── ASCCredentialStore.swift     # Credential persistence
├── Build/
│   ├── BuildRunner.swift   # Sync builds, asset catalog compilation
│   └── BuildManager.swift  # Async builds with job tracking
├── Deploy/
│   └── DeployRunner.swift  # simctl/devicectl deployment
├── Discovery/
│   └── SigningDiscovery.swift  # Keychain + profile parsing
├── Config/
│   ├── XClaudeConfig.swift     # xclaude.toml → struct
│   ├── ConfigTranslator.swift  # → Bundler.toml generation
│   └── ConfigUpdater.swift     # In-place updates
├── Project/
│   └── ProjectScaffold.swift   # New project templates
└── Cache/
    └── GlobalCache.swift       # ~/.xclaude/ with TTLs
```

### Build Modes
- **Async only** (`build_start/status/logs/cancel`): `BuildManager` returns job ID immediately
- `build_status` returns `appPath` so you know where the built `.app` is located
- `build_start` defaults: platform=`iOS`, config=`debug`. Use `clean: true` to delete `.build/` first.
- `build_logs` preserves buffer by default. Use `clear: true` to clear after reading.
- `deploy` defaults to `device` target. `bundle_id` auto-detects from xclaude.toml if omitted.

### Post-Build Processing
After successful builds, xclaude automatically:
1. Finds `.xcassets` in project
2. Runs `xcrun actool` to compile asset catalog (fixes app icon)
3. Updates Info.plist with icon metadata
4. Re-signs the app if needed

## Common Pitfalls

### 1. devicectl requires file path for JSON output
```swift
// WRONG - -j requires a path argument, not just the flag
runCommand("devicectl", ["list", "devices", "-j"])

// CORRECT - write to temp file, then read
let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("devices.json")
runCommand("devicectl", ["list", "devices", "-j", tempFile.path])
let data = Data(contentsOf: tempFile)
```

### 2. Target parsing defaults
- Explicit UDIDs → default to **device** (users pass UDIDs for physical devices)
- Names → default to **simulator** (common dev workflow)
- Use prefixes for explicit control: `device:UDID` or `simulator:UDID`

### 3. Config file handling
- xclaude.toml → translated to `.xclaude/derived/Bundler.toml`
- Use `--config-file` flag to avoid overwriting existing Bundler.toml
- Never modify user's root Bundler.toml directly

### 4. Silent error handling
Avoid `try?` that swallows errors. Prefer explicit handling or at minimum log failures.

### 5. Entitlements architecture (v3.7.0+)
`Entitlements.plist` is a **purely derived file** - regenerated fresh each build from `xclaude.toml`:

```toml
[capabilities]
healthkit = true
push-notifications = "development"
app-groups = ["group.com.example.myapp"]
```

**How it works:**
- `add_capability` writes to `xclaude.toml [capabilities]` section only
- At build time, `generateEntitlements()` reads capabilities and generates platform-appropriate entitlements
- macOS-only capabilities auto-filtered for iOS builds (and vice versa)
- Correct `get-task-allow` variant per platform (iOS: `get-task-allow`, macOS: `com.apple.security.get-task-allow`)

**No more cross-platform contamination** - each build starts fresh.

### 6. Capability platform differences
Many capabilities work differently across platforms:

| Capability | macOS | iOS |
|------------|-------|-----|
| bluetooth | `com.apple.security.device.bluetooth` entitlement | `NSBluetoothAlwaysUsageDescription` Info.plist |
| camera | `com.apple.security.device.camera` entitlement | `NSCameraUsageDescription` Info.plist |
| location | `com.apple.security.personal-information.location` | `NSLocationWhenInUseUsageDescription` Info.plist |

`ConfigUpdater.swift` handles this with the `platform` property on capabilities - check `.iOS`, `.macOS`, or `.both`.

### 7. iOS vs macOS certificate types
Different certificate types for different distribution methods:

| Certificate | Use For |
|-------------|---------|
| Apple Development | Development builds (any platform) |
| Apple Distribution | App Store / TestFlight (iOS + macOS) |
| Developer ID Application | macOS direct distribution (notarized, outside App Store) |

**Common mistake**: Using "Developer ID Application" for iOS TestFlight. This will fail silently - the build uploads but never processes. The `archive` tool now validates this and returns a clear error with instructions.

### 8. Provisioning profile troubleshooting
Common "A valid provisioning profile was not found" causes:
1. **Certificate not in profile**: Profile created before your signing cert existed → regenerate profile
2. **Device not registered**: Your device UDID isn't in the profile → add device to Apple Portal, regenerate profile
3. **Entitlement mismatch**: App has entitlements the profile doesn't allow → see pitfall #6
4. **Wrong profile cached**: Delete `.build/` and rebuild

**Device UDID confusion**: `devicectl` shows CoreDevice UUID (97452CCA-E01F-5542-...), but Apple Portal uses hardware UDID (00008130-000605841AE0...). Both refer to the same device.

## Adding New MCP Tools

1. Add tool definition to `MCPTools.allTools` array:
```swift
MCPTool(
  name: "my_tool",
  description: "Does something useful",
  inputSchema: [
    "type": "object",
    "properties": ["param": ["type": "string"]],
    "required": ["param"]
  ]
)
```

2. Add case to `MCPTools.callTool()` switch
3. Implement static function returning JSON via `encodeJSON()`

## Caching (GlobalCache)

Stores expensive discovery results in `~/.xclaude/`:
- **Signing**: 5 min TTL
- **Simulators**: 1 min TTL
- **Devices**: 30 sec TTL

Force refresh: `forceRefresh: true`

## App Store Connect API Integration

21 tools for automating Apple Developer Portal tasks:

### Authentication
- `asc_configure(issuer_id, key_path, key_id?)` - Configure API credentials (stored in `~/.xclaude/asc_credentials.json`)
- `asc_status()` - Check credential status and test connection

### Device Registration
- `asc_list_devices()` - List registered devices
- `asc_register_device(udid, name)` - Register new device (uses hardware UDID, not CoreDevice UUID)

### Provisioning Profiles
- `asc_list_profiles()` - List all profiles
- `asc_create_profile(name, bundle_id, profile_type?)` - Create new profile
- `asc_delete_profile(profile_id)` - Delete profile
- `asc_download_profile(profile_id)` - Download and install profile
- `asc_regenerate_profile(bundle_id)` - Delete + recreate with all devices

### TestFlight
- `asc_list_apps()` - List apps (get app IDs)
- `asc_list_bundle_ids()` - List registered bundle identifiers
- `asc_create_bundle_id(identifier, name)` - Register new bundle ID
- `asc_create_app(bundle_id, name, sku)` - **Limited**: Apple's API doesn't support this, returns manual steps
- `asc_list_builds(app_id)` - List uploaded builds
- `asc_list_groups()` - List beta groups
- `asc_create_group(app_id, name, is_internal?, public_link_enabled?)` - Create beta group
- `asc_add_build_to_group(group_id, build_id)` - Add build for distribution
- `asc_list_testers()` - List beta testers
- `asc_add_tester(email, first_name?, last_name?, group_ids?)` - Add tester
- `asc_remove_tester(email)` - Remove tester
- `asc_set_whats_new(build_id, whats_new, locale?)` - Set "What's New" text

### API Credentials
Get from App Store Connect → Users and Access → Keys:
1. Generate API Key (Admin role recommended)
2. Download the `.p8` private key (only available once!)
3. Note the Key ID and Issuer ID
4. Run `asc_configure(issuer_id: "...", key_path: "/path/to/AuthKey_XXX.p8")`

### Known Limitations
- **Cannot create apps via API**: Apple's API returns FORBIDDEN_ERROR. `asc_create_app` detects this and returns manual steps with pre-filled values.
- **Hardware UDID vs CoreDevice UUID**: `devicectl` shows CoreDevice UUID, but `asc_register_device` needs the hardware UDID. Use `xcrun devicectl device info details --device <uuid>` to get the hardware UDID.

## Testing Changes

1. `swift build -c release --product xclaude`
2. In Claude Code: `/mcp` to reconnect
3. `get_version` to verify new binary loaded
4. Test affected tools

## Swift Bundler Architecture (the engine)

### Modules

- **SwiftBundler** - Main library with bundlers, config, commands
- **SwiftBundlerRuntime** - Hot reloading runtime
- **SwiftBundlerBuilders** - Programmatic config DSL

### Bundlers

- **DarwinBundler** - macOS/iOS/tvOS/visionOS `.app` bundles
- **GenericLinuxBundler** - Base for AppImageBundler, RPMBundler
- **GenericWindowsBundler** - Base for MSIBundler

### Error Handling

Uses `RichError<T>` for typed error chains:

```swift
enum ErrorMessage: Error { case failedToReadFile(String) }
typealias Error = RichError<ErrorMessage>
throw Error(.failedToReadFile(path), cause: underlyingError)
```

## Code Style

- 2-space indentation
- Functional style: avoid global state, prefer static functions
- Swift 6 with typed throws

## Git Workflow

This repo is a fork of `stackotter/swift-bundler`:

```
origin    https://github.com/bmdragos/xclaude.git      # Our repo
upstream  https://github.com/stackotter/swift-bundler.git  # Original
```

**Important:**
- Always specify `--repo bmdragos/xclaude` for `gh` commands (releases, PRs, issues)
- Never push to upstream (stackotter's repo)
- Keep upstream to pull in Swift Bundler updates if needed

```bash
# Create releases
gh release create v3.1.0 --repo bmdragos/xclaude --title "Title" --notes "Notes"

# Pull upstream updates (if needed)
git fetch upstream
git merge upstream/main
```

## Distribution

Install via Mint:
```bash
mint install bmdragos/xclaude
```

This installs both `xclaude` and `swift-bundler` to `~/.mint/bin/`.
