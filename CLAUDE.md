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
