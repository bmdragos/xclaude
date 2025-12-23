# xclaude Implementation Plan

## Architecture Decisions

### 1. Repository Structure

MCP server lives in this repo as a new target. Structure:

```
xclaude/
├── Sources/
│   ├── swift-bundler/          # Existing CLI (keep for now)
│   ├── SwiftBundler/           # Core library (the engine)
│   ├── xclaude/                # NEW: MCP server executable
│   └── XClaudeCore/            # NEW: MCP logic, discovery, config translation
├── xclaude.toml                # Example/test config
└── PLAN.md
```

### 2. Config Format

**User-facing:** `xclaude.toml` (simple, minimal)
**Internal:** Generate `Bundler.toml` in `.xclaude/derived/`

User never sees Bundler.toml. We translate xclaude.toml → Bundler.toml internally. This keeps Swift Bundler's config parsing intact while giving users a clean interface.

```toml
# xclaude.toml - what the user writes
[app]
name = "MyApp"
bundle_id = "com.company.myapp"  # optional, derived from name if missing

[signing]
team = "ABC123"  # optional, discovered if missing
```

```toml
# .xclaude/derived/Bundler.toml - generated, never edited
format_version = 2

[apps.MyApp]
identifier = "com.company.myapp"
product = "MyApp"
version = "1.0.0"
icon = "icon.png"
```

### 3. Device Deployment from Day 1

No "simulator-only MVP". Device deployment is core functionality.

This means signing auto-discovery is in the critical path:
- Keychain identity scanning
- Provisioning profile parsing
- Entitlements generation

### 4. MCP Protocol

Implement JSON-RPC over stdio ourselves. It's ~100 lines of Swift. No external dependencies needed.

---

## Implementation Phases

### Phase 1: Verify & Fix iOS Build ✅ COMPLETE

**Goal:** `swift-bundler run -p iOSSimulator` works with correct icons.

- [x] **1.1** Test current iOS build state
  - Created test project, built for iOS simulator
  - Found: No Assets.car, no icon files, wrong Info.plist entries

- [x] **1.2** Fix iOS icons
  - Modified `PlistCreator.swift`: Only add CFBundleIconFile/Name for macOS
  - Modified `DarwinBundler.swift`: Added `compileAppIconForNonMac()` method
  - Creates temp asset catalog, compiles with actool --app-icon flag
  - Merges partial plist into Info.plist

- [x] **1.3** Verify fix works
  - Built test app with icon.png for iOS simulator
  - Confirmed: Assets.car, AppIcon60x60@2x.png, CFBundleIcons in plist

### Phase 2: Signing Discovery ✅ COMPLETE

**Goal:** Automatically find signing identity, provisioning profile, team ID.

- [x] **2.1** Identity discovery
  - Run `security find-identity -v -p codesigning`
  - Parse output, extract identity names and team IDs
  - Implemented in `SigningDiscovery.discoverIdentities()`

- [x] **2.2** Provisioning profile discovery
  - Scan `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`
  - Parse .mobileprovision files using openssl to extract plist
  - Extract: bundle ID pattern, team ID, platforms, expiry
  - Implemented in `SigningDiscovery.discoverProfiles()`

- [x] **2.3** Simulator/device discovery
  - Parse `xcrun simctl list devices -j`
  - Parse `xcrun devicectl list devices -j`
  - Filter by platform, state (booted_only)
  - Implemented in `MCPTools.listSimulators()` and `listDevices()`

- [x] **2.4** Global cache
  - Created `~/.xclaude/` directory
  - Store signing data with TTL (5 min for signing, 1 min for simulators, 30s for devices)
  - Implemented in `GlobalCache.swift` with Codable types

- [ ] **2.5** Profile matching (deferred to Phase 3)
  - Given a bundle ID, find matching profile (exact or wildcard)
  - Extract entitlements from profile
  - Generate entitlements file

### Phase 3: MCP Server Core ✅ COMPLETE

**Goal:** Basic MCP server that can build and deploy.

- [x] **3.1** Create MCP server targets
  - Added `xclaude` executable target
  - Added `XClaudeCore` library target
  - Updated Package.swift

- [x] **3.2** Implement MCP protocol
  - JSON-RPC 2.0 over stdio
  - Tool registration via `tools/list`
  - Request/response handling via `tools/call`
  - Implemented in `MCPServer.swift`

