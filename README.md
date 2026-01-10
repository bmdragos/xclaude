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

### Install via Mint (recommended)

```bash
mint install bmdragos/xclaude
```

This installs both `xclaude` and `swift-bundler` to `~/.mint/bin/`.

> **Note:** First install takes 3-5 minutes to compile dependencies. Subsequent updates are faster.

### Build from source

```bash
git clone https://github.com/bmdragos/xclaude.git
cd xclaude
swift build -c release
```

The binaries will be at `.build/release/xclaude` and `.build/release/swift-bundler`.

### Add to Claude Code

Add to your Claude Code MCP settings (`~/.claude/settings.json` or project `.claude/settings.json`):

```json
{
  "mcpServers": {
    "xclaude": {
      "command": "~/.mint/bin/xclaude"
    }
  }
}
```

Or if you built from source:

```json
{
  "mcpServers": {
    "xclaude": {
      "command": "/path/to/xclaude/.build/release/xclaude"
    }
  }
}
```

Restart Claude Code to load the MCP server.

## Quick Start

Once configured, just ask Claude:

> "Create a new iOS app called TaskMaster and deploy it to my iPhone"

Claude will use xclaude to:
1. Create the project structure
2. Generate `Package.swift` and `xclaude.toml`
3. Scaffold SwiftUI app code
4. Discover signing credentials
5. Build and deploy to your device

> **For physical devices:** You'll need an Apple Developer account with provisioning profiles set up. Run `configure_signing` to auto-discover and apply credentials.

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

### 36 MCP Tools

| Category | Tools |
|----------|-------|
| **Project** | `create_project`, `init_project`, `get_config`, `update_config` |
| **Signing** | `discover_signing`, `get_signing_status`, `configure_signing` |
| **Build** | `build`, `build_start`, `build_status`, `build_logs`, `build_cancel` |
| **Deploy** | `deploy`, `run`, `watch`, `stop_watch` |
| **Devices** | `list_simulators`, `list_devices`, `reset_simulator` |
| **Debug** | `screenshot`, `get_logs`, `get_crash_logs`, `diagnose` |
| **Test** | `test` |
| **Dependencies** | `add_dependency` |
| **Capabilities** | `add_capability`, `remove_capability`, `list_capabilities` |
| **Distribution** | `archive`, `validate`, `upload` |
| **Scaffolding** | `generate_icon`, `add_model`, `add_extension`, `generate_api_client` |
| **Info** | `get_version` |

### Async Builds

For long-running builds, use the async pattern:

```
build_start(platform: "iOS")     → { job_id: "build-1" }
build_status(job_id: "build-1")  → { status: "running", duration: 45.2 }
build_logs(job_id: "build-1")    → { lines: [...], status: "success" }
```

This returns immediately and lets you poll for progress, similar to CI/CD job patterns.

### Example Workflows

**Create and run a new app:**
> "Create an iOS app called WeatherApp and deploy it to my iPhone"

**Build for Mac:**
> "Build and run my app on macOS"

**Add a SwiftData model:**
> "Add a SwiftData model called Task with properties: id (UUID), title (String), isComplete (Bool), dueDate (Date?)"

**Add a widget:**
> "Add a widget extension to my app"

**Prepare for App Store:**
> "Archive my app for App Store submission"

**Debug issues:**
> "Take a screenshot and show me the recent logs"

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

- macOS 13+
- Xcode Command Line Tools
- [Mint](https://github.com/yonaskolb/Mint) (for easy installation): `brew install mint`
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
1. Open Xcode → Settings → Accounts
2. Add your Apple ID and download provisioning profiles
3. Run `configure_signing` in xclaude

See Apple's [Distributing Your App to Registered Devices](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices) guide for detailed setup.

### Build fails

Run `diagnose` to check your environment:
- Xcode installation
- Package.swift validity
- Icon presence
- Signing status

### "A valid provisioning profile was not found" (device install fails)

This usually means one of:

1. **Certificate not in profile**: The profile was created before your signing certificate existed
   - Go to Apple Developer Portal → Profiles → Edit your profile
   - Check your certificate is selected
   - Regenerate and reinstall the profile

2. **Device not in profile**: Your device isn't registered to the profile
   - Check Portal → Devices for your device
   - Device UDIDs differ between formats: `devicectl` shows CoreDevice UUID, Portal shows hardware UDID
   - Both refer to the same device - use `xcrun devicectl device info details --device <udid>` to see hardware UDID

3. **Entitlement mismatch**: App has entitlements the profile doesn't allow
   - macOS sandbox entitlements (`com.apple.security.*`) don't work on iOS
   - xclaude v3.1+ automatically strips these for iOS builds

### Certificate shows in Xcode but not in keychain

If Xcode shows your certificate but `security find-identity -v -p codesigning` doesn't:

1. The private key wasn't saved when the cert was created
2. **Fix**: In Xcode → Settings → Accounts → Manage Certificates, delete the cert and create a new one
3. Or manually: Generate CSR in Keychain Access, upload to Portal, download and import the .cer

### Multiple teams/certificates confusion

Apple certificates embed the team ID in the Common Name (CN), but organizational certs may show a different team ID than the organization:

```
# Certificate might show:
"Apple Development: Your Name (PERSONAL_TEAM_ID)"
# But actually belong to:
OU=ORGANIZATION_TEAM_ID
```

xclaude will match based on the provisioning profile's team. Use `discover_signing` to see all available identities and profiles.

### Multi-platform apps (iOS + macOS)

xclaude supports building for multiple platforms from the same project:

```bash
# Build for iOS
build(platform: "iOS")

# Build for macOS
build(platform: "macOS")
```

Platform-specific entitlements are handled automatically:
- macOS sandbox entitlements are stripped from iOS builds
- Info.plist usage descriptions are added for iOS capabilities (camera, bluetooth, etc.)

## License

MIT

## Credits

Built on [Swift Bundler](https://github.com/stackotter/swift-bundler) by stackotter.
