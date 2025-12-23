import Foundation

/// Creates new SwiftUI app projects
public struct ProjectScaffold {

  /// Result of project creation
  public struct CreateResult: Codable {
    public let success: Bool
    public let message: String
    public let projectPath: String?
    public let filesCreated: [String]
  }

  /// Create a new SwiftUI app project
  public static func create(
    name: String,
    at parentDirectory: URL,
    bundleId: String? = nil
  ) throws -> CreateResult {
    // Validate name
    guard isValidAppName(name) else {
      return CreateResult(
        success: false,
        message: "Invalid app name. Use only letters (a-z, A-Z).",
        projectPath: nil,
        filesCreated: []
      )
    }

    let projectDir = parentDirectory.appendingPathComponent(name)

    // Check if directory exists
    if FileManager.default.fileExists(atPath: projectDir.path) {
      return CreateResult(
        success: false,
        message: "Directory '\(name)' already exists",
        projectPath: nil,
        filesCreated: []
      )
    }

    // Create directories
    let sourcesDir = projectDir.appendingPathComponent("Sources/\(name)")
    try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

    var filesCreated: [String] = []

    // Generate Package.swift
    let packageSwift = generatePackageSwift(name: name)
    let packagePath = projectDir.appendingPathComponent("Package.swift")
    try packageSwift.write(to: packagePath, atomically: true, encoding: .utf8)
    filesCreated.append("Package.swift")

    // Generate xclaude.toml
    let resolvedBundleId = bundleId ?? XClaudeConfig.deriveBundleId(from: name)
    let xclaudeToml = generateXClaudeToml(name: name, bundleId: resolvedBundleId)
    let xclaudePath = projectDir.appendingPathComponent("xclaude.toml")
    try xclaudeToml.write(to: xclaudePath, atomically: true, encoding: .utf8)
    filesCreated.append("xclaude.toml")

    // Generate App.swift
    let appSwift = generateAppSwift(name: name)
    let appPath = sourcesDir.appendingPathComponent("\(name)App.swift")
    try appSwift.write(to: appPath, atomically: true, encoding: .utf8)
    filesCreated.append("Sources/\(name)/\(name)App.swift")

    // Generate ContentView.swift
    let contentView = generateContentView(name: name)
    let contentPath = sourcesDir.appendingPathComponent("ContentView.swift")
    try contentView.write(to: contentPath, atomically: true, encoding: .utf8)
    filesCreated.append("Sources/\(name)/ContentView.swift")

    // Generate .gitignore
    let gitignore = generateGitignore()
    let gitignorePath = projectDir.appendingPathComponent(".gitignore")
    try gitignore.write(to: gitignorePath, atomically: true, encoding: .utf8)
    filesCreated.append(".gitignore")

    // Note: We don't generate a placeholder icon because it must be 1024x1024
    // The user needs to add their own icon.png

    return CreateResult(
      success: true,
      message: "Created '\(name)' SwiftUI app. Add a 1024x1024 icon.png to the project root.",
      projectPath: projectDir.path,
      filesCreated: filesCreated
    )
  }

  // MARK: - Validation

  private static func isValidAppName(_ name: String) -> Bool {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    return name.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  // MARK: - File Generators

  private static func generatePackageSwift(name: String) -> String {
    """
    // swift-tools-version: 5.9
    import PackageDescription

    let package = Package(
      name: "\(name)",
      platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1)
      ],
      products: [
        .executable(name: "\(name)", targets: ["\(name)"])
      ],
      targets: [
        .executableTarget(
          name: "\(name)",
          path: "Sources/\(name)"
        )
      ]
    )
    """
  }

  private static func generateXClaudeToml(name: String, bundleId: String) -> String {
    """
    [app]
    name = "\(name)"
    bundle_id = "\(bundleId)"
    """
  }

  private static func generateAppSwift(name: String) -> String {
    """
    import SwiftUI

    @main
    struct \(name)App: App {
      var body: some Scene {
        WindowGroup {
          ContentView()
        }
      }
    }
    """
  }

  private static func generateContentView(name: String) -> String {
    """
    import SwiftUI

    struct ContentView: View {
      var body: some View {
        VStack(spacing: 20) {
          Image(systemName: "swift")
            .font(.system(size: 60))
            .foregroundStyle(.orange)

          Text("Hello, \(name)!")
            .font(.largeTitle)
            .fontWeight(.bold)

          Text("Built with xclaude")
            .foregroundStyle(.secondary)
        }
        .padding()
      }
    }

    #Preview {
      ContentView()
    }
    """
  }

  private static func generateGitignore() -> String {
    """
    # Build
    .build/
    .swiftpm/
    *.xcodeproj
    *.xcworkspace

    # xclaude
    .xclaude/
    Bundler.toml.xclaude-backup

    # macOS
    .DS_Store

    # IDE
    *.idea/
    *.vscode/
    """
  }

}
