import Foundation

/// The kind of an app extension, modeled on Apple's supported extension points.
///
/// Each case maps to a specific `NSExtensionPointIdentifier` and a set of
/// required Info.plist keys + entitlements. This is the single source of truth
/// for "what does a widget extension need?" (or share, intents, etc.) —
/// mirroring the per-platform manifest pattern used for capabilities.
public enum ExtensionType: String, Codable, CaseIterable, Sendable {
  /// WidgetKit widgets, including Live Activities (when configured).
  case widget

  /// Share sheet extensions.
  case share

  /// Action sheet extensions.
  case action

  /// Intent handler extensions (SiriKit / App Intents).
  case intents

  /// Custom UI for notifications.
  case notificationContent = "notification-content"

  /// Background notification processing (mutating push payloads).
  case notificationService = "notification-service"

  /// Human-readable display name.
  public var displayName: String {
    switch self {
    case .widget: return "Widget Extension"
    case .share: return "Share Extension"
    case .action: return "Action Extension"
    case .intents: return "Intents Extension"
    case .notificationContent: return "Notification Content Extension"
    case .notificationService: return "Notification Service Extension"
    }
  }

  /// The `NSExtensionPointIdentifier` value for this extension type.
  public var extensionPointIdentifier: String {
    switch self {
    case .widget: return "com.apple.widgetkit-extension"
    case .share: return "com.apple.share-services"
    case .action: return "com.apple.ui-services"
    case .intents: return "com.apple.intents-service"
    case .notificationContent: return "com.apple.usernotifications.content-extension"
    case .notificationService: return "com.apple.usernotifications.service"
    }
  }

  /// The principal class name to put in the extension's NSExtension dict, if
  /// the extension type requires one. Widget extensions don't — they use
  /// `@main` on a `Widget` conformer instead.
  public var principalClass: String? {
    switch self {
    case .widget: return nil
    case .share: return "ShareViewController"
    case .action: return "ActionViewController"
    case .intents: return "IntentHandler"
    case .notificationContent: return "NotificationViewController"
    case .notificationService: return "NotificationService"
    }
  }

  /// One-line summary surfaced to AI agents via list_extensions.
  public var summary: String {
    switch self {
    case .widget:
      return "WidgetKit widget, Control Center widget, or Live Activity."
    case .share:
      return "Appears in the system share sheet to receive shared content."
    case .action:
      return "Custom action in the share sheet or other action extension points."
    case .intents:
      return "SiriKit intent handler."
    case .notificationContent:
      return "Custom UI displayed when the user long-presses a notification."
    case .notificationService:
      return "Runs before a remote notification is delivered to modify its content."
    }
  }
}

/// What an extension of a given type emits: Info.plist keys, entitlements,
/// and any additional notes or flags.
public struct ExtensionPlatformSpec: Sendable, Equatable {
  /// Info.plist keys specific to this extension target (not the parent app).
  /// These go into `<ext>.appex/Info.plist`, not the parent `.app`'s Info.plist.
  public let infoPlist: [String: CapabilityValue]

  /// Entitlement keys with default values for the extension target.
  /// These go into the extension's own Entitlements.plist.
  public let entitlements: [String: CapabilityValue]

  /// Info.plist keys that must be added to the PARENT app (not the extension).
  /// Example: widgets that host Live Activities need `NSSupportsLiveActivities`
  /// in the parent app's Info.plist, not the widget's.
  public let parentAppInfoPlist: [String: String]

  /// Additional guidance for users / AI agents.
  public let notes: String?

  public init(
    infoPlist: [String: CapabilityValue] = [:],
    entitlements: [String: CapabilityValue] = [:],
    parentAppInfoPlist: [String: String] = [:],
    notes: String? = nil
  ) {
    self.infoPlist = infoPlist
    self.entitlements = entitlements
    self.parentAppInfoPlist = parentAppInfoPlist
    self.notes = notes
  }
}

/// Single source of truth for what an extension target needs to be built and
/// embedded correctly. A manifest is declarative data, resolved at build time
/// into per-extension Info.plist + Entitlements.plist files by `ConfigTranslator`
/// and `SigningDiscovery`.
public struct ExtensionManifest: Sendable {
  /// The extension kind (widget, share, intents, etc.).
  public let type: ExtensionType

  /// Default per-platform emission spec. Use `spec(for:liveActivities:)` to
  /// get the fully-resolved spec, which may add Live Activity keys for widget
  /// extensions.
  public let baseSpec: ExtensionPlatformSpec

  public init(type: ExtensionType, baseSpec: ExtensionPlatformSpec) {
    self.type = type
    self.baseSpec = baseSpec
  }
}

