# xclaude

> Terraform for Apple development. Declarative. Headless. AI-native.

**What Terraform did for cloud infrastructure, xclaude does for iOS/macOS development.**

Describe what you want. xclaude figures out how.

## What This Is

An MCP server that lets Claude Code build, sign, and deploy iOS/macOS/visionOS apps without Xcode project files, without memorizing xcrun commands, without provisioning profile hell.

Claude talks to xclaude. xclaude handles the rest.

## The Problem

Building Apple platform apps requires tribal knowledge:

```
"Use xcrun actool with --app-icon and --output-partial-info-plist, 
then merge the plist with PlistBuddy, then re-sign with codesign 
using the entitlements file that you created manually..."
```

This is insane. Claude shouldn't need to know this. YOU shouldn't need to know this.

## The Solution

Claude asks xclaude to do things. xclaude does them.

```
Claude: "Build for iOS and put it on my phone"
         ↓
     xclaude MCP
         ↓
     [magic happens]
         ↓
     App on phone
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Claude Code                     │
└─────────────────────┬───────────────────────────┘
                      │ MCP Protocol
┌─────────────────────▼───────────────────────────┐
│               xclaude MCP Server                 │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│         Swift Bundler Engine (embedded)          │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│              Apple Toolchain                     │
│    xcrun, codesign, actool, devicectl, etc.     │
└─────────────────────────────────────────────────┘
```

## Project Config

One file. Everything in it.

```toml
# xclaude.toml

[app]
name = "MyApp"
bundle_id = "com.company.myapp"
version = "1.0.0"

[platforms]
ios = "17.0"
macos = "14.0"

[icon]
source = "icon.png"  # One image. All sizes generated.

[signing]
team = "ABC123"
# Identity and profile auto-discovered

[capabilities]
push_notifications = true
keychain_sharing = ["com.company.*"]

[devices]
iphone = "00008130-000605841AE0001C"
ipad = "00008120-..."
```

No `.xcodeproj`. No `*.entitlements`. No 20 icon sizes. No `Info.plist`.

## MCP Tools

### Project

```
create_project(name, platforms[], template?)
  → Creates project structure + xclaude.toml

get_config()
  → Returns current xclaude.toml

update_config(key, value)
  → Updates config

add_capability(name, options?)
  → Adds capability + required entitlements

add_dependency(package_url, version)
  → Adds SPM dependency
```

### Build

```
build(platform, configuration?)
  → Builds app, returns { success, artifacts[], errors[] }

get_errors()
  → Returns structured build errors with suggested fixes

clean()
  → Cleans build artifacts
```

### Devices

```
list_devices()
  → Returns connected devices with names, IDs, OS versions

list_simulators()
  → Returns available simulators

save_device(name, id)
  → Saves device to config with friendly name
```

### Deploy

```
deploy(target)
  → Installs to device or simulator
  → target: "iphone" | "simulator:iPhone 16" | device_id

run(target?)
  → build + deploy + launch
  → Uses last target if not specified
```

### Signing

```
get_signing_status()
  → Returns current signing config, any issues

list_identities()
  → Returns available signing identities

list_profiles()
  → Returns provisioning profiles

configure_signing(team_id)
  → Auto-discovers identity + profile, updates config
```

### Assets

```
generate_icons(source_png)
  → Creates all required icon sizes for all platforms

compile_assets()
  → Compiles asset catalogs with correct flags
```

### Diagnostics

```
diagnose()
  → Checks everything: signing, capabilities, config
  → Returns issues with fix suggestions

fix_issue(issue_id)
  → Attempts automatic fix
```

## Error Philosophy

Every error must be:
1. **Specific** - What exactly failed
2. **Contextual** - What state we're in
3. **Actionable** - How to fix it

```json
{
  "error": "signing_profile_missing",
  "message": "No provisioning profile found for com.company.myapp",
  "context": {
    "bundle_id": "com.company.myapp",
    "team": "ABC123",
    "available_profiles": [
      { "id": "...", "bundle_id": "com.company.*", "name": "Wildcard Dev" }
    ]
  },
  "suggestion": "Use wildcard profile? Call configure_signing() to auto-select."
}
```

## What Claude Can Do

With xclaude, Claude can:

- **Create a new iOS app from scratch** - `create_project("MyApp", ["ios"])`
- **Add push notifications** - `add_capability("push_notifications")`
- **Build and deploy** - `run("iphone")`
- **Fix signing issues** - `diagnose()` → `fix_issue("signing_profile_missing")`
- **Generate app icons** - `generate_icons("logo.png")`

All without knowing:
- How xcrun actool works
- What entitlements are needed for which capabilities
- How to merge plists
- What codesign flags to use
- How to find provisioning profiles

## Implementation Phases

### Phase 1: Foundation
- [x] Fork Swift Bundler
- [ ] Fix iOS app icons
- [ ] Add signing to config
- [ ] Add entitlements to config
- [ ] Embed as library

### Phase 2: MCP Server
- [ ] Basic MCP server structure
- [ ] `build()` tool
- [ ] `deploy()` tool
- [ ] `run()` tool
- [ ] `list_devices()` / `list_simulators()`

### Phase 3: Project Management
- [ ] `create_project()` tool
- [ ] `get_config()` / `update_config()`
- [ ] `add_capability()`
- [ ] `add_dependency()`

### Phase 4: Intelligence
- [ ] `diagnose()` tool
- [ ] `fix_issue()` tool
- [ ] Structured error messages
- [ ] Auto-discovery (signing, devices)

### Phase 5: Assets
- [ ] `generate_icons()` - single PNG to all sizes
- [ ] `compile_assets()` - proper iOS icon handling

## Non-Goals

- CLI interface (MCP only)
- App Store submission (dev workflow only)
- Xcode feature parity (not replacing Xcode, replacing xcodeproj)
- Supporting every edge case (optimize for common path)

## Success

Claude can say:

> "I'll create an iOS app for you, add push notifications, 
> build it, and put it on your phone."

And then just... do it.

---

*Skate to where the puck is going.*
