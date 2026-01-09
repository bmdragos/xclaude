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

## Status: v3.0.0 Released

- [x] Fork Swift Bundler
- [x] Fix iOS app icons
- [x] Implement signing discovery
- [x] Create MCP server (31 tools, 61 capabilities)
- [x] Mint distribution (`mint install bmdragos/xclaude`)

## Key Files

| File | Purpose |
|------|---------|
| `Sources/XClaudeCore/MCP/MCPTools.swift` | All 31 MCP tool implementations (3800+ lines) |
| `Sources/XClaudeCore/MCP/MCPServer.swift` | JSON-RPC 2.0 server |
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
│   └── MCPTools.swift      # All 31 tools (LARGE - consider splitting)
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
- **Sync** (`build` tool): `BuildRunner.build()` blocks until complete
- **Async** (`build_start/status/logs/cancel`): `BuildManager` returns job ID immediately

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
