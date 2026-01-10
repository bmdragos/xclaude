import Foundation
import TOMLKit

/// xclaude.toml configuration - simple, user-facing format
public struct XClaudeConfig: Codable {
  public var app: AppConfig
  public var signing: SigningConfig?
  public var infoPlist: [String: String]?  // Custom Info.plist entries

  public init(app: AppConfig, signing: SigningConfig? = nil, infoPlist: [String: String]? = nil) {
    self.app = app
    self.signing = signing
    self.infoPlist = infoPlist
  }

  /// Load config from xclaude.toml in a directory
  public static func load(from directory: URL) throws -> XClaudeConfig {
    let configPath = directory.appendingPathComponent("xclaude.toml")

    guard FileManager.default.fileExists(atPath: configPath.path) else {
      throw ConfigError.notFound(configPath.path)
    }

    let content = try String(contentsOf: configPath, encoding: .utf8)
    return try parse(content)
  }

  /// Parse xclaude.toml content
  public static func parse(_ content: String) throws -> XClaudeConfig {
    let table = try TOMLTable(string: content)

    // Parse [app] section (required)
    guard let appTable = table["app"]?.table else {
      throw ConfigError.missingSectionApp
    }

    guard let name = appTable["name"]?.string else {
      throw ConfigError.missingField("app.name")
    }

    let bundleId = appTable["bundle_id"]?.string ?? deriveBundleId(from: name)
    let version = appTable["version"]?.string ?? "1.0.0"
    let icon = appTable["icon"]?.string ?? "icon.png"

    // Helper to parse string arrays
    func parseStringArray(_ key: String) -> [String]? {
      guard let array = appTable[key]?.array else { return nil }
      let strings = array.compactMap { $0.string }
      return strings.isEmpty ? nil : strings
    }

    // Parse all optional fields
    let orientations = parseStringArray("orientations")
    let orientationsIpad = parseStringArray("orientations_ipad")
    let requiresFullScreen = appTable["requires_full_screen"]?.bool
    let statusBarHidden = appTable["status_bar_hidden"]?.bool
    let statusBarStyle = appTable["status_bar_style"]?.string
    let backgroundModes = parseStringArray("background_modes")
    let requiredCapabilities = parseStringArray("required_capabilities")
    let urlSchemes = parseStringArray("url_schemes")
    let queriedSchemes = parseStringArray("queried_schemes")
    let requiresPersistentWifi = appTable["requires_persistent_wifi"]?.bool
    let fileSharingEnabled = appTable["file_sharing_enabled"]?.bool
    let supportsDocumentBrowser = appTable["supports_document_browser"]?.bool
    let appFonts = parseStringArray("app_fonts")
    let launchStoryboard = appTable["launch_storyboard"]?.string

    let app = AppConfig(
      name: name,
      bundleId: bundleId,
      version: version,
      icon: icon,
      orientations: orientations,
      orientationsIpad: orientationsIpad,
      requiresFullScreen: requiresFullScreen,
      statusBarHidden: statusBarHidden,
      statusBarStyle: statusBarStyle,
      backgroundModes: backgroundModes,
      requiredCapabilities: requiredCapabilities,
      urlSchemes: urlSchemes,
      queriedSchemes: queriedSchemes,
      requiresPersistentWifi: requiresPersistentWifi,
      fileSharingEnabled: fileSharingEnabled,
      supportsDocumentBrowser: supportsDocumentBrowser,
      appFonts: appFonts,
      launchStoryboard: launchStoryboard
    )

    // Parse [signing] section (optional)
    var signing: SigningConfig? = nil
    if let signingTable = table["signing"]?.table {
      signing = SigningConfig(
        team: signingTable["team"]?.string,
        identity: signingTable["identity"]?.string,
        profile: signingTable["profile"]?.string
      )
    }

    // Parse [info_plist] section (optional)
    var infoPlist: [String: String]? = nil
    if let infoPlistTable = table["info_plist"]?.table {
      var entries: [String: String] = [:]
      for (key, value) in infoPlistTable {
        if let strValue = value.string {
          entries[key] = strValue
        }
      }
      if !entries.isEmpty {
        infoPlist = entries
      }
    }

    return XClaudeConfig(app: app, signing: signing, infoPlist: infoPlist)
  }

  /// Save config to xclaude.toml
  public func save(to directory: URL) throws {
    let configPath = directory.appendingPathComponent("xclaude.toml")
    let content = toTOML()
    try content.write(to: configPath, atomically: true, encoding: .utf8)
  }

