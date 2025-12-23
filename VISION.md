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

## Design Principles

### 1. Convention Over Configuration

No decisions. Files go in predictable places.

```
MyApp/
├── xclaude.toml          # Single config file (always here)
├── icon.png              # App icon, 1024x1024 (always here)
├── Package.swift         # Swift package
├── Sources/
│   └── MyApp/
│       └── MyApp.swift
└── .xclaude/             # Generated workspace (gitignored)
    ├── derived/          # Generated assets, plists, entitlements
    └── cache/            # Signing info, device cache
```

Icon is always `icon.png` at root. Config is always `xclaude.toml`. No questions.

### 2. Progressive Disclosure

Start with almost nothing. Add complexity only when needed.

**Minimum viable config:**
```toml
[app]
name = "MyApp"
```

That's it. Everything else is discovered or defaulted:
- `bundle_id` → `com.developer.myapp` (derived from name)
- `team` → discovered from keychain
- `platform` → iOS
- `min_version` → iOS 17.0

**Add overrides as needed:**
```toml
[app]
name = "MyApp"
bundle_id = "com.mycompany.myapp"  # Override derived default

[signing]
team = "ABC123"  # Override auto-discovery

[platforms]
ios = "16.0"  # Override default
```

### 3. Auto-Discovery

Never ask for what we can find.

**Discovered automatically:**
- Team ID (from keychain certificates)
- Signing identity (from keychain)
- Provisioning profiles (from ~/Library/Developer/...)
- Connected devices (from devicectl)
- Available simulators (from simctl)

**Cached globally in `~/.xclaude/`:**
```json
{
  "default_team": "5N8M3V42V6",
  "identities": [...],
  "profiles": [...],
  "devices": [...]
}
```

### 4. Structured Errors with Auto-Fix

Errors must be machine-readable so Claude can reason about them.

```json
{
  "error": "provisioning_profile_mismatch",
  "message": "Bundle ID com.foo.myapp not covered by any profile",
  "context": {
    "bundle_id": "com.foo.myapp",
    "team": "ABC123",
    "available_profiles": [
      {"id": "abc123", "bundle_id": "com.foo.*", "name": "Wildcard Dev"}
    ]
  },
  "suggestion": "Use wildcard profile com.foo.* or change bundle_id",
  "fixable": true,
  "fix": {"action": "use_profile", "profile_id": "abc123"}
}
```

If `fixable: true`, Claude calls `fix_issue()` without bothering the user.

### 5. Single Icon

One 1024x1024 PNG. All sizes generated automatically.

No asset catalog management. No remembering which sizes iOS needs vs macOS.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Claude Code                     │
└─────────────────────┬───────────────────────────┘
                      │ MCP Protocol
┌─────────────────────▼───────────────────────────┐
│               xclaude MCP Server                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Auto-Discovery  │  Error Intelligence  │    │
│  └─────────────────────────────────────────┘    │
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

## MCP Tools

All tools return structured JSON. All errors include `fixable` flag.

### Project

```
create_project(name)
  → Creates project with xclaude.toml, Package.swift, placeholder icon
  → Returns {success, path, config}

get_config()
  → Returns current resolved config (with discovered values filled in)

update_config(key, value)
  → Updates xclaude.toml
  → Returns {success, config}

add_capability(name)
  → Adds capability + generates required entitlements
  → Returns {success, entitlements_added}

add_dependency(url, version?)
  → Adds SPM dependency to Package.swift
  → Returns {success, package}
```

### Build

```
build(platform?, configuration?)
  → Builds app
  → Returns {success, artifacts[], warnings[], errors[]}

clean()
  → Cleans .xclaude/derived and build artifacts
  → Returns {success}
```

### Deploy

```
list_devices()
  → Returns {devices: [{id, name, os_version, connected}]}

list_simulators()
  → Returns {simulators: [{id, name, os_version, state}]}

deploy(target?)
  → Installs to device or simulator
  → target: "simulator" | "device" | device_id | simulator_name
  → Default: simulator if no device connected
  → Returns {success, target, app_path}

run(target?)
  → build + deploy + launch
  → Returns {success, target, logs_streaming: true}
```

### Signing

```
get_signing_status()
  → Returns {configured, team, identity, profile, issues[]}

discover_signing()
  → Scans environment, updates cache
  → Returns {team, identities[], profiles[]}
```

### Diagnostics

```
diagnose()
  → Checks everything: config, signing, capabilities, environment
  → Returns {issues: [{id, error, message, fixable, fix?}]}

fix_issue(issue_id)
  → Attempts automatic fix
  → Returns {success, action_taken}
```

## What Claude Needs to Ask

**Required (no defaults possible):**
- App name

**Asked with smart defaults:**
- "iOS or macOS?" → default iOS
- "Device or simulator?" → default simulator (or device if connected)

**Never asked:**
- Team ID, signing identity, profiles → discovered
- Device IDs → discovered
- Icon sizes → generated from single PNG
- Entitlements → generated from capabilities

## Implementation Phases

### Phase 1: Foundation (Current)
- [x] Fork Swift Bundler
- [ ] Fix iOS app icons (actool flags + plist merge)
- [ ] Single icon → asset catalog generation
- [ ] Embed Swift Bundler as library

### Phase 2: MCP Server Core
- [ ] Basic MCP server in Swift
- [ ] `build()` tool
- [ ] `deploy()` tool
- [ ] `run()` tool
- [ ] `list_devices()` / `list_simulators()`

### Phase 3: Auto-Discovery
- [ ] Keychain identity scanning
- [ ] Provisioning profile scanning
- [ ] Device/simulator discovery
- [ ] Global cache (~/.xclaude/)
- [ ] `discover_signing()` tool

### Phase 4: Project Management
- [ ] `create_project()` with conventions
- [ ] `get_config()` / `update_config()`
- [ ] `add_capability()` with entitlement generation
- [ ] `add_dependency()`

### Phase 5: Intelligence
- [ ] `diagnose()` tool
- [ ] `fix_issue()` tool
- [ ] Structured errors with `fixable` flag
- [ ] Auto-fix for common issues

## Non-Goals

- CLI interface (MCP only - Claude is the interface)
- App Store submission (dev workflow only)
- Xcode feature parity (replacing xcodeproj, not Xcode)
- Every edge case (optimize for the common path)

## Success

Claude can say:

> "I'll create an iOS app for you, add push notifications,
> build it, and put it on your phone."

And then just... do it.

---

*Skate to where the puck is going.*
