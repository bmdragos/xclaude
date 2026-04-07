import Foundation

/// Target platform for capability emission.
public enum CapabilityPlatform: String, Codable, CaseIterable, Sendable {
  case iOS
  case macOS

  /// Parse a platform string like "iOS", "macos", "iphoneos", etc.
  /// Defaults to iOS for anything that isn't recognizably macOS.
  public static func parse(_ raw: String) -> CapabilityPlatform {
    let lower = raw.lowercased()
    if lower.contains("mac") || lower.contains("osx") || lower.contains("darwin") {
      return .macOS
    }
    return .iOS
  }
}

/// What a capability emits on a single platform.
public struct PlatformSpec: Sendable, Equatable {
  /// Entitlement keys with default values. Empty means no entitlement is required
  /// on this platform (e.g., iOS camera, which is handled purely via Info.plist).
  public let entitlements: [String: CapabilityValue]

  /// Info.plist keys with default string values (usage descriptions, etc.).
  public let infoPlist: [String: String]

  /// True if this capability requires macOS App Sandbox to be enabled.
  public let requiresSandbox: Bool

  /// Extra guidance surfaced to AI agents and users.
  public let notes: String?

  public init(
    entitlements: [String: CapabilityValue] = [:],
    infoPlist: [String: String] = [:],
    requiresSandbox: Bool = false,
    notes: String? = nil
  ) {
    self.entitlements = entitlements
    self.infoPlist = infoPlist
    self.requiresSandbox = requiresSandbox
    self.notes = notes
  }
}

/// Where a user-provided `value` parameter flows when `add_capability` is called
/// with a custom value.
public enum ValueSlot: Sendable, Equatable {
  /// Value replaces the default string at this Info.plist key (usage descriptions).
  case infoPlist(String)
  /// Value replaces the default at this entitlement key (e.g., aps-environment).
  case entitlement(String)
  /// Value is ignored (pure boolean capabilities).
  case none
}

/// Single source of truth for everything a capability produces, per platform.
///
/// A capability that is missing an entry in `platforms` for a given target is
/// considered unsupported on that platform — the build-time emitter will skip it.
public struct CapabilityManifest: Sendable {
  /// Stable identifier used in xclaude.toml `[capabilities]` keys.
  public let name: String

  /// Human-readable name (e.g., "Camera Access").
  public let displayName: String

  /// One-line summary of what the capability does.
  public let summary: String

  /// Per-platform emission specs.
  public let platforms: [CapabilityPlatform: PlatformSpec]

  /// Where a user's custom `value` parameter flows.
  public let valueSlot: ValueSlot

  public init(
    name: String,
    displayName: String,
    summary: String,
    platforms: [CapabilityPlatform: PlatformSpec],
    valueSlot: ValueSlot = .none
  ) {
    self.name = name
    self.displayName = displayName
    self.summary = summary
    self.platforms = platforms
    self.valueSlot = valueSlot
  }
}

extension CapabilityManifest {
  /// Is this capability supported on the given platform?
  public func supports(_ platform: CapabilityPlatform) -> Bool {
    platforms[platform] != nil
  }

  /// Platforms this capability supports, in stable order.
  public var supportedPlatforms: [CapabilityPlatform] {
    CapabilityPlatform.allCases.filter { supports($0) }
  }

  /// Entitlements to emit for `platform`, after applying the user-provided value.
  /// Returns an empty dictionary if the capability produces no entitlements on that
  /// platform (e.g., camera on iOS) or isn't supported there.
  public func resolvedEntitlements(
    for platform: CapabilityPlatform,
    userValue: CapabilityValue? = nil
  ) -> [String: Any] {
    guard let spec = platforms[platform] else { return [:] }
    var result: [String: Any] = [:]
    for (key, defaultValue) in spec.entitlements {
      result[key] = defaultValue.anyValue
    }
    if case .entitlement(let slotKey) = valueSlot,
       let userValue,
       result[slotKey] != nil {
      result[slotKey] = userValue.anyValue
    }
    return result
  }

