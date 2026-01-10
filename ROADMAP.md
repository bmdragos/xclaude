# xclaude Roadmap

Feature ideas and implementation notes for future development.

## High Priority

### Dev ↔ Distribution Workflow

**Problem**: Switching between device testing and TestFlight/App Store submission is painful. Multiple manual steps, profile confusion, wrong entitlements.

**Issues to fix**:

1. **Single signing config** - Only one `[signing.iOS]` section, manual editing to switch
   - Add `[signing.iOS.development]` and `[signing.iOS.distribution]` sections
   - `build_start` uses development, `archive` uses distribution automatically

2. **Profile name collision** - ASC names ("Lode Bike Development") become just "Lode Bike" locally
   - Match profiles by UUID instead of display name
   - Or parse profile type from contents (development vs distribution)

3. **Wrong entitlements for archive** - `get-task-allow = true` even with distribution profile
   - `archive` must force `get-task-allow = false`
   - Detect profile type and set entitlements accordingly

4. **Missing Info.plist keys for App Store**:
   - `DTPlatformName` - required
   - `UIRequiredDeviceCapabilities` - should include `arm64`
   - `DTSDKName`, `DTXcode`, `DTXcodeBuild` - nice to have

5. **Upload ignores asc_configure** - Had to manually pass api_key params
   - Auto-use stored credentials from `~/.xclaude/asc_credentials.json`
   - Add `profile` parameter to `upload` tool

6. **Certificate naming** - API-created certs named "Created via API"
   - Pass proper common_name when creating CSR

**Implementation order**:
1. ~~Fix upload to auto-use ASC credentials (quick win)~~ ✅
2. ~~Add missing Info.plist keys for App Store~~ ✅
3. ~~Fix archive entitlements (get-task-allow = false)~~ ✅
4. ~~Add dual signing config support~~ ✅

---

### Device App Logs

**Problem**: Can't see app logs from physical devices. `get_logs` only works for simulator.

**Solution**: Use `idevicesyslog` from libimobiledevice to stream device logs.

**Implementation**:
```
start_device_logs(bundle_id?)  → { session_id }
get_device_logs(session_id)    → { lines: [...], buffered_remaining }
stop_device_logs(session_id)   → { lines: [...] }
```

**Details**:
- Dependency: `brew install libimobiledevice`
- Filter by process name (derived from xclaude.toml `app.name`)
- Command: `idevicesyslog -u <UDID> -p <ProcessName>`
- Buffer output (cap at ~5000 lines like build logs)
- Auto-detect: bundle_id from xclaude.toml, device from first connected

**Challenges**:
- Process name vs bundle ID (usually app.name matches process name)
- Log volume can be high even when filtered
- Need to start capture before/during app launch

**Future**: Monitor `devicectl` for native log streaming support in future Xcode versions.

---

### Structured Build Errors

**Problem**: Build failures dump raw log output. Have to hunt for actual errors.

**Solution**: Parse compiler output into structured JSON with file/line/message.

**Implementation**:
- Parse swift build output for error patterns: `path/file.swift:42:15: error: message`
- Return structured errors in build_status/build_logs when status=failed
- Include warning count, error count, first N errors

**Output format**:
```json
{
  "status": "failed",
  "errors": [
    { "file": "ContentView.swift", "line": 42, "column": 15, "message": "...", "severity": "error" }
  ],
  "errorCount": 3,
  "warningCount": 12
}
```

---

## Medium Priority

### Pre-flight Signing Check

