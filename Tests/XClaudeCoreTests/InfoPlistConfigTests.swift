import Foundation
import Testing

@testable import XClaudeCore

// Regression coverage for the [info_plist] section in xclaude.toml.
//
// History: v4.0.2 typed `XClaudeConfig.infoPlist` as `[String: String]`, so
// any non-string TOML value (bool, array) was silently dropped at parse
// time. The blocker case was `NSBonjourServices = ["_zeno._tcp"]` — iOS 14+
// Bonjour needs the array form, and dropping it left apps unable to
// resolve their own service on the local network. These tests pin the
// typed-value behavior so the regression can't sneak back in.

@Suite("xclaude.toml [info_plist] parsing and emission")
struct InfoPlistConfigTests {

  // MARK: - Parsing

  @Test("Parses string entries")
  func parseString() throws {
    let toml = """
      [app]
      name = "Demo"

      [info_plist]
      NSCameraUsageDescription = "We use the camera."
      """
    let config = try XClaudeConfig.parse(toml)
    #expect(config.infoPlist?["NSCameraUsageDescription"] == .string("We use the camera."))
  }

  @Test("Parses bool entries")
  func parseBool() throws {
    let toml = """
      [app]
      name = "Demo"

      [info_plist]
      ITSAppUsesNonExemptEncryption = false
      """
    let config = try XClaudeConfig.parse(toml)
    #expect(config.infoPlist?["ITSAppUsesNonExemptEncryption"] == .bool(false))
  }

  @Test("Parses string-array entries — NSBonjourServices regression")
  func parseStringArray() throws {
    let toml = """
      [app]
      name = "Demo"

      [info_plist]
      NSBonjourServices = ["_zeno._tcp", "_other._tcp"]
      """
    let config = try XClaudeConfig.parse(toml)
    #expect(
      config.infoPlist?["NSBonjourServices"]
        == .array(["_zeno._tcp", "_other._tcp"]))
  }

  @Test("Mixed-type [info_plist] section retains every entry")
  func parseMixed() throws {
    let toml = """
      [app]
      name = "Demo"

      [info_plist]
      NSLocalNetworkUsageDescription = "Find your Mac on Wi-Fi."
      NSBonjourServices = ["_zeno._tcp"]
      ITSAppUsesNonExemptEncryption = false
      """
    let config = try XClaudeConfig.parse(toml)
    let plist = try #require(config.infoPlist)
    #expect(plist.count == 3)
    #expect(plist["NSLocalNetworkUsageDescription"] == .string("Find your Mac on Wi-Fi."))
    #expect(plist["NSBonjourServices"] == .array(["_zeno._tcp"]))
    #expect(plist["ITSAppUsesNonExemptEncryption"] == .bool(false))
  }

  @Test("Per-extension [info_plist] supports the same value types")
  func parseExtensionInfoPlist() throws {
    let toml = """
      [app]
      name = "Demo"

      [extensions.MyWidget]
      type = "widget"

      [extensions.MyWidget.info_plist]
      NSExtensionAttributes = "ignored-string"
      MySupportedSchemes = ["scheme-a", "scheme-b"]
      MyBoolKey = true
      """
    let config = try XClaudeConfig.parse(toml)
    let ext = try #require(config.extensions?["MyWidget"])
    #expect(ext.infoPlist?["NSExtensionAttributes"] == .string("ignored-string"))
    #expect(ext.infoPlist?["MySupportedSchemes"] == .array(["scheme-a", "scheme-b"]))
    #expect(ext.infoPlist?["MyBoolKey"] == .bool(true))
  }

  // MARK: - Round-trip via toTOML()

  @Test("toTOML round-trips bool/string/array values")
  func roundTrip() throws {
    let original = XClaudeConfig(
      app: AppConfig(name: "Demo", bundleId: "com.demo.app"),
      infoPlist: [
        "NSLocalNetworkUsageDescription": .string("Find your Mac on Wi-Fi."),
        "NSBonjourServices": .array(["_zeno._tcp"]),
        "ITSAppUsesNonExemptEncryption": .bool(false),
      ]
    )

    let emitted = original.toTOML()
    let reparsed = try XClaudeConfig.parse(emitted)

    #expect(reparsed.infoPlist == original.infoPlist)
  }

  @Test("toTOML emits arrays as TOML literals, not quoted strings")
  func emissionFormat() {
    let config = XClaudeConfig(
      app: AppConfig(name: "Demo", bundleId: "com.demo.app"),
      infoPlist: ["NSBonjourServices": .array(["_zeno._tcp"])]
    )
    let toml = config.toTOML()
    #expect(toml.contains("NSBonjourServices = [\"_zeno._tcp\"]"))
    // Sanity: the value is not wrapped in quotes.
    #expect(!toml.contains("NSBonjourServices = \"["))
  }

  @Test("PlistValue.tomlLiteral escapes embedded quotes and backslashes")
  func tomlLiteralEscaping() {
    #expect(PlistValue.string("a\"b").tomlLiteral == "\"a\\\"b\"")
    #expect(PlistValue.string("a\\b").tomlLiteral == "\"a\\\\b\"")
    #expect(PlistValue.array(["a\"b"]).tomlLiteral == "[\"a\\\"b\"]")
    #expect(PlistValue.bool(true).tomlLiteral == "true")
    #expect(PlistValue.bool(false).tomlLiteral == "false")
  }

  // MARK: - Translation to Bundler.toml

  @Test("Translator emits arrays into [apps.<name>.plist]")
  func translatorEmitsArrays() throws {
    let config = XClaudeConfig(
      app: AppConfig(name: "Demo", bundleId: "com.demo.app"),
      infoPlist: ["NSBonjourServices": .array(["_zeno._tcp"])]
    )

    let bundlerToml = try translateAndRead(config: config)
    #expect(bundlerToml.contains("[apps.Demo.plist]"))
    #expect(bundlerToml.contains("\"NSBonjourServices\" = [\"_zeno._tcp\"]"))
  }

  @Test("Translator emits bools into [apps.<name>.plist]")
  func translatorEmitsBools() throws {
    let config = XClaudeConfig(
      app: AppConfig(name: "Demo", bundleId: "com.demo.app"),
      infoPlist: ["ITSAppUsesNonExemptEncryption": .bool(false)]
    )

    let bundlerToml = try translateAndRead(config: config)
    #expect(bundlerToml.contains("\"ITSAppUsesNonExemptEncryption\" = false"))
  }

  // MARK: - Helpers

  /// Run `ConfigTranslator.translate` against a scratch directory and
  /// return the generated Bundler.toml as a string. The scratch directory
  /// is cleaned up before the function returns.
  private func translateAndRead(config: XClaudeConfig) throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("xclaude-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let bundlerPath = try ConfigTranslator.translate(
      config: config, projectDirectory: tempDir)
    return try String(contentsOf: bundlerPath, encoding: .utf8)
  }
}