  /// Info.plist entries to emit for `platform`, after applying the user-provided value.
  /// Returns an empty dictionary if the capability produces no Info.plist keys on that
  /// platform or isn't supported there.
  public func resolvedInfoPlist(
    for platform: CapabilityPlatform,
    userValue: CapabilityValue? = nil
  ) -> [String: String] {
    guard let spec = platforms[platform] else { return [:] }
    var result = spec.infoPlist
    if case .infoPlist(let slotKey) = valueSlot,
       let userValue,
       case .string(let str) = userValue,
       result[slotKey] != nil {
      result[slotKey] = str
    }
    return result
  }

  /// Union of all Info.plist entries this capability can emit across every platform
  /// it supports. Used at build-time to populate Info.plist without needing to know
  /// which exact platform is being targeted (extra NS*UsageDescription keys are
  /// harmless on all Apple platforms).
  public func unionInfoPlist(userValue: CapabilityValue? = nil) -> [String: String] {
    var merged: [String: String] = [:]
    for platform in supportedPlatforms {
      for (key, value) in resolvedInfoPlist(for: platform, userValue: userValue) {
        merged[key] = value
      }
    }
    return merged
  }
}

// MARK: - Registry

/// Registry of every capability xclaude understands.
///
/// Adding a new capability = adding a new entry to `manifests`. That single
/// declaration drives entitlement emission, Info.plist emission, platform
/// validation, and AI-agent-facing introspection.
public enum CapabilityRegistry {
  /// All capabilities, indexed by their stable xclaude.toml name.
  public static let manifests: [String: CapabilityManifest] = Dictionary(
    uniqueKeysWithValues: allManifests.map { ($0.name, $0) }
  )

  /// Look up a capability manifest by name.
  public static func manifest(for name: String) -> CapabilityManifest? {
    manifests[name]
  }

  /// All capability names in stable sorted order.
  public static var allNames: [String] {
    manifests.keys.sorted()
  }

  /// All manifests in the order they were declared below.
  public static let allManifests: [CapabilityManifest] = [
    // MARK: - iOS/macOS native permissions (the bug class)
    //
    // These are the capabilities that burned us: on iOS they need ONLY an
    // Info.plist usage description; on macOS they need BOTH a sandbox
    // entitlement AND the Info.plist key. Putting the macOS sandbox entitlement
    // into an iOS entitlements file breaks provisioning profile validation
    // with the cryptic "valid provisioning profile not found" error.

    CapabilityManifest(
      name: "camera",
      displayName: "Camera Access",
      summary: "Access the device camera.",
      platforms: [
        .iOS: PlatformSpec(
          infoPlist: ["NSCameraUsageDescription": "This app needs access to the camera."]
        ),
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.device.camera": .bool(true)],
          infoPlist: ["NSCameraUsageDescription": "This app needs access to the camera."],
          requiresSandbox: true
        ),
      ],
      valueSlot: .infoPlist("NSCameraUsageDescription")
    ),