  /// Generate TOML string
  public func toTOML() -> String {
    var lines: [String] = []

    // Helper to format string arrays for TOML
    func formatArray(_ arr: [String]) -> String {
      arr.map { "\"\($0)\"" }.joined(separator: ", ")
    }

    lines.append("[app]")
    lines.append("name = \"\(app.name)\"")
    if app.bundleId != XClaudeConfig.deriveBundleId(from: app.name) {
      lines.append("bundle_id = \"\(app.bundleId)\"")
    }
    if app.version != "1.0.0" {
      lines.append("version = \"\(app.version)\"")
    }
    if app.icon != "icon.png" {
      lines.append("icon = \"\(app.icon)\"")
    }

    // Orientations
    if let orientations = app.orientations, !orientations.isEmpty {
      lines.append("orientations = [\(formatArray(orientations))]")
    }
    if let orientationsIpad = app.orientationsIpad, !orientationsIpad.isEmpty {
      lines.append("orientations_ipad = [\(formatArray(orientationsIpad))]")
    }
    if let requiresFullScreen = app.requiresFullScreen {
      lines.append("requires_full_screen = \(requiresFullScreen)")
    }

    // Status Bar
    if let statusBarHidden = app.statusBarHidden {
      lines.append("status_bar_hidden = \(statusBarHidden)")
    }
    if let statusBarStyle = app.statusBarStyle {
      lines.append("status_bar_style = \"\(statusBarStyle)\"")
    }

    // Background Modes
    if let backgroundModes = app.backgroundModes, !backgroundModes.isEmpty {
      lines.append("background_modes = [\(formatArray(backgroundModes))]")
    }

    // Device Capabilities
    if let requiredCapabilities = app.requiredCapabilities, !requiredCapabilities.isEmpty {
      lines.append("required_capabilities = [\(formatArray(requiredCapabilities))]")
    }

    // URL Schemes
    if let urlSchemes = app.urlSchemes, !urlSchemes.isEmpty {
      lines.append("url_schemes = [\(formatArray(urlSchemes))]")
    }
    if let queriedSchemes = app.queriedSchemes, !queriedSchemes.isEmpty {
      lines.append("queried_schemes = [\(formatArray(queriedSchemes))]")
    }

    // Medium Priority
    if let requiresPersistentWifi = app.requiresPersistentWifi {
      lines.append("requires_persistent_wifi = \(requiresPersistentWifi)")
    }
    if let fileSharingEnabled = app.fileSharingEnabled {
      lines.append("file_sharing_enabled = \(fileSharingEnabled)")
    }
    if let supportsDocumentBrowser = app.supportsDocumentBrowser {
      lines.append("supports_document_browser = \(supportsDocumentBrowser)")
    }
    if let appFonts = app.appFonts, !appFonts.isEmpty {
      lines.append("app_fonts = [\(formatArray(appFonts))]")
    }
    if let launchStoryboard = app.launchStoryboard {
      lines.append("launch_storyboard = \"\(launchStoryboard)\"")
    }

    if let signing = signing,
       (signing.team != nil || signing.identity != nil || signing.profile != nil) {
      lines.append("")
      lines.append("[signing]")
      if let team = signing.team {
        lines.append("team = \"\(team)\"")
      }
      if let identity = signing.identity {
        lines.append("identity = \"\(identity)\"")
      }
      if let profile = signing.profile {
        lines.append("profile = \"\(profile)\"")
      }
    }

    if let infoPlist = infoPlist, !infoPlist.isEmpty {
      lines.append("")
      lines.append("[info_plist]")
      for (key, value) in infoPlist.sorted(by: { $0.key < $1.key }) {
        let escapedValue = value.replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "\"", with: "\\\"")
        lines.append("\(key) = \"\(escapedValue)\"")
      }
    }

    return lines.joined(separator: "\n") + "\n"
  }

  /// Derive bundle ID from app name
  public static func deriveBundleId(from name: String) -> String {
    let sanitized = name
      .lowercased()
      .replacingOccurrences(of: " ", with: "")
      .filter { $0.isLetter || $0.isNumber }
    return "com.xclaude.\(sanitized)"
  }
}

/// App configuration
public struct AppConfig: Codable {
  // Basic
  public var name: String
  public var bundleId: String
  public var version: String
  public var icon: String

  // Orientation
  public var orientations: [String]?       // iPhone orientations
  public var orientationsIpad: [String]?   // iPad-specific orientations
  public var requiresFullScreen: Bool?     // Locks iPad orientation (disables multitasking)

  // Status Bar
  public var statusBarHidden: Bool?
  public var statusBarStyle: String?       // "default", "light", "dark"

  // Background Modes
  public var backgroundModes: [String]?    // ["audio", "bluetooth-central", "location", etc.]

  // Device Capabilities
  public var requiredCapabilities: [String]?  // ["bluetooth-le", "arm64", "arkit", etc.]

