import Foundation
import Testing

@testable import XClaudeCore

// MARK: - Background
//
// xclaude.toml supports two-level signing config:
//
//   [signing.iOS]                              # platform-level defaults
//   identity = "Apple Distribution: Foo"
//   profile  = "MyApp App Store"
//
//   [signing.iOS.development]                  # debug-only override
//   identity = "Apple Development: Bar"
//   profile  = "MyApp Development"
//
//   [signing.iOS.distribution]                 # release-only override
//   identity = "Apple Distribution: Foo"
//   profile  = "MyApp App Store"
//
// Before this fix, the build path always called `forPlatform(_:)` (no mode),
// so the `[signing.iOS.development]` and `[signing.iOS.distribution]`
// sub-tables were dead config. A debug build with both sub-tables defined
// could silently grab the App Store profile, producing an .app that fails to
// install on-device with "Beta profile without proper entitlement".
//
// These tests lock in the corrected mode-aware lookup.

@Suite("SigningConfig.forPlatform(_:mode:)")
struct SigningConfigForPlatformTests {

  /// Helper: build a SigningConfig with a single iOS platform block.
  private func config(
    iOSIdentity: String? = nil,
    iOSProfile: String? = nil,
    devIdentity: String? = nil,
    devProfile: String? = nil,
    distIdentity: String? = nil,
    distProfile: String? = nil,
    rootTeam: String? = nil,
    rootIdentity: String? = nil,
    rootProfile: String? = nil
  ) -> SigningConfig {
    let dev: SigningModeConfig?
    if devIdentity != nil || devProfile != nil {
      dev = SigningModeConfig(identity: devIdentity, profile: devProfile)
    } else {
      dev = nil
    }
    let dist: SigningModeConfig?
    if distIdentity != nil || distProfile != nil {
      dist = SigningModeConfig(identity: distIdentity, profile: distProfile)
    } else {
      dist = nil
    }
    let iOS = PlatformSigningConfig(
      identity: iOSIdentity,
      profile: iOSProfile,
      development: dev,
      distribution: dist
    )
    return SigningConfig(
      team: rootTeam,
      identity: rootIdentity,
      profile: rootProfile,
      iOS: iOS
    )
  }

  @Test("debug picks [signing.iOS.development] when present")
  func debugPicksDevelopment() {
    let cfg = config(
      iOSIdentity: "Apple Distribution: Foo",
      iOSProfile: "MyApp App Store",
      devIdentity: "Apple Development: Bar",
      devProfile: "MyApp Development",
      distIdentity: "Apple Distribution: Foo",
      distProfile: "MyApp App Store"
    )
    let r = cfg.forPlatform("iOS", mode: .development)
    #expect(r.identity == "Apple Development: Bar")
    #expect(r.profile == "MyApp Development")
  }

  @Test("release picks [signing.iOS.distribution] when present")
  func releasePicksDistribution() {
    let cfg = config(
      iOSIdentity: "Apple Development: Bar",
      iOSProfile: "MyApp Development",
      devIdentity: "Apple Development: Bar",
      devProfile: "MyApp Development",
      distIdentity: "Apple Distribution: Foo",
      distProfile: "MyApp App Store"
    )
    let r = cfg.forPlatform("iOS", mode: .distribution)
    #expect(r.identity == "Apple Distribution: Foo")
    #expect(r.profile == "MyApp App Store")
  }

  @Test("falls back to platform root when mode sub-table missing")
  func fallsBackToPlatformRoot() {
    // Only [signing.iOS] set; no .development sub-table.
    let cfg = config(
      iOSIdentity: "Apple Development: Bar",
      iOSProfile: "MyApp Development"
    )
    let dev = cfg.forPlatform("iOS", mode: .development)
    #expect(dev.identity == "Apple Development: Bar")
    #expect(dev.profile == "MyApp Development")

    let dist = cfg.forPlatform("iOS", mode: .distribution)
    #expect(dist.identity == "Apple Development: Bar")
    #expect(dist.profile == "MyApp Development")
  }

  @Test("falls back to top-level [signing] when nothing platform-specific")
  func fallsBackToTopLevel() {
    let cfg = SigningConfig(
      team: "TEAMID",
      identity: "Apple Development: Generic",
      profile: "Generic Profile"
      // no iOS/macOS/etc. blocks at all
    )
    let r = cfg.forPlatform("iOS", mode: .development)
    #expect(r.identity == "Apple Development: Generic")
    #expect(r.profile == "Generic Profile")
    #expect(r.team == "TEAMID")
  }

