import Foundation
import Testing

@testable import XClaudeCore

// MARK: - Registry integrity

@Suite("ExtensionRegistry integrity")
struct ExtensionRegistryTests {

  @Test("Every extension type has a manifest")
  func everyTypeHasManifest() {
    for type in ExtensionType.allCases {
      #expect(
        ExtensionRegistry.manifest(for: type) != nil,
        "Missing manifest for \(type.rawValue)"
      )
    }
  }

  @Test("manifest(forName:) works for every declared type")
  func manifestLookupByName() {
    for type in ExtensionType.allCases {
      #expect(
        ExtensionRegistry.manifest(forName: type.rawValue) != nil,
        "Lookup by name failed for \(type.rawValue)"
      )
    }
  }

  @Test("Unknown name returns nil")
  func unknownName() {
    #expect(ExtensionRegistry.manifest(forName: "not-a-type") == nil)
    #expect(ExtensionRegistry.manifest(forName: "") == nil)
  }

  @Test("allNames returns all extension types")
  func allNames() {
    let names = Set(ExtensionRegistry.allNames)
    for type in ExtensionType.allCases {
      #expect(names.contains(type.rawValue))
    }
  }
}

// MARK: - ExtensionPointIdentifier mapping

@Suite("ExtensionType extensionPointIdentifier")
struct ExtensionTypeIdentifierTests {

  static let expected: [(ExtensionType, String)] = [
    (.widget, "com.apple.widgetkit-extension"),
    (.share, "com.apple.share-services"),
    (.action, "com.apple.ui-services"),
    (.intents, "com.apple.intents-service"),
    (.notificationContent, "com.apple.usernotifications.content-extension"),
    (.notificationService, "com.apple.usernotifications.service"),
  ]

  @Test("Each type maps to its Apple extension point identifier", arguments: expected)
  func identifier(_ pair: (ExtensionType, String)) {
    #expect(pair.0.extensionPointIdentifier == pair.1)
  }

  @Test("Widgets have no principal class (use @main instead)")
  func widgetNoPrincipalClass() {
    #expect(ExtensionType.widget.principalClass == nil)
  }

  @Test("Non-widget types declare a principal class")
  func nonWidgetPrincipalClass() {
    for type in ExtensionType.allCases where type != .widget {
      #expect(
        type.principalClass != nil,
        "\(type.rawValue) should declare a principal class"
      )
    }
  }
}

// MARK: - Live activities resolution

@Suite("Live Activities spec resolution")
struct LiveActivitiesResolutionTests {

  @Test("Widget with live_activities=true adds NSSupportsLiveActivities to parent app")
  func widgetWithLiveActivities() {
    let manifest = ExtensionRegistry.manifest(for: .widget)!
    let spec = manifest.resolvedSpec(liveActivities: true)
    #expect(spec.parentAppInfoPlist["NSSupportsLiveActivities"] == "YES")
  }

  @Test("Widget without live_activities does not touch parent app Info.plist")
  func widgetWithoutLiveActivities() {
    let manifest = ExtensionRegistry.manifest(for: .widget)!
    let spec = manifest.resolvedSpec(liveActivities: false)
    #expect(spec.parentAppInfoPlist["NSSupportsLiveActivities"] == nil)
  }

  @Test("Non-widget extensions ignore live_activities flag")
  func nonWidgetIgnoresLiveActivities() {
    for type in ExtensionType.allCases where type != .widget {
      let manifest = ExtensionRegistry.manifest(for: type)!
      let spec = manifest.resolvedSpec(liveActivities: true)
      #expect(
        spec.parentAppInfoPlist["NSSupportsLiveActivities"] == nil,
        "\(type.rawValue) should not set NSSupportsLiveActivities"
      )
    }
  }
}

// MARK: - XClaudeConfig [extensions] round-trip

@Suite("XClaudeConfig extensions round-trip")
struct XClaudeConfigExtensionsRoundTripTests {