- [x] **3.3** Config translation
  - Parse xclaude.toml via `XClaudeConfig.swift`
  - Generate Bundler.toml via `ConfigTranslator.swift`
  - Format version 2 with `format_version` key
  - Handle defaults (bundle ID derived from app name)

- [x] **3.4** Implement `build()` tool
  - `BuildRunner.swift` shells out to swift-bundler
  - Returns structured result with app path, warnings, errors
  - Generates Bundler.toml before build, cleans up after

- [x] **3.5** Implement `list_devices()` and `list_simulators()`
  - Call devicectl / simctl
  - Parse and return structured data
  - Filter by platform, booted state

- [x] **3.6** Implement `deploy()`
  - `DeployRunner.swift` handles simulator and device
  - Simulator: `xcrun simctl install` + `simctl launch`
  - Device: `xcrun devicectl device install app` + `device process launch`
  - Auto-boots simulator if none running

- [x] **3.7** Implement `run()`
  - Composes: build → deploy → launch
  - Returns combined result with build and deploy status

- [x] **3.8** Implement `init_project()` and `get_config()`
  - `init_project`: Creates xclaude.toml from Package.swift
  - `get_config`: Returns resolved config with signing status

### Phase 4: Project Conventions ✅ COMPLETE

**Goal:** `create_project()` generates conventional structure.

- [x] **4.1** Implement `create_project(name)`
  - Generate Package.swift with SwiftUI template
  - Generate minimal xclaude.toml
  - Create Sources/{name}/{name}App.swift and ContentView.swift
  - Generate .gitignore with Swift/xclaude patterns
  - Note: User must add 1024x1024 icon.png (not auto-generated)

- [x] **4.2** Implement `get_config()` (already done in Phase 3)
  - Return resolved config (defaults + discovery + overrides)
  - Show signing status

- [x] **4.3** Implement `update_config(key, value)`
  - Update xclaude.toml via ConfigUpdater
  - Supports: app.name, app.bundle_id, app.version, app.icon, signing.team, signing.identity, signing.profile

- [x] **4.4** Implement `add_capability(name)` + `list_capabilities()`
  - Map capability to required entitlements via CapabilityManager
  - Generate Entitlements.plist in .xclaude/derived/
  - Supports: push-notifications, app-groups, icloud, keychain, healthkit, homekit, in-app-purchase, network-extension, siri, wallet, background-modes

### Phase 4.5: Device Signing ✅ COMPLETE

**Goal:** Automatic code signing for physical device builds.

- [x] **4.5.1** Profile matching
  - Match bundle ID to provisioning profile (exact or wildcard)
  - Sort wildcards by specificity (most specific prefix wins)
  - Implemented in `SigningDiscovery.findMatchingProfile()`

- [x] **4.5.2** Identity matching
  - Match team ID to signing identity
  - Prefer "Apple Development" over other certificate types
  - Implemented in `SigningDiscovery.findMatchingIdentity()`

- [x] **4.5.3** Entitlements generation
  - Generate required signing entitlements: application-identifier, team-identifier, get-task-allow, keychain-access-groups
  - Merge with any capability entitlements from `add_capability`
  - Implemented in `SigningDiscovery.generateEntitlements()`

- [x] **4.5.4** BuildRunner integration
  - Resolve signing when platform requires it (iOS, tvOS, visionOS device builds)
  - Pass --identity, --entitlements, --provisioning-profile to swift-bundler
  - Include signing info in BuildResult for transparency

### Phase 5: Developer Experience ✅ COMPLETE

**Goal:** Remove all friction from the create → build → debug → iterate cycle.

#### 5.1 Debugging & Visibility ✅ COMPLETE

- [x] **5.1.1** Implement `screenshot`
  - Capture simulator screen: `xcrun simctl io booted screenshot`
  - Returns file path to PNG
  - **Priority: HIGH** - Essential for seeing what's happening

- [x] **5.1.2** Implement `get_logs`
  - Uses `log show --last 10s` on simulator
  - Filter by app bundle ID
  - Return recent log lines (configurable count)
  - **Priority: HIGH** - Essential for debugging

- [x] **5.1.3** Implement `get_crash_logs`
  - Find crash reports in `~/Library/Logs/DiagnosticReports/`
  - Parse .ips and .crash files, extract bundle ID, exception type, date
  - **Priority: MEDIUM** - Helpful for crashes

#### 5.2 Testing ✅ COMPLETE