extension ExtensionManifest {
  /// Resolve the full per-extension spec, applying any opt-in flags from the
  /// user's `ExtensionConfig` declaration.
  ///
  /// - Parameter liveActivities: if true, widget extensions opt into
  ///   ActivityKit — the parent app gets `NSSupportsLiveActivities = true`.
  public func resolvedSpec(liveActivities: Bool = false) -> ExtensionPlatformSpec {
    guard type == .widget && liveActivities else {
      return baseSpec
    }
    // Widget extensions with Live Activities need NSSupportsLiveActivities
    // in the PARENT app's Info.plist, not the widget's own Info.plist.
    var parentInfoPlist = baseSpec.parentAppInfoPlist
    parentInfoPlist["NSSupportsLiveActivities"] = "YES"
    return ExtensionPlatformSpec(
      infoPlist: baseSpec.infoPlist,
      entitlements: baseSpec.entitlements,
      parentAppInfoPlist: parentInfoPlist,
      notes: baseSpec.notes
    )
  }
}

// MARK: - Registry

/// Registry of every extension type xclaude understands.
///
/// Adding support for a new extension type = adding an entry to `manifests`.
/// The single declaration drives Info.plist emission, entitlements emission,
/// parent-app flag injection, and AI-agent-facing introspection.
public enum ExtensionRegistry {
  /// All extension manifests, indexed by type.
  public static let manifests: [ExtensionType: ExtensionManifest] = Dictionary(
    uniqueKeysWithValues: allManifests.map { ($0.type, $0) }
  )

  /// Look up the manifest for an extension type.
  public static func manifest(for type: ExtensionType) -> ExtensionManifest? {
    manifests[type]
  }

  /// Look up the manifest by string name (as it appears in xclaude.toml).
  public static func manifest(forName name: String) -> ExtensionManifest? {
    guard let type = ExtensionType(rawValue: name) else { return nil }
    return manifests[type]
  }

  /// All extension type names in stable order.
  public static var allNames: [String] {
    ExtensionType.allCases.map { $0.rawValue }
  }

  /// All manifests, in declaration order.
  public static let allManifests: [ExtensionManifest] = [

    // MARK: - Widget Extension (WidgetKit + optional ActivityKit)
    //
    // Widgets use `@main` on a `Widget`-conforming struct, so there's no
    // principal class. The NSExtension dict (built from the type's
    // extensionPointIdentifier + principalClass) is the only extension-
    // specific Info.plist content needed. If the widget hosts Live
    // Activities, the PARENT app also needs `NSSupportsLiveActivities = YES`
    // (handled automatically when `live_activities = true` is set).

    ExtensionManifest(
      type: .widget,
      baseSpec: ExtensionPlatformSpec(
        notes:
          "Add `live_activities = true` to the extension declaration to enable "
          + "ActivityKit — this adds NSSupportsLiveActivities to the PARENT app's "
          + "Info.plist automatically."
      )
    ),

    // MARK: - Share Extension
    //
    // Share extensions appear in the share sheet. The principal class is a
    // UIViewController (typically SLComposeServiceViewController subclass).
    // NSExtensionAttributes declares what content types the extension accepts.

    ExtensionManifest(
      type: .share,
      baseSpec: ExtensionPlatformSpec(
        notes:
          "Customize NSExtensionAttributes.NSExtensionActivationRule to declare "
          + "which content types the extension accepts."
      )
    ),

    // MARK: - Action Extension

    ExtensionManifest(
      type: .action,
      baseSpec: ExtensionPlatformSpec()
    ),

    // MARK: - Intents Extension (SiriKit)

    ExtensionManifest(
      type: .intents,
      baseSpec: ExtensionPlatformSpec(
        notes:
          "Declare supported intents under NSExtensionAttributes.IntentsSupported."
      )
    ),

    // MARK: - Notification Content Extension
    //
    // Custom UI shown when the user long-presses a remote notification.
    // Requires NSExtensionAttributes.UNNotificationExtensionCategory.

    ExtensionManifest(
      type: .notificationContent,
      baseSpec: ExtensionPlatformSpec(
        notes:
          "Set NSExtensionAttributes.UNNotificationExtensionCategory to the "
          + "notification category identifier this UI applies to."
      )
    ),

    // MARK: - Notification Service Extension
    //
    // Runs before a remote notification is delivered. Can modify the payload
    // (e.g., download attachments, decrypt content). Requires Push
    // Notifications capability.

    ExtensionManifest(
      type: .notificationService,
      baseSpec: ExtensionPlatformSpec(
        notes:
          "The parent app must declare the Push Notifications capability."
      )
    ),
  ]
}