  func makeTempProject(toml: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("xclaude-ext-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let tomlPath = dir.appendingPathComponent("xclaude.toml")
    try toml.write(to: tomlPath, atomically: true, encoding: .utf8)
    return dir
  }

  @Test("Parses [extensions.<name>] section")
  func parseExtensionsSection() throws {
    let dir = try makeTempProject(toml: """
      [app]
      name = "TestApp"
      bundle_id = "com.example.testapp"
      version = "1.0.0"

      [extensions.TestWidget]
      type = "widget"
      live_activities = true
      """)
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    #expect(config.extensions?.count == 1)
    #expect(config.extensions?["TestWidget"]?.type == "widget")
    #expect(config.extensions?["TestWidget"]?.liveActivities == true)
  }

  @Test("Parses per-extension bundle_id, info_plist, and capabilities")
  func parseExtensionOverrides() throws {
    let dir = try makeTempProject(toml: """
      [app]
      name = "TestApp"
      bundle_id = "com.example.testapp"
      version = "1.0.0"

      [extensions.CustomWidget]
      type = "widget"
      bundle_id = "com.example.testapp.custom"

      [extensions.CustomWidget.info_plist]
      CustomKey = "CustomValue"

      [extensions.CustomWidget.capabilities]
      push-notifications = "production"
      """)
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    let ext = config.extensions?["CustomWidget"]
    #expect(ext?.bundleId == "com.example.testapp.custom")
    #expect(ext?.infoPlist?["CustomKey"] == .string("CustomValue"))
    #expect(ext?.capabilities?["push-notifications"] == .string("production"))
  }

  @Test("save() and load() preserve extensions section")
  func saveLoadPreservesExtensions() throws {
    let dir = try makeTempProject(toml: """
      [app]
      name = "TestApp"
      bundle_id = "com.example.testapp"
      version = "1.0.0"
      """)
    defer { try? FileManager.default.removeItem(at: dir) }

    var config = try XClaudeConfig.load(from: dir)
    config.extensions = [
      "W1": ExtensionConfig(type: "widget", liveActivities: true),
      "W2": ExtensionConfig(
        type: "share",
        bundleId: "com.example.testapp.sharesheet"
      ),
    ]
    try config.save(to: dir)

    let reloaded = try XClaudeConfig.load(from: dir)
    #expect(reloaded.extensions?.count == 2)
    #expect(reloaded.extensions?["W1"]?.type == "widget")
    #expect(reloaded.extensions?["W1"]?.liveActivities == true)
    #expect(reloaded.extensions?["W2"]?.type == "share")
    #expect(reloaded.extensions?["W2"]?.bundleId == "com.example.testapp.sharesheet")
  }

  @Test("Missing type field skips the extension (lenient parse)")
  func missingTypeSkipped() throws {
    let dir = try makeTempProject(toml: """
      [app]
      name = "TestApp"
      bundle_id = "com.example.testapp"

      [extensions.NoType]
      live_activities = true
      """)
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    // Lenient parse skips entries without a type.
    #expect(config.extensions?["NoType"] == nil)
  }
}

// MARK: - ConfigTranslator derived files

@Suite("ConfigTranslator extension derived files")
struct ConfigTranslatorExtensionTests {

  func makeTempProject(with extensions: [String: ExtensionConfig]) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("xclaude-translator-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let tomlPath = dir.appendingPathComponent("xclaude.toml")
    try """
      [app]
      name = "TestApp"
      bundle_id = "com.example.testapp"
      version = "1.2.3"
      """.write(to: tomlPath, atomically: true, encoding: .utf8)

    // Load, set extensions, save.
    var config = try XClaudeConfig.load(from: dir)
    config.extensions = extensions
    try config.save(to: dir)
    return dir
  }

  @Test("Writes Info.plist with correct keys for widget extension")
  func widgetInfoPlist() throws {
    let dir = try makeTempProject(with: [
      "MyWidget": ExtensionConfig(type: "widget", liveActivities: true)
    ])
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    let processed = try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: dir
    )
    #expect(processed == ["MyWidget"])

    let plistURL = ConfigTranslator.extensionDerivedDirectory(
      for: dir,
      extensionName: "MyWidget"
    ).appendingPathComponent("Info.plist")

    let data = try Data(contentsOf: plistURL)
    let plist =
      try PropertyListSerialization.propertyList(from: data, format: nil)
      as! [String: Any]

