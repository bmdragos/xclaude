# xclaude

**Terraform for Apple development.** An MCP server that lets Claude Code build, sign, and deploy iOS/macOS/visionOS apps without Xcode project files.

## What is this?

xclaude is an [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) server that gives Claude Code the ability to:

- Create iOS/macOS apps from scratch
- Build and deploy to simulators and physical devices
- Automatically discover and configure code signing
- Run tests, capture screenshots, read logs
- Generate SwiftData models, widgets, and API clients
- Archive and upload to the App Store

All without ever opening Xcode or creating an `.xcodeproj` file.

## Installation

### Build from source

```bash
git clone https://github.com/bmdragos/xclaude.git
cd xclaude
swift build -c release
```

The binary will be at `.build/release/xclaude`.

### Add to Claude Code

Add to your Claude Code MCP settings (`~/.claude/settings.json` or project `.claude/settings.json`):

```json
{
  "mcpServers": {
    "xclaude": {
      "command": "/path/to/xclaude"
    }
  }
}
```

Or use the build directory directly:

```json
{
  "mcpServers": {
    "xclaude": {
      "command": "/Users/you/xclaude/.build/release/xclaude"
    }
  }
}
```

Restart Claude Code to load the MCP server.

## Quick Start

Once configured, just ask Claude:

> "Create a new iOS app called TaskMaster"

Claude will use xclaude to:
1. Create the project structure
2. Generate `Package.swift` and `xclaude.toml`
3. Scaffold SwiftUI app code
4. Build and deploy to the simulator

### Project Structure

xclaude uses conventions:

```
MyApp/
├── xclaude.toml          # Simple config (the only config you need)
├── icon.png              # 1024x1024 app icon
├── Package.swift         # Swift Package Manager manifest
├── Sources/MyApp/
│   ├── MyAppApp.swift    # @main entry point
│   └── ContentView.swift
└── .xclaude/             # Generated (gitignored)
    └── derived/          # Bundler.toml, entitlements, etc.
```

### Configuration

`xclaude.toml` is intentionally minimal:

```toml
[app]
name = "MyApp"
# bundle_id = "com.company.myapp"  # Optional, derived from name
# version = "1.0.0"                # Optional, defaults to 1.0.0

[signing]
# team = "ABC123XYZ"               # Optional, auto-discovered
# identity = "Apple Development"   # Optional, auto-discovered
# profile = "iOS Team Provisioning" # Optional, auto-discovered
```

Most projects only need the app name. Everything else is auto-discovered.

## Features

### 31 MCP Tools

| Category | Tools |
|----------|-------|
| **Project** | `create_project`, `init_project`, `get_config`, `update_config` |
| **Signing** | `discover_signing`, `get_signing_status`, `configure_signing` |
| **Build** | `build`, `deploy`, `run`, `watch`, `stop_watch` |
| **Devices** | `list_simulators`, `list_devices`, `reset_simulator` |
| **Debug** | `screenshot`, `get_logs`, `get_crash_logs`, `diagnose` |
| **Test** | `test` |
| **Dependencies** | `add_dependency` |
| **Capabilities** | `add_capability`, `list_capabilities` |
| **Distribution** | `archive`, `validate`, `upload` |
| **Scaffolding** | `generate_icon`, `add_model`, `add_extension`, `generate_api_client` |
| **Info** | `get_version` |

### Example Workflows

**Create and run a new app:**
> "Create an iOS app called WeatherApp and run it on the simulator"

**Add a SwiftData model:**
> "Add a SwiftData model called Task with properties: id (UUID), title (String), isComplete (Bool), dueDate (Date?)"

**Add a widget:**
> "Add a widget extension to my app"

**Deploy to physical device:**
> "Build and deploy to my iPhone"

**Prepare for App Store:**
> "Archive my app for App Store submission"

**Debug issues:**
> "Take a screenshot of the simulator and show me the recent logs"

**Add macOS automation capability:**
> "Add the apple-events capability so my app can control other apps"

### Capabilities (61 available)

`add_capability` automatically handles both entitlements AND Info.plist:

```
add_capability("apple-events")
        ↓
┌─────────────────────────────────────────────────────────────┐
│ Entitlements.plist:                                         │
│   com.apple.security.automation.apple-events = true         │
│                                                             │
│ Info.plist:                                                 │
│   NSAppleEventsUsageDescription = "This app needs to..."   │
└─────────────────────────────────────────────────────────────┘
        ↓
    build (macOS)  →  automatically signed with entitlements
```

**iOS/Shared:** push-notifications, app-groups, icloud, keychain, healthkit, homekit, in-app-purchase, siri, wallet, background-modes, and more.

**macOS:** apple-events, hardened-runtime, camera, microphone, location, files-read-write, system-extension, network-client, network-server, bluetooth, usb, print, serial, app-sandbox, and more.

**Continuity/Ecosystem:** handoff, associated-domains, sign-in-with-apple, shareplay, nfc, carplay, weatherkit, and more.

**Notifications:** critical-alerts, time-sensitive, communication-notifications.

**Newer APIs:** shazamkit, musickit, push-to-talk, matter, financekit, devicecheck.

**Performance:** increased-memory-limit, extended-virtual-addressing.

**Other:** personal-vpn, data-protection, family-controls, autofill-credentials, maps-routing.

Run `list_capabilities` to see all 61 with platform info.

## Auto-Discovery

xclaude automatically discovers:

- **Signing identities** from your keychain
- **Provisioning profiles** from `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`
- **Simulators** via `xcrun simctl`
- **Physical devices** via `xcrun devicectl`

Run `configure_signing` to see available options and auto-apply the best match.

## Supported Platforms

- iOS / iPadOS
- macOS
- tvOS
- visionOS

## Requirements

- macOS with Xcode Command Line Tools
- Swift 5.9+
- For physical devices: Apple Developer account with provisioning profiles

## How It Works

xclaude is built on top of [Swift Bundler](https://github.com/stackotter/swift-bundler), a tool for building Swift apps without Xcode. xclaude adds:

1. **MCP interface** - JSON-RPC 2.0 protocol for Claude Code integration
2. **Auto-discovery** - Automatic signing credential detection
3. **Config translation** - Simple `xclaude.toml` → Swift Bundler's `Bundler.toml`
4. **Scaffolding** - Project, model, extension, and API client generation
5. **Developer tools** - Screenshots, logs, diagnostics

## Troubleshooting

### "No signing identity found"

Run `discover_signing` to see available identities, or:

```bash
security find-identity -v -p codesigning
```

### "No provisioning profile found"

For simulators, no profile is needed. For devices:
1. Open Xcode → Preferences → Accounts
2. Download provisioning profiles
3. Run `configure_signing` in xclaude

### Build fails

Run `diagnose` to check your environment:
- Xcode installation
- Package.swift validity
- Icon presence
- Signing status

## License

MIT

## Credits

Built on [Swift Bundler](https://github.com/stackotter/swift-bundler) by stackotter.