    CapabilityManifest(
      name: "audio-input",
      displayName: "Microphone Access",
      summary: "Record audio from the microphone.",
      platforms: [
        .iOS: PlatformSpec(
          infoPlist: ["NSMicrophoneUsageDescription": "This app needs access to the microphone."]
        ),
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.device.audio-input": .bool(true)],
          infoPlist: ["NSMicrophoneUsageDescription": "This app needs access to the microphone."],
          requiresSandbox: true
        ),
      ],
      valueSlot: .infoPlist("NSMicrophoneUsageDescription")
    ),

    CapabilityManifest(
      name: "location",
      displayName: "Location Services",
      summary: "Access the user's location (when-in-use).",
      platforms: [
        .iOS: PlatformSpec(
          infoPlist: [
            "NSLocationWhenInUseUsageDescription": "This app needs access to your location."
          ],
          notes: "For background location tracking, also add 'location' to [app].background_modes."
        ),
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.personal-information.location": .bool(true)],
          infoPlist: [
            "NSLocationWhenInUseUsageDescription": "This app needs access to your location."
          ],
          requiresSandbox: true
        ),
      ],
      valueSlot: .infoPlist("NSLocationWhenInUseUsageDescription")
    ),

    CapabilityManifest(
      name: "address-book",
      displayName: "Contacts Access",
      summary: "Read or write the user's contacts.",
      platforms: [
        .iOS: PlatformSpec(
          infoPlist: ["NSContactsUsageDescription": "This app needs access to your contacts."]
        ),
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.personal-information.addressbook": .bool(true)],
          infoPlist: ["NSContactsUsageDescription": "This app needs access to your contacts."],
          requiresSandbox: true
        ),
      ],
      valueSlot: .infoPlist("NSContactsUsageDescription")
    ),

    CapabilityManifest(
      name: "calendars",
      displayName: "Calendars Access",
      summary: "Read or write the user's calendars.",
      platforms: [
        .iOS: PlatformSpec(
          infoPlist: ["NSCalendarsUsageDescription": "This app needs access to your calendars."]
        ),
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.personal-information.calendars": .bool(true)],
          infoPlist: ["NSCalendarsUsageDescription": "This app needs access to your calendars."],
          requiresSandbox: true
        ),
      ],
      valueSlot: .infoPlist("NSCalendarsUsageDescription")
    ),

    CapabilityManifest(
      name: "photos",
      displayName: "Photo Library Access",
      summary: "Access the user's photo library.",
      platforms: [
        .iOS: PlatformSpec(
          infoPlist: ["NSPhotoLibraryUsageDescription": "This app needs access to your photo library."]
        ),
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.personal-information.photos-library": .bool(true)],
          infoPlist: ["NSPhotoLibraryUsageDescription": "This app needs access to your photo library."],
          requiresSandbox: true
        ),
      ],
      valueSlot: .infoPlist("NSPhotoLibraryUsageDescription")
    ),

    CapabilityManifest(
      name: "bluetooth",
      displayName: "Bluetooth Access",
      summary: "Communicate with Bluetooth devices.",
      platforms: [
        .iOS: PlatformSpec(
          infoPlist: [
            "NSBluetoothAlwaysUsageDescription": "This app needs to communicate with Bluetooth devices."
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.device.bluetooth": .bool(true)],
          requiresSandbox: true
        ),
      ],
      valueSlot: .infoPlist("NSBluetoothAlwaysUsageDescription")
    ),

    // MARK: - Cross-platform Apple-developer entitlements
    //
    // These use `com.apple.developer.*` entitlements that work the same on both
    // iOS and macOS. The provisioning profile needs to authorize them on both
    // platforms, so they're straightforward `.both` capabilities.

    CapabilityManifest(
      name: "push-notifications",
      displayName: "Push Notifications",
      summary: "Receive remote push notifications from APNs.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["aps-environment": .string("development")]),
        .macOS: PlatformSpec(entitlements: ["aps-environment": .string("development")]),
      ],
      valueSlot: .entitlement("aps-environment")
    ),

    CapabilityManifest(
      name: "app-groups",
      displayName: "App Groups",
      summary: "Share data between apps and extensions via an app group.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.security.application-groups": .array(["group.$(CFBundleIdentifier)"])
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: [
            "com.apple.security.application-groups": .array(["group.$(CFBundleIdentifier)"])
          ]
        ),
      ],
      valueSlot: .entitlement("com.apple.security.application-groups")
    ),

    CapabilityManifest(
      name: "icloud",
      displayName: "iCloud",
      summary: "Store data in iCloud via CloudKit or key-value storage.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.icloud-container-identifiers": .array(["iCloud.$(CFBundleIdentifier)"])
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.icloud-container-identifiers": .array(["iCloud.$(CFBundleIdentifier)"])
          ]
        ),
      ],
      valueSlot: .entitlement("com.apple.developer.icloud-container-identifiers")
    ),

    CapabilityManifest(
      name: "keychain",
      displayName: "Keychain Sharing",
      summary: "Share keychain items between apps from the same developer.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "keychain-access-groups": .array(["$(AppIdentifierPrefix)$(CFBundleIdentifier)"])
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: [
            "keychain-access-groups": .array(["$(AppIdentifierPrefix)$(CFBundleIdentifier)"])
          ]
        ),
      ],
      valueSlot: .entitlement("keychain-access-groups")
    ),

    CapabilityManifest(
      name: "in-app-purchase",
      displayName: "In-App Purchase",
      summary: "Sell in-app purchases or subscriptions.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.in-app-payments": .array(["merchant.$(CFBundleIdentifier)"])
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.in-app-payments": .array(["merchant.$(CFBundleIdentifier)"])
          ]
        ),
      ],
      valueSlot: .entitlement("com.apple.developer.in-app-payments")
    ),

    CapabilityManifest(
      name: "siri",
      displayName: "SiriKit",
      summary: "Integrate with Siri via intents.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.siri": .bool(true)],
          infoPlist: ["NSSiriUsageDescription": "This app uses Siri to provide voice commands."]
        ),
        .macOS: PlatformSpec(
          entitlements: ["com.apple.developer.siri": .bool(true)],
          infoPlist: ["NSSiriUsageDescription": "This app uses Siri to provide voice commands."]
        ),
      ],
      valueSlot: .infoPlist("NSSiriUsageDescription")
    ),

    CapabilityManifest(
      name: "associated-domains",
      displayName: "Associated Domains",
      summary: "Universal Links and web credentials via associated domains.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.associated-domains": .array([
              "applinks:example.com", "webcredentials:example.com"
            ])
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.associated-domains": .array([
              "applinks:example.com", "webcredentials:example.com"
            ])
          ]
        ),
      ],
      valueSlot: .entitlement("com.apple.developer.associated-domains")
    ),

    CapabilityManifest(
      name: "sign-in-with-apple",
      displayName: "Sign in with Apple",
      summary: "Authenticate users with their Apple ID.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.applesignin": .array(["Default"])]),
        .macOS: PlatformSpec(entitlements: ["com.apple.developer.applesignin": .array(["Default"])]),
      ]
    ),

    CapabilityManifest(
      name: "game-center",
      displayName: "Game Center",
      summary: "Integrate with Game Center for leaderboards and achievements.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.game-center": .bool(true)]),
        .macOS: PlatformSpec(entitlements: ["com.apple.developer.game-center": .bool(true)]),
      ]
    ),

    CapabilityManifest(
      name: "shareplay",
      displayName: "SharePlay (Group Activities)",
      summary: "Share activities with users during FaceTime calls.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.group-session": .bool(true)]),
        .macOS: PlatformSpec(entitlements: ["com.apple.developer.group-session": .bool(true)]),
      ]
    ),

    CapabilityManifest(
      name: "handoff",
      displayName: "Handoff (Continuity)",
      summary: "Continue user activities between devices via Handoff.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.handoff": .bool(true)]),
        .macOS: PlatformSpec(entitlements: ["com.apple.developer.handoff": .bool(true)]),
      ]
    ),

    CapabilityManifest(
      name: "shazamkit",
      displayName: "ShazamKit",
      summary: "Audio recognition via ShazamKit.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.shazamkit.referral": .bool(true)]),
        .macOS: PlatformSpec(entitlements: ["com.apple.developer.shazamkit.referral": .bool(true)]),
      ]
    ),

    CapabilityManifest(
      name: "musickit",
      displayName: "MusicKit",
      summary: "Access Apple Music content via MusicKit.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.musickit": .bool(true)]),
        .macOS: PlatformSpec(entitlements: ["com.apple.developer.musickit": .bool(true)]),
      ]
    ),

    CapabilityManifest(
      name: "devicecheck",
      displayName: "DeviceCheck / App Attest",
      summary: "Validate device integrity via DeviceCheck / App Attest.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.devicecheck.appattest-environment": .string("production")
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.devicecheck.appattest-environment": .string("production")
          ]
        ),
      ],
      valueSlot: .entitlement("com.apple.developer.devicecheck.appattest-environment")
    ),

    CapabilityManifest(
      name: "data-protection",
      displayName: "Data Protection",
      summary: "File-level encryption via Data Protection classes.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.default-data-protection": .string("NSFileProtectionComplete")
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.default-data-protection": .string("NSFileProtectionComplete")
          ]
        ),
      ],
      valueSlot: .entitlement("com.apple.developer.default-data-protection")
    ),

    CapabilityManifest(
      name: "autofill-credentials",
      displayName: "AutoFill Credential Provider",
      summary: "Provide passwords via AutoFill.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.authentication-services.autofill-credential-provider": .bool(true)
          ]
        ),
        .macOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.authentication-services.autofill-credential-provider": .bool(true)
          ]
        ),
      ]
    ),

    // MARK: - iOS-only capabilities

    CapabilityManifest(
      name: "healthkit",
      displayName: "HealthKit",
      summary: "Read and write Apple Health data.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.healthkit": .bool(true)],
          infoPlist: [
            "NSHealthShareUsageDescription": "This app needs to read your health data.",
            "NSHealthUpdateUsageDescription": "This app needs to save workout data to Health.",
          ]
        )
      ],
      valueSlot: .infoPlist("NSHealthShareUsageDescription")
    ),

    CapabilityManifest(
      name: "homekit",
      displayName: "HomeKit",
      summary: "Control HomeKit-compatible smart home devices.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.homekit": .bool(true)],
          infoPlist: ["NSHomeKitUsageDescription": "This app needs access to your HomeKit devices."]
        )
      ],
      valueSlot: .infoPlist("NSHomeKitUsageDescription")
    ),

    CapabilityManifest(
      name: "network-extension",
      displayName: "Network Extensions",
      summary: "Implement VPN, content filters, or packet tunnels.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.networking.networkextension": .array(["packet-tunnel"])
          ]
        )
      ],
      valueSlot: .entitlement("com.apple.developer.networking.networkextension")
    ),

    CapabilityManifest(
      name: "wallet",
      displayName: "Wallet",
      summary: "Add passes to Apple Wallet.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.pass-type-identifiers": .array(["$(TeamIdentifierPrefix)*"])
          ]
        )
      ],
      valueSlot: .entitlement("com.apple.developer.pass-type-identifiers")
    ),

    CapabilityManifest(
      name: "background-modes",
      displayName: "Background Modes",
      summary: "Request background execution modes (fetch, audio, location, etc.).",
      platforms: [
        .iOS: PlatformSpec(
          notes: "Set the actual modes via [app].background_modes in xclaude.toml."
        )
      ]
    ),

    CapabilityManifest(
      name: "nfc",
      displayName: "NFC Tag Reading",
      summary: "Read NFC tags via Core NFC.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: [
            "com.apple.developer.nfc.readersession.formats": .array(["NDEF", "TAG"])
          ],
          infoPlist: ["NFCReaderUsageDescription": "This app needs to read NFC tags."]
        )
      ],
      valueSlot: .infoPlist("NFCReaderUsageDescription")
    ),

    CapabilityManifest(
      name: "carplay",
      displayName: "CarPlay",
      summary: "Integrate with CarPlay.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.carplay-audio": .bool(true)])
      ]
    ),

    CapabilityManifest(
      name: "classkit",
      displayName: "ClassKit (Education)",
      summary: "Integrate with ClassKit for educational apps.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.ClassKit-environment": .bool(true)])
      ]
    ),

    CapabilityManifest(
      name: "access-wifi",
      displayName: "Access WiFi Information",
      summary: "Read the current Wi-Fi network SSID / BSSID.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.networking.wifi-info": .bool(true)])
      ]
    ),

    CapabilityManifest(
      name: "hotspot",
      displayName: "Hotspot Configuration",
      summary: "Configure Wi-Fi hotspot networks.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.networking.HotspotConfiguration": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "multipath",
      displayName: "Multipath Networking",
      summary: "Use Multipath TCP to combine Wi-Fi and cellular.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.networking.multipath": .bool(true)])
      ]
    ),

    CapabilityManifest(
      name: "weatherkit",
      displayName: "WeatherKit",
      summary: "Access weather data via WeatherKit.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.weatherkit": .bool(true)])
      ]
    ),

    CapabilityManifest(
      name: "critical-alerts",
      displayName: "Critical Alerts",
      summary: "Deliver critical notifications that bypass Do Not Disturb.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.usernotifications.critical-alerts": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "time-sensitive",
      displayName: "Time-Sensitive Notifications",
      summary: "Send time-sensitive notifications.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.usernotifications.time-sensitive": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "communication-notifications",
      displayName: "Communication Notifications",
      summary: "Show communication notifications with sender avatars.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.usernotifications.communication": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "push-to-talk",
      displayName: "Push to Talk",
      summary: "Walkie-talkie style push-to-talk experiences.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.push-to-talk": .bool(true)])
      ]
    ),

    CapabilityManifest(
      name: "matter",
      displayName: "Matter Smart Home",
      summary: "Control Matter-compatible smart home accessories.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.matter.allow-setup-payload": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "financekit",
      displayName: "FinanceKit",
      summary: "Access Apple Wallet financial data.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.financekit": .bool(true)])
      ]
    ),

    CapabilityManifest(
      name: "increased-memory-limit",
      displayName: "Increased Memory Limit",
      summary: "Request an increased memory limit on supported devices.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.kernel.increased-memory-limit": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "extended-virtual-addressing",
      displayName: "Extended Virtual Addressing",
      summary: "Access more than 4 GB of virtual address space.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.kernel.extended-virtual-addressing": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "personal-vpn",
      displayName: "Personal VPN",
      summary: "Configure personal VPN tunnels.",
      platforms: [
        .iOS: PlatformSpec(
          entitlements: ["com.apple.developer.networking.vpn.api": .array(["allow-vpn"])]
        )
      ]
    ),

    CapabilityManifest(
      name: "family-controls",
      displayName: "Family Controls (Screen Time)",
      summary: "Integrate with Screen Time / Family Controls APIs.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.family-controls": .bool(true)])
      ]
    ),

    CapabilityManifest(
      name: "maps-routing",
      displayName: "Maps Routing",
      summary: "Register as a Maps routing app.",
      platforms: [
        .iOS: PlatformSpec(entitlements: ["com.apple.developer.maps": .bool(true)])
      ]
    ),

    // MARK: - macOS-only capabilities (App Sandbox, hardened runtime, etc.)

    CapabilityManifest(
      name: "apple-events",
      displayName: "Apple Events (Automation)",
      summary: "Control other applications via AppleScript / Apple Events.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.automation.apple-events": .bool(true)],
          infoPlist: [
            "NSAppleEventsUsageDescription":
              "This app needs to control other applications for automation."
          ],
          requiresSandbox: true
        )
      ],
      valueSlot: .infoPlist("NSAppleEventsUsageDescription")
    ),

    CapabilityManifest(
      name: "hardened-runtime",
      displayName: "Hardened Runtime",
      summary: "Enable Hardened Runtime (set via codesign flags, not entitlements).",
      platforms: [
        .macOS: PlatformSpec(
          notes: "Hardened Runtime is a codesign flag (--options runtime), not an entitlement."
        )
      ]
    ),

    CapabilityManifest(
      name: "allow-jit",
      displayName: "Allow JIT Compilation",
      summary: "Permit JIT-compiled code under Hardened Runtime.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.cs.allow-jit": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "allow-unsigned-memory",
      displayName: "Allow Unsigned Executable Memory",
      summary: "Permit unsigned executable memory pages under Hardened Runtime.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.cs.allow-unsigned-executable-memory": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "allow-dyld-env",
      displayName: "Allow DYLD Environment Variables",
      summary: "Honor DYLD_* environment variables under Hardened Runtime.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.cs.allow-dyld-environment-variables": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "files-read-only",
      displayName: "User-Selected Files (Read Only)",
      summary: "Read files selected by the user via an open panel.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.files.user-selected.read-only": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "files-read-write",
      displayName: "User-Selected Files (Read/Write)",
      summary: "Read and write files selected by the user.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.files.user-selected.read-write": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "files-downloads",
      displayName: "Downloads Folder Access",
      summary: "Read and write the user's Downloads folder.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.files.downloads.read-write": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "system-extension",
      displayName: "System Extension Installation",
      summary: "Install system extensions.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.developer.system-extension.install": .bool(true)]
        )
      ]
    ),

    CapabilityManifest(
      name: "network-client",
      displayName: "Network Client (Outgoing Connections)",
      summary: "Make outgoing network connections (sandboxed apps).",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.network.client": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "network-server",
      displayName: "Network Server (Incoming Connections)",
      summary: "Accept incoming network connections (sandboxed apps).",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.network.server": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "usb",
      displayName: "USB Device Access",
      summary: "Communicate with USB devices (sandboxed apps).",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.device.usb": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "print",
      displayName: "Printing",
      summary: "Print documents (sandboxed apps).",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.print": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "serial",
      displayName: "Serial Port Access",
      summary: "Communicate with serial devices (sandboxed apps).",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.device.serial": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "music-library",
      displayName: "Music Library Access (iTunes)",
      summary: "Read the user's iTunes / Music library.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.assets.music.read-only": .bool(true)],
          requiresSandbox: true
        )
      ]
    ),

    CapabilityManifest(
      name: "app-sandbox",
      displayName: "App Sandbox",
      summary: "Enable the macOS App Sandbox.",
      platforms: [
        .macOS: PlatformSpec(
          entitlements: ["com.apple.security.app-sandbox": .bool(true)]
        )
      ]
    ),
  ]
}