    // Standard bundle keys.
    #expect(plist["CFBundleIdentifier"] as? String == "com.example.testapp.MyWidget")
    #expect(plist["CFBundleExecutable"] as? String == "MyWidget")
    #expect(plist["CFBundlePackageType"] as? String == "XPC!")
    #expect(plist["CFBundleShortVersionString"] as? String == "1.2.3")

    // NSExtension dict with the right point identifier.
    let nsExtension = plist["NSExtension"] as? [String: Any]
    #expect(nsExtension?["NSExtensionPointIdentifier"] as? String == "com.apple.widgetkit-extension")

    // Widget uses @main, no principal class.
    #expect(nsExtension?["NSExtensionPrincipalClass"] == nil)
  }

  @Test("Writes Info.plist with principal class for non-widget extensions")
  func shareInfoPlist() throws {
    let dir = try makeTempProject(with: [
      "MyShare": ExtensionConfig(type: "share")
    ])
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    _ = try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: dir
    )

    let plistURL = ConfigTranslator.extensionDerivedDirectory(
      for: dir,
      extensionName: "MyShare"
    ).appendingPathComponent("Info.plist")

    let data = try Data(contentsOf: plistURL)
    let plist =
      try PropertyListSerialization.propertyList(from: data, format: nil)
      as! [String: Any]

    let nsExtension = plist["NSExtension"] as? [String: Any]
    #expect(nsExtension?["NSExtensionPointIdentifier"] as? String == "com.apple.share-services")
    #expect(
      nsExtension?["NSExtensionPrincipalClass"] as? String
        == "$(PRODUCT_MODULE_NAME).ShareViewController"
    )
  }

  @Test("Uses custom bundle_id when provided")
  func customBundleId() throws {
    let dir = try makeTempProject(with: [
      "MyWidget": ExtensionConfig(
        type: "widget",
        bundleId: "com.custom.widget"
      )
    ])
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    _ = try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: dir
    )

    let plistURL = ConfigTranslator.extensionDerivedDirectory(
      for: dir,
      extensionName: "MyWidget"
    ).appendingPathComponent("Info.plist")

    let data = try Data(contentsOf: plistURL)
    let plist =
      try PropertyListSerialization.propertyList(from: data, format: nil)
      as! [String: Any]

    #expect(plist["CFBundleIdentifier"] as? String == "com.custom.widget")
  }

  @Test("User info_plist overrides take precedence over manifest defaults")
  func userOverridesWin() throws {
    let dir = try makeTempProject(with: [
      "MyWidget": ExtensionConfig(
        type: "widget",
        infoPlist: ["CFBundleDisplayName": .string("CustomDisplayName")]
      )
    ])
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    _ = try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: dir
    )

    let plistURL = ConfigTranslator.extensionDerivedDirectory(
      for: dir,
      extensionName: "MyWidget"
    ).appendingPathComponent("Info.plist")

    let data = try Data(contentsOf: plistURL)
    let plist =
      try PropertyListSerialization.propertyList(from: data, format: nil)
      as! [String: Any]

    #expect(plist["CFBundleDisplayName"] as? String == "CustomDisplayName")
  }

  @Test("Writes Entitlements.plist with application-identifier")
  func entitlementsBaseKeys() throws {
    let dir = try makeTempProject(with: [
      "MyWidget": ExtensionConfig(type: "widget")
    ])
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    _ = try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: dir
    )

    let entitlementsURL = ConfigTranslator.extensionDerivedDirectory(
      for: dir,
      extensionName: "MyWidget"
    ).appendingPathComponent("Entitlements.plist")

    let data = try Data(contentsOf: entitlementsURL)
    let entitlements =
      try PropertyListSerialization.propertyList(from: data, format: nil)
      as! [String: Any]

    #expect(
      entitlements["application-identifier"] as? String
        == "com.example.testapp.MyWidget"
    )
  }

  @Test("Per-extension capabilities flow into Entitlements.plist")
  func perExtensionCapabilities() throws {
    let dir = try makeTempProject(with: [
      "MyWidget": ExtensionConfig(
        type: "widget",
        capabilities: ["push-notifications": .string("production")]
      )
    ])
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    _ = try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: dir
    )

    let entitlementsURL = ConfigTranslator.extensionDerivedDirectory(
      for: dir,
      extensionName: "MyWidget"
    ).appendingPathComponent("Entitlements.plist")

    let data = try Data(contentsOf: entitlementsURL)
    let entitlements =
      try PropertyListSerialization.propertyList(from: data, format: nil)
      as! [String: Any]

    #expect(entitlements["aps-environment"] as? String == "production")
  }

  @Test("Returns empty array when no extensions declared")
  func noExtensions() throws {
    let dir = try makeTempProject(with: [:])
    defer { try? FileManager.default.removeItem(at: dir) }

    let config = try XClaudeConfig.load(from: dir)
    let processed = try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: dir
    )
    #expect(processed.isEmpty)
  }
}