**Problem**: Build succeeds but deploy fails due to signing issues (profile doesn't include device, cert expired, etc.). Wastes 30+ seconds on build.

**Solution**: `preflight_signing()` tool that validates signing will work before building.

**Checks**:
1. Certificate exists and is valid (not expired)
2. Provisioning profile exists and is valid
3. Profile includes the certificate
4. Profile includes the target device UDID
5. Bundle ID matches profile's app ID

**Output**:
```json
{
  "valid": false,
  "issues": [
    { "severity": "error", "message": "Device 00008130-... not in provisioning profile", "fix": "Add device to Apple Developer Portal and regenerate profile" }
  ]
}
```

---

### Build Progress

**Problem**: During builds, only see line count. No sense of "50% done".

**Solution**: Parse swift build output to extract progress.

**Implementation**:
- Swift outputs: `[15/47] Compiling MyApp ContentView.swift`
- Parse current/total from build output
- Add to build_status response: `"progress": { "current": 15, "total": 47, "phase": "compiling" }`

**Phases**: resolving dependencies, compiling, linking, bundling, signing

---

## Nice to Have

### Multi-device Deploy

**Problem**: Testing on multiple devices requires running deploy multiple times.

**Solution**: `deploy(targets: ["device1-udid", "device2-udid"])` deploys in parallel.

**Implementation**:
- Accept array of targets
- Run deployments concurrently
- Return results for each device

---

### Test on Device

**Problem**: `test` tool only works on simulator.

**Solution**: Add device testing support via `xcodebuild test -destination 'platform=iOS,id=<UDID>'`

**Challenges**:
- Needs signing for device
- Test results parsing
- May need different xcodebuild invocation than simulator

---

## Completed

### v3.10.0
- [x] Dev ↔ Distribution workflow improvements:
  - `upload` tool auto-uses ASC credentials from `asc_configure`
  - Added `profile` parameter to `upload` for multi-account support
  - Archive adds missing Info.plist keys (DTPlatformName, DTSDKName, DTPlatformVersion, DTXcode, DTXcodeBuild, UIRequiredDeviceCapabilities)
  - Archive forces `get-task-allow = false` for distribution entitlements
  - Dual signing config: `[signing.iOS.development]` and `[signing.iOS.distribution]` sections in xclaude.toml
  - Build uses development signing, archive uses distribution signing automatically

### v3.9.0
- [x] App Store Connect API integration (24 tools)
  - Device registration: `asc_list_devices`, `asc_register_device`
  - Provisioning profiles: `asc_list_profiles`, `asc_create_profile`, `asc_delete_profile`, `asc_download_profile`, `asc_regenerate_profile`
  - Certificates: `asc_list_certificates`, `asc_create_certificate`, `asc_revoke_certificate`
  - Bundle IDs: `asc_list_bundle_ids`, `asc_create_bundle_id`
  - Apps: `asc_list_apps`, `asc_create_app` (returns manual steps - Apple API limitation)
  - TestFlight: `asc_list_builds`, `asc_list_groups`, `asc_create_group`, `asc_add_build_to_group`, `asc_list_testers`, `asc_add_tester`, `asc_remove_tester`, `asc_set_whats_new`
  - Auth: `asc_configure`, `asc_status`
- [x] JWT authentication with ES256 signing via CryptoKit
- [x] Credentials stored in `~/.xclaude/asc_credentials.json`
- [x] `upload` tool auto-uses ASC credentials

### v3.8.0
- [x] Device-first defaults (build_start defaults to iOS, deploy defaults to device)
- [x] Bundle ID auto-detection in deploy
- [x] Clean build parameter
- [x] Build logs buffer preservation

### v3.7.0
- [x] Clean entitlements architecture (regenerated fresh per build)
- [x] Platform-aware capability filtering
- [x] appPath in build_status

### Earlier
- [x] Async build system (build_start/status/logs/cancel)
- [x] Signing discovery and auto-configuration
- [x] Multi-team signing support
- [x] Capability management (add/remove/list)
- [x] 61 capabilities supported

---

## Ideas Backlog

Things that might be useful but haven't been fully thought through:

- **Watch mode for device** - rebuild and redeploy on file changes (currently only works for simulator)
- **Crash symbolication** - get_crash_logs exists but doesn't symbolicate
- **Build caching insights** - show what's being rebuilt vs cached
- **Dependency vulnerability scanning** - check SPM dependencies for known issues
- **Icon generation improvements** - more icon styles, gradients, SF Symbols
- **SwiftUI preview support** - probably not possible without Xcode
- **Performance profiling** - launch with Instruments templates
