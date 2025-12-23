# xclaude Research Notes

Research and findings that inform xclaude implementation.

See `VISION.md` for design principles and `CLAUDE.md` for developer guidance.

## iOS App Icon Fix

### Current State (Tested Dec 23, 2024)

- `swift-bundler bundle -p iOSSimulator` **builds successfully**
- But the app bundle has **no Assets.car** (compiled assets)
- Info.plist references `CFBundleIconFile: AppIcon` but no icon exists
- Templates don't include Assets.xcassets at all

### The Problem

Swift Bundler's `ResourceBundler.swift` (lines 22-31) calls `actool` without the flags needed for iOS app icons:

```swift
// Current (broken for iOS icons):
try await Process.create(
  "/usr/bin/xcrun",
  arguments: [
    "actool", assetCatalog.path,
    "--compile", destinationDirectory.path,
    "--platform", platform.sdkName,
    "--minimum-deployment-target", platformVersion,
  ]
).runAndWait()
```

### The Fix

1. Add `--app-icon AppIcon` flag to actool
2. Add `--output-partial-info-plist <path>` flag
3. Merge the generated partial plist into the app's Info.plist

### Working Reference

See `fix-ios-icon.sh` in this folder - a working workaround script.

Key actool invocation:
```bash
xcrun actool "$ASSETS_PATH" \
  --compile "$APP_PATH" \
  --platform iphoneos \
  --minimum-deployment-target 17.0 \
  --app-icon AppIcon \
  --output-partial-info-plist /tmp/assetcatalog_generated_info.plist
```

### Partial Plist Output Format

The `--output-partial-info-plist` flag generates this structure:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIcons</key>
	<dict>
		<key>CFBundlePrimaryIcon</key>
		<dict>
			<key>CFBundleIconFiles</key>
			<array>
				<string>AppIcon60x60</string>
			</array>
			<key>CFBundleIconName</key>
			<string>AppIcon</string>
		</dict>
	</dict>
	<key>CFBundleIcons~ipad</key>
	<dict>
		<key>CFBundlePrimaryIcon</key>
		<dict>
			<key>CFBundleIconFiles</key>
			<array>
				<string>AppIcon60x60</string>
				<string>AppIcon76x76</string>
			</array>
			<key>CFBundleIconName</key>
			<string>AppIcon</string>
		</dict>
	</dict>
</dict>
</plist>
```

### Plist Merge

Use PlistBuddy to merge:
```bash
/usr/libexec/PlistBuddy -c "Merge /tmp/assetcatalog_generated_info.plist" "$APP_PATH/Info.plist"
```

---

## Code Signing

### Test Signing Config

For development/testing xclaude:

| Field | Value |
|-------|-------|
| Team ID | `5N8M3V42V6` (DEXA FIT LLC) |
| Identity | `Apple Development: Brandon Dragos (PQ7368HKNW)` |
| Provisioning Profile | `50b26d1c-e6d4-473e-a8ca-8a6a1e9023f8.mobileprovision` |
| Profile Location | `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` |
| Test Device | `00008130-000605841AE0001C` (iPhone) |

### Entitlements Structure

Basic development entitlements:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>${TEAM_ID}.${BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${TEAM_ID}</string>
    <key>get-task-allow</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>${TEAM_ID}.${BUNDLE_ID}</string>
    </array>
</dict>
</plist>
```

---

## Swift Bundler Source Locations

Key files to modify:

| File | Purpose |
|------|---------|
| `Sources/SwiftBundler/Bundler/ResourceBundler.swift` | Asset catalog compilation (icon fix goes here) |
| `Sources/SwiftBundler/Bundler/Bundler.swift` | Main bundling orchestration |
| `Sources/SwiftBundler/Bundler/CodeSigner.swift` | Code signing logic |
| `Sources/swift-bundler/Commands/` | CLI commands (not needed for MCP-only) |

---

## Platform SDK Names

From Swift Bundler's Platform enum:

| Platform | SDK Name |
|----------|----------|
| iOS | `iphoneos` |
| iOSSimulator | `iphonesimulator` |
| macOS | `macosx` |
| visionOS | `xros` |
| visionOSSimulator | `xrsimulator` |
| tvOS | `appletvos` |
| tvOSSimulator | `appletvsimulator` |

---

## Device Deployment

Install to device:
```bash
xcrun devicectl device install app --device "<device-id>" <app-path>
```

List devices:
```bash
swift-bundler devices list
# or
xcrun devicectl list devices
```