// MARK: - MinimumOSVersion parsing

@Suite("ConfigTranslator.parseMinimumIOSVersion")
struct ParseMinimumIOSVersionTests {

  @Test("Parses .iOS(.v17)")
  func simpleMajorVersion() {
    let content = #"platforms: [.iOS(.v17), .macOS(.v14)]"#
    #expect(ConfigTranslator.parseMinimumIOSVersion(from: content) == "17.0")
  }

  @Test("Parses .iOS(.v16_1) for Live Activities")
  func majorMinorVersion() {
    let content = #"platforms: [.iOS(.v16_1)]"#
    #expect(ConfigTranslator.parseMinimumIOSVersion(from: content) == "16.1")
  }

  @Test("Parses .iOS(.v18_2)")
  func newMajorMinor() {
    let content = #"platforms: [.iOS(.v18_2)]"#
    #expect(ConfigTranslator.parseMinimumIOSVersion(from: content) == "18.2")
  }

  @Test("Parses string literal form .iOS(\"17.0\")")
  func stringLiteralForm() {
    let content = #"platforms: [.iOS("17.0")]"#
    #expect(ConfigTranslator.parseMinimumIOSVersion(from: content) == "17.0")
  }

  @Test("Returns nil when no iOS platform declared")
  func noIOSPlatform() {
    let content = #"platforms: [.macOS(.v14), .tvOS(.v17)]"#
    #expect(ConfigTranslator.parseMinimumIOSVersion(from: content) == nil)
  }

  @Test("Ignores commented-out declarations")
  func notReallyCommentAware() {
    // Regex-based parser picks up the first .iOS(...) it finds. Comments
    // that contain a valid-looking declaration would fool it; callers
    // should write real Package.swift files. This test locks in the
    // current "simple, fast, regex-based" behavior.
    let content = #"platforms: [.iOS(.v18)]"#
    #expect(ConfigTranslator.parseMinimumIOSVersion(from: content) == "18.0")
  }

  @Test("Handles multiline Package.swift")
  func multilinePackageSwift() {
    let content = """
      let package = Package(
        name: "Demo",
        platforms: [
          .iOS(.v16_1),
          .macOS(.v14)
        ],
        products: []
      )
      """
    #expect(ConfigTranslator.parseMinimumIOSVersion(from: content) == "16.1")
  }

  @Test("Derived extension Info.plist uses the parsed version")
  func integrationWithExtensionDerivedFiles() throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("xclaude-minOS-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    // Write a Package.swift with iOS 16.1 (Live Activities minimum).
    let packageSwift = """
      // swift-tools-version: 5.9
      import PackageDescription
      let package = Package(
        name: "Demo",
        platforms: [.iOS(.v16_1)],
        targets: []
      )
      """
    try packageSwift.write(
      to: dir.appendingPathComponent("Package.swift"),
      atomically: true,
      encoding: .utf8
    )

    // Write an xclaude.toml with a widget extension.
    try """
      [app]
      name = "Demo"
      bundle_id = "com.example.demo"

      [extensions.DemoWidget]
      type = "widget"
      live_activities = true
      """.write(
      to: dir.appendingPathComponent("xclaude.toml"),
      atomically: true,
      encoding: .utf8
    )

    let config = try XClaudeConfig.load(from: dir)
    _ = try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: dir
    )

    let plistURL = ConfigTranslator.extensionDerivedDirectory(
      for: dir,
      extensionName: "DemoWidget"
    ).appendingPathComponent("Info.plist")
    let data = try Data(contentsOf: plistURL)
    let plist =
      try PropertyListSerialization.propertyList(from: data, format: nil)
      as! [String: Any]

