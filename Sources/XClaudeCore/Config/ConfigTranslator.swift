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

    // Helper to format arrays for TOML
    func tomlArray(_ arr: [String]) -> String {
      arr.map { "\"\($0)\"" }.joined(separator: ", ")
    }

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

    // Collect all plist entries
    var plistLines: [String] = []

    // Add Info.plist entries from xclaude.toml [info_plist] section
    if let infoPlist = config.infoPlist, !infoPlist.isEmpty {
      for (key, value) in infoPlist.sorted(by: { $0.key < $1.key }) {
        let escapedValue = value.replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "\"", with: "\\\"")
        plistLines.append("\"\(key)\" = \"\(escapedValue)\"")
      }
    }

    // Also check InfoAdditions.plist for backward compatibility (capabilities may write here)
    let infoAdditionsPath = derivedDirectory(for: projectDirectory)
      .appendingPathComponent("InfoAdditions.plist")
    if FileManager.default.fileExists(atPath: infoAdditionsPath.path),
       let data = try? Data(contentsOf: infoAdditionsPath),
       let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
       !plist.isEmpty {
      for (key, value) in plist.sorted(by: { $0.key < $1.key }) {
        // Skip if already in config.infoPlist (config takes precedence)
        if config.infoPlist?[key] != nil { continue }
        let escapedValue = value.replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "\"", with: "\\\"")
        plistLines.append("\"\(key)\" = \"\(escapedValue)\"")
      }
    }

    // --- Orientations ---
    if let orientations = config.app.orientations, !orientations.isEmpty {
      let mapped = AppConfig.mapOrientations(orientations)
      plistLines.append("\"UISupportedInterfaceOrientations\" = [\(tomlArray(mapped))]")
    }
    if let orientationsIpad = config.app.orientationsIpad, !orientationsIpad.isEmpty {
      let mapped = AppConfig.mapOrientations(orientationsIpad)
      plistLines.append("\"UISupportedInterfaceOrientations~ipad\" = [\(tomlArray(mapped))]")
    }
    if let requiresFullScreen = config.app.requiresFullScreen, requiresFullScreen {
      plistLines.append("\"UIRequiresFullScreen\" = true")
    }

    // --- Status Bar ---
    if let statusBarHidden = config.app.statusBarHidden {
      plistLines.append("\"UIStatusBarHidden\" = \(statusBarHidden)")
    }
    if let statusBarStyle = config.app.statusBarStyle {
      let mapped = AppConfig.mapStatusBarStyle(statusBarStyle)
      plistLines.append("\"UIStatusBarStyle\" = \"\(mapped)\"")
    }

    // --- Background Modes ---
    if let backgroundModes = config.app.backgroundModes, !backgroundModes.isEmpty {
      let mapped = AppConfig.mapBackgroundModes(backgroundModes)
      plistLines.append("\"UIBackgroundModes\" = [\(tomlArray(mapped))]")
    }

    // --- Device Family ---
    if let devices = config.app.devices, !devices.isEmpty {
      var deviceFamily: [Int] = []
      for device in devices {
        switch device.lowercased() {
        case "iphone":
          if !deviceFamily.contains(1) { deviceFamily.append(1) }
        case "ipad":
          if !deviceFamily.contains(2) { deviceFamily.append(2) }
        default:
          break
        }
      }
      if !deviceFamily.isEmpty {
        let sorted = deviceFamily.sorted()
        plistLines.append("\"UIDeviceFamily\" = [\(sorted.map { String($0) }.joined(separator: ", "))]")
      }
    }

    // --- Device Capabilities ---
    if let requiredCapabilities = config.app.requiredCapabilities, !requiredCapabilities.isEmpty {
      plistLines.append("\"UIRequiredDeviceCapabilities\" = [\(tomlArray(requiredCapabilities))]")
    }

    // --- URL Schemes ---
    // Note: CFBundleURLTypes is complex - we generate a simplified version
    // Swift Bundler may need special handling for this
    if let urlSchemes = config.app.urlSchemes, !urlSchemes.isEmpty {
      // For now, output as a comment since CFBundleURLTypes needs special structure
      // TODO: Implement proper CFBundleURLTypes support in swift-bundler
      lines.append("")
      lines.append("# URL Schemes: \(urlSchemes.joined(separator: ", "))")
      lines.append("# Note: CFBundleURLTypes requires manual Info.plist configuration")
    }

    // --- Queried Schemes ---
    if let queriedSchemes = config.app.queriedSchemes, !queriedSchemes.isEmpty {
      plistLines.append("\"LSApplicationQueriesSchemes\" = [\(tomlArray(queriedSchemes))]")
    }

    // --- Medium Priority ---
    if let requiresPersistentWifi = config.app.requiresPersistentWifi, requiresPersistentWifi {
      plistLines.append("\"UIRequiresPersistentWiFi\" = true")
    }
    if let fileSharingEnabled = config.app.fileSharingEnabled, fileSharingEnabled {
      plistLines.append("\"UIFileSharingEnabled\" = true")
    }
    if let supportsDocumentBrowser = config.app.supportsDocumentBrowser, supportsDocumentBrowser {
      plistLines.append("\"UISupportsDocumentBrowser\" = true")
    }
    if let appFonts = config.app.appFonts, !appFonts.isEmpty {
      plistLines.append("\"UIAppFonts\" = [\(tomlArray(appFonts))]")
    }
    if let launchStoryboard = config.app.launchStoryboard {
      plistLines.append("\"UILaunchStoryboardName\" = \"\(launchStoryboard)\"")
    }

    // Output plist section if we have any additions
    if !plistLines.isEmpty {
      lines.append("")
      lines.append("[apps.\(config.app.name).plist]")
      lines.append(contentsOf: plistLines)
    }

    return lines.joined(separator: "\n") + "\n"
  }

  // MARK: - Extension derived files

  /// Directory holding all per-extension derived files.
  public static func extensionsDerivedDirectory(for project: URL) -> URL {
    derivedDirectory(for: project).appendingPathComponent("extensions")
  }

  /// Per-extension derived directory (contains Info.plist + Entitlements.plist).
  public static func extensionDerivedDirectory(
    for project: URL,
    extensionName: String
  ) -> URL {
    extensionsDerivedDirectory(for: project).appendingPathComponent(extensionName)
  }

  /// Generate per-extension `Info.plist` and `Entitlements.plist` files into
  /// `.xclaude/derived/extensions/<name>/` for every extension declared in
  /// `xclaude.toml`'s `[extensions]` section.
  ///
  /// Consumed by xclaude's own post-build step (see `ExtensionEmbedder`) —
  /// not by SwiftBundler. This keeps the SwiftBundler fork untouched while
  /// still letting xclaude emit a fully-signed `.app` with embedded `.appex`
  /// bundles.
  ///
  /// Returns the list of extension names that were processed.
  @discardableResult
  public static func generateExtensionDerivedFiles(
    config: XClaudeConfig,
    projectDirectory: URL
  ) throws -> [String] {
    guard let extensions = config.extensions, !extensions.isEmpty else {
      return []
    }

    let baseDir = extensionsDerivedDirectory(for: projectDirectory)
    try FileManager.default.createDirectory(
      at: baseDir, withIntermediateDirectories: true
    )

    // Parse minimum iOS version from Package.swift once, reuse across all
    // extensions. Falls back to "17.0" if Package.swift is missing or the
    // platforms clause is unparseable.
    let minimumOSVersion = parseMinimumIOSVersion(in: projectDirectory) ?? "17.0"

    var processed: [String] = []
    for (extName, extConfig) in extensions.sorted(by: { $0.key < $1.key }) {
      guard let manifest = ExtensionRegistry.manifest(forName: extConfig.type) else {
        // Unknown extension type — `add_extension` should have validated
        // this at declaration time, so just skip rather than error out.
        continue
      }

      let extDir = extensionDerivedDirectory(
        for: projectDirectory,
        extensionName: extName
      )
      try FileManager.default.createDirectory(
        at: extDir, withIntermediateDirectories: true
      )

      let bundleId = extConfig.bundleId ?? "\(config.app.bundleId).\(extName)"
      let spec = manifest.resolvedSpec(liveActivities: extConfig.liveActivities ?? false)

      // Info.plist
      let infoPlist = buildExtensionInfoPlist(
        extensionName: extName,
        bundleId: bundleId,
        version: config.app.version,
        minimumOSVersion: minimumOSVersion,
        manifest: manifest,
        spec: spec,
        userOverrides: extConfig.infoPlist
      )
      let infoPlistURL = extDir.appendingPathComponent("Info.plist")
      let infoPlistData = try PropertyListSerialization.data(
        fromPropertyList: infoPlist, format: .xml, options: 0
      )
      try infoPlistData.write(to: infoPlistURL)

      // Entitlements.plist
      let entitlements = buildExtensionEntitlements(
        extConfig: extConfig,
        bundleId: bundleId,
        manifest: manifest,
        spec: spec
      )
      let entitlementsURL = extDir.appendingPathComponent("Entitlements.plist")
      let entitlementsData = try PropertyListSerialization.data(
        fromPropertyList: entitlements, format: .xml, options: 0
      )
      try entitlementsData.write(to: entitlementsURL)

      processed.append(extName)
    }
    return processed
  }

  /// Parse the minimum iOS version from a project's `Package.swift`.
  /// Returns nil if the file is missing, unreadable, or has no iOS platform
  /// declaration.
  public static func parseMinimumIOSVersion(in projectDirectory: URL) -> String? {
    let packagePath = projectDirectory.appendingPathComponent("Package.swift")
    guard let content = try? String(contentsOf: packagePath, encoding: .utf8) else {
      return nil
    }
    return parseMinimumIOSVersion(from: content)
  }

  /// Parse the minimum iOS version from `Package.swift` content.
  ///
  /// Handles the three forms SPM accepts for platform declarations:
  /// - `.iOS(.v17)` → `"17.0"`
  /// - `.iOS(.v16_1)` → `"16.1"` (important — Live Activities require 16.1+)
  /// - `.iOS("17.0")` → `"17.0"`
  ///
  /// Returns nil if no iOS platform declaration is found.
  public static func parseMinimumIOSVersion(from content: String) -> String? {
    // Form 1: `.iOS(.vN)` or `.iOS(.vN_M)` — the most common style.
    if let range = content.range(
      of: #"\.iOS\(\.v(\d+)(?:_(\d+))?\)"#,
      options: .regularExpression
    ) {
      let matched = String(content[range])
      // Extract all integer tokens from the match (major + optional minor).
      var numbers: [Int] = []
      var searchStart = matched.startIndex
      while let numRange = matched.range(
        of: #"\d+"#,
        options: .regularExpression,
        range: searchStart..<matched.endIndex
      ) {
        if let n = Int(matched[numRange]) {
          numbers.append(n)
        }
        searchStart = numRange.upperBound
      }
      if numbers.count == 1 {
        return "\(numbers[0]).0"
      } else if numbers.count >= 2 {
        return "\(numbers[0]).\(numbers[1])"
      }
    }

    // Form 2: `.iOS("17.0")` — string literal form.
    if let range = content.range(
      of: #"\.iOS\("(\d+\.\d+)"\)"#,
      options: .regularExpression
    ) {
      let matched = String(content[range])
      if let versionRange = matched.range(
        of: #"\d+\.\d+"#,
        options: .regularExpression
      ) {
        return String(matched[versionRange])
      }
    }

    return nil
  }

  /// Build the `Info.plist` contents for a single extension, as a dictionary
  /// ready for `PropertyListSerialization`.
  private static func buildExtensionInfoPlist(
    extensionName: String,
    bundleId: String,
    version: String,
    minimumOSVersion: String,
    manifest: ExtensionManifest,
    spec: ExtensionPlatformSpec,
    userOverrides: [String: String]?
  ) -> [String: Any] {
    // Standard bundle keys every app extension needs.
    var plist: [String: Any] = [
      "CFBundleDevelopmentRegion": "en",
      "CFBundleDisplayName": extensionName,
      "CFBundleExecutable": extensionName,
      "CFBundleIdentifier": bundleId,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": extensionName,
      // App extensions declare themselves via CFBundlePackageType = XPC!
      "CFBundlePackageType": "XPC!",
      "CFBundleShortVersionString": version,
      "CFBundleVersion": "1",
      "MinimumOSVersion": minimumOSVersion,
    ]

    // NSExtension dict — extensionPointIdentifier is always required; the
    // principal class is optional (widgets use @main and have no principal).
    var nsExtension: [String: Any] = [
      "NSExtensionPointIdentifier": manifest.type.extensionPointIdentifier
    ]
    if let principalClass = manifest.type.principalClass {
      // $(PRODUCT_MODULE_NAME) gets substituted by codesign/runtime to the
      // extension target's module name.
      nsExtension["NSExtensionPrincipalClass"] = "$(PRODUCT_MODULE_NAME).\(principalClass)"
    }
    plist["NSExtension"] = nsExtension

    // Merge in any top-level Info.plist keys from the manifest spec.
    // (Currently unused — extension-point identifiers live in NSExtension.)
    for (key, value) in spec.infoPlist {
      plist[key] = value.anyValue
    }

    // User overrides from [extensions.<name>.info_plist] take final precedence.
    if let overrides = userOverrides {
      for (key, value) in overrides {
        plist[key] = value
      }
    }

    return plist
  }

  /// Build the `Entitlements.plist` contents for a single extension.
  ///
  /// Extensions get their own entitlements file because a widget extension
  /// may need to declare different capabilities than its parent app (e.g.,
  /// `com.apple.security.application-groups` to share storage with the app).
  private static func buildExtensionEntitlements(
    extConfig: ExtensionConfig,
    bundleId: String,
    manifest: ExtensionManifest,
    spec: ExtensionPlatformSpec
  ) -> [String: Any] {
    var entitlements: [String: Any] = [:]

    // Baseline keys every signed extension needs.
    // `application-identifier` is normally TEAM_ID.bundle_id but on simulator
    // (ad-hoc signing) we write just the bundle id; codesign doesn't require
    // the team prefix for ad-hoc signed extensions.
    entitlements["application-identifier"] = bundleId

    // Manifest-declared entitlements for this extension type.
    for (key, value) in spec.entitlements {
      entitlements[key] = value.anyValue
    }

    // User-declared per-extension capabilities via [extensions.<name>.capabilities].
    // Reuse the CapabilityRegistry to resolve them identically to the main app.
    if let capabilities = extConfig.capabilities {
      for (capName, capValue) in capabilities {
        guard let capManifest = CapabilityRegistry.manifest(for: capName) else {
          continue
        }
        // Extensions on Darwin are currently only supported for iOS — use
        // the iOS platform spec from the capability manifest. Future: pass
        // through the actual target platform.
        let resolved = capManifest.resolvedEntitlements(
          for: .iOS,
          userValue: capValue
        )
        for (key, value) in resolved {
          entitlements[key] = value
        }
      }
    }

    return entitlements
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
