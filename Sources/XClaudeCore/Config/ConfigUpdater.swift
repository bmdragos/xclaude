import Foundation

/// Updates xclaude.toml configuration
public struct ConfigUpdater {

  /// Result of config update
  public struct UpdateResult: Codable {
    public let success: Bool
    public let message: String
    public let key: String
    public let oldValue: String?
    public let newValue: String
  }

  /// Supported config keys
  public enum ConfigKey: String, CaseIterable {
    case name = "app.name"
    case bundleId = "app.bundle_id"
    case version = "app.version"
    case icon = "app.icon"
    case team = "signing.team"
    case identity = "signing.identity"
    case profile = "signing.profile"

    var section: String {
      switch self {
      case .name, .bundleId, .version, .icon:
        return "app"
      case .team, .identity, .profile:
        return "signing"
      }
    }

    var key: String {
      switch self {
      case .name: return "name"
      case .bundleId: return "bundle_id"
      case .version: return "version"
      case .icon: return "icon"
      case .team: return "team"
      case .identity: return "identity"
      case .profile: return "profile"
      }
    }
  }

  /// Update a config value
  public static func update(
    key keyPath: String,
    value: String,
    at projectDirectory: URL
  ) throws -> UpdateResult {
    // Parse key
    guard let configKey = ConfigKey(rawValue: keyPath) else {
      let validKeys = ConfigKey.allCases.map { $0.rawValue }.joined(separator: ", ")
      return UpdateResult(
        success: false,
        message: "Invalid key '\(keyPath)'. Valid keys: \(validKeys)",
        key: keyPath,
        oldValue: nil,
        newValue: value
      )
    }

    // Load existing config
    var config = try XClaudeConfig.load(from: projectDirectory)

    // Get old value for reporting
    let oldValue = getValue(from: config, key: configKey)

    // Update value
    setValue(in: &config, key: configKey, value: value)

    // Save config
    try config.save(to: projectDirectory)

    return UpdateResult(
      success: true,
      message: "Updated \(keyPath) to '\(value)'",
      key: keyPath,
      oldValue: oldValue,
      newValue: value
    )
  }

  private static func getValue(from config: XClaudeConfig, key: ConfigKey) -> String? {
    switch key {
    case .name: return config.app.name
    case .bundleId: return config.app.bundleId
    case .version: return config.app.version
    case .icon: return config.app.icon
    case .team: return config.signing?.team
    case .identity: return config.signing?.identity
    case .profile: return config.signing?.profile
    }
  }

  private static func setValue(in config: inout XClaudeConfig, key: ConfigKey, value: String) {
    switch key {
    case .name:
      config.app.name = value
    case .bundleId:
      config.app.bundleId = value
    case .version:
      config.app.version = value
    case .icon:
      config.app.icon = value
    case .team:
      if config.signing == nil {
        config.signing = SigningConfig()
      }
      config.signing?.team = value
    case .identity:
      if config.signing == nil {
        config.signing = SigningConfig()
      }
      config.signing?.identity = value
    case .profile:
      if config.signing == nil {
        config.signing = SigningConfig()
      }
      config.signing?.profile = value
    }
  }
}

/// Manages app capabilities and entitlements.
///
/// This is a thin façade over `CapabilityRegistry` — the registry holds the
/// per-platform emission manifests, and this type just mutates `xclaude.toml`
/// accordingly.
public struct CapabilityManager {

  // MARK: - Result types

  /// Per-platform emission summary for a single capability.
  public struct PlatformEmission: Codable, Equatable {
    public let entitlements: [String: String]
    public let infoPlist: [String: String]
    public let requiresSandbox: Bool
    public let notes: String?
  }

  /// Result of adding or removing a capability.
  public struct CapabilityResult: Codable {
    public let success: Bool
    public let message: String
    public let capability: String
    /// Flat union of all entitlements added (for quick inspection).
    public let entitlements: [String: String]?
    /// Flat union of all Info.plist keys added (for quick inspection).
    public let infoPlistAdditions: [String: String]?
    /// Per-platform emission breakdown — what gets written at build time on
    /// each supported platform.
    public let platforms: [String: PlatformEmission]?
    /// Warning if the capability isn't supported on the requested target.
    public let platformWarning: String?
  }

  /// Capability metadata for listing. Per-platform — AI agents can see
  /// exactly what a capability does on each platform.
  public struct CapabilityInfo: Codable {
    public let name: String
    public let displayName: String
    public let summary: String
    public let supportedPlatforms: [String]
    public let platforms: [String: PlatformEmission]
  }

  // MARK: - Add

