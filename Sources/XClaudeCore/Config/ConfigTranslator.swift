import Foundation

/// Translates xclaude.toml to Bundler.toml
public struct ConfigTranslator {
  /// Directory for derived files
  public static func derivedDirectory(for project: URL) -> URL {
    project.appendingPathComponent(".xclaude").appendingPathComponent("derived")
  }

  /// Path to generated Bundler.toml
  public static func bundlerConfigPath(for project: URL) -> URL {
    derivedDirectory(for: project).appendingPathComponent("Bundler.toml")
  }

  /// Translate xclaude.toml to Bundler.toml
  /// Returns path to generated Bundler.toml
  public static func translate(config: XClaudeConfig, projectDirectory: URL) throws -> URL {
    let derivedDir = derivedDirectory(for: projectDirectory)
    let bundlerPath = bundlerConfigPath(for: projectDirectory)

    // Create derived directory
    try FileManager.default.createDirectory(at: derivedDir, withIntermediateDirectories: true)

    // Resolve icon path - check explicit config, then fallback to asset catalog
    let resolvedIconPath = resolveIconPath(config: config, projectDirectory: projectDirectory, derivedDir: derivedDir)

    // Generate Bundler.toml content with resolved icon
    let content = generateBundlerTOML(config: config, projectDirectory: projectDirectory, iconPath: resolvedIconPath)

    // Write file
    try content.write(to: bundlerPath, atomically: true, encoding: .utf8)

    // Create symlink to icon if it exists and isn't already in derived
    if let iconPath = resolvedIconPath {
      let iconSource = projectDirectory.appendingPathComponent(iconPath)
      let iconFilename = (iconPath as NSString).lastPathComponent
      let iconDest = derivedDir.appendingPathComponent(iconFilename)

      // Only create symlink if source is outside derived dir
      if FileManager.default.fileExists(atPath: iconSource.path) &&
         !iconSource.path.hasPrefix(derivedDir.path) {
        try? FileManager.default.removeItem(at: iconDest)
        try FileManager.default.createSymbolicLink(at: iconDest, withDestinationURL: iconSource)
      }
    }

    return bundlerPath
  }

  /// Resolve icon path - tries config path first, then falls back to asset catalog extraction
  private static func resolveIconPath(config: XClaudeConfig, projectDirectory: URL, derivedDir: URL) -> String? {
    // First, check if explicitly configured icon exists
    let configuredIcon = projectDirectory.appendingPathComponent(config.app.icon)
    if FileManager.default.fileExists(atPath: configuredIcon.path) {
      return config.app.icon
    }

    // Try to extract from asset catalog
    if let extractedPath = extractIconFromAssetCatalog(projectDirectory: projectDirectory, derivedDir: derivedDir) {
      return extractedPath
    }

    return nil
  }

  /// Search for and extract icon from asset catalog
  /// Returns relative path from project root if successful
  private static func extractIconFromAssetCatalog(projectDirectory: URL, derivedDir: URL) -> String? {
    // Search for AppIcon in asset catalogs
    let searchPaths = [
      "Sources/\(projectDirectory.lastPathComponent)/Resources/Assets.xcassets",
      "Sources/Resources/Assets.xcassets",
      "Resources/Assets.xcassets",
      "Assets.xcassets"
    ]

    var assetCatalogPath: URL?

    // Try known paths first
    for relativePath in searchPaths {
      let path = projectDirectory.appendingPathComponent(relativePath)
      if FileManager.default.fileExists(atPath: path.path) {
        assetCatalogPath = path
        break
      }
    }

    // If not found, search Sources directory
    if assetCatalogPath == nil {
      let sourcesDir = projectDirectory.appendingPathComponent("Sources")
      if let enumerator = FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator {
          if fileURL.pathExtension == "xcassets" {
            assetCatalogPath = fileURL
            break
          }
        }
      }
    }

    guard let catalogPath = assetCatalogPath else { return nil }

    // Look for AppIcon.appiconset
    let appIconSet = catalogPath.appendingPathComponent("AppIcon.appiconset")
    guard FileManager.default.fileExists(atPath: appIconSet.path) else { return nil }

    // Read Contents.json to find the best icon
    let contentsJson = appIconSet.appendingPathComponent("Contents.json")
    guard let data = try? Data(contentsOf: contentsJson),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let images = json["images"] as? [[String: Any]] else {
      return nil
    }

    // Find the best icon (prefer 1024x1024, any idiom)
    var bestIcon: (filename: String, size: Int)?

    for image in images {
      guard let filename = image["filename"] as? String,
            let sizeStr = image["size"] as? String else { continue }

      // Parse size like "1024x1024"
      let components = sizeStr.split(separator: "x")
      guard let size = components.first.flatMap({ Int($0) }) else { continue }

      if bestIcon == nil || size > bestIcon!.size {
        bestIcon = (filename, size)
      }
    }

