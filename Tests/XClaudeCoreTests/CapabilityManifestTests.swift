import Foundation
import Testing

@testable import XClaudeCore

// MARK: - The bug class: iOS-native permissions must NOT emit entitlements
//
// These are the capabilities that burned us: on iOS they need ONLY an
// Info.plist usage description. Putting a macOS sandbox entitlement
// (`com.apple.security.*`) into an iOS entitlements file silently breaks
// provisioning profile validation with the cryptic "A valid provisioning
// profile for this executable was not found" error.
//
// The tests below lock this invariant in CI: every capability that is
// handled via Info.plist on iOS must emit zero entitlements for `.iOS` and
// the correct sandbox entitlement for `.macOS`.

@Suite("Info.plist-only capabilities on iOS")
struct InfoPlistOnlyiOSCapabilityTests {

  /// The canonical bug class. Each case is (capability, expected iOS Info.plist
  /// key, expected macOS sandbox entitlement key).
  static let cases: [(name: String, infoPlistKey: String, macOSEntitlement: String)] = [
    ("camera", "NSCameraUsageDescription", "com.apple.security.device.camera"),
    ("audio-input", "NSMicrophoneUsageDescription", "com.apple.security.device.audio-input"),
    (
      "location", "NSLocationWhenInUseUsageDescription",
      "com.apple.security.personal-information.location"
    ),
    (
      "address-book", "NSContactsUsageDescription",
      "com.apple.security.personal-information.addressbook"
    ),
    (
      "calendars", "NSCalendarsUsageDescription",
      "com.apple.security.personal-information.calendars"
    ),
    (
      "photos", "NSPhotoLibraryUsageDescription",
      "com.apple.security.personal-information.photos-library"
    ),
    ("bluetooth", "NSBluetoothAlwaysUsageDescription", "com.apple.security.device.bluetooth"),
  ]

  @Test("Never emits entitlements on iOS", arguments: cases)
  func noEntitlementsOnIOS(_ tuple: (name: String, infoPlistKey: String, macOSEntitlement: String))
  {
    let manifest = CapabilityRegistry.manifest(for: tuple.name)
    #expect(manifest != nil, "missing manifest for \(tuple.name)")

    let entitlements = manifest!.resolvedEntitlements(for: .iOS)
    let msg =
      "'\(tuple.name)' must emit zero entitlements on iOS (got \(entitlements.keys.sorted())). "
      + "This is the camera/bluetooth provisioning-profile bug class — "
      + "com.apple.security.* entitlements are macOS-only."
    #expect(entitlements.isEmpty, Comment(rawValue: msg))
  }

  @Test("Emits correct Info.plist key on iOS", arguments: cases)
  func infoPlistKeyOnIOS(_ tuple: (name: String, infoPlistKey: String, macOSEntitlement: String)) {
    let manifest = CapabilityRegistry.manifest(for: tuple.name)!
    let infoPlist = manifest.resolvedInfoPlist(for: .iOS)
    #expect(
      infoPlist[tuple.infoPlistKey] != nil,
      "'\(tuple.name)' must emit \(tuple.infoPlistKey) on iOS"
    )
  }

  @Test("Emits sandbox entitlement on macOS", arguments: cases)
  func sandboxEntitlementOnMacOS(
    _ tuple: (name: String, infoPlistKey: String, macOSEntitlement: String)
  ) {
    let manifest = CapabilityRegistry.manifest(for: tuple.name)!
    let entitlements = manifest.resolvedEntitlements(for: .macOS)
    #expect(
      entitlements[tuple.macOSEntitlement] != nil,
      "'\(tuple.name)' must emit \(tuple.macOSEntitlement) on macOS (got \(entitlements.keys.sorted()))"
    )
  }

  @Test("User-provided value flows into usage description", arguments: cases)
  func customValueOverridesUsageDescription(
    _ tuple: (name: String, infoPlistKey: String, macOSEntitlement: String)
  ) {
    let manifest = CapabilityRegistry.manifest(for: tuple.name)!
    let custom = "For testing purposes only."

    let iosPlist = manifest.resolvedInfoPlist(for: .iOS, userValue: .string(custom))
    #expect(iosPlist[tuple.infoPlistKey] == custom)

    let macPlist = manifest.resolvedInfoPlist(for: .macOS, userValue: .string(custom))
    // bluetooth has no Info.plist entry on macOS, so it's the exception.
    if tuple.name != "bluetooth" {
      #expect(macPlist[tuple.infoPlistKey] == custom)
    }
  }
}