  /// Add a capability to the project.
  ///
  /// Only modifies `xclaude.toml` — entitlements are generated fresh at build
  /// time by `SigningDiscovery.generateEntitlements`, and Info.plist keys are
  /// merged in by `ConfigTranslator`.
  ///
  /// - Parameters:
  ///   - capabilityName: The capability identifier (e.g. "camera", "push-notifications").
  ///   - projectDirectory: Project root containing `xclaude.toml`.
  ///   - value: Optional custom value — typically a usage description string
  ///            for permission capabilities, or an entitlement value for others.
  ///   - targetPlatform: Optional target platform to validate against. If
  ///            provided and the capability is unsupported there, returns a
  ///            fixable error with a suggestion.
  public static func addCapability(
    _ capabilityName: String,
    to projectDirectory: URL,
    value: String? = nil,
    targetPlatform: CapabilityPlatform? = nil
  ) throws -> CapabilityResult {
    // Look up manifest
    guard let manifest = CapabilityRegistry.manifest(for: capabilityName) else {
      let validNames = CapabilityRegistry.allNames.joined(separator: ", ")
      return CapabilityResult(
        success: false,
        message: "Unknown capability '\(capabilityName)'. Valid options: \(validNames)",
        capability: capabilityName,
        entitlements: nil,
        infoPlistAdditions: nil,
        platforms: nil,
        platformWarning: nil
      )
    }

    // Validate target platform (if specified)
    if let target = targetPlatform, !manifest.supports(target) {
      let supported = manifest.supportedPlatforms.map { $0.rawValue }.joined(separator: ", ")
      return CapabilityResult(
        success: false,
        message:
          "'\(capabilityName)' is not supported on \(target.rawValue). Supported platforms: \(supported).",
        capability: capabilityName,
        entitlements: nil,
        infoPlistAdditions: nil,
        platforms: nil,
        platformWarning:
          "\(manifest.displayName) cannot be used on \(target.rawValue). Supported: \(supported)."
      )
    }

    // Load config
    var config = try XClaudeConfig.load(from: projectDirectory)
    if config.capabilities == nil {
      config.capabilities = [:]
    }

    // Capability value stored in [capabilities] section.
    // If user provided a string, store it; otherwise store a bool sentinel.
    let capabilityValue: CapabilityValue
    if let customValue = value {
      capabilityValue = .string(customValue)
    } else {
      capabilityValue = .bool(true)
    }
    config.capabilities?[capabilityName] = capabilityValue

    // Merge Info.plist usage descriptions into [info_plist].
    // We use the union across all supported platforms because Info.plist
    // keys (NS*UsageDescription, etc.) are harmless on any Apple platform.
    let infoPlistUpdates = manifest.unionInfoPlist(userValue: capabilityValue)
    if !infoPlistUpdates.isEmpty {
      if config.infoPlist == nil {
        config.infoPlist = [:]
      }
      for (key, plistValue) in infoPlistUpdates {
        // Don't overwrite user's existing custom values.
        if config.infoPlist?[key] == nil {
          config.infoPlist?[key] = .string(plistValue)
        }
      }
    }

    try config.save(to: projectDirectory)

    // Build per-platform emission summary
    let platforms = buildPlatformEmissions(manifest: manifest, userValue: capabilityValue)

    // Build flat union summaries for backward compat
    let flatEntitlements = flatUnionEntitlements(from: platforms)
    let flatInfoPlist = flatUnionInfoPlist(from: platforms)

    return CapabilityResult(
      success: true,
      message: "Added \(manifest.displayName) capability to xclaude.toml",
      capability: capabilityName,
      entitlements: flatEntitlements.isEmpty ? nil : flatEntitlements,
      infoPlistAdditions: flatInfoPlist.isEmpty ? nil : flatInfoPlist,
      platforms: platforms.isEmpty ? nil : platforms,
      platformWarning: nil
    )
  }

  // MARK: - Remove