  @Test("mode-specific identity override but inherited profile from platform root")
  func partialModeOverride() {
    // .development overrides identity but not profile — profile should
    // inherit from [signing.iOS].
    let cfg = config(
      iOSIdentity: "Apple Distribution: Foo",
      iOSProfile: "Shared Profile",
      devIdentity: "Apple Development: Bar"
      // devProfile intentionally nil
    )
    let r = cfg.forPlatform("iOS", mode: .development)
    #expect(r.identity == "Apple Development: Bar")
    #expect(r.profile == "Shared Profile")
  }
}

@Suite("BuildRunner.Configuration.signingMode")
struct BuildRunnerConfigurationSigningModeTests {
  @Test("debug → .development")
  func debugMapsToDevelopment() {
    #expect(BuildRunner.Configuration.debug.signingMode == .development)
  }

  @Test("release → .distribution")
  func releaseMapsToDistribution() {
    #expect(BuildRunner.Configuration.release.signingMode == .distribution)
  }
}

@Suite("SigningDiscovery.profileTypeMatches(_:mode:)")
struct ProfileTypeMatchesTests {
  @Test("development mode accepts only development profiles")
  func developmentMode() {
    #expect(SigningDiscovery.profileTypeMatches(.development, mode: .development))
    #expect(!SigningDiscovery.profileTypeMatches(.appStore, mode: .development))
    #expect(!SigningDiscovery.profileTypeMatches(.adHoc, mode: .development))
    #expect(!SigningDiscovery.profileTypeMatches(.enterprise, mode: .development))
  }

  @Test("distribution mode accepts app-store, ad-hoc, enterprise — never development")
  func distributionMode() {
    #expect(!SigningDiscovery.profileTypeMatches(.development, mode: .distribution))
    #expect(SigningDiscovery.profileTypeMatches(.appStore, mode: .distribution))
    #expect(SigningDiscovery.profileTypeMatches(.adHoc, mode: .distribution))
    #expect(SigningDiscovery.profileTypeMatches(.enterprise, mode: .distribution))
  }
}

@Suite("SigningDiscovery.findMatchingProfile mode preference")
struct FindMatchingProfileModeTests {

  /// Build a fake SigningData with two profiles for the same bundle id —
  /// one development, one App Store — exactly the configuration that
  /// produced the original "wrong profile picked" bug.
  private func sameBundleIdBothTypes() -> SigningData {
    let now = Date(timeIntervalSinceNow: 86_400 * 30)  // not expired
    let dev = ProvisioningProfile(
      uuid: "dev-uuid",
      name: "MyApp Development",
      appIdName: "MyApp",
      path: "/tmp/dev.mobileprovision",
      teamId: "TEAMID",
      bundleIdPattern: "com.example.myapp",
      platforms: ["iOS"],
      expiresAt: now,
      isWildcard: false,
      isExpired: false,
      profileType: .development
    )
    let dist = ProvisioningProfile(
      uuid: "dist-uuid",
      name: "MyApp App Store",
      appIdName: "MyApp",
      path: "/tmp/dist.mobileprovision",
      teamId: "TEAMID",
      bundleIdPattern: "com.example.myapp",
      platforms: ["iOS"],
      expiresAt: now,
      isWildcard: false,
      isExpired: false,
      profileType: .appStore
    )
    return SigningData(
      identities: [SigningIdentity(id: "id1", name: "Apple Development: x", teamId: "TEAMID")],
      profiles: [dist, dev],  // dist listed first to ensure ordering doesn't accidentally save us
      defaultTeamId: "TEAMID"
    )
  }

  @Test("debug build prefers the development profile over App Store")
  func debugPrefersDevelopment() async throws {
    let discovery = SigningDiscovery()
    let profile = try await discovery.findMatchingProfile(
      bundleId: "com.example.myapp",
      platform: "iOS",
      mode: .development,
      signingData: sameBundleIdBothTypes()
    )
    #expect(profile.profileType == .development)
    #expect(profile.name == "MyApp Development")
  }

  @Test("release build prefers the App Store profile over development")
  func releasePrefersAppStore() async throws {
    let discovery = SigningDiscovery()
    let profile = try await discovery.findMatchingProfile(
      bundleId: "com.example.myapp",
      platform: "iOS",
      mode: .distribution,
      signingData: sameBundleIdBothTypes()
    )
    #expect(profile.profileType == .appStore)
    #expect(profile.name == "MyApp App Store")
  }
}