// MARK: - Cross-platform Apple-developer capabilities

@Suite("Cross-platform capabilities")
struct CrossPlatformCapabilityTests {

  @Test("push-notifications emits aps-environment on both platforms")
  func pushNotifications() {
    let m = CapabilityRegistry.manifest(for: "push-notifications")!
    #expect(m.supports(.iOS))
    #expect(m.supports(.macOS))
    #expect(m.resolvedEntitlements(for: .iOS)["aps-environment"] as? String == "development")
    #expect(m.resolvedEntitlements(for: .macOS)["aps-environment"] as? String == "development")
  }

  @Test("push-notifications user value overrides environment")
  func pushNotificationsCustomValue() {
    let m = CapabilityRegistry.manifest(for: "push-notifications")!
    let entitlements = m.resolvedEntitlements(for: .iOS, userValue: .string("production"))
    #expect(entitlements["aps-environment"] as? String == "production")
  }

  @Test("app-groups emits array entitlement on both platforms")
  func appGroups() {
    let m = CapabilityRegistry.manifest(for: "app-groups")!
    let iosEnt = m.resolvedEntitlements(for: .iOS)
    let macEnt = m.resolvedEntitlements(for: .macOS)
    #expect(iosEnt["com.apple.security.application-groups"] as? [String] != nil)
    #expect(macEnt["com.apple.security.application-groups"] as? [String] != nil)
  }
}

// MARK: - Platform-exclusive capabilities

@Suite("iOS-only capabilities")
struct iOSOnlyCapabilityTests {

  static let iOSOnlyNames = [
    "healthkit", "homekit", "network-extension", "wallet", "background-modes",
    "nfc", "carplay", "classkit", "access-wifi", "hotspot", "multipath",
    "weatherkit", "critical-alerts", "time-sensitive", "communication-notifications",
    "push-to-talk", "matter", "financekit", "increased-memory-limit",
    "extended-virtual-addressing", "personal-vpn", "family-controls", "maps-routing",
  ]

  @Test("Supports iOS but not macOS", arguments: iOSOnlyNames)
  func iOSOnly(_ name: String) {
    guard let manifest = CapabilityRegistry.manifest(for: name) else {
      Issue.record("missing manifest for \(name)")
      return
    }
    #expect(manifest.supports(.iOS), "\(name) should support iOS")
    #expect(!manifest.supports(.macOS), "\(name) should NOT support macOS")
  }

  @Test("healthkit emits both usage descriptions on iOS")
  func healthKitUsageDescriptions() {
    let m = CapabilityRegistry.manifest(for: "healthkit")!
    let plist = m.resolvedInfoPlist(for: .iOS)
    #expect(plist["NSHealthShareUsageDescription"] != nil)
    #expect(plist["NSHealthUpdateUsageDescription"] != nil)
    #expect(m.resolvedEntitlements(for: .iOS)["com.apple.developer.healthkit"] as? Bool == true)
  }
}

@Suite("macOS-only capabilities")
struct macOSOnlyCapabilityTests {

  static let macOSOnlyNames = [
    "apple-events", "hardened-runtime", "allow-jit", "allow-unsigned-memory",
    "allow-dyld-env", "files-read-only", "files-read-write", "files-downloads",
    "system-extension", "network-client", "network-server", "usb", "print",
    "serial", "music-library", "app-sandbox",
  ]

  @Test("Supports macOS but not iOS", arguments: macOSOnlyNames)
  func macOSOnly(_ name: String) {
    guard let manifest = CapabilityRegistry.manifest(for: name) else {
      Issue.record("missing manifest for \(name)")
      return
    }
    #expect(manifest.supports(.macOS), "\(name) should support macOS")
    #expect(!manifest.supports(.iOS), "\(name) should NOT support iOS")
  }

