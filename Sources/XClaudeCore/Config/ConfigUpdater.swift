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
    public let infoPlistAdditions: [String: String]?
  }

  /// Known capabilities and their entitlements (iOS + macOS)
  public enum Capability: String, CaseIterable {
    // iOS/Shared capabilities
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

    // macOS-specific capabilities
    case appleEvents = "apple-events"
    case hardenedRuntime = "hardened-runtime"
    case allowJit = "allow-jit"
    case allowUnsignedMemory = "allow-unsigned-memory"
    case allowDyldEnv = "allow-dyld-env"
    case filesUserSelectedReadOnly = "files-read-only"
    case filesUserSelectedReadWrite = "files-read-write"
    case filesDownloads = "files-downloads"
    case audioInput = "audio-input"
    case camera = "camera"
    case location = "location"
    case addressBook = "address-book"
    case calendars = "calendars"
    case photos = "photos"
    case systemExtension = "system-extension"

    // Continuity & Ecosystem capabilities
    case handoff = "handoff"
    case associatedDomains = "associated-domains"
    case signInWithApple = "sign-in-with-apple"
    case gameCenter = "game-center"
    case sharePlay = "shareplay"
    case nfc = "nfc"
    case carPlay = "carplay"
    case weatherKit = "weatherkit"
    case classKit = "classkit"
    case accessWifi = "access-wifi"
    case hotspot = "hotspot"
    case multipath = "multipath"

    // App Sandbox (macOS)
    case networkClient = "network-client"
    case networkServer = "network-server"
    case bluetooth = "bluetooth"
    case usb = "usb"
    case printing = "print"
    case serialPort = "serial"

    // Notifications
    case criticalAlerts = "critical-alerts"
    case timeSensitive = "time-sensitive"
    case communicationNotifications = "communication-notifications"

    // Newer APIs
    case shazamKit = "shazamkit"
    case musicKit = "musickit"
    case pushToTalk = "push-to-talk"
    case matter = "matter"
    case financeKit = "financekit"
    case deviceCheck = "devicecheck"

    // Memory/Performance
    case increasedMemoryLimit = "increased-memory-limit"
    case extendedVirtualAddressing = "extended-virtual-addressing"

    // Other
    case personalVPN = "personal-vpn"
    case dataProtection = "data-protection"
    case familyControls = "family-controls"
    case autofillCredentials = "autofill-credentials"
    case mapsRouting = "maps-routing"
    case appSandbox = "app-sandbox"

    /// The entitlement key for this capability
    var entitlementKey: String {
      switch self {
      // iOS/Shared
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
      // macOS-specific
      case .appleEvents:
        return "com.apple.security.automation.apple-events"
      case .hardenedRuntime:
        return "com.apple.security.app-sandbox"  // Note: hardened runtime uses code signing flags
      case .allowJit:
        return "com.apple.security.cs.allow-jit"
      case .allowUnsignedMemory:
        return "com.apple.security.cs.allow-unsigned-executable-memory"
      case .allowDyldEnv:
        return "com.apple.security.cs.allow-dyld-environment-variables"
      case .filesUserSelectedReadOnly:
        return "com.apple.security.files.user-selected.read-only"
      case .filesUserSelectedReadWrite:
        return "com.apple.security.files.user-selected.read-write"
      case .filesDownloads:
        return "com.apple.security.files.downloads.read-write"
      case .audioInput:
        return "com.apple.security.device.audio-input"
      case .camera:
        return "com.apple.security.device.camera"
      case .location:
        return "com.apple.security.personal-information.location"
      case .addressBook:
        return "com.apple.security.personal-information.addressbook"
      case .calendars:
        return "com.apple.security.personal-information.calendars"
      case .photos:
        return "com.apple.security.personal-information.photos-library"
      case .systemExtension:
        return "com.apple.developer.system-extension.install"
      // Continuity & Ecosystem
      case .handoff:
        return "com.apple.developer.handoff"
      case .associatedDomains:
        return "com.apple.developer.associated-domains"
      case .signInWithApple:
        return "com.apple.developer.applesignin"
      case .gameCenter:
        return "com.apple.developer.game-center"
      case .sharePlay:
        return "com.apple.developer.group-session"
      case .nfc:
        return "com.apple.developer.nfc.readersession.formats"
      case .carPlay:
        return "com.apple.developer.carplay-audio"
      case .weatherKit:
        return "com.apple.developer.weatherkit"
      case .classKit:
        return "com.apple.developer.ClassKit-environment"
      case .accessWifi:
        return "com.apple.developer.networking.wifi-info"
      case .hotspot:
        return "com.apple.developer.networking.HotspotConfiguration"
      case .multipath:
        return "com.apple.developer.networking.multipath"
      // App Sandbox (macOS)
      case .networkClient:
        return "com.apple.security.network.client"
      case .networkServer:
        return "com.apple.security.network.server"
      case .bluetooth:
        return "com.apple.security.device.bluetooth"
      case .usb:
        return "com.apple.security.device.usb"
      case .printing:
        return "com.apple.security.print"
      case .serialPort:
        return "com.apple.security.device.serial"
      // Notifications
      case .criticalAlerts:
        return "com.apple.developer.usernotifications.critical-alerts"
      case .timeSensitive:
        return "com.apple.developer.usernotifications.time-sensitive"
      case .communicationNotifications:
        return "com.apple.developer.usernotifications.communication"
      // Newer APIs
      case .shazamKit:
        return "com.apple.developer.shazamkit.referral"
      case .musicKit:
        return "com.apple.developer.musickit"
      case .pushToTalk:
        return "com.apple.developer.push-to-talk"
      case .matter:
        return "com.apple.developer.matter.allow-setup-payload"
      case .financeKit:
        return "com.apple.developer.financekit"
      case .deviceCheck:
        return "com.apple.developer.devicecheck.appattest-environment"
      // Memory/Performance
      case .increasedMemoryLimit:
        return "com.apple.developer.kernel.increased-memory-limit"
      case .extendedVirtualAddressing:
        return "com.apple.developer.kernel.extended-virtual-addressing"
      // Other
      case .personalVPN:
        return "com.apple.developer.networking.vpn.api"
      case .dataProtection:
        return "com.apple.developer.default-data-protection"
      case .familyControls:
        return "com.apple.developer.family-controls"
      case .autofillCredentials:
        return "com.apple.developer.authentication-services.autofill-credential-provider"
      case .mapsRouting:
        return "com.apple.developer.maps"
      case .appSandbox:
        return "com.apple.security.app-sandbox"
      }
    }

    /// Default entitlement value (some capabilities need specific values)
    var defaultValue: Any {
      switch self {
      // iOS/Shared
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
      // macOS-specific (all boolean entitlements)
      case .appleEvents, .hardenedRuntime, .allowJit, .allowUnsignedMemory,
           .allowDyldEnv, .filesUserSelectedReadOnly, .filesUserSelectedReadWrite,
           .filesDownloads, .audioInput, .camera, .location,
           .addressBook, .calendars, .photos, .systemExtension:
        return true
      // Continuity & Ecosystem
      case .handoff, .gameCenter, .weatherKit, .classKit,
           .accessWifi, .hotspot, .multipath:
        return true
      case .associatedDomains:
        return ["applinks:example.com", "webcredentials:example.com"]
      case .signInWithApple:
        return ["Default"]
      case .sharePlay:
        return true
      case .nfc:
        return ["NDEF", "TAG"]
      case .carPlay:
        return true
      // App Sandbox (macOS) - all boolean
      case .networkClient, .networkServer, .bluetooth, .usb, .printing, .serialPort, .appSandbox:
        return true
      // Notifications - all boolean
      case .criticalAlerts, .timeSensitive, .communicationNotifications:
        return true
      // Newer APIs - mostly boolean
      case .shazamKit, .musicKit, .pushToTalk, .matter, .financeKit:
        return true
      case .deviceCheck:
        return "production"  // or "development"
      // Memory/Performance - all boolean
      case .increasedMemoryLimit, .extendedVirtualAddressing:
        return true
      // Other
      case .personalVPN:
        return ["allow-vpn"]
      case .dataProtection:
        return "NSFileProtectionComplete"
      case .familyControls:
        return true
      case .autofillCredentials:
        return true
      case .mapsRouting:
        return true
      }
    }

    /// Human-readable description
    var description: String {
      switch self {
      // iOS/Shared
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
      // macOS-specific
      case .appleEvents: return "Apple Events (Automation)"
      case .hardenedRuntime: return "Hardened Runtime"
      case .allowJit: return "Allow JIT Compilation"
      case .allowUnsignedMemory: return "Allow Unsigned Executable Memory"
      case .allowDyldEnv: return "Allow DYLD Environment Variables"
      case .filesUserSelectedReadOnly: return "User-Selected Files (Read Only)"
      case .filesUserSelectedReadWrite: return "User-Selected Files (Read/Write)"
      case .filesDownloads: return "Downloads Folder Access"
      case .audioInput: return "Microphone Access"
      case .camera: return "Camera Access (Continuity Camera)"
      case .location: return "Location Services"
      case .addressBook: return "Contacts Access"
      case .calendars: return "Calendars Access"
      case .photos: return "Photos Library Access"
      case .systemExtension: return "System Extension Installation"
      // Continuity & Ecosystem
      case .handoff: return "Handoff (Continuity)"
      case .associatedDomains: return "Associated Domains (Universal Links)"
      case .signInWithApple: return "Sign in with Apple"
      case .gameCenter: return "Game Center"
      case .sharePlay: return "SharePlay (Group Activities)"
      case .nfc: return "NFC Tag Reading"
      case .carPlay: return "CarPlay"
      case .weatherKit: return "WeatherKit"
      case .classKit: return "ClassKit (Education)"
      case .accessWifi: return "Access WiFi Information"
      case .hotspot: return "Hotspot Configuration"
      case .multipath: return "Multipath Networking"
      // App Sandbox (macOS)
      case .networkClient: return "Network Client (Outgoing Connections)"
      case .networkServer: return "Network Server (Incoming Connections)"
      case .bluetooth: return "Bluetooth Access"
      case .usb: return "USB Device Access"
      case .printing: return "Printing"
      case .serialPort: return "Serial Port Access"
      // Notifications
      case .criticalAlerts: return "Critical Alerts"
      case .timeSensitive: return "Time-Sensitive Notifications"
      case .communicationNotifications: return "Communication Notifications"
      // Newer APIs
      case .shazamKit: return "ShazamKit"
      case .musicKit: return "MusicKit"
      case .pushToTalk: return "Push to Talk"
      case .matter: return "Matter Smart Home"
      case .financeKit: return "FinanceKit"
      case .deviceCheck: return "DeviceCheck / App Attest"
      // Memory/Performance
      case .increasedMemoryLimit: return "Increased Memory Limit"
      case .extendedVirtualAddressing: return "Extended Virtual Addressing"
      // Other
      case .personalVPN: return "Personal VPN"
      case .dataProtection: return "Data Protection"
      case .familyControls: return "Family Controls (Screen Time)"
      case .autofillCredentials: return "AutoFill Credential Provider"
      case .mapsRouting: return "Maps Routing"
      case .appSandbox: return "App Sandbox"
      }
    }

    /// Info.plist usage description key (if capability requires one)
    var usageDescriptionKey: String? {
      switch self {
      case .appleEvents:
        return "NSAppleEventsUsageDescription"
      case .camera:
        return "NSCameraUsageDescription"
      case .audioInput:
        return "NSMicrophoneUsageDescription"
      case .location:
        return "NSLocationUsageDescription"
      case .photos:
        return "NSPhotoLibraryUsageDescription"
      case .addressBook:
        return "NSContactsUsageDescription"
      case .calendars:
        return "NSCalendarsUsageDescription"
      case .healthKit:
        return "NSHealthShareUsageDescription"
      case .homeKit:
        return "NSHomeKitUsageDescription"
      case .siri:
        return "NSSiriUsageDescription"
      case .nfc:
        return "NFCReaderUsageDescription"
      default:
        return nil
      }
    }

    /// Default usage description for Info.plist
    var defaultUsageDescription: String? {
      switch self {
      case .appleEvents:
        return "This app needs to control other applications for automation."
      case .camera:
        return "This app needs access to the camera."
      case .audioInput:
        return "This app needs access to the microphone."
      case .location:
        return "This app needs access to your location."
      case .photos:
        return "This app needs access to your photo library."
      case .addressBook:
        return "This app needs access to your contacts."
      case .calendars:
        return "This app needs access to your calendars."
      case .healthKit:
        return "This app needs access to your health data."
      case .homeKit:
        return "This app needs access to your HomeKit devices."
      case .siri:
        return "This app uses Siri to provide voice commands."
      case .nfc:
        return "This app needs to read NFC tags."
      default:
        return nil
      }
    }

    /// Platform this capability applies to
    var platform: CapabilityPlatform {
      switch self {
      // Both platforms
      case .pushNotifications, .appGroups, .iCloud, .keychain, .inAppPurchase,
           .siri, .audioInput, .camera, .location, .addressBook, .calendars, .photos,
           .handoff, .associatedDomains, .signInWithApple, .gameCenter, .sharePlay,
           .shazamKit, .musicKit, .deviceCheck, .dataProtection, .autofillCredentials:
        return .both
      // iOS only
      case .healthKit, .homeKit, .networkExtension, .wallet, .backgroundModes,
           .nfc, .carPlay, .classKit, .accessWifi, .hotspot, .multipath, .weatherKit,
           .criticalAlerts, .timeSensitive, .communicationNotifications,
           .pushToTalk, .matter, .financeKit,
           .increasedMemoryLimit, .extendedVirtualAddressing,
           .personalVPN, .familyControls, .mapsRouting:
        return .iOS
      // macOS only
      case .appleEvents, .hardenedRuntime, .allowJit, .allowUnsignedMemory,
           .allowDyldEnv, .filesUserSelectedReadOnly, .filesUserSelectedReadWrite,
           .filesDownloads, .systemExtension,
           .networkClient, .networkServer, .bluetooth, .usb, .printing, .serialPort,
           .appSandbox:
        return .macOS
      }
    }
  }

  public enum CapabilityPlatform: String, Codable {
    case iOS
    case macOS
    case both
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
        entitlements: nil,
        infoPlistAdditions: nil
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

    // Add Info.plist usage description if needed
    var infoPlistAdditions: [String: Any] = [:]
    let infoPlistPath = entitlementsDir.appendingPathComponent("InfoAdditions.plist")

    // Load existing Info.plist additions if present
    if FileManager.default.fileExists(atPath: infoPlistPath.path),
       let data = try? Data(contentsOf: infoPlistPath),
       let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
      infoPlistAdditions = plist
    }

    // Add usage description if this capability requires one
    if let usageKey = capability.usageDescriptionKey,
       let usageDesc = value ?? capability.defaultUsageDescription {
      infoPlistAdditions[usageKey] = usageDesc
      let infoPlistData = try PropertyListSerialization.data(fromPropertyList: infoPlistAdditions, format: .xml, options: 0)
      try infoPlistData.write(to: infoPlistPath)
    }

    // Build result dictionaries
    var entitlementsDict: [String: String] = [:]
    if let strValue = entitlementValue as? String {
      entitlementsDict[capability.entitlementKey] = strValue
    } else if let arrValue = entitlementValue as? [String] {
      entitlementsDict[capability.entitlementKey] = arrValue.joined(separator: ", ")
    } else if let boolValue = entitlementValue as? Bool {
      entitlementsDict[capability.entitlementKey] = boolValue ? "true" : "false"
    }

    var infoPlistDict: [String: String]? = nil
    if let usageKey = capability.usageDescriptionKey,
       let usageDesc = capability.defaultUsageDescription {
      infoPlistDict = [usageKey: value ?? usageDesc]
    }

    return CapabilityResult(
      success: true,
      message: "Added \(capability.description) capability",
      capability: capabilityName,
      entitlements: entitlementsDict,
      infoPlistAdditions: infoPlistDict
    )
  }

  /// List all available capabilities with platform info
  public static func listCapabilities() -> [String: CapabilityInfo] {
    var result: [String: CapabilityInfo] = [:]
    for cap in Capability.allCases {
      result[cap.rawValue] = CapabilityInfo(
        description: cap.description,
        platform: cap.platform.rawValue,
        entitlementKey: cap.entitlementKey
      )
    }
    return result
  }

  /// Capability info for listing
  public struct CapabilityInfo: Codable {
    public let description: String
    public let platform: String
    public let entitlementKey: String
  }
}
