import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(AppKit)
import AppKit
#endif

/// MCP tool definitions and implementations
public enum MCPTools {
  /// Tool definition
  struct Tool {
    let name: String
    let description: String
    let inputSchema: [String: Any]
  }

  /// All available tools
  static let allTools: [Tool] = [
    Tool(
      name: "discover_signing",
      description: "Discover available code signing identities and provisioning profiles",
      inputSchema: [
        "type": "object",
        "properties": [
          "force_refresh": [
            "type": "boolean",
            "description": "Force refresh instead of using cached data",
            "default": false
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "get_signing_status",
      description: "Get current signing configuration status (quick summary)",
      inputSchema: [
        "type": "object",
        "properties": [:] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "list_simulators",
      description: "List available iOS/tvOS/visionOS simulators",
      inputSchema: [
        "type": "object",
        "properties": [
          "platform": [
            "type": "string",
            "description": "Filter by platform (iOS, tvOS, watchOS, visionOS)",
            "enum": ["iOS", "tvOS", "watchOS", "visionOS"]
          ],
          "booted_only": [
            "type": "boolean",
            "description": "Only show booted simulators",
            "default": false
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "list_devices",
      description: "List connected iOS/tvOS/visionOS devices",
      inputSchema: [
        "type": "object",
        "properties": [:] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "build",
      description: "Build an app for a target platform",
      inputSchema: [
        "type": "object",
        "properties": [
          "platform": [
            "type": "string",
            "description": "Target platform (iOS, iOSSimulator, macOS, etc.)",
            "default": "iOSSimulator"
          ],
          "configuration": [
            "type": "string",
            "description": "Build configuration (debug or release)",
            "default": "debug"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "deploy",
      description: "Deploy an app to a device or simulator",
      inputSchema: [
        "type": "object",
        "properties": [
          "target": [
            "type": "string",
            "description": "Target device/simulator (UDID, name, or 'simulator'/'device')",
            "default": "simulator"
          ],
          "app_path": [
            "type": "string",
            "description": "Path to the .app bundle"
          ],
          "bundle_id": [
            "type": "string",
            "description": "App bundle identifier (for launching)"
          ],
          "launch": [
            "type": "boolean",
            "description": "Launch the app after installing",
            "default": true
          ]
        ] as [String: Any],
        "required": ["app_path", "bundle_id"] as [String]
      ]
    ),
    Tool(
      name: "run",
      description: "Build and run an app (combines build + deploy)",
      inputSchema: [
        "type": "object",
        "properties": [
          "platform": [
            "type": "string",
            "description": "Target platform (iOSSimulator, iOS, macOS)",
            "default": "iOSSimulator"
          ],
          "target": [
            "type": "string",
            "description": "Target device/simulator (UDID, name, or 'simulator'/'device')",
            "default": "simulator"
          ],
          "configuration": [
            "type": "string",
            "description": "Build configuration (debug or release)",
            "default": "debug"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "init_project",
      description: "Initialize xclaude.toml for a Swift package",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ],
          "name": [
            "type": "string",
            "description": "App name (auto-detected from Package.swift if not provided)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "get_config",
      description: "Get resolved project configuration",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "create_project",
      description: "Create a new SwiftUI app project",
      inputSchema: [
        "type": "object",
        "properties": [
          "name": [
            "type": "string",
            "description": "App name (letters only, e.g. 'MyApp')"
          ],
          "path": [
            "type": "string",
            "description": "Parent directory for the project (default: current directory)"
          ],
          "bundle_id": [
            "type": "string",
            "description": "Bundle identifier (default: derived from name)"
          ]
        ] as [String: Any],
        "required": ["name"] as [String]
      ]
    ),
    Tool(
      name: "update_config",
      description: "Update a value in xclaude.toml",
      inputSchema: [
        "type": "object",
        "properties": [
          "key": [
            "type": "string",
            "description": "Config key (e.g. 'app.name', 'app.bundle_id', 'signing.team')"
          ],
          "value": [
            "type": "string",
            "description": "New value"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": ["key", "value"] as [String]
      ]
    ),
    Tool(
      name: "add_capability",
      description: "Add an app capability (e.g. push-notifications, icloud, healthkit)",
      inputSchema: [
        "type": "object",
        "properties": [
          "capability": [
            "type": "string",
            "description": "Capability name (e.g. 'push-notifications', 'icloud', 'app-groups')"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ],
          "value": [
            "type": "string",
            "description": "Custom entitlement value (optional)"
          ]
        ] as [String: Any],
        "required": ["capability"] as [String]
      ]
    ),
    Tool(
      name: "list_capabilities",
      description: "List all available app capabilities",
      inputSchema: [
        "type": "object",
        "properties": [:] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "configure_signing",
      description: "Configure code signing for device builds. Shows available options and can auto-apply.",
      inputSchema: [
        "type": "object",
        "properties": [
          "team": [
            "type": "string",
            "description": "Team ID to use (if not specified, shows all options)"
          ],
          "apply": [
            "type": "boolean",
            "description": "Auto-apply the best matching configuration",
            "default": false
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "screenshot",
      description: "Capture a screenshot from the booted simulator",
      inputSchema: [
        "type": "object",
        "properties": [
          "simulator": [
            "type": "string",
            "description": "Simulator UDID (default: booted)"
          ],
          "output": [
            "type": "string",
            "description": "Output file path (default: temp file)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "get_logs",
      description: "Get recent logs from a running app on simulator",
      inputSchema: [
        "type": "object",
        "properties": [
          "bundle_id": [
            "type": "string",
            "description": "App bundle ID to filter logs (optional)"
          ],
          "lines": [
            "type": "integer",
            "description": "Number of recent lines to return (default: 50)"
          ],
          "simulator": [
            "type": "string",
            "description": "Simulator UDID (default: booted)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "test",
      description: "Run Swift tests and return results",
      inputSchema: [
        "type": "object",
        "properties": [
          "filter": [
            "type": "string",
            "description": "Filter tests by name pattern"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "add_dependency",
      description: "Add an SPM dependency to Package.swift",
      inputSchema: [
        "type": "object",
        "properties": [
          "url": [
            "type": "string",
            "description": "Git URL of the package"
          ],
          "version": [
            "type": "string",
            "description": "Version requirement (e.g., '1.0.0', 'from: 1.0.0', 'branch: main')"
          ],
          "name": [
            "type": "string",
            "description": "Package name (optional, derived from URL)"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": ["url"] as [String]
      ]
    ),
    Tool(
      name: "reset_simulator",
      description: "Reset a simulator to clean state",
      inputSchema: [
        "type": "object",
        "properties": [
          "simulator": [
            "type": "string",
            "description": "Simulator UDID or name (default: booted)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "generate_icon",
      description: "Generate a placeholder app icon (1024x1024 PNG)",
      inputSchema: [
        "type": "object",
        "properties": [
          "name": [
            "type": "string",
            "description": "App name to display on icon (default: from config)"
          ],
          "color": [
            "type": "string",
            "description": "Primary color hex (default: random gradient)"
          ],
          "output": [
            "type": "string",
            "description": "Output path (default: icon.png in project root)"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "get_crash_logs",
      description: "Get recent crash logs for an app",
      inputSchema: [
        "type": "object",
        "properties": [
          "bundle_id": [
            "type": "string",
            "description": "App bundle ID to filter crashes"
          ],
          "limit": [
            "type": "integer",
            "description": "Max number of crashes to return (default: 5)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "diagnose",
      description: "Check environment and project health, return issues with fix suggestions",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "archive",
      description: "Create a release build and package as .ipa for distribution",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ],
          "export_method": [
            "type": "string",
            "description": "Distribution method: app-store, ad-hoc, development, enterprise",
            "enum": ["app-store", "ad-hoc", "development", "enterprise"],
            "default": "ad-hoc"
          ],
          "output": [
            "type": "string",
            "description": "Output path for .ipa file (default: project directory)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "validate",
      description: "Validate an app or .ipa against App Store requirements",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to .app bundle or .ipa file"
          ],
          "strict": [
            "type": "boolean",
            "description": "Use strict validation (all warnings as errors)",
            "default": false
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "upload",
      description: "Upload an app to App Store Connect",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to .ipa file to upload"
          ],
          "api_key": [
            "type": "string",
            "description": "Path to App Store Connect API key (.p8 file)"
          ],
          "api_key_id": [
            "type": "string",
            "description": "App Store Connect API Key ID"
          ],
          "api_issuer": [
            "type": "string",
            "description": "App Store Connect API Issuer ID"
          ],
          "apple_id": [
            "type": "string",
            "description": "Apple ID (alternative to API key auth)"
          ],
          "password": [
            "type": "string",
            "description": "App-specific password (use @keychain: prefix for keychain)"
          ]
        ] as [String: Any],
        "required": ["path"] as [String]
      ]
    ),
    Tool(
      name: "watch",
      description: "Watch for file changes and auto-rebuild/redeploy",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ],
          "platform": [
            "type": "string",
            "description": "Target platform",
            "default": "iOSSimulator"
          ],
          "target": [
            "type": "string",
            "description": "Target device/simulator",
            "default": "simulator"
          ],
          "interval": [
            "type": "number",
            "description": "Poll interval in seconds (default: 2)",
            "default": 2
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "stop_watch",
      description: "Stop the file watcher",
      inputSchema: [
        "type": "object",
        "properties": [:] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "add_model",
      description: "Create a new SwiftData @Model class",
      inputSchema: [
        "type": "object",
        "properties": [
          "name": [
            "type": "string",
            "description": "Model class name (e.g., 'Task', 'User')"
          ],
          "properties": [
            "type": "array",
            "description": "Model properties as 'name:type' (e.g., ['title:String', 'isComplete:Bool', 'dueDate:Date?'])",
            "items": ["type": "string"]
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": ["name"] as [String]
      ]
    ),
    Tool(
      name: "add_extension",
      description: "Add an app extension (widget, share, etc.)",
      inputSchema: [
        "type": "object",
        "properties": [
          "type": [
            "type": "string",
            "description": "Extension type",
            "enum": ["widget", "share", "action", "today", "intents", "notification-content", "notification-service"]
          ],
          "name": [
            "type": "string",
            "description": "Extension name (default: derived from type)"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": ["type"] as [String]
      ]
    ),
    Tool(
      name: "generate_api_client",
      description: "Generate API client code from OpenAPI/Swagger spec",
      inputSchema: [
        "type": "object",
        "properties": [
          "spec": [
            "type": "string",
            "description": "Path or URL to OpenAPI spec (JSON or YAML)"
          ],
          "name": [
            "type": "string",
            "description": "API client class name (default: 'APIClient')"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ]
        ] as [String: Any],
        "required": ["spec"] as [String]
      ]
    ),
  ]

  /// Call a tool by name
  static func call(name: String, arguments: [String: Any]) async throws -> String {
    switch name {
      case "discover_signing":
        return try await discoverSigning(arguments: arguments)
      case "get_signing_status":
        return try await getSigningStatus()
      case "list_simulators":
        return try await listSimulators(arguments: arguments)
      case "list_devices":
        return try await listDevices()
      case "build":
        return try await build(arguments: arguments)
      case "deploy":
        return try await deploy(arguments: arguments)
      case "run":
        return try await run(arguments: arguments)
      case "init_project":
        return try await initProject(arguments: arguments)
      case "get_config":
        return try await getConfig(arguments: arguments)
      case "create_project":
        return try await createProject(arguments: arguments)
      case "update_config":
        return try await updateConfig(arguments: arguments)
      case "add_capability":
        return try await addCapability(arguments: arguments)
      case "list_capabilities":
        return listCapabilities()
      case "configure_signing":
        return try await configureSigning(arguments: arguments)
      case "screenshot":
        return try await screenshot(arguments: arguments)
      case "get_logs":
        return try await getLogs(arguments: arguments)
      case "test":
        return try await runTests(arguments: arguments)
      case "add_dependency":
        return try await addDependency(arguments: arguments)
      case "reset_simulator":
        return try await resetSimulator(arguments: arguments)
      case "generate_icon":
        return try await generateIcon(arguments: arguments)
      case "get_crash_logs":
        return try await getCrashLogs(arguments: arguments)
      case "diagnose":
        return try await diagnose(arguments: arguments)
      case "archive":
        return try await archive(arguments: arguments)
      case "validate":
        return try await validate(arguments: arguments)
      case "upload":
        return try await upload(arguments: arguments)
      case "watch":
        return try await watch(arguments: arguments)
      case "stop_watch":
        return try await stopWatch()
      case "add_model":
        return try await addModel(arguments: arguments)
      case "add_extension":
        return try await addExtension(arguments: arguments)
      case "generate_api_client":
        return try await generateAPIClient(arguments: arguments)
      default:
        throw MCPError.unknownTool(name)
    }
  }

  // MARK: - Tool Implementations

  static func discoverSigning(arguments: [String: Any]) async throws -> String {
    let forceRefresh = arguments["force_refresh"] as? Bool ?? false
    let discovery = SigningDiscovery()
    let data = try await discovery.discoverAll(forceRefresh: forceRefresh)
    return encodeJSON(data)
  }

  static func getSigningStatus() async throws -> String {
    let discovery = SigningDiscovery()
    let status = try await discovery.getStatus()
    return encodeJSON(status)
  }

  static func listSimulators(arguments: [String: Any]) async throws -> String {
    let output = try await runCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "devices", "-j"])

    guard let data = output.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let devices = json["devices"] as? [String: [[String: Any]]] else {
      return output
    }

    let platformFilter = arguments["platform"] as? String
    let bootedOnly = arguments["booted_only"] as? Bool ?? false

    var results: [SimulatorInfo] = []

    for (runtime, simulators) in devices {
      // Parse runtime to get platform and version
      // Format: com.apple.CoreSimulator.SimRuntime.iOS-17-0
      let runtimeParts = runtime.split(separator: ".")
      guard let lastPart = runtimeParts.last else { continue }

      let nameParts = lastPart.split(separator: "-")
      guard nameParts.count >= 2 else { continue }

      let platform = String(nameParts[0])
      let version = nameParts.dropFirst().joined(separator: ".")

      // Apply platform filter
      if let filter = platformFilter, platform != filter {
        continue
      }

      for sim in simulators {
        guard let name = sim["name"] as? String,
              let udid = sim["udid"] as? String,
              let state = sim["state"] as? String,
              let isAvailable = sim["isAvailable"] as? Bool else {
          continue
        }

        // Apply booted filter
        if bootedOnly && state != "Booted" {
          continue
        }

        // Skip unavailable simulators
        guard isAvailable else { continue }

        results.append(SimulatorInfo(
          name: name,
          udid: udid,
          state: state,
          platform: platform,
          version: version
        ))
      }
    }

    // Sort by platform, then by name
    results.sort { ($0.platform, $0.name) < ($1.platform, $1.name) }

    return encodeJSON(results)
  }

  static func listDevices() async throws -> String {
    // Use devicectl for connected devices (macOS 14+)
    let output = try await runCommand("/usr/bin/xcrun", arguments: ["devicectl", "list", "devices", "-j"])

    guard let data = output.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let result = json["result"] as? [String: Any],
          let devices = result["devices"] as? [[String: Any]] else {
      // Fall back to raw output if parsing fails
      return output
    }

    var results: [DeviceInfo] = []

    for device in devices {
      guard let deviceProperties = device["deviceProperties"] as? [String: Any],
            let name = deviceProperties["name"] as? String,
            let udid = device["identifier"] as? String else {
        continue
      }

      let platform = deviceProperties["platform"] as? String ?? "unknown"
      let osVersion = deviceProperties["osVersionNumber"] as? String
      let connectionProperties = device["connectionProperties"] as? [String: Any]
      let transportType = connectionProperties?["transportType"] as? String

      results.append(DeviceInfo(
        name: name,
        udid: udid,
        platform: platform,
        osVersion: osVersion,
        connectionType: transportType
      ))
    }

    return encodeJSON(results)
  }

  static func build(arguments: [String: Any]) async throws -> String {
    let platformStr = arguments["platform"] as? String ?? "iOSSimulator"
    let configStr = arguments["configuration"] as? String ?? "debug"
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath

    guard let platform = BuildRunner.Platform(rawValue: platformStr) else {
      return encodeJSON(BuildRunner.BuildResult(
        success: false,
        appPath: nil,
        platform: platformStr,
        configuration: configStr,
        duration: 0,
        warnings: [],
        errors: [BuildRunner.BuildError(
          code: "INVALID_PLATFORM",
          message: "Invalid platform: \(platformStr). Valid options: \(BuildRunner.Platform.allCases.map { $0.rawValue }.joined(separator: ", "))",
          fixable: false
        )]
      ))
    }

    let configuration: BuildRunner.Configuration = configStr == "release" ? .release : .debug
    let projectURL = URL(fileURLWithPath: pathStr)

    let result = try await BuildRunner.build(
      projectDirectory: projectURL,
      platform: platform,
      configuration: configuration
    )

    return encodeJSON(result)
  }

  static func deploy(arguments: [String: Any]) async throws -> String {
    guard let appPath = arguments["app_path"] as? String else {
      throw ToolError.missingArgument("app_path")
    }
    guard let bundleId = arguments["bundle_id"] as? String else {
      throw ToolError.missingArgument("bundle_id")
    }

    let targetStr = arguments["target"] as? String ?? "simulator"
    let launch = arguments["launch"] as? Bool ?? true
    let target = DeployRunner.Target.parse(targetStr)

    // Determine if this is a simulator or device target
    let result: DeployRunner.DeployResult
    switch target {
    case .simulator, .simulatorByName, .anyBootedSimulator:
      result = try await DeployRunner.deployToSimulator(
        appPath: appPath,
        bundleId: bundleId,
        target: target,
        launch: launch
      )
    case .device, .deviceByName, .anyDevice:
      result = try await DeployRunner.deployToDevice(
        appPath: appPath,
        bundleId: bundleId,
        target: target,
        launch: launch
      )
    }

    return encodeJSON(result)
  }

  static func run(arguments: [String: Any]) async throws -> String {
    let platformStr = arguments["platform"] as? String ?? "iOSSimulator"
    let configStr = arguments["configuration"] as? String ?? "debug"
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let targetStr = arguments["target"] as? String ?? "simulator"

    // First build
    let buildResult = try await BuildRunner.build(
      projectDirectory: URL(fileURLWithPath: pathStr),
      platform: BuildRunner.Platform(rawValue: platformStr) ?? .iOSSimulator,
      configuration: configStr == "release" ? .release : .debug
    )

    guard buildResult.success, let appPath = buildResult.appPath else {
      return encodeJSON(RunResult(
        success: false,
        buildResult: buildResult,
        deployResult: nil
      ))
    }

    // Get bundle ID from config
    let config = try? XClaudeConfig.load(from: URL(fileURLWithPath: pathStr))
    let bundleId = config?.app.bundleId ?? "com.xclaude.app"

    // Handle platform-specific deployment
    let platform = BuildRunner.Platform(rawValue: platformStr) ?? .iOSSimulator
    let deployResult: DeployRunner.DeployResult

    if platform == .macOS {
      // For macOS, just open the .app directly
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      process.arguments = [appPath]
      try process.run()
      process.waitUntilExit()

      let launchSuccess = process.terminationStatus == 0
      deployResult = DeployRunner.DeployResult(
        success: launchSuccess,
        target: DeployRunner.TargetInfo(type: .simulator, udid: "local", name: "macOS (local)"),
        appPath: appPath,
        bundleId: bundleId,
        launched: launchSuccess,
        error: launchSuccess ? nil : "Failed to launch app"
      )
    } else {
      // For iOS/tvOS/visionOS, deploy to simulator or device
      let target = DeployRunner.Target.parse(targetStr)

      switch target {
      case .simulator, .simulatorByName, .anyBootedSimulator:
        deployResult = try await DeployRunner.deployToSimulator(
          appPath: appPath,
          bundleId: bundleId,
          target: target,
          launch: true
        )
      case .device, .deviceByName, .anyDevice:
        deployResult = try await DeployRunner.deployToDevice(
          appPath: appPath,
          bundleId: bundleId,
          target: target,
          launch: true
        )
      }
    }

    return encodeJSON(RunResult(
      success: deployResult.success,
      buildResult: buildResult,
      deployResult: deployResult
    ))
  }

  static func initProject(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let name = arguments["name"] as? String
    let projectURL = URL(fileURLWithPath: pathStr)

    // Check if already initialized
    if ConfigTranslator.hasXClaudeConfig(at: projectURL) {
      return encodeJSON(InitResult(
        success: false,
        message: "Project already has xclaude.toml",
        configPath: nil
      ))
    }

    // Initialize config
    let config = try ConfigTranslator.initializeXClaudeConfig(at: projectURL, appName: name)
    let configPath = projectURL.appendingPathComponent("xclaude.toml").path

    return encodeJSON(InitResult(
      success: true,
      message: "Created xclaude.toml for '\(config.app.name)'",
      configPath: configPath
    ))
  }

  static func getConfig(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let projectURL = URL(fileURLWithPath: pathStr)

    let projectType = ConfigTranslator.detectProjectType(at: projectURL)

    switch projectType {
    case .xclaude:
      let config = try XClaudeConfig.load(from: projectURL)

      // Also get signing info
      let signing = try? await SigningDiscovery().getStatus()

      return encodeJSON(ResolvedConfig(
        projectType: "xclaude",
        config: config,
        signingStatus: signing
      ))

    case .swiftBundler:
      return encodeJSON(["projectType": "swiftBundler", "message": "Using existing Bundler.toml"])

    case .swiftPackage:
      return encodeJSON(["projectType": "swiftPackage", "message": "No xclaude.toml found. Run init_project to create one."])

    case .unknown:
      return encodeJSON(["projectType": "unknown", "message": "Not a Swift project"])
    }
  }

  static func createProject(arguments: [String: Any]) async throws -> String {
    guard let name = arguments["name"] as? String else {
      throw ToolError.missingArgument("name")
    }

    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let bundleId = arguments["bundle_id"] as? String
    let parentDir = URL(fileURLWithPath: pathStr)

    let result = try ProjectScaffold.create(
      name: name,
      at: parentDir,
      bundleId: bundleId
    )

    return encodeJSON(result)
  }

  static func updateConfig(arguments: [String: Any]) async throws -> String {
    guard let key = arguments["key"] as? String else {
      throw ToolError.missingArgument("key")
    }
    guard let value = arguments["value"] as? String else {
      throw ToolError.missingArgument("value")
    }

    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let projectURL = URL(fileURLWithPath: pathStr)

    let result = try ConfigUpdater.update(key: key, value: value, at: projectURL)
    return encodeJSON(result)
  }

  static func addCapability(arguments: [String: Any]) async throws -> String {
    guard let capability = arguments["capability"] as? String else {
      throw ToolError.missingArgument("capability")
    }

    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let projectURL = URL(fileURLWithPath: pathStr)
    let value = arguments["value"] as? String

    let result = try CapabilityManager.addCapability(capability, to: projectURL, value: value)
    return encodeJSON(result)
  }

  static func listCapabilities() -> String {
    let caps = CapabilityManager.listCapabilities()
    return encodeJSON(caps)
  }

  static func configureSigning(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let projectURL = URL(fileURLWithPath: pathStr)
    let requestedTeam = arguments["team"] as? String
    let shouldApply = arguments["apply"] as? Bool ?? false

    // Load project config to get bundle ID
    let config = try? XClaudeConfig.load(from: projectURL)
    let bundleId = config?.app.bundleId ?? "com.example.app"

    // Discover signing
    let discovery = SigningDiscovery()
    let signingData = try await discovery.discoverAll()

    // Group profiles by team, filter for iOS
    var teamOptions: [SigningOption] = []

    // Get unique team IDs from profiles (that aren't expired)
    let validProfiles = signingData.profiles.filter { !$0.isExpired }
    let teamIds = Set(validProfiles.map { $0.teamId })

    for teamId in teamIds {
      // Skip if user requested specific team and this isn't it
      if let requested = requestedTeam, teamId != requested {
        continue
      }

      // Find profiles for this team that match the bundle ID
      let teamProfiles = validProfiles.filter { $0.teamId == teamId }
      let matchingProfiles = teamProfiles.filter { profile in
        if profile.bundleIdPattern == bundleId {
          return true
        }
        if profile.isWildcard {
          let prefix = profile.bundleIdPattern.replacingOccurrences(of: "*", with: "")
          return prefix.isEmpty || bundleId.hasPrefix(prefix)
        }
        return false
      }

      guard !matchingProfiles.isEmpty else { continue }

      // Find identity for this team
      let teamIdentities = signingData.identities.filter { $0.teamId == teamId }

      // Prefer development certificates
      let identity = teamIdentities.first { $0.name.contains("Development") } ?? teamIdentities.first

      guard let identity = identity else { continue }

      // Pick best profile (exact match over wildcard)
      let bestProfile = matchingProfiles.first { !$0.isWildcard } ?? matchingProfiles.first!

      teamOptions.append(SigningOption(
        teamId: teamId,
        identity: identity.name,
        profile: bestProfile.name,
        profilePath: bestProfile.path,
        isWildcard: bestProfile.isWildcard,
        bundleIdPattern: bestProfile.bundleIdPattern
      ))
    }

    // Sort options (prefer exact match, then alphabetical)
    teamOptions.sort { a, b in
      if a.isWildcard != b.isWildcard {
        return !a.isWildcard
      }
      return a.teamId < b.teamId
    }

    // Mark recommended
    var result = SigningConfiguration(
      bundleId: bundleId,
      currentConfig: CurrentSigningConfig(
        team: config?.signing?.team,
        identity: config?.signing?.identity,
        profile: config?.signing?.profile
      ),
      options: teamOptions,
      recommended: teamOptions.first,
      applied: false
    )

    // Auto-apply if requested and we have a recommendation
    if shouldApply, let recommended = result.recommended {
      _ = try ConfigUpdater.update(key: "signing.team", value: recommended.teamId, at: projectURL)
      _ = try ConfigUpdater.update(key: "signing.identity", value: recommended.identity, at: projectURL)
      _ = try ConfigUpdater.update(key: "signing.profile", value: recommended.profile, at: projectURL)
      result.applied = true
    }

    return encodeJSON(result)
  }

  struct SigningOption: Codable {
    let teamId: String
    let identity: String
    let profile: String
    let profilePath: String
    let isWildcard: Bool
    let bundleIdPattern: String
  }

  struct CurrentSigningConfig: Codable {
    let team: String?
    let identity: String?
    let profile: String?
  }

  struct SigningConfiguration: Codable {
    let bundleId: String
    let currentConfig: CurrentSigningConfig
    let options: [SigningOption]
    let recommended: SigningOption?
    var applied: Bool
  }

  // MARK: - Screenshot

  static func screenshot(arguments: [String: Any]) async throws -> String {
    let simulator = arguments["simulator"] as? String ?? "booted"
    let outputPath = arguments["output"] as? String ?? "/tmp/xclaude-screenshot-\(UUID().uuidString).png"

    let output = try await runCommand(
      "/usr/bin/xcrun",
      arguments: ["simctl", "io", simulator, "screenshot", outputPath]
    )

    // Check if file was created
    if FileManager.default.fileExists(atPath: outputPath) {
      return encodeJSON(ScreenshotResult(
        success: true,
        path: outputPath,
        message: "Screenshot saved"
      ))
    } else {
      return encodeJSON(ScreenshotResult(
        success: false,
        path: nil,
        message: output.isEmpty ? "Failed to capture screenshot. Is a simulator booted?" : output
      ))
    }
  }

  struct ScreenshotResult: Codable {
    let success: Bool
    let path: String?
    let message: String
  }

  // MARK: - Logs

  static func getLogs(arguments: [String: Any]) async throws -> String {
    let bundleId = arguments["bundle_id"] as? String
    let lineCount = arguments["lines"] as? Int ?? 50
    let simulator = arguments["simulator"] as? String ?? "booted"

    // Build predicate for filtering - always filter to reduce output
    var predicate = "eventType == 'logEvent'"
    if let bundleId = bundleId {
      predicate = "(subsystem CONTAINS '\(bundleId)' OR process CONTAINS '\(bundleId)')"
    }

    // Use log show with very short time window to avoid slowness
    // --last 10s is much faster than --last 1m
    let args = ["simctl", "spawn", simulator, "log", "show",
                "--last", "10s",
                "--style", "compact",
                "--predicate", predicate]

    let output = try await runCommand("/usr/bin/xcrun", arguments: args)

    // Take last N lines
    let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
    let recentLines = lines.suffix(lineCount)

    return encodeJSON(LogsResult(
      success: true,
      lineCount: recentLines.count,
      logs: recentLines.joined(separator: "\n"),
      bundleIdFilter: bundleId
    ))
  }

  struct LogsResult: Codable {
    let success: Bool
    let lineCount: Int
    let logs: String
    let bundleIdFilter: String?
  }

  // MARK: - Tests

  static func runTests(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let filter = arguments["filter"] as? String
    let projectURL = URL(fileURLWithPath: pathStr)

    var args = ["test"]
    if let filter = filter {
      args.append("--filter")
      args.append(filter)
    }

    let (exitCode, stdout, stderr) = try await runProcessWithStatus(
      "/usr/bin/swift",
      arguments: args,
      currentDirectory: projectURL
    )

    // Parse test output
    let allOutput = stdout + "\n" + stderr
    var passed = 0
    var failed = 0
    var skipped = 0
    var failures: [TestFailure] = []

    for line in allOutput.split(separator: "\n") {
      let lineStr = String(line)

      // Count results - look for "Test Suite ... passed" or "Test Suite ... failed"
      if lineStr.contains("passed (") {
        // Extract count from "X tests passed"
        if let match = lineStr.range(of: "(\\d+) test", options: .regularExpression) {
          let numStr = lineStr[match].dropLast(5) // remove " test"
          passed += Int(numStr) ?? 0
        }
      }
      if lineStr.contains("failed (") {
        if let match = lineStr.range(of: "(\\d+) test", options: .regularExpression) {
          let numStr = lineStr[match].dropLast(5)
          failed += Int(numStr) ?? 0
        }
      }

      // Capture failure details
      if lineStr.contains("✗") || lineStr.contains("FAIL") {
        failures.append(TestFailure(message: lineStr, file: nil, line: nil))
      }
    }

    return encodeJSON(TestResult(
      success: exitCode == 0,
      passed: passed,
      failed: failed,
      skipped: skipped,
      failures: failures,
      output: allOutput.count > 5000 ? String(allOutput.prefix(5000)) + "\n... (truncated)" : allOutput
    ))
  }

  struct TestResult: Codable {
    let success: Bool
    let passed: Int
    let failed: Int
    let skipped: Int
    let failures: [TestFailure]
    let output: String
  }

  struct TestFailure: Codable {
    let message: String
    let file: String?
    let line: Int?
  }

  // MARK: - Dependencies

  static func addDependency(arguments: [String: Any]) async throws -> String {
    guard let url = arguments["url"] as? String else {
      throw ToolError.missingArgument("url")
    }

    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let version = arguments["version"] as? String ?? "from: \"1.0.0\""
    let projectURL = URL(fileURLWithPath: pathStr)
    let packagePath = projectURL.appendingPathComponent("Package.swift")

    // Derive package name from URL
    let packageName = arguments["name"] as? String ?? {
      // Extract name from URL like https://github.com/user/PackageName.git
      var name = URL(string: url)?.lastPathComponent ?? "Package"
      if name.hasSuffix(".git") {
        name = String(name.dropLast(4))
      }
      return name
    }()

    // Read current Package.swift
    guard FileManager.default.fileExists(atPath: packagePath.path) else {
      return encodeJSON(DependencyResult(
        success: false,
        message: "Package.swift not found at \(packagePath.path)",
        packageName: packageName
      ))
    }

    var content = try String(contentsOf: packagePath, encoding: .utf8)

    // Parse version requirement
    let versionRequirement: String
    if version.contains(":") {
      // Already formatted like "from: \"1.0.0\"" or "branch: \"main\""
      versionRequirement = version
    } else if version.hasPrefix(".") {
      // Version like ".upToNextMajor(from: \"1.0.0\")"
      versionRequirement = version
    } else {
      // Just a version number
      versionRequirement = "from: \"\(version)\""
    }

    // Create the package dependency line
    let packageLine = ".package(url: \"\(url)\", \(versionRequirement))"

    // Find the dependencies array and add to it
    // Look for "dependencies: [" in the Package definition
    if let dependenciesRange = content.range(of: "dependencies:\\s*\\[", options: .regularExpression) {
      // Find the closing bracket
      let searchStart = dependenciesRange.upperBound
      var bracketCount = 1
      var insertIndex = searchStart

      for idx in content[searchStart...].indices {
        let char = content[idx]
        if char == "[" { bracketCount += 1 }
        if char == "]" {
          bracketCount -= 1
          if bracketCount == 0 {
            insertIndex = idx
            break
          }
        }
      }

      // Check if array is empty or has items
      let arrayContent = content[searchStart..<insertIndex].trimmingCharacters(in: .whitespacesAndNewlines)
      let insertText: String
      if arrayContent.isEmpty {
        insertText = "\n    \(packageLine),\n  "
      } else {
        insertText = "\n    \(packageLine),"
      }

      content.insert(contentsOf: insertText, at: insertIndex)
    } else {
      // No dependencies array - add one after products
      if let productsRange = content.range(of: "products:\\s*\\[", options: .regularExpression) {
        // Find the end of products array
        let searchStart = productsRange.upperBound
        var bracketCount = 1
        var afterProducts = searchStart

        for idx in content[searchStart...].indices {
          let char = content[idx]
          if char == "[" { bracketCount += 1 }
          if char == "]" {
            bracketCount -= 1
            if bracketCount == 0 {
              afterProducts = content.index(after: idx)
              break
            }
          }
        }

        // Insert dependencies array after products
        let dependenciesArray = ",\n  dependencies: [\n    \(packageLine),\n  ]"
        content.insert(contentsOf: dependenciesArray, at: afterProducts)
      } else {
        return encodeJSON(DependencyResult(
          success: false,
          message: "Could not find products or dependencies array in Package.swift",
          packageName: packageName
        ))
      }
    }

    // Also add to target dependencies if we can find it
    // Look for .target(name: "AppName", dependencies: [
    // This is more complex, so we'll just add the package for now

    // Write updated content
    try content.write(to: packagePath, atomically: true, encoding: .utf8)

    return encodeJSON(DependencyResult(
      success: true,
      message: "Added \(packageName) to Package.swift. You may need to add it to your target's dependencies array.",
      packageName: packageName
    ))
  }

  struct DependencyResult: Codable {
    let success: Bool
    let message: String
    let packageName: String
  }

  // MARK: - Simulator Management

  static func resetSimulator(arguments: [String: Any]) async throws -> String {
    let simulator = arguments["simulator"] as? String ?? "booted"

    // If "booted", we need to get the actual UDID first
    var udid = simulator
    if simulator == "booted" {
      let listOutput = try await runCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "devices", "-j"])
      if let data = listOutput.data(using: .utf8),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let devices = json["devices"] as? [String: [[String: Any]]] {
        for (_, sims) in devices {
          for sim in sims {
            if let state = sim["state"] as? String, state == "Booted",
               let simUdid = sim["udid"] as? String {
              udid = simUdid
              break
            }
          }
        }
      }
    }

    // Shutdown first if booted
    _ = try? await runCommand("/usr/bin/xcrun", arguments: ["simctl", "shutdown", udid])

    // Erase
    let output = try await runCommand("/usr/bin/xcrun", arguments: ["simctl", "erase", udid])

    if output.isEmpty || output.contains("erased") || !output.contains("error") {
      return encodeJSON(SimulatorResetResult(
        success: true,
        message: "Simulator reset to clean state",
        udid: udid
      ))
    } else {
      return encodeJSON(SimulatorResetResult(
        success: false,
        message: output,
        udid: udid
      ))
    }
  }

  struct SimulatorResetResult: Codable {
    let success: Bool
    let message: String
    let udid: String
  }

  // MARK: - Icon Generation

  static func generateIcon(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let projectURL = URL(fileURLWithPath: pathStr)

    // Get app name from config or argument
    let config = try? XClaudeConfig.load(from: projectURL)
    let appName = arguments["name"] as? String ?? config?.app.name ?? "App"

    // Output path
    let outputPath = arguments["output"] as? String ?? projectURL.appendingPathComponent("icon.png").path

    // Color - use provided or generate based on app name hash
    let colorHex = arguments["color"] as? String
    let primaryColor = colorHex.flatMap { hexToColor($0) } ?? colorFromHash(appName)

    #if canImport(AppKit)
    // Generate icon using CoreGraphics
    let size = 1024
    let scale: CGFloat = 1.0

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
      return encodeJSON(IconResult(
        success: false,
        path: nil,
        message: "Failed to create graphics context"
      ))
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Draw gradient background
    let startColor = primaryColor
    let endColor = darkenColor(primaryColor, by: 0.3)

    let colors = [startColor.cgColor, endColor.cgColor] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
      context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: CGFloat(size)),
        end: CGPoint(x: CGFloat(size), y: 0),
        options: []
      )
    }

    // Draw app name text
    let fontSize: CGFloat = CGFloat(size) / CGFloat(max(appName.count, 3)) * 0.8
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)

    let textAttributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.white
    ]

    let textSize = (appName as NSString).size(withAttributes: textAttributes)
    let textRect = CGRect(
      x: (CGFloat(size) - textSize.width) / 2,
      y: (CGFloat(size) - textSize.height) / 2,
      width: textSize.width,
      height: textSize.height
    )

    // Draw text using NSGraphicsContext
    NSGraphicsContext.saveGraphicsState()
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = nsContext

    (appName as NSString).draw(in: textRect, withAttributes: textAttributes)

    NSGraphicsContext.restoreGraphicsState()

    // Create image and save
    guard let cgImage = context.makeImage() else {
      return encodeJSON(IconResult(
        success: false,
        path: nil,
        message: "Failed to create image"
      ))
    }

    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
      return encodeJSON(IconResult(
        success: false,
        path: nil,
        message: "Failed to convert image to PNG"
      ))
    }

    do {
      try pngData.write(to: URL(fileURLWithPath: outputPath))
      return encodeJSON(IconResult(
        success: true,
        path: outputPath,
        message: "Generated 1024x1024 icon for '\(appName)'"
      ))
    } catch {
      return encodeJSON(IconResult(
        success: false,
        path: nil,
        message: "Failed to write icon: \(error.localizedDescription)"
      ))
    }
    #else
    return encodeJSON(IconResult(
      success: false,
      path: nil,
      message: "Icon generation requires macOS (AppKit)"
    ))
    #endif
  }

  #if canImport(AppKit)
  private static func hexToColor(_ hex: String) -> NSColor? {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    guard hexSanitized.count == 6,
          let hexNumber = UInt64(hexSanitized, radix: 16) else {
      return nil
    }

    let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
    let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
    let b = CGFloat(hexNumber & 0x0000FF) / 255.0

    return NSColor(red: r, green: g, blue: b, alpha: 1.0)
  }

  private static func colorFromHash(_ string: String) -> NSColor {
    // Generate a pleasant color from string hash
    let hash = abs(string.hashValue)
    let hue = CGFloat(hash % 360) / 360.0
    return NSColor(hue: hue, saturation: 0.7, brightness: 0.8, alpha: 1.0)
  }

  private static func darkenColor(_ color: NSColor, by amount: CGFloat) -> NSColor {
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return NSColor(hue: h, saturation: s, brightness: max(0, b - amount), alpha: a)
  }
  #endif

  struct IconResult: Codable {
    let success: Bool
    let path: String?
    let message: String
  }

  // MARK: - Crash Logs

  static func getCrashLogs(arguments: [String: Any]) async throws -> String {
    let bundleId = arguments["bundle_id"] as? String
    let limit = arguments["limit"] as? Int ?? 5

    // Crash logs are stored in ~/Library/Logs/DiagnosticReports/
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let crashDir = homeDir
      .appendingPathComponent("Library")
      .appendingPathComponent("Logs")
      .appendingPathComponent("DiagnosticReports")

    guard FileManager.default.fileExists(atPath: crashDir.path) else {
      return encodeJSON(CrashLogsResult(
        success: true,
        crashes: [],
        message: "No crash reports directory found"
      ))
    }

    let contents = try FileManager.default.contentsOfDirectory(
      at: crashDir,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    )

    // Filter for .ips files (newer format) and .crash files
    var crashFiles = contents.filter { url in
      let ext = url.pathExtension.lowercased()
      return ext == "ips" || ext == "crash"
    }

    // Filter by bundle ID if specified
    if let bundleId = bundleId {
      crashFiles = crashFiles.filter { url in
        url.lastPathComponent.contains(bundleId) ||
        (try? String(contentsOf: url, encoding: .utf8).contains(bundleId)) ?? false
      }
    }

    // Sort by modification date (newest first)
    crashFiles.sort { a, b in
      let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
      let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
      return aDate > bDate
    }

    // Take top N
    let recentCrashes = Array(crashFiles.prefix(limit))

    // Parse each crash
    var crashes: [CrashInfo] = []
    for crashFile in recentCrashes {
      let content = try String(contentsOf: crashFile, encoding: .utf8)
      let info = parseCrashLog(content: content, path: crashFile.path)
      crashes.append(info)
    }

    return encodeJSON(CrashLogsResult(
      success: true,
      crashes: crashes,
      message: crashes.isEmpty ? "No crash reports found" : "Found \(crashes.count) crash report(s)"
    ))
  }

  private static func parseCrashLog(content: String, path: String) -> CrashInfo {
    var processName: String?
    var bundleId: String?
    var crashDate: String?
    var exceptionType: String?
    var crashedThread: String?

    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

    for line in lines.prefix(100) { // Only scan first 100 lines for headers
      let lineStr = String(line)

      if lineStr.hasPrefix("Process:") {
        processName = lineStr.replacingOccurrences(of: "Process:", with: "").trimmingCharacters(in: .whitespaces)
      } else if lineStr.hasPrefix("Identifier:") || lineStr.contains("\"bundleID\"") {
        bundleId = lineStr
          .replacingOccurrences(of: "Identifier:", with: "")
          .replacingOccurrences(of: "\"bundleID\"", with: "")
          .replacingOccurrences(of: ":", with: "")
          .replacingOccurrences(of: "\"", with: "")
          .trimmingCharacters(in: .whitespaces)
      } else if lineStr.hasPrefix("Date/Time:") || lineStr.contains("\"captureTime\"") {
        crashDate = lineStr
          .replacingOccurrences(of: "Date/Time:", with: "")
          .trimmingCharacters(in: .whitespaces)
      } else if lineStr.hasPrefix("Exception Type:") || lineStr.contains("\"exception\"") {
        exceptionType = lineStr
          .replacingOccurrences(of: "Exception Type:", with: "")
          .trimmingCharacters(in: .whitespaces)
      } else if lineStr.hasPrefix("Crashed Thread:") {
        crashedThread = lineStr
          .replacingOccurrences(of: "Crashed Thread:", with: "")
          .trimmingCharacters(in: .whitespaces)
      }
    }

    return CrashInfo(
      path: path,
      processName: processName,
      bundleId: bundleId,
      date: crashDate,
      exceptionType: exceptionType,
      crashedThread: crashedThread,
      snippet: String(content.prefix(500))
    )
  }

  struct CrashLogsResult: Codable {
    let success: Bool
    let crashes: [CrashInfo]
    let message: String
  }

  struct CrashInfo: Codable {
    let path: String
    let processName: String?
    let bundleId: String?
    let date: String?
    let exceptionType: String?
    let crashedThread: String?
    let snippet: String
  }

  // MARK: - Diagnose

  static func diagnose(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let projectURL = URL(fileURLWithPath: pathStr)

    var issues: [DiagnosticIssue] = []

    // Check 1: Xcode installed
    let xcodeCheck = try? await runCommand("/usr/bin/xcode-select", arguments: ["-p"])
    if xcodeCheck?.isEmpty ?? true {
      issues.append(DiagnosticIssue(
        code: "XCODE_NOT_INSTALLED",
        severity: "error",
        message: "Xcode command line tools not installed",
        suggestion: "Run: xcode-select --install",
        fixable: true
      ))
    }

    // Check 2: Project has Package.swift
    let packagePath = projectURL.appendingPathComponent("Package.swift")
    if !FileManager.default.fileExists(atPath: packagePath.path) {
      issues.append(DiagnosticIssue(
        code: "NO_PACKAGE_SWIFT",
        severity: "error",
        message: "No Package.swift found",
        suggestion: "Run create_project to create a new project, or init_project to initialize an existing one",
        fixable: false
      ))
    }

    // Check 3: xclaude.toml exists
    let xclaudePath = projectURL.appendingPathComponent("xclaude.toml")
    if !FileManager.default.fileExists(atPath: xclaudePath.path) {
      issues.append(DiagnosticIssue(
        code: "NO_XCLAUDE_CONFIG",
        severity: "warning",
        message: "No xclaude.toml found",
        suggestion: "Run init_project to create xclaude.toml",
        fixable: true
      ))
    } else {
      // Check 3b: Config is valid
      do {
        let _ = try XClaudeConfig.load(from: projectURL)
      } catch {
        issues.append(DiagnosticIssue(
          code: "INVALID_CONFIG",
          severity: "error",
          message: "xclaude.toml is invalid: \(error.localizedDescription)",
          suggestion: "Check xclaude.toml for syntax errors",
          fixable: false
        ))
      }
    }

    // Check 4: Icon exists
    let iconPath = projectURL.appendingPathComponent("icon.png")
    if !FileManager.default.fileExists(atPath: iconPath.path) {
      issues.append(DiagnosticIssue(
        code: "NO_ICON",
        severity: "warning",
        message: "No icon.png found",
        suggestion: "Run generate_icon to create a placeholder icon, or add a 1024x1024 icon.png",
        fixable: true
      ))
    }

    // Check 5: Signing available
    let discovery = SigningDiscovery()
    let signingStatus = try? await discovery.getStatus()

    if signingStatus?.identityCount == 0 {
      issues.append(DiagnosticIssue(
        code: "NO_SIGNING_IDENTITY",
        severity: "warning",
        message: "No code signing identities found",
        suggestion: "Open Xcode and sign in with your Apple ID to download signing certificates",
        fixable: false
      ))
    }

    if signingStatus?.profileCount == 0 {
      issues.append(DiagnosticIssue(
        code: "NO_PROVISIONING_PROFILES",
        severity: "warning",
        message: "No provisioning profiles found",
        suggestion: "Open Xcode, create a project with the same bundle ID, and run on a device to generate profiles",
        fixable: false
      ))
    }

    // Check 6: Simulators available
    let simOutput = try? await runCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "devices", "-j"])
    if simOutput?.isEmpty ?? true {
      issues.append(DiagnosticIssue(
        code: "NO_SIMULATORS",
        severity: "warning",
        message: "No iOS simulators found",
        suggestion: "Open Xcode → Settings → Platforms and download simulator runtimes",
        fixable: false
      ))
    }

    // Check 7: swift-bundler available
    let bundlerPath = findSwiftBundlerPath()
    if bundlerPath == nil {
      issues.append(DiagnosticIssue(
        code: "NO_SWIFT_BUNDLER",
        severity: "error",
        message: "swift-bundler not found",
        suggestion: "Build xclaude project with: swift build",
        fixable: false
      ))
    }

    // Summary
    let errorCount = issues.filter { $0.severity == "error" }.count
    let warningCount = issues.filter { $0.severity == "warning" }.count

    let status: String
    if errorCount > 0 {
      status = "unhealthy"
    } else if warningCount > 0 {
      status = "degraded"
    } else {
      status = "healthy"
    }

    return encodeJSON(DiagnoseResult(
      status: status,
      errorCount: errorCount,
      warningCount: warningCount,
      issues: issues,
      environment: EnvironmentInfo(
        xcodeInstalled: !(xcodeCheck?.isEmpty ?? true),
        signingIdentities: signingStatus?.identityCount ?? 0,
        provisioningProfiles: signingStatus?.profileCount ?? 0,
        swiftBundlerPath: bundlerPath
      )
    ))
  }

  private static func findSwiftBundlerPath() -> String? {
    // Check next to xclaude executable
    if let execPath = Bundle.main.executablePath {
      let execDir = URL(fileURLWithPath: execPath).deletingLastPathComponent()
      let siblingPath = execDir.appendingPathComponent("swift-bundler").path
      if FileManager.default.isExecutableFile(atPath: siblingPath) {
        return siblingPath
      }
    }

    // Check common locations
    let candidates = [
      ".build/debug/swift-bundler",
      ".build/release/swift-bundler",
      "/usr/local/bin/swift-bundler"
    ]

    for candidate in candidates {
      let path = NSString(string: candidate).expandingTildeInPath
      if FileManager.default.isExecutableFile(atPath: path) {
        return path
      }
    }

    return nil
  }

  struct DiagnoseResult: Codable {
    let status: String  // "healthy", "degraded", "unhealthy"
    let errorCount: Int
    let warningCount: Int
    let issues: [DiagnosticIssue]
    let environment: EnvironmentInfo
  }

  struct DiagnosticIssue: Codable {
    let code: String
    let severity: String  // "error", "warning", "info"
    let message: String
    let suggestion: String
    let fixable: Bool
  }

  struct EnvironmentInfo: Codable {
    let xcodeInstalled: Bool
    let signingIdentities: Int
    let provisioningProfiles: Int
    let swiftBundlerPath: String?
  }

  // MARK: - Archive

  static func archive(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let exportMethod = arguments["export_method"] as? String ?? "ad-hoc"
    let projectURL = URL(fileURLWithPath: pathStr)

    // Load config
    guard let config = try? XClaudeConfig.load(from: projectURL) else {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: nil,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "No xclaude.toml found. Run init_project first."
      ))
    }

    let appName = config.app.name
    let bundleId = config.app.bundleId ?? "com.example.\(appName)"

    // Step 1: Build in release mode for iOS
    let buildResult = try await BuildRunner.build(
      projectDirectory: projectURL,
      platform: .iOS,
      configuration: .release
    )

    guard buildResult.success, let appPath = buildResult.appPath else {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: nil,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "Build failed: \(buildResult.errors.first?.message ?? "Unknown error")"
      ))
    }

    // Step 2: Find distribution signing based on export method
    let discovery = SigningDiscovery()
    let signingData = try await discovery.discoverAll()

    // Find appropriate profile based on export method
    let profileType: String
    switch exportMethod {
    case "app-store":
      profileType = "App Store"
    case "ad-hoc":
      profileType = "Ad Hoc"
    case "enterprise":
      profileType = "Enterprise"
    default:
      profileType = "Development"
    }

    // Find matching profile for distribution
    let matchingProfiles = signingData.profiles.filter { profile in
      // Match bundle ID
      let matchesBundleId = profile.bundleIdPattern == bundleId ||
        (profile.isWildcard && (profile.bundleIdPattern == "*" ||
          bundleId.hasPrefix(profile.bundleIdPattern.replacingOccurrences(of: "*", with: ""))))

      // For app-store/ad-hoc, prefer non-development profiles
      // (Development profiles have "Development" in name usually)
      let isDistribution = exportMethod == "development" ||
        !profile.name.lowercased().contains("development")

      return matchesBundleId && !profile.isExpired && isDistribution
    }

    guard let profile = matchingProfiles.first else {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "No matching provisioning profile found for '\(bundleId)' with export method '\(exportMethod)'. Available profiles: \(signingData.profiles.map { $0.name }.joined(separator: ", "))"
      ))
    }

    // Find distribution identity (prefer "Distribution" certificates)
    let distributionIdentities = signingData.identities.filter { identity in
      identity.teamId == profile.teamId &&
      (exportMethod == "development" || identity.name.contains("Distribution") || identity.name.contains("Developer ID"))
    }

    let identity = distributionIdentities.first ?? signingData.identities.first { $0.teamId == profile.teamId }

    guard let identity = identity else {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "No signing identity found for team '\(profile.teamId)'"
      ))
    }

    // Step 3: Re-sign the app with distribution credentials if needed
    // The app was already signed during build, but we may need to re-sign for distribution
    // For now, we'll use the existing signature (BuildRunner handles signing)

    // Step 4: Create .ipa structure
    // .ipa is a zip file with Payload/AppName.app structure
    let outputPath = arguments["output"] as? String ?? projectURL.appendingPathComponent("\(appName).ipa").path

    let payloadDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("xclaude-archive-\(UUID().uuidString)")
      .appendingPathComponent("Payload")

    do {
      // Create Payload directory
      try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

      // Copy .app to Payload/
      let appURL = URL(fileURLWithPath: appPath)
      let destURL = payloadDir.appendingPathComponent(appURL.lastPathComponent)
      try FileManager.default.copyItem(at: appURL, to: destURL)

      // Create .ipa by zipping Payload directory
      let parentDir = payloadDir.deletingLastPathComponent()
      let zipOutput = try await runCommand(
        "/usr/bin/ditto",
        arguments: ["-c", "-k", "--keepParent", "Payload", outputPath],
        currentDirectory: parentDir
      )

      // Clean up temp directory
      try? FileManager.default.removeItem(at: parentDir)

      // Verify .ipa was created
      guard FileManager.default.fileExists(atPath: outputPath) else {
        return encodeJSON(ArchiveResult(
          success: false,
          ipaPath: nil,
          appPath: appPath,
          exportMethod: exportMethod,
          signingInfo: nil,
          message: "Failed to create .ipa: \(zipOutput)"
        ))
      }

      // Get .ipa file size
      let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64) ?? 0

      return encodeJSON(ArchiveResult(
        success: true,
        ipaPath: outputPath,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: ArchiveSigningInfo(
          identity: identity.name,
          teamId: profile.teamId,
          profile: profile.name,
          bundleId: bundleId
        ),
        message: "Created \(appName).ipa (\(formatBytes(fileSize)))",
        fileSize: fileSize
      ))
    } catch {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "Failed to create .ipa: \(error.localizedDescription)"
      ))
    }
  }

  struct ArchiveResult: Codable {
    let success: Bool
    let ipaPath: String?
    let appPath: String?
    let exportMethod: String
    let signingInfo: ArchiveSigningInfo?
    let message: String
    var fileSize: Int64?
  }

  struct ArchiveSigningInfo: Codable {
    let identity: String
    let teamId: String
    let profile: String
    let bundleId: String
  }

  private static func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  private static func runCommand(
    _ command: String,
    arguments: [String],
    currentDirectory: URL
  ) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectory

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }

  // MARK: - Validate

  static func validate(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let strict = arguments["strict"] as? Bool ?? false

    var issues: [ValidationIssue] = []
    var appPath: String?
    var bundleId: String?
    var version: String?

    // Determine if path is .ipa or .app or project directory
    if pathStr.hasSuffix(".ipa") {
      // Extract .ipa to temp directory for validation
      let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("xclaude-validate-\(UUID().uuidString)")

      do {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Unzip .ipa
        _ = try await runCommand("/usr/bin/unzip", arguments: ["-q", pathStr, "-d", tempDir.path], currentDirectory: tempDir)

        // Find .app in Payload
        let payloadDir = tempDir.appendingPathComponent("Payload")
        let contents = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
        if let app = contents.first(where: { $0.pathExtension == "app" }) {
          appPath = app.path
        }
      } catch {
        issues.append(ValidationIssue(
          code: "IPA_EXTRACT_FAILED",
          severity: "error",
          message: "Failed to extract .ipa: \(error.localizedDescription)",
          fixable: false
        ))
      }
    } else if pathStr.hasSuffix(".app") {
      appPath = pathStr
    } else {
      // Assume project directory - look for built app
      let projectURL = URL(fileURLWithPath: pathStr)
      let productsDir = projectURL.appendingPathComponent(".build").appendingPathComponent("products")

      // Find any .app in products
      if let enumerator = FileManager.default.enumerator(at: productsDir, includingPropertiesForKeys: nil) {
        while let url = enumerator.nextObject() as? URL {
          if url.pathExtension == "app" {
            appPath = url.path
            break
          }
        }
      }

      if appPath == nil {
        issues.append(ValidationIssue(
          code: "NO_APP_FOUND",
          severity: "error",
          message: "No .app bundle found. Run 'build' first.",
          fixable: true
        ))
      }
    }

    // If we have an app path, validate it
    if let appPath = appPath {
      let appURL = URL(fileURLWithPath: appPath)

      // 1. Check Info.plist exists and is valid
      let infoPlistPath = appURL.appendingPathComponent("Info.plist")
      if FileManager.default.fileExists(atPath: infoPlistPath.path) {
        if let plistData = try? Data(contentsOf: infoPlistPath),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {

          bundleId = plist["CFBundleIdentifier"] as? String
          version = plist["CFBundleShortVersionString"] as? String
          let buildNumber = plist["CFBundleVersion"] as? String

          // Check required keys
          if bundleId == nil {
            issues.append(ValidationIssue(
              code: "MISSING_BUNDLE_ID",
              severity: "error",
              message: "CFBundleIdentifier is missing from Info.plist",
              fixable: false
            ))
          }

          if version == nil {
            issues.append(ValidationIssue(
              code: "MISSING_VERSION",
              severity: "error",
              message: "CFBundleShortVersionString is missing from Info.plist",
              fixable: true
            ))
          }

          if buildNumber == nil {
            issues.append(ValidationIssue(
              code: "MISSING_BUILD_NUMBER",
              severity: "error",
              message: "CFBundleVersion is missing from Info.plist",
              fixable: true
            ))
          }

          // Check bundle ID format
          if let bid = bundleId, !bid.contains(".") || bid.contains(" ") {
            issues.append(ValidationIssue(
              code: "INVALID_BUNDLE_ID",
              severity: "error",
              message: "Bundle ID '\(bid)' is invalid. Use reverse-DNS format (e.g., com.company.app)",
              fixable: true
            ))
          }

          // Check for required iOS keys
          let uiDeviceFamily = plist["UIDeviceFamily"] as? [Int]
          if uiDeviceFamily == nil || uiDeviceFamily!.isEmpty {
            issues.append(ValidationIssue(
              code: "MISSING_DEVICE_FAMILY",
              severity: "warning",
              message: "UIDeviceFamily not specified in Info.plist",
              fixable: true
            ))
          }

          // Check for launch storyboard or screen
          let launchStoryboard = plist["UILaunchStoryboardName"] as? String
          let launchImages = plist["UILaunchImages"] as? [[String: Any]]
          if launchStoryboard == nil && (launchImages == nil || launchImages!.isEmpty) {
            issues.append(ValidationIssue(
              code: "MISSING_LAUNCH_SCREEN",
              severity: "warning",
              message: "No launch storyboard or launch images specified",
              fixable: true
            ))
          }

        } else {
          issues.append(ValidationIssue(
            code: "INVALID_PLIST",
            severity: "error",
            message: "Info.plist is invalid or corrupted",
            fixable: false
          ))
        }
      } else {
        issues.append(ValidationIssue(
          code: "MISSING_PLIST",
          severity: "error",
          message: "Info.plist not found in app bundle",
          fixable: false
        ))
      }

      // 2. Check for icon
      let hasIcon = FileManager.default.fileExists(atPath: appURL.appendingPathComponent("AppIcon60x60@2x.png").path) ||
                    FileManager.default.fileExists(atPath: appURL.appendingPathComponent("Assets.car").path)

      if !hasIcon {
        issues.append(ValidationIssue(
          code: "MISSING_ICON",
          severity: "error",
          message: "No app icon found in bundle",
          fixable: true
        ))
      }

      // 3. Check code signature
      let codesignOutput = try? await runCommand("/usr/bin/codesign", arguments: ["-v", "--strict", appPath])
      if let output = codesignOutput, output.contains("invalid") || output.contains("not signed") {
        issues.append(ValidationIssue(
          code: "INVALID_SIGNATURE",
          severity: "error",
          message: "App is not properly signed: \(output)",
          fixable: false
        ))
      }

      // 4. Check for executable
      let appName = appURL.deletingPathExtension().lastPathComponent
      let executablePath = appURL.appendingPathComponent(appName)
      if !FileManager.default.fileExists(atPath: executablePath.path) {
        issues.append(ValidationIssue(
          code: "MISSING_EXECUTABLE",
          severity: "error",
          message: "No executable found at expected path: \(appName)",
          fixable: false
        ))
      }

      // 5. Check for embedded provisioning profile (required for distribution)
      let embeddedProfile = appURL.appendingPathComponent("embedded.mobileprovision")
      if !FileManager.default.fileExists(atPath: embeddedProfile.path) {
        issues.append(ValidationIssue(
          code: "MISSING_PROVISIONING",
          severity: "warning",
          message: "No embedded.mobileprovision found (required for device/App Store)",
          fixable: false
        ))
      }
    }

    // Calculate result
    let errors = issues.filter { $0.severity == "error" }
    let warnings = issues.filter { $0.severity == "warning" }

    let isValid = errors.isEmpty && (!strict || warnings.isEmpty)

    return encodeJSON(ValidationResult(
      valid: isValid,
      appPath: appPath,
      bundleId: bundleId,
      version: version,
      errorCount: errors.count,
      warningCount: warnings.count,
      issues: issues,
      message: isValid ? "Validation passed" : "Validation failed with \(errors.count) error(s)"
    ))
  }

  struct ValidationResult: Codable {
    let valid: Bool
    let appPath: String?
    let bundleId: String?
    let version: String?
    let errorCount: Int
    let warningCount: Int
    let issues: [ValidationIssue]
    let message: String
  }

  struct ValidationIssue: Codable {
    let code: String
    let severity: String
    let message: String
    let fixable: Bool
  }

  // MARK: - Upload

  static func upload(arguments: [String: Any]) async throws -> String {
    guard let pathStr = arguments["path"] as? String else {
      return encodeJSON(UploadResult(
        success: false,
        message: "Path to .ipa is required",
        uploadId: nil
      ))
    }

    // Verify file exists
    guard FileManager.default.fileExists(atPath: pathStr) else {
      return encodeJSON(UploadResult(
        success: false,
        message: "File not found: \(pathStr)",
        uploadId: nil
      ))
    }

    // Determine authentication method
    let apiKey = arguments["api_key"] as? String
    let apiKeyId = arguments["api_key_id"] as? String
    let apiIssuer = arguments["api_issuer"] as? String
    let appleId = arguments["apple_id"] as? String
    let password = arguments["password"] as? String

    var uploadArgs: [String]

    if let apiKey = apiKey, let apiKeyId = apiKeyId, let apiIssuer = apiIssuer {
      // API Key authentication (preferred)
      uploadArgs = [
        "altool", "--upload-app",
        "-f", pathStr,
        "-t", "ios",
        "--apiKey", apiKeyId,
        "--apiIssuer", apiIssuer
      ]

      // If api_key is a path, we need to put it in the right location
      // App Store Connect API keys should be in ~/private_keys/AuthKey_<ID>.p8
      let keyPath = URL(fileURLWithPath: apiKey)
      let expectedPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("private_keys")
        .appendingPathComponent("AuthKey_\(apiKeyId).p8")

      if !FileManager.default.fileExists(atPath: expectedPath.path) {
        // Copy key to expected location
        do {
          try FileManager.default.createDirectory(
            at: expectedPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
          )
          try FileManager.default.copyItem(at: keyPath, to: expectedPath)
        } catch {
          return encodeJSON(UploadResult(
            success: false,
            message: "Failed to copy API key to expected location: \(error.localizedDescription)",
            uploadId: nil
          ))
        }
      }
    } else if let appleId = appleId, let password = password {
      // Apple ID authentication
      uploadArgs = [
        "altool", "--upload-app",
        "-f", pathStr,
        "-t", "ios",
        "-u", appleId,
        "-p", password
      ]
    } else {
      return encodeJSON(UploadResult(
        success: false,
        message: "Authentication required. Provide either: (api_key + api_key_id + api_issuer) or (apple_id + password)",
        uploadId: nil
      ))
    }

    // Add verbose output
    uploadArgs.append("--output-format")
    uploadArgs.append("json")

    // Run upload
    let (exitCode, stdout, stderr) = try await runProcessWithStatus(
      "/usr/bin/xcrun",
      arguments: uploadArgs,
      currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    )

    let output = stdout + stderr

    if exitCode == 0 {
      // Try to parse upload ID from response
      var uploadId: String?
      if let data = stdout.data(using: .utf8),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let result = json["product-request-uuid"] as? String {
        uploadId = result
      }

      return encodeJSON(UploadResult(
        success: true,
        message: "Upload successful! Your app is being processed by App Store Connect.",
        uploadId: uploadId
      ))
    } else {
      // Parse error message
      var errorMessage = "Upload failed"

      if output.contains("Unable to authenticate") {
        errorMessage = "Authentication failed. Check your credentials."
      } else if output.contains("The bundle identifier") {
        errorMessage = "Bundle ID not registered in App Store Connect. Create the app first."
      } else if output.contains("already exists") {
        errorMessage = "This version already exists. Increment the build number."
      } else if !output.isEmpty {
        errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
      }

      return encodeJSON(UploadResult(
        success: false,
        message: errorMessage,
        uploadId: nil
      ))
    }
  }

  struct UploadResult: Codable {
    let success: Bool
    let message: String
    let uploadId: String?
  }

  // MARK: - Watch Mode

  // Global state for file watcher
  private static var watcherTask: Task<Void, Never>?
  private static var isWatching = false

  static func watch(arguments: [String: Any]) async throws -> String {
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let platformStr = arguments["platform"] as? String ?? "iOSSimulator"
    let targetStr = arguments["target"] as? String ?? "simulator"
    let interval = arguments["interval"] as? Double ?? 2.0
    let projectURL = URL(fileURLWithPath: pathStr)

    // Stop any existing watcher
    if isWatching {
      watcherTask?.cancel()
      watcherTask = nil
    }

    // Get initial file modification times
    var lastModTimes = getSourceFileModTimes(in: projectURL)
    isWatching = true

    // Return immediately with status - the watcher runs in background
    // Note: In a real MCP scenario, this would use streaming or notifications
    // For now, we'll do one build and set up watching state

    // Do initial build
    let buildResult = try await BuildRunner.build(
      projectDirectory: projectURL,
      platform: BuildRunner.Platform(rawValue: platformStr) ?? .iOSSimulator,
      configuration: .debug
    )

    guard buildResult.success, let appPath = buildResult.appPath else {
      isWatching = false
      return encodeJSON(WatchResult(
        success: false,
        message: "Initial build failed: \(buildResult.errors.first?.message ?? "Unknown error")",
        watching: false,
        rebuilds: 0
      ))
    }

    // Deploy initial build
    let config = try? XClaudeConfig.load(from: projectURL)
    let bundleId = config?.app.bundleId ?? "com.xclaude.app"
    let target = DeployRunner.Target.parse(targetStr)

    _ = try? await DeployRunner.deployToSimulator(
      appPath: appPath,
      bundleId: bundleId,
      target: target,
      launch: true
    )

    // Start background watcher
    watcherTask = Task {
      var rebuildCount = 0

      while !Task.isCancelled && isWatching {
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

        if Task.isCancelled { break }

        // Check for file changes
        let currentModTimes = getSourceFileModTimes(in: projectURL)
        let changedFiles = findChangedFiles(old: lastModTimes, new: currentModTimes)

        if !changedFiles.isEmpty {
          lastModTimes = currentModTimes
          rebuildCount += 1

          // Rebuild
          if let result = try? await BuildRunner.build(
            projectDirectory: projectURL,
            platform: BuildRunner.Platform(rawValue: platformStr) ?? .iOSSimulator,
            configuration: .debug
          ), result.success, let newAppPath = result.appPath {
            // Redeploy
            _ = try? await DeployRunner.deployToSimulator(
              appPath: newAppPath,
              bundleId: bundleId,
              target: target,
              launch: true
            )
          }
        }
      }
    }

    return encodeJSON(WatchResult(
      success: true,
      message: "Watching for changes. Rebuild on save. Call stop_watch to stop.",
      watching: true,
      rebuilds: 0,
      watchedPath: pathStr,
      platform: platformStr,
      interval: interval
    ))
  }

  static func stopWatch() async throws -> String {
    if isWatching {
      watcherTask?.cancel()
      watcherTask = nil
      isWatching = false
      return encodeJSON(WatchResult(
        success: true,
        message: "File watcher stopped",
        watching: false,
        rebuilds: 0
      ))
    } else {
      return encodeJSON(WatchResult(
        success: true,
        message: "No watcher was running",
        watching: false,
        rebuilds: 0
      ))
    }
  }

  private static func getSourceFileModTimes(in directory: URL) -> [String: Date] {
    var modTimes: [String: Date] = [:]

    let sourcesDir = directory.appendingPathComponent("Sources")
    guard let enumerator = FileManager.default.enumerator(
      at: sourcesDir,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return modTimes
    }

    while let url = enumerator.nextObject() as? URL {
      if url.pathExtension == "swift" {
        if let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
          modTimes[url.path] = modDate
        }
      }
    }

    return modTimes
  }

  private static func findChangedFiles(old: [String: Date], new: [String: Date]) -> [String] {
    var changed: [String] = []

    for (path, newDate) in new {
      if let oldDate = old[path] {
        if newDate > oldDate {
          changed.append(path)
        }
      } else {
        // New file
        changed.append(path)
      }
    }

    return changed
  }

  struct WatchResult: Codable {
    let success: Bool
    let message: String
    let watching: Bool
    let rebuilds: Int
    var watchedPath: String?
    var platform: String?
    var interval: Double?
  }

  // MARK: - SwiftData Model Scaffolding

  static func addModel(arguments: [String: Any]) async throws -> String {
    guard let modelName = arguments["name"] as? String else {
      return encodeJSON(ModelResult(
        success: false,
        message: "Model name is required",
        filePath: nil
      ))
    }

    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let properties = arguments["properties"] as? [String] ?? []
    let projectURL = URL(fileURLWithPath: pathStr)

    // Get app name from config or directory
    let config = try? XClaudeConfig.load(from: projectURL)
    let appName = config?.app.name ?? projectURL.lastPathComponent

    // Create Models directory if needed
    let modelsDir = projectURL
      .appendingPathComponent("Sources")
      .appendingPathComponent(appName)
      .appendingPathComponent("Models")

    try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

    // Parse properties
    var propertyLines: [String] = []
    var initParams: [String] = []
    var initAssignments: [String] = []

    for prop in properties {
      let parts = prop.split(separator: ":", maxSplits: 1)
      guard parts.count == 2 else { continue }

      let propName = String(parts[0]).trimmingCharacters(in: .whitespaces)
      var propType = String(parts[1]).trimmingCharacters(in: .whitespaces)

      // Handle optional types
      let isOptional = propType.hasSuffix("?")
      if isOptional {
        propType = String(propType.dropLast())
      }

      // Add @Attribute for special cases
      var attribute = ""
      if propType == "Data" {
        attribute = "  @Attribute(.externalStorage) "
      } else if propName.lowercased() == "id" || propName.lowercased().hasSuffix("id") {
        attribute = "  @Attribute(.unique) "
      }

      let typeDecl = isOptional ? "\(propType)?" : propType
      propertyLines.append("\(attribute)var \(propName): \(typeDecl)")

      // Build init
      let defaultValue = isOptional ? " = nil" : ""
      initParams.append("\(propName): \(typeDecl)\(defaultValue)")
      initAssignments.append("    self.\(propName) = \(propName)")
    }

    // Generate the model file
    let modelCode = """
    import Foundation
    import SwiftData

    @Model
    final class \(modelName) {
      \(propertyLines.joined(separator: "\n  "))

      init(\(initParams.joined(separator: ", "))) {
    \(initAssignments.joined(separator: "\n"))
      }
    }
    """

    // Write the file
    let filePath = modelsDir.appendingPathComponent("\(modelName).swift")

    do {
      try modelCode.write(to: filePath, atomically: true, encoding: .utf8)
      return encodeJSON(ModelResult(
        success: true,
        message: "Created SwiftData model '\(modelName)' with \(properties.count) properties",
        filePath: filePath.path,
        modelName: modelName,
        properties: properties
      ))
    } catch {
      return encodeJSON(ModelResult(
        success: false,
        message: "Failed to write model file: \(error.localizedDescription)",
        filePath: nil
      ))
    }
  }

  struct ModelResult: Codable {
    let success: Bool
    let message: String
    let filePath: String?
    var modelName: String?
    var properties: [String]?
  }

  // MARK: - App Extension

  static func addExtension(arguments: [String: Any]) async throws -> String {
    guard let extensionType = arguments["type"] as? String else {
      return encodeJSON(ExtensionResult(
        success: false,
        message: "Extension type is required",
        files: []
      ))
    }

    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let projectURL = URL(fileURLWithPath: pathStr)

    // Get app name and bundle ID
    let config = try? XClaudeConfig.load(from: projectURL)
    let appName = config?.app.name ?? projectURL.lastPathComponent
    let bundleId = config?.app.bundleId ?? "com.example.\(appName.lowercased())"

    // Derive extension name
    let extensionName = arguments["name"] as? String ?? {
      switch extensionType {
      case "widget": return "\(appName)Widget"
      case "share": return "\(appName)Share"
      case "action": return "\(appName)Action"
      case "today": return "\(appName)Today"
      case "intents": return "\(appName)Intents"
      case "notification-content": return "\(appName)NotificationContent"
      case "notification-service": return "\(appName)NotificationService"
      default: return "\(appName)Extension"
      }
    }()

    let extensionBundleId = "\(bundleId).\(extensionName)"

    // Create extension directory
    let extensionDir = projectURL
      .appendingPathComponent("Sources")
      .appendingPathComponent(extensionName)

    try? FileManager.default.createDirectory(at: extensionDir, withIntermediateDirectories: true)

    var createdFiles: [String] = []

    // Generate extension-specific code
    switch extensionType {
    case "widget":
      let widgetCode = generateWidgetCode(extensionName: extensionName, appName: appName)
      let filePath = extensionDir.appendingPathComponent("\(extensionName).swift")
      try widgetCode.write(to: filePath, atomically: true, encoding: .utf8)
      createdFiles.append(filePath.path)

    case "share":
      let shareCode = generateShareExtensionCode(extensionName: extensionName)
      let filePath = extensionDir.appendingPathComponent("ShareViewController.swift")
      try shareCode.write(to: filePath, atomically: true, encoding: .utf8)
      createdFiles.append(filePath.path)

    case "intents":
      let intentsCode = generateIntentsCode(extensionName: extensionName)
      let filePath = extensionDir.appendingPathComponent("IntentHandler.swift")
      try intentsCode.write(to: filePath, atomically: true, encoding: .utf8)
      createdFiles.append(filePath.path)

    default:
      // Generic extension template
      let genericCode = generateGenericExtensionCode(extensionName: extensionName, extensionType: extensionType)
      let filePath = extensionDir.appendingPathComponent("\(extensionName).swift")
      try genericCode.write(to: filePath, atomically: true, encoding: .utf8)
      createdFiles.append(filePath.path)
    }

    // Update Package.swift to add extension target
    let packagePath = projectURL.appendingPathComponent("Package.swift")
    if var packageContent = try? String(contentsOf: packagePath, encoding: .utf8) {
      // Add extension target
      let extensionTarget = """
          .executableTarget(
            name: "\(extensionName)",
            path: "Sources/\(extensionName)"
          ),
      """

      // Find targets array and add extension
      if let targetsRange = packageContent.range(of: "targets:\\s*\\[", options: .regularExpression) {
        let insertPoint = packageContent.index(after: packageContent.range(of: "[", range: targetsRange)!.lowerBound)
        packageContent.insert(contentsOf: "\n    \(extensionTarget)", at: insertPoint)
        try? packageContent.write(to: packagePath, atomically: true, encoding: .utf8)
      }
    }

    return encodeJSON(ExtensionResult(
      success: true,
      message: "Created \(extensionType) extension '\(extensionName)'",
      files: createdFiles,
      extensionName: extensionName,
      extensionBundleId: extensionBundleId,
      extensionType: extensionType
    ))
  }

  private static func generateWidgetCode(extensionName: String, appName: String) -> String {
    return """
    import WidgetKit
    import SwiftUI

    struct \(extensionName)Entry: TimelineEntry {
      let date: Date
      let message: String
    }

    struct \(extensionName)Provider: TimelineProvider {
      func placeholder(in context: Context) -> \(extensionName)Entry {
        \(extensionName)Entry(date: Date(), message: "Placeholder")
      }

      func getSnapshot(in context: Context, completion: @escaping (\(extensionName)Entry) -> Void) {
        let entry = \(extensionName)Entry(date: Date(), message: "Snapshot")
        completion(entry)
      }

      func getTimeline(in context: Context, completion: @escaping (Timeline<\(extensionName)Entry>) -> Void) {
        let entry = \(extensionName)Entry(date: Date(), message: "Hello from \(appName)!")
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
      }
    }

    struct \(extensionName)EntryView: View {
      var entry: \(extensionName)Provider.Entry

      var body: some View {
        VStack {
          Text(entry.message)
            .font(.headline)
          Text(entry.date, style: .time)
            .font(.caption)
        }
        .containerBackground(.fill.tertiary, for: .widget)
      }
    }

    @main
    struct \(extensionName): Widget {
      let kind: String = "\(extensionName)"

      var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: \(extensionName)Provider()) { entry in
          \(extensionName)EntryView(entry: entry)
        }
        .configurationDisplayName("\(appName) Widget")
        .description("A widget for \(appName).")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
      }
    }
    """
  }

  private static func generateShareExtensionCode(extensionName: String) -> String {
    return """
    import UIKit
    import Social

    class ShareViewController: SLComposeServiceViewController {
      override func isContentValid() -> Bool {
        return true
      }

      override func didSelectPost() {
        // Handle the shared content
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
          if let attachments = item.attachments {
            for attachment in attachments {
              // Process attachments
              print("Received attachment: \\(attachment)")
            }
          }
        }

        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      }

      override func configurationItems() -> [Any]! {
        return []
      }
    }
    """
  }

  private static func generateIntentsCode(extensionName: String) -> String {
    return """
    import Intents

    class IntentHandler: INExtension {
      override func handler(for intent: INIntent) -> Any {
        // Return the handler for the specific intent
        return self
      }
    }
    """
  }

  private static func generateGenericExtensionCode(extensionName: String, extensionType: String) -> String {
    return """
    import Foundation

    // \(extensionType) Extension: \(extensionName)
    // Add your extension implementation here

    @main
    struct \(extensionName) {
      static func main() {
        print("\(extensionName) started")
      }
    }
    """
  }

  struct ExtensionResult: Codable {
    let success: Bool
    let message: String
    let files: [String]
    var extensionName: String?
    var extensionBundleId: String?
    var extensionType: String?
  }

  // MARK: - API Client Generation

  static func generateAPIClient(arguments: [String: Any]) async throws -> String {
    guard let specPath = arguments["spec"] as? String else {
      return encodeJSON(APIClientResult(
        success: false,
        message: "OpenAPI spec path is required",
        files: []
      ))
    }

    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let clientName = arguments["name"] as? String ?? "APIClient"
    let projectURL = URL(fileURLWithPath: pathStr)

    // Get app name
    let config = try? XClaudeConfig.load(from: projectURL)
    let appName = config?.app.name ?? projectURL.lastPathComponent

    // Load OpenAPI spec
    let specContent: String
    if specPath.hasPrefix("http://") || specPath.hasPrefix("https://") {
      // Fetch from URL
      guard let url = URL(string: specPath),
            let data = try? Data(contentsOf: url),
            let content = String(data: data, encoding: .utf8) else {
        return encodeJSON(APIClientResult(
          success: false,
          message: "Failed to fetch OpenAPI spec from URL",
          files: []
        ))
      }
      specContent = content
    } else {
      // Read from file
      let specURL = URL(fileURLWithPath: specPath)
      guard let content = try? String(contentsOf: specURL, encoding: .utf8) else {
        return encodeJSON(APIClientResult(
          success: false,
          message: "Failed to read OpenAPI spec file",
          files: []
        ))
      }
      specContent = content
    }

    // Parse spec (basic JSON parsing)
    guard let specData = specContent.data(using: .utf8),
          let spec = try? JSONSerialization.jsonObject(with: specData) as? [String: Any] else {
      return encodeJSON(APIClientResult(
        success: false,
        message: "Failed to parse OpenAPI spec as JSON. YAML support requires additional dependencies.",
        files: []
      ))
    }

    // Extract info
    let info = spec["info"] as? [String: Any] ?? [:]
    let title = info["title"] as? String ?? "API"
    let servers = spec["servers"] as? [[String: Any]] ?? []
    let baseURL = (servers.first?["url"] as? String) ?? "https://api.example.com"
    let paths = spec["paths"] as? [String: [String: Any]] ?? [:]
    let schemas = (spec["components"] as? [String: Any])?["schemas"] as? [String: Any] ?? [:]

    // Create Network directory
    let networkDir = projectURL
      .appendingPathComponent("Sources")
      .appendingPathComponent(appName)
      .appendingPathComponent("Network")

    try? FileManager.default.createDirectory(at: networkDir, withIntermediateDirectories: true)

    var createdFiles: [String] = []
    var endpoints: [(method: String, path: String, operationId: String, summary: String)] = []

    // Extract endpoints
    for (path, methods) in paths {
      for (method, details) in methods {
        guard let detailsDict = details as? [String: Any] else { continue }
        let operationId = detailsDict["operationId"] as? String ?? "\(method)\(path.replacingOccurrences(of: "/", with: "_"))"
        let summary = detailsDict["summary"] as? String ?? ""
        endpoints.append((method: method.uppercased(), path: path, operationId: operationId, summary: summary))
      }
    }

    // Generate API client
    let clientCode = generateAPIClientCode(
      clientName: clientName,
      baseURL: baseURL,
      title: title,
      endpoints: endpoints
    )

    let clientPath = networkDir.appendingPathComponent("\(clientName).swift")
    try clientCode.write(to: clientPath, atomically: true, encoding: .utf8)
    createdFiles.append(clientPath.path)

    // Generate model types from schemas
    for (schemaName, schemaDetails) in schemas {
      guard let schemaDict = schemaDetails as? [String: Any] else { continue }
      let modelCode = generateModelFromSchema(name: schemaName, schema: schemaDict)
      let modelPath = networkDir.appendingPathComponent("\(schemaName).swift")
      try modelCode.write(to: modelPath, atomically: true, encoding: .utf8)
      createdFiles.append(modelPath.path)
    }

    return encodeJSON(APIClientResult(
      success: true,
      message: "Generated API client '\(clientName)' with \(endpoints.count) endpoints and \(schemas.count) models",
      files: createdFiles,
      clientName: clientName,
      baseURL: baseURL,
      endpointCount: endpoints.count,
      modelCount: schemas.count
    ))
  }

  private static func generateAPIClientCode(
    clientName: String,
    baseURL: String,
    title: String,
    endpoints: [(method: String, path: String, operationId: String, summary: String)]
  ) -> String {
    var methodsCode = ""

    for endpoint in endpoints {
      let funcName = endpoint.operationId.prefix(1).lowercased() + endpoint.operationId.dropFirst()
      let comment = endpoint.summary.isEmpty ? "" : "  /// \(endpoint.summary)\n"

      methodsCode += """

      \(comment)  func \(funcName)() async throws -> Data {
          let url = baseURL.appendingPathComponent("\(endpoint.path)")
          var request = URLRequest(url: url)
          request.httpMethod = "\(endpoint.method)"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          let (data, response) = try await session.data(for: request)

          guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
          }

          return data
        }

      """
    }

    return """
    import Foundation

    /// Generated API client for \(title)
    /// Base URL: \(baseURL)
    class \(clientName) {
      static let shared = \(clientName)()

      private let baseURL: URL
      private let session: URLSession

      enum APIError: Error {
        case invalidURL
        case requestFailed
        case decodingFailed
      }

      init(baseURL: URL = URL(string: "\(baseURL)")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
      }
    \(methodsCode)
    }
    """
  }

  private static func generateModelFromSchema(name: String, schema: [String: Any]) -> String {
    let type = schema["type"] as? String ?? "object"
    let properties = schema["properties"] as? [String: Any] ?? [:]
    let required = schema["required"] as? [String] ?? []

    var propertyLines: [String] = []

    for (propName, propDetails) in properties {
      guard let propDict = propDetails as? [String: Any] else { continue }
      let propType = schemaTypeToSwift(propDict)
      let isRequired = required.contains(propName)
      let typeDecl = isRequired ? propType : "\(propType)?"

      propertyLines.append("  let \(propName): \(typeDecl)")
    }

    return """
    import Foundation

    /// Generated from OpenAPI schema
    struct \(name): Codable {
    \(propertyLines.joined(separator: "\n"))
    }
    """
  }

  private static func schemaTypeToSwift(_ schema: [String: Any]) -> String {
    let type = schema["type"] as? String ?? "any"
    let format = schema["format"] as? String

    switch type {
    case "string":
      if format == "date-time" { return "Date" }
      if format == "date" { return "Date" }
      if format == "uuid" { return "UUID" }
      return "String"
    case "integer":
      if format == "int64" { return "Int64" }
      return "Int"
    case "number":
      if format == "float" { return "Float" }
      return "Double"
    case "boolean":
      return "Bool"
    case "array":
      if let items = schema["items"] as? [String: Any] {
        return "[\(schemaTypeToSwift(items))]"
      }
      return "[Any]"
    case "object":
      return "[String: Any]"
    default:
      return "Any"
    }
  }

  struct APIClientResult: Codable {
    let success: Bool
    let message: String
    let files: [String]
    var clientName: String?
    var baseURL: String?
    var endpointCount: Int?
    var modelCount: Int?
  }

  // Helper to run process and get exit code
  private static func runProcessWithStatus(
    _ executable: String,
    arguments: [String],
    currentDirectory: URL
  ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectory

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    return (
      process.terminationStatus,
      String(data: stdoutData, encoding: .utf8) ?? "",
      String(data: stderrData, encoding: .utf8) ?? ""
    )
  }

  // MARK: - Response Types

  struct SimulatorInfo: Codable {
    let name: String
    let udid: String
    let state: String
    let platform: String
    let version: String
  }

  struct DeviceInfo: Codable {
    let name: String
    let udid: String
    let platform: String
    let osVersion: String?
    let connectionType: String?
  }

  struct RunResult: Codable {
    let success: Bool
    let buildResult: BuildRunner.BuildResult
    let deployResult: DeployRunner.DeployResult?
  }

  struct InitResult: Codable {
    let success: Bool
    let message: String
    let configPath: String?
  }

  struct ResolvedConfig: Codable {
    let projectType: String
    let config: XClaudeConfig
    let signingStatus: SigningStatus?
  }

  // MARK: - Helpers

  static func encodeJSON<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    guard let data = try? encoder.encode(value),
          let string = String(data: data, encoding: .utf8) else {
      return "{\"error\": \"Failed to serialize result\"}"
    }
    return string
  }

  static func runCommand(_ command: String, arguments: [String]) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }
}

enum ToolError: Error {
  case missingArgument(String)
  case commandFailed(String)
}