  @Test("App Sandbox capabilities require sandbox flag")
  func sandboxCapabilitiesFlagged() {
    let sandboxed = [
      "files-read-only", "files-read-write", "files-downloads",
      "network-client", "network-server", "usb", "print", "serial",
      "music-library",
    ]
    for name in sandboxed {
      let manifest = CapabilityRegistry.manifest(for: name)!
      let spec = manifest.platforms[.macOS]!
      #expect(spec.requiresSandbox, "\(name) should require App Sandbox")
    }
  }
}

// MARK: - Registry integrity

@Suite("Registry integrity")
struct CapabilityRegistryTests {

  @Test("Every manifest has at least one supported platform")
  func allManifestsHaveAPlatform() {
    for (name, manifest) in CapabilityRegistry.manifests {
      #expect(
        !manifest.platforms.isEmpty,
        "'\(name)' has no platforms — it will never emit anything")
      #expect(!manifest.supportedPlatforms.isEmpty)
    }
  }

  @Test("Every platform spec has at least one entitlement, Info.plist key, or explanatory note")
  func noEmptyPlatformSpecs() {
    for (name, manifest) in CapabilityRegistry.manifests {
      for (platform, spec) in manifest.platforms {
        let hasContent = !spec.entitlements.isEmpty || !spec.infoPlist.isEmpty || spec.notes != nil
        #expect(
          hasContent,
          "'\(name)' on \(platform.rawValue) is an empty spec with no entitlements, Info.plist keys, or notes"
        )
      }
    }
  }

  @Test("manifest(for:) is case-sensitive and matches the name field")
  func manifestLookup() {
    for name in CapabilityRegistry.allNames {
      let manifest = CapabilityRegistry.manifest(for: name)
      #expect(manifest != nil)
      #expect(manifest?.name == name)
    }
  }

  @Test("Unknown capability lookup returns nil")
  func unknownLookup() {
    #expect(CapabilityRegistry.manifest(for: "does-not-exist") == nil)
    #expect(CapabilityRegistry.manifest(for: "") == nil)
  }

  @Test("All expected capability count")
  func capabilityCount() {
    // Guards against accidental deletions during future refactors.
    #expect(
      CapabilityRegistry.allNames.count >= 50,
      "Expected at least 50 capabilities, got \(CapabilityRegistry.allNames.count)")
  }
}

// MARK: - CapabilityPlatform parsing

@Suite("CapabilityPlatform.parse")
struct CapabilityPlatformParseTests {

  @Test("Recognizes macOS variants")
  func macOSVariants() {
    #expect(CapabilityPlatform.parse("macOS") == .macOS)
    #expect(CapabilityPlatform.parse("macos") == .macOS)
    #expect(CapabilityPlatform.parse("MACOS") == .macOS)
    #expect(CapabilityPlatform.parse("darwin") == .macOS)
    #expect(CapabilityPlatform.parse("osx") == .macOS)
  }

  @Test("Defaults to iOS for everything else")
  func iOSDefault() {
    #expect(CapabilityPlatform.parse("iOS") == .iOS)
    #expect(CapabilityPlatform.parse("ios") == .iOS)
    #expect(CapabilityPlatform.parse("iphoneos") == .iOS)
    #expect(CapabilityPlatform.parse("tvos") == .iOS)
    #expect(CapabilityPlatform.parse("visionos") == .iOS)
    #expect(CapabilityPlatform.parse("") == .iOS)
  }
}

// MARK: - CapabilityManager integration

@Suite("CapabilityManager addCapability")
struct CapabilityManagerTests {

  /// Create a fresh temp project directory with a minimal xclaude.toml.
  func makeTempProject() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("xclaude-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let tomlPath = dir.appendingPathComponent("xclaude.toml")
    let toml = """
      [app]
      name = "TestApp"
      bundle_id = "com.example.testapp"
      version = "1.0.0"
      """
    try toml.write(to: tomlPath, atomically: true, encoding: .utf8)
    return dir
  }