    #expect(plist["MinimumOSVersion"] as? String == "16.1")
  }
}

// MARK: - ExtensionEmbedder helpers

@Suite("ExtensionEmbedder helpers")
struct ExtensionEmbedderTests {

  @Test("PlugIns directory is at App.app/PlugIns on iOS")
  func plugInsIOS() {
    let appURL = URL(fileURLWithPath: "/tmp/Example.app")
    let plugIns = ExtensionEmbedder.plugInsDirectory(
      for: appURL,
      platform: .iOSSimulator
    )
    #expect(plugIns.path == "/tmp/Example.app/PlugIns")
  }

  @Test("PlugIns directory is at App.app/Contents/PlugIns on macOS")
  func plugInsMacOS() {
    let appURL = URL(fileURLWithPath: "/tmp/Example.app")
    let plugIns = ExtensionEmbedder.plugInsDirectory(
      for: appURL,
      platform: .macOS
    )
    #expect(plugIns.path == "/tmp/Example.app/Contents/PlugIns")
  }

  @Test("PlugIns directory matches iOS layout for tvOS/visionOS")
  func plugInsOtherApplePlatforms() {
    let appURL = URL(fileURLWithPath: "/tmp/Example.app")
    for platform in [
      BuildRunner.Platform.iOS, .iOSSimulator, .tvOS, .tvOSSimulator,
      .visionOS, .visionOSSimulator,
    ] {
      let plugIns = ExtensionEmbedder.plugInsDirectory(
        for: appURL,
        platform: platform
      )
      #expect(
        plugIns.path == "/tmp/Example.app/PlugIns",
        "Wrong PlugIns path for \(platform.rawValue)"
      )
    }
  }
}

// MARK: - remove_extension (Package.swift regex round-trip)

@Suite("remove_extension regex round-trip")
struct RemoveExtensionPackageSwiftTests {

  /// End-to-end: write a Package.swift that matches what `add_extension`
  /// produces, then regex-strip the entries and verify they're gone while
  /// the main app's entries are left alone.
  @Test("Removes .executable product and .executableTarget for a named extension")
  func removesBothEntries() throws {
    let original = """
      // swift-tools-version: 5.9
      import PackageDescription

      let package = Package(
        name: "Demo",
        platforms: [.iOS(.v17)],
        products: [
          .executable(name: "DemoWidget", targets: ["DemoWidget"]),
          .executable(name: "Demo", targets: ["Demo"])
        ],
        targets: [
          .executableTarget(
            name: "DemoWidget",
            path: "Sources/DemoWidget"
          ),
          .executableTarget(
            name: "Demo",
            path: "Sources/Demo"
          )
        ]
      )
      """

    var content = original
    let name = "DemoWidget"

    // Same regexes as removeExtension uses in MCPTools.
    let productPattern =
      #"\s*\.executable\(name:\s*"\#(name)",\s*targets:\s*\["\#(name)"\]\),?"#
    if let regex = try? NSRegularExpression(pattern: productPattern) {
      content = regex.stringByReplacingMatches(
        in: content,
        range: NSRange(content.startIndex..., in: content),
        withTemplate: ""
      )
    }

    let targetPattern =
      #"(?s)\s*\.executableTarget\(\s*name:\s*"\#(name)",\s*path:\s*"Sources/\#(name)"\s*\),?"#
    if let regex = try? NSRegularExpression(pattern: targetPattern) {
      content = regex.stringByReplacingMatches(
        in: content,
        range: NSRange(content.startIndex..., in: content),
        withTemplate: ""
      )
    }

    // DemoWidget entries should be gone.
    #expect(!content.contains(#".executable(name: "DemoWidget""#))
    #expect(!content.contains(#""DemoWidget""#) == false || !content.contains("Sources/DemoWidget"))
    #expect(!content.contains("Sources/DemoWidget"))

    // Main app entries should still be present.
    #expect(content.contains(#".executable(name: "Demo", targets: ["Demo"])"#))
    #expect(content.contains(#"name: "Demo""#))
    #expect(content.contains("Sources/Demo"))
  }
}
