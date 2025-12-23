import Foundation
import TOMLKit

/// xclaude.toml configuration - simple, user-facing format
public struct XClaudeConfig: Codable {
  public var app: AppConfig
  public var signing: SigningConfig?

  public init(app: AppConfig, signing: SigningConfig? = nil) {
    self.app = app
    self.signing = signing
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

    let app = AppConfig(
      name: name,
      bundleId: bundleId,
      version: version,
      icon: icon
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

    return XClaudeConfig(app: app, signing: signing)
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
  public var name: String
  public var bundleId: String
  public var version: String
  public var icon: String

  public init(name: String, bundleId: String, version: String = "1.0.0", icon: String = "icon.png") {
    self.name = name
    self.bundleId = bundleId
    self.version = version
    self.icon = icon
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