  @Test("Adding camera writes to both [capabilities] and [info_plist]")
  func addCameraWritesInfoPlist() throws {
    let dir = try makeTempProject()
    defer { try? FileManager.default.removeItem(at: dir) }

    let result = try CapabilityManager.addCapability(
      "camera", to: dir, value: "For scanning QR codes"
    )
    #expect(result.success)
    #expect(result.capability == "camera")

    // Per-platform breakdown should show iOS without entitlements and
    // macOS with the sandbox entitlement.
    let iosEmission = result.platforms?["iOS"]
    let macEmission = result.platforms?["macOS"]
    #expect(iosEmission?.entitlements.isEmpty == true)
    #expect(macEmission?.entitlements["com.apple.security.device.camera"] == "true")
    #expect(iosEmission?.infoPlist["NSCameraUsageDescription"] == "For scanning QR codes")
    #expect(macEmission?.infoPlist["NSCameraUsageDescription"] == "For scanning QR codes")

    // Config on disk should reflect both sections.
    let config = try XClaudeConfig.load(from: dir)
    #expect(config.capabilities?["camera"] != nil)
    #expect(config.infoPlist?["NSCameraUsageDescription"] == .string("For scanning QR codes"))
  }

  @Test("Adding healthkit on iOS succeeds")
  func addHealthKitIOS() throws {
    let dir = try makeTempProject()
    defer { try? FileManager.default.removeItem(at: dir) }

    let result = try CapabilityManager.addCapability(
      "healthkit", to: dir, value: nil, targetPlatform: .iOS
    )
    #expect(result.success)
    #expect(result.platformWarning == nil)
  }

  @Test("Adding healthkit with macOS target returns a fixable error")
  func addHealthKitMacOSFails() throws {
    let dir = try makeTempProject()
    defer { try? FileManager.default.removeItem(at: dir) }

    let result = try CapabilityManager.addCapability(
      "healthkit", to: dir, value: nil, targetPlatform: .macOS
    )
    #expect(!result.success)
    #expect(result.platformWarning != nil)
    #expect(result.message.contains("macOS"))

    // Should NOT have written to config.
    let config = try XClaudeConfig.load(from: dir)
    #expect(config.capabilities?["healthkit"] == nil)
  }

  @Test("Adding an unknown capability returns an error with valid options")
  func unknownCapability() throws {
    let dir = try makeTempProject()
    defer { try? FileManager.default.removeItem(at: dir) }

    let result = try CapabilityManager.addCapability("not-a-real-cap", to: dir)
    #expect(!result.success)
    #expect(result.message.contains("Unknown capability"))
    #expect(result.message.contains("camera"))  // one of the valid options
  }

  @Test("Removing a capability cleans up xclaude.toml")
  func removeCapability() throws {
    let dir = try makeTempProject()
    defer { try? FileManager.default.removeItem(at: dir) }

    _ = try CapabilityManager.addCapability("camera", to: dir, value: "test")
    let addedConfig = try XClaudeConfig.load(from: dir)
    #expect(addedConfig.capabilities?["camera"] != nil)
    #expect(addedConfig.infoPlist?["NSCameraUsageDescription"] != nil)

    let removeResult = try CapabilityManager.removeCapability("camera", from: dir)
    #expect(removeResult.success)

    let removedConfig = try XClaudeConfig.load(from: dir)
    #expect(removedConfig.capabilities?["camera"] == nil)
    #expect(removedConfig.infoPlist?["NSCameraUsageDescription"] == nil)
  }
}

@Suite("CapabilityManager listCapabilities")
struct CapabilityManagerListTests {

  @Test("Returns per-platform info for every capability")
  func listReturnsPerPlatformInfo() {
    let all = CapabilityManager.listCapabilities()
    #expect(all.count == CapabilityRegistry.allNames.count)

    for (_, info) in all {
      #expect(!info.supportedPlatforms.isEmpty)
      #expect(!info.platforms.isEmpty)
    }
  }

  @Test("camera listing shows iOS with no entitlements and macOS with sandbox entitlement")
  func cameraListing() {
    let all = CapabilityManager.listCapabilities()
    let camera = all["camera"]
    #expect(camera != nil)
    #expect(camera!.supportedPlatforms.contains("iOS"))
    #expect(camera!.supportedPlatforms.contains("macOS"))

    let iosEmission = camera!.platforms["iOS"]
    #expect(iosEmission?.entitlements.isEmpty == true)
    #expect(iosEmission?.infoPlist["NSCameraUsageDescription"] != nil)

    let macEmission = camera!.platforms["macOS"]
    #expect(macEmission?.entitlements["com.apple.security.device.camera"] == "true")
    #expect(macEmission?.requiresSandbox == true)
  }
}
