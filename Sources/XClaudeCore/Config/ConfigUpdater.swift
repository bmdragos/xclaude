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

/// Manages app capabilities and entitlements
public struct CapabilityManager {

  /// Result of adding a capability
  public struct CapabilityResult: Codable {
    public let success: Bool
    public let message: String
    public let capability: String
    public let entitlements: [String: String]?
  }

  /// Known iOS capabilities and their entitlements
  public enum Capability: String, CaseIterable {
    case pushNotifications = "push-notifications"
    case appGroups = "app-groups"
    case iCloud = "icloud"
    case keychain = "keychain"
    case healthKit = "healthkit"
    case homeKit = "homekit"
    case inAppPurchase = "in-app-purchase"
    case networkExtension = "network-extension"
    case siri = "siri"
    case wallet = "wallet"
    case backgroundModes = "background-modes"

    /// The entitlement key for this capability
    var entitlementKey: String {
      switch self {
      case .pushNotifications:
        return "aps-environment"
      case .appGroups:
        return "com.apple.security.application-groups"
      case .iCloud:
        return "com.apple.developer.icloud-container-identifiers"
      case .keychain:
        return "keychain-access-groups"
      case .healthKit:
        return "com.apple.developer.healthkit"
      case .homeKit:
        return "com.apple.developer.homekit"
      case .inAppPurchase:
        return "com.apple.developer.in-app-payments"
      case .networkExtension:
        return "com.apple.developer.networking.networkextension"
      case .siri:
        return "com.apple.developer.siri"
      case .wallet:
        return "com.apple.developer.pass-type-identifiers"
      case .backgroundModes:
        return "UIBackgroundModes"
      }
    }

    /// Default entitlement value (some capabilities need specific values)
    var defaultValue: Any {
      switch self {
      case .pushNotifications:
        return "development"  // or "production" for release
      case .appGroups:
        return ["group.$(CFBundleIdentifier)"]
      case .iCloud:
        return ["iCloud.$(CFBundleIdentifier)"]
      case .keychain:
        return ["$(AppIdentifierPrefix)$(CFBundleIdentifier)"]
      case .healthKit:
        return true
      case .homeKit:
        return true
      case .inAppPurchase:
        return ["merchant.$(CFBundleIdentifier)"]
      case .networkExtension:
        return ["packet-tunnel"]
      case .siri:
        return true
      case .wallet:
        return ["$(TeamIdentifierPrefix)*"]
      case .backgroundModes:
        return ["fetch", "remote-notification"]
      }
    }

    /// Human-readable description
    var description: String {
      switch self {
      case .pushNotifications: return "Push Notifications"
      case .appGroups: return "App Groups"
      case .iCloud: return "iCloud"
      case .keychain: return "Keychain Sharing"
      case .healthKit: return "HealthKit"
      case .homeKit: return "HomeKit"
      case .inAppPurchase: return "In-App Purchase"
      case .networkExtension: return "Network Extensions"
      case .siri: return "SiriKit"
      case .wallet: return "Wallet"
      case .backgroundModes: return "Background Modes"
      }
    }
  }

  /// Add a capability to the project
  public static func addCapability(
    _ capabilityName: String,
    to projectDirectory: URL,
    value: String? = nil
  ) throws -> CapabilityResult {
    // Parse capability
    guard let capability = Capability(rawValue: capabilityName) else {
      let validCaps = Capability.allCases.map { $0.rawValue }.joined(separator: ", ")
      return CapabilityResult(
        success: false,
        message: "Unknown capability '\(capabilityName)'. Valid options: \(validCaps)",
        capability: capabilityName,
        entitlements: nil
      )
    }

    // Load or create entitlements
    let entitlementsDir = projectDirectory.appendingPathComponent(".xclaude/derived")
    try FileManager.default.createDirectory(at: entitlementsDir, withIntermediateDirectories: true)

    let entitlementsPath = entitlementsDir.appendingPathComponent("Entitlements.plist")
    var entitlements: [String: Any] = [:]

    // Load existing entitlements if present
    if FileManager.default.fileExists(atPath: entitlementsPath.path),
       let data = try? Data(contentsOf: entitlementsPath),
       let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
      entitlements = plist
    }

    // Add the entitlement
    let entitlementValue = value ?? (capability.defaultValue as? String) ?? capability.defaultValue
    entitlements[capability.entitlementKey] = entitlementValue

    // Save entitlements
    let plistData = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0)
    try plistData.write(to: entitlementsPath)

    // Update xclaude.toml to reference entitlements (if needed)
    // For now, we just track the capability was added

    // Return result
    var entitlementsDict: [String: String] = [:]
    if let strValue = entitlementValue as? String {
      entitlementsDict[capability.entitlementKey] = strValue
    } else if let arrValue = entitlementValue as? [String] {
      entitlementsDict[capability.entitlementKey] = arrValue.joined(separator: ", ")
    } else if let boolValue = entitlementValue as? Bool {
      entitlementsDict[capability.entitlementKey] = boolValue ? "true" : "false"
    }

    return CapabilityResult(
      success: true,
      message: "Added \(capability.description) capability",
      capability: capabilityName,
      entitlements: entitlementsDict
    )
  }

  /// List all available capabilities
  public static func listCapabilities() -> [String: String] {
    var result: [String: String] = [:]
    for cap in Capability.allCases {
      result[cap.rawValue] = cap.description
    }
    return result
  }
}