- [x] **5.2.1** Implement `test`
  - Run `swift test` and parse output
  - Return structured results: passed, failed, skipped counts
  - Include failure details
  - **Priority: HIGH** - Essential for quality

- [ ] **5.2.2** Implement `test_ui` (future)
  - Run UI tests via xcodebuild
  - Capture screenshots on failure
  - **Priority: LOW** - Nice to have

#### 5.3 Dependency Management ✅ COMPLETE

- [x] **5.3.1** Implement `add_dependency`
  - Parse Package.swift
  - Add SPM dependency with version
  - Creates dependencies array if missing
  - **Priority: HIGH** - Very common need

- [ ] **5.3.2** Implement `list_dependencies`
  - Parse Package.swift and show current dependencies
  - Show available updates (via SPM)
  - **Priority: LOW** - Nice to have

#### 5.4 Simulator Management ✅ PARTIAL

- [x] **5.4.1** Implement `reset_simulator`
  - Erase simulator: `xcrun simctl erase <udid>`
  - Auto-detects booted simulator
  - **Priority: MEDIUM** - Helpful for stuck states

- [ ] **5.4.2** Implement `boot_simulator`
  - Boot specific simulator by name or UDID
  - Currently embedded in deploy, extract standalone
  - **Priority: LOW** - Already works via deploy

- [ ] **5.4.3** Implement `create_simulator`
  - Create new simulator: `xcrun simctl create`
  - Specify device type and runtime
  - **Priority: LOW** - Rarely needed

#### 5.5 Icon Generation ✅ COMPLETE

- [x] **5.5.1** Implement `generate_icon`
  - Create placeholder 1024x1024 PNG using CoreGraphics/AppKit
  - App name text on gradient background
  - Auto-detects app name from xclaude.toml or directory
  - **Priority: MEDIUM** - Every new project needs an icon

#### 5.6 Environment & Diagnostics ✅ COMPLETE

- [ ] **5.6.1** Error wrapper (deferred)
  - All errors include: code, message, context, suggestion, fixable
  - Consistent JSON structure across all tools

- [x] **5.6.2** Implement `diagnose`
  - Check config validity (Package.swift, xclaude.toml, icon.png)
  - Check signing status (identities, profiles)
  - Check environment (Xcode, simulators, swift-bundler)
  - Return status (healthy/degraded/unhealthy) with issues array

### Phase 6: Release & Distribution ✅ COMPLETE

**Goal:** Prepare apps for App Store submission.

- [x] **6.1** Implement `archive`
  - Build in release mode for iOS
  - Find matching distribution signing (identity + profile)
  - Package as .ipa (Payload/App.app structure)
  - Return path, file size, signing info

- [x] **6.2** Implement `validate`
  - Validate .app, .ipa, or project directory
  - Check Info.plist (bundle ID, version, required keys)
  - Check icons, code signature, embedded provisioning
  - Return structured issues with severity and fixable flags

- [x] **6.3** Implement `upload`
  - Upload .ipa to App Store Connect via altool
  - Support API Key auth (preferred) or Apple ID auth
  - Handle common errors (auth failed, version exists, bundle ID not registered)
  - Return upload status and request ID

### Phase 7: Advanced Features ✅ COMPLETE

**Goal:** Support complex app architectures.

- [x] **7.1** Implement `watch` + `stop_watch`
  - File watching with auto-rebuild on save
  - Polls Sources/ for .swift file changes
  - Automatically rebuilds and redeploys to simulator
  - Configurable poll interval

- [x] **7.2** Implement `add_model` (SwiftData scaffolding)
  - Generate @Model class with properties
  - Smart attributes: @Attribute(.unique) for IDs, @Attribute(.externalStorage) for Data
  - Proper init with optional defaults
  - Creates Models/ directory automatically

- [x] **7.3** Implement `add_extension`
  - App extension scaffolding (widget, share, action, today, intents, notification)
  - Generates complete, working extension code
  - Updates Package.swift with new target
  - Derives bundle ID from parent app

- [x] **7.4** Implement `generate_api_client`
  - Parse OpenAPI/Swagger JSON specs
  - Generate typed API client with async/await
  - Generate Codable model structs from schemas
  - Creates Network/ directory with all generated files

---

## Current Status

**Phase:** 7 - Advanced Features ✅ COMPLETE
**Completed:** Phase 1-7 (iOS Icons, Signing Discovery, MCP Server Core, Project Conventions, Device Signing, Developer Experience, Release & Distribution, Advanced Features)
**Status:** All planned phases complete! xclaude is a fully-featured MCP server for iOS/macOS app development.