  /// Remove a capability from the project.
  public static func removeCapability(
    _ capabilityName: String,
    from projectDirectory: URL
  ) throws -> CapabilityResult {
    guard let manifest = CapabilityRegistry.manifest(for: capabilityName) else {
      let validNames = CapabilityRegistry.allNames.joined(separator: ", ")
      return CapabilityResult(
        success: false,
        message: "Unknown capability '\(capabilityName)'. Valid options: \(validNames)",
        capability: capabilityName,
        entitlements: nil,
        infoPlistAdditions: nil,
        platforms: nil,
        platformWarning: nil
      )
    }

    var removedCapability = false
    var removedInfoPlist: [String: String] = [:]

    var config = try XClaudeConfig.load(from: projectDirectory)

    // Remove from [capabilities]
    if var capabilities = config.capabilities {
      if capabilities[capabilityName] != nil {
        capabilities.removeValue(forKey: capabilityName)
        config.capabilities = capabilities.isEmpty ? nil : capabilities
        removedCapability = true
      }
    }

    // Remove the Info.plist keys this capability would have added.
    // Union across platforms so we clean up everything we might've written.
    let infoPlistKeysToRemove = Set(manifest.unionInfoPlist().keys)
    if var infoPlist = config.infoPlist, !infoPlistKeysToRemove.isEmpty {
      for key in infoPlistKeysToRemove where infoPlist[key] != nil {
        removedInfoPlist[key] = "removed"
        infoPlist.removeValue(forKey: key)
      }
      config.infoPlist = infoPlist.isEmpty ? nil : infoPlist
    }

    if removedCapability || !removedInfoPlist.isEmpty {
      try config.save(to: projectDirectory)
    }

    if !removedCapability && removedInfoPlist.isEmpty {
      return CapabilityResult(
        success: false,
        message: "Capability '\(manifest.displayName)' was not found in xclaude.toml",
        capability: capabilityName,
        entitlements: nil,
        infoPlistAdditions: nil,
        platforms: nil,
        platformWarning: nil
      )
    }

    // Report what was in the manifest (not a live snapshot — the capability is gone now).
    let platforms = buildPlatformEmissions(manifest: manifest, userValue: nil)
    let flatEntitlements = flatUnionEntitlements(from: platforms)
      .mapValues { _ in "removed" }

    return CapabilityResult(
      success: true,
      message: "Removed \(manifest.displayName) capability",
      capability: capabilityName,
      entitlements: flatEntitlements.isEmpty ? nil : flatEntitlements,
      infoPlistAdditions: removedInfoPlist.isEmpty ? nil : removedInfoPlist,
      platforms: platforms.isEmpty ? nil : platforms,
      platformWarning: nil
    )
  }

  // MARK: - List

  /// List every known capability with full per-platform emission info.
  ///
  /// AI agents should call this to introspect what's available before calling
  /// `addCapability` — the response describes exactly what each capability
  /// produces on each supported platform.
  public static func listCapabilities() -> [String: CapabilityInfo] {
    var result: [String: CapabilityInfo] = [:]
    for name in CapabilityRegistry.allNames {
      guard let manifest = CapabilityRegistry.manifest(for: name) else { continue }
      let platforms = buildPlatformEmissions(manifest: manifest, userValue: nil)
      result[name] = CapabilityInfo(
        name: manifest.name,
        displayName: manifest.displayName,
        summary: manifest.summary,
        supportedPlatforms: manifest.supportedPlatforms.map { $0.rawValue },
        platforms: platforms
      )
    }
    return result
  }

  // MARK: - Helpers

  /// Build a `[platform: PlatformEmission]` dictionary from a manifest.
  private static func buildPlatformEmissions(
    manifest: CapabilityManifest,
    userValue: CapabilityValue?
  ) -> [String: PlatformEmission] {
    var result: [String: PlatformEmission] = [:]
    for platform in manifest.supportedPlatforms {
      guard let spec = manifest.platforms[platform] else { continue }
      let resolvedEntitlements = manifest.resolvedEntitlements(for: platform, userValue: userValue)
      let resolvedInfoPlist = manifest.resolvedInfoPlist(for: platform, userValue: userValue)
      result[platform.rawValue] = PlatformEmission(
        entitlements: stringifyEntitlements(resolvedEntitlements),
        infoPlist: resolvedInfoPlist,
        requiresSandbox: spec.requiresSandbox,
        notes: spec.notes
      )
    }
    return result
  }

  /// Convert `[String: Any]` entitlement values to `[String: String]` for JSON
  /// serialization. Bool → "true"/"false", Array → comma-joined.
  private static func stringifyEntitlements(_ dict: [String: Any]) -> [String: String] {
    var result: [String: String] = [:]
    for (key, value) in dict {
      if let b = value as? Bool {
        result[key] = b ? "true" : "false"
      } else if let s = value as? String {
        result[key] = s
      } else if let arr = value as? [String] {
        result[key] = arr.joined(separator: ", ")
      } else {
        result[key] = "\(value)"
      }
    }
    return result
  }

  private static func flatUnionEntitlements(
    from platforms: [String: PlatformEmission]
  ) -> [String: String] {
    var result: [String: String] = [:]
    for emission in platforms.values {
      for (key, value) in emission.entitlements {
        result[key] = value
      }
    }
    return result
  }

  private static func flatUnionInfoPlist(
    from platforms: [String: PlatformEmission]
  ) -> [String: String] {
    var result: [String: String] = [:]
    for emission in platforms.values {
      for (key, value) in emission.infoPlist {
        result[key] = value
      }
    }
    return result
  }
}
