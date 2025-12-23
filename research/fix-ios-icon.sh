#!/bin/bash
# fix-ios-icon.sh - Compiles asset catalog and re-signs app for iOS
# Run this after: swift-bundler bundle -p iOS ...

set -e

APP_PATH=".build/bundler/DexaFitAdmin.app"
ASSETS_PATH="Sources/DexaFitAdmin/Resources/Assets.xcassets"
IDENTITY="Apple Development: Brandon Dragos (PQ7368HKNW)"
TEAM_ID="5N8M3V42V6"
BUNDLE_ID="com.dexafit.admin"

echo "Compiling asset catalog..."
xcrun actool "$ASSETS_PATH" \
  --compile "$APP_PATH" \
  --platform iphoneos \
  --minimum-deployment-target 17.0 \
  --app-icon AppIcon \
  --output-partial-info-plist /tmp/assetcatalog_generated_info.plist

echo "Updating Info.plist..."
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP_PATH/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$APP_PATH/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Merge /tmp/assetcatalog_generated_info.plist" "$APP_PATH/Info.plist"

echo "Creating entitlements..."
cat > /tmp/entitlements.plist << EOF
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
		<string>com.apple.token</string>
	</array>
</dict>
</plist>
EOF

echo "Re-signing app..."
codesign --force --sign "$IDENTITY" --entitlements /tmp/entitlements.plist "$APP_PATH"

echo "Done! App ready for installation."
