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

## Current Phase: Signing Discovery

- [x] Fork Swift Bundler
- [x] Fix iOS app icons (completed Dec 23, 2024)
- [ ] Implement signing discovery
- [ ] Create MCP server targets

## What Was Fixed (iOS Icons)

**Problem:** iOS apps had no icons - wrong actool flags, wrong Info.plist entries.

**Solution:**
- `PlistCreator.swift`: Only add CFBundleIconFile/Name for macOS
- `DarwinBundler.swift`: Added `compileAppIconForNonMac()` that:
  1. Creates temp asset catalog with AppIcon.appiconset
  2. Compiles with `actool --app-icon AppIcon --output-partial-info-plist`
  3. Merges partial plist into Info.plist

## Key Files

| File | Purpose |
|------|---------|
| `Sources/SwiftBundler/Bundler/ResourceBundler.swift` | Asset catalog compilation (iOS icon fix) |
| `Sources/SwiftBundler/Bundler/DarwinBundler.swift` | macOS/iOS bundling |
| `Sources/SwiftBundler/Bundler/CodeSigner/CodeSigner.swift` | Code signing |
| `Sources/SwiftBundler/Configuration/` | Config parsing |

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