    guard let icon = bestIcon else { return nil }

    // Copy icon to derived folder as icon.png
    let sourceIcon = appIconSet.appendingPathComponent(icon.filename)
    let destIcon = derivedDir.appendingPathComponent("icon.png")

    guard FileManager.default.fileExists(atPath: sourceIcon.path) else { return nil }

    do {
      try? FileManager.default.removeItem(at: destIcon)
      try FileManager.default.copyItem(at: sourceIcon, to: destIcon)
      // Return path relative to derived dir (which swift-bundler runs from)
      return "icon.png"
    } catch {
      return nil
    }
  }

  /// Generate Bundler.toml content
  private static func generateBundlerTOML(config: XClaudeConfig, projectDirectory: URL, iconPath: String? = nil) -> String {
    var lines: [String] = []

    lines.append("# Generated by xclaude - DO NOT EDIT")
    lines.append("# Source: xclaude.toml")
    lines.append("# Generated: \(ISO8601DateFormatter().string(from: Date()))")
    lines.append("")
    lines.append("format_version = 2")
    lines.append("")
    lines.append("[apps.\(config.app.name)]")
    lines.append("identifier = \"\(config.app.bundleId)\"")
    lines.append("product = \"\(config.app.name)\"")
    lines.append("version = \"\(config.app.version)\"")

    // Use resolved icon path if provided
    if let icon = iconPath {
      lines.append("icon = \"\(icon)\"")
    }

    // Add Info.plist additions from capabilities (if present)
    let infoAdditionsPath = derivedDirectory(for: projectDirectory)
      .appendingPathComponent("InfoAdditions.plist")
    if FileManager.default.fileExists(atPath: infoAdditionsPath.path),
       let data = try? Data(contentsOf: infoAdditionsPath),
       let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
       !plist.isEmpty {
      lines.append("")
      lines.append("[apps.\(config.app.name).plist]")
      for (key, value) in plist.sorted(by: { $0.key < $1.key }) {
        // Escape the value for TOML
        let escapedValue = value.replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "\"", with: "\\\"")
        lines.append("\"\(key)\" = \"\(escapedValue)\"")
      }
    }

    return lines.joined(separator: "\n") + "\n"
  }

  /// Check if project has xclaude.toml
  public static func hasXClaudeConfig(at directory: URL) -> Bool {
    let configPath = directory.appendingPathComponent("xclaude.toml")
    return FileManager.default.fileExists(atPath: configPath.path)
  }

  /// Check if project has Bundler.toml (existing swift-bundler project)
  public static func hasBundlerConfig(at directory: URL) -> Bool {
    let configPath = directory.appendingPathComponent("Bundler.toml")
    return FileManager.default.fileExists(atPath: configPath.path)
  }

  /// Detect project type
  public static func detectProjectType(at directory: URL) -> ProjectType {
    if hasXClaudeConfig(at: directory) {
      return .xclaude
    } else if hasBundlerConfig(at: directory) {
      return .swiftBundler
    } else if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
      return .swiftPackage
    } else {
      return .unknown
    }
  }

  /// Create minimal xclaude.toml for existing Package.swift project
  public static func initializeXClaudeConfig(at directory: URL, appName: String? = nil) throws -> XClaudeConfig {
    // Try to detect app name from Package.swift
    let name: String
    if let provided = appName {
      name = provided
    } else {
      name = try detectAppName(at: directory) ?? "App"
    }

    let config = XClaudeConfig(
      app: AppConfig(
        name: name,
        bundleId: XClaudeConfig.deriveBundleId(from: name)
      )
    )

    try config.save(to: directory)
    return config
  }

  /// Try to detect app name from Package.swift
  private static func detectAppName(at directory: URL) throws -> String? {
    let packagePath = directory.appendingPathComponent("Package.swift")
    guard FileManager.default.fileExists(atPath: packagePath.path) else {
      return nil
    }

    let content = try String(contentsOf: packagePath, encoding: .utf8)

    // Look for: name: "AppName" in Package definition
    // Simple regex-like search
    if let nameRange = content.range(of: "name:\\s*\"([^\"]+)\"", options: .regularExpression) {
      let match = content[nameRange]
      if let quoteStart = match.firstIndex(of: "\""),
         let quoteEnd = match.lastIndex(of: "\""),
         quoteStart != quoteEnd {
        let nameRange = content.index(after: quoteStart)..<quoteEnd
        return String(match[nameRange])
      }
    }

    return nil
  }
}

/// Project type detection
public enum ProjectType {
  case xclaude       // Has xclaude.toml
  case swiftBundler  // Has Bundler.toml
  case swiftPackage  // Has Package.swift only
  case unknown
}