### Working MCP Tools (30 total)

| Tool | Status | Description |
|------|--------|-------------|
| `discover_signing` | ✅ Working | Discover identities + profiles, cached for 5 min |
| `get_signing_status` | ✅ Working | Quick summary: configured?, team ID, counts |
| `list_simulators` | ✅ Working | iOS/tvOS/visionOS simulators, filterable |
| `list_devices` | ✅ Working | Connected physical devices |
| `init_project` | ✅ Working | Creates xclaude.toml from Package.swift |
| `get_config` | ✅ Working | Returns resolved config + signing status |
| `build` | ✅ Working | Builds app via swift-bundler |
| `deploy` | ✅ Working | Installs + launches on simulator/device |
| `run` | ✅ Working | Composes build → deploy → launch |
| `create_project` | ✅ Working | Creates new SwiftUI app with Package.swift, xclaude.toml |
| `update_config` | ✅ Working | Updates xclaude.toml values |
| `add_capability` | ✅ Working | Adds entitlements for capabilities |
| `list_capabilities` | ✅ Working | Lists available capabilities |
| `configure_signing` | ✅ Working | Shows signing options, auto-applies best match |
| `screenshot` | ✅ Working | Capture simulator screenshot |
| `get_logs` | ✅ Working | Get recent simulator logs |
| `test` | ✅ Working | Run swift test with parsed results |
| `add_dependency` | ✅ Working | Add SPM dependency to Package.swift |
| `reset_simulator` | ✅ Working | Reset simulator to clean state |
| `generate_icon` | ✅ Working | Generate placeholder 1024x1024 icon with app name |
| `get_crash_logs` | ✅ Working | Find and parse crash reports |
| `diagnose` | ✅ Working | Check environment health, identify issues |
| `archive` | ✅ Working | Build release + package as .ipa for distribution |
| `validate` | ✅ Working | Validate app against App Store requirements |
| `upload` | ✅ Working | Upload .ipa to App Store Connect |
| `watch` | ✅ Working | Auto-rebuild on file changes |
| `stop_watch` | ✅ Working | Stop the file watcher |
| `add_model` | ✅ Working | Generate SwiftData @Model class |
| `add_extension` | ✅ Working | Add app extension (widget, share, etc.) |
| `generate_api_client` | ✅ Working | Generate API client from OpenAPI spec |

### End-to-End Test Results

Tested full flow on `/tmp/xclaude-test/FinalTest`:
1. `create_project` → Created SwiftUI app structure
2. Added 1024x1024 icon.png
3. `build` → Generated Bundler.toml, built app with icon
4. `deploy` → Installed on iPhone 16 Pro simulator
5. App launched successfully (PID 32872)

---

## File Locations

| Purpose | Location |
|---------|----------|
| MCP server entry | `Sources/xclaude/main.swift` |
| MCP protocol impl | `Sources/XClaudeCore/MCP/MCPServer.swift` |
| MCP tool definitions | `Sources/XClaudeCore/MCP/MCPTools.swift` |
| Config types | `Sources/XClaudeCore/Config/XClaudeConfig.swift` |
| Config translation | `Sources/XClaudeCore/Config/ConfigTranslator.swift` |
| Config updates | `Sources/XClaudeCore/Config/ConfigUpdater.swift` |
| Project scaffolding | `Sources/XClaudeCore/Project/ProjectScaffold.swift` |
| Build runner | `Sources/XClaudeCore/Build/BuildRunner.swift` |
| Deploy runner | `Sources/XClaudeCore/Deploy/DeployRunner.swift` |
| Discovery logic | `Sources/XClaudeCore/Discovery/SigningDiscovery.swift` |
| Global cache | `Sources/XClaudeCore/Cache/GlobalCache.swift` |
| iOS icon fix | `Sources/SwiftBundler/Bundler/Bundlers/Darwin/DarwinBundler.swift` |
| Info.plist generation | `Sources/SwiftBundler/Bundler/Bundlers/Darwin/PlistCreator.swift` |

---

## Test Credentials (from research/NOTES.md)

For development/testing:
- Team ID: `5N8M3V42V6`
- Identity: `Apple Development: Brandon Dragos (PQ7368HKNW)`
- Test Device: `00008130-000605841AE0001C`