  // URL Schemes
  public var urlSchemes: [String]?         // Custom URL schemes app handles
  public var queriedSchemes: [String]?     // Schemes app queries with canOpenURL

  // Medium Priority
  public var requiresPersistentWifi: Bool?
  public var fileSharingEnabled: Bool?
  public var supportsDocumentBrowser: Bool?
  public var appFonts: [String]?           // Custom font filenames
  public var launchStoryboard: String?

  public init(
    name: String,
    bundleId: String,
    version: String = "1.0.0",
    icon: String = "icon.png",
    orientations: [String]? = nil,
    orientationsIpad: [String]? = nil,
    requiresFullScreen: Bool? = nil,
    statusBarHidden: Bool? = nil,
    statusBarStyle: String? = nil,
    backgroundModes: [String]? = nil,
    requiredCapabilities: [String]? = nil,
    urlSchemes: [String]? = nil,
    queriedSchemes: [String]? = nil,
    requiresPersistentWifi: Bool? = nil,
    fileSharingEnabled: Bool? = nil,
    supportsDocumentBrowser: Bool? = nil,
    appFonts: [String]? = nil,
    launchStoryboard: String? = nil
  ) {
    self.name = name
    self.bundleId = bundleId
    self.version = version
    self.icon = icon
    self.orientations = orientations
    self.orientationsIpad = orientationsIpad
    self.requiresFullScreen = requiresFullScreen
    self.statusBarHidden = statusBarHidden
    self.statusBarStyle = statusBarStyle
    self.backgroundModes = backgroundModes
    self.requiredCapabilities = requiredCapabilities
    self.urlSchemes = urlSchemes
    self.queriedSchemes = queriedSchemes
    self.requiresPersistentWifi = requiresPersistentWifi
    self.fileSharingEnabled = fileSharingEnabled
    self.supportsDocumentBrowser = supportsDocumentBrowser
    self.appFonts = appFonts
    self.launchStoryboard = launchStoryboard
  }

  // MARK: - Mapping Helpers

  /// Map user-friendly orientation names to UIInterfaceOrientation values
  public static func mapOrientations(_ orientations: [String]) -> [String] {
    orientations.compactMap { orientation in
      switch orientation.lowercased() {
      case "portrait":
        return "UIInterfaceOrientationPortrait"
      case "portrait-upside-down", "portraitupsidedown":
        return "UIInterfaceOrientationPortraitUpsideDown"
      case "landscape-left", "landscapeleft":
        return "UIInterfaceOrientationLandscapeLeft"
      case "landscape-right", "landscaperight":
        return "UIInterfaceOrientationLandscapeRight"
      default:
        return nil
      }
    }
  }

  /// Map user-friendly status bar style to UIStatusBarStyle values
  public static func mapStatusBarStyle(_ style: String) -> String {
    switch style.lowercased() {
    case "light", "light-content":
      return "UIStatusBarStyleLightContent"
    case "dark", "dark-content":
      return "UIStatusBarStyleDarkContent"
    default:
      return "UIStatusBarStyleDefault"
    }
  }

  /// Map user-friendly background mode names to UIBackgroundModes values
  public static func mapBackgroundModes(_ modes: [String]) -> [String] {
    modes.compactMap { mode in
      switch mode.lowercased() {
      case "audio":
        return "audio"
      case "location":
        return "location"
      case "voip":
        return "voip"
      case "fetch", "background-fetch":
        return "fetch"
      case "remote-notification", "push":
        return "remote-notification"
      case "newsstand-content":
        return "newsstand-content"
      case "external-accessory":
        return "external-accessory"
      case "bluetooth-central", "ble-central":
        return "bluetooth-central"
      case "bluetooth-peripheral", "ble-peripheral":
        return "bluetooth-peripheral"
      case "processing":
        return "processing"
      default:
        return mode  // Pass through unknown modes
      }
    }
  }
}

/// Signing configuration (all optional - discovered if missing)
public struct SigningConfig: Codable {
  public var team: String?
  public var identity: String?
  public var profile: String?

  public init(team: String? = nil, identity: String? = nil, profile: String? = nil) {
    self.team = team
    self.identity = identity
    self.profile = profile
  }
}

/// Config errors
public enum ConfigError: Error, CustomStringConvertible {
  case notFound(String)
  case missingSectionApp
  case missingField(String)
  case invalidFormat(String)

  public var description: String {
    switch self {
    case .notFound(let path):
      return "xclaude.toml not found at \(path)"
    case .missingSectionApp:
      return "Missing required [app] section in xclaude.toml"
    case .missingField(let field):
      return "Missing required field '\(field)' in xclaude.toml"
    case .invalidFormat(let message):
      return "Invalid config format: \(message)"
    }
  }
}
