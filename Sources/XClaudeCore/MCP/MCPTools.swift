import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(AppKit)
import AppKit
#endif

/// MCP tool definitions and implementations
public enum MCPTools {
  /// Process start time (captured when module loads - changes on /mcp reconnect)
  private static let processStartTime: Date = Date()

  /// xclaude version
  public static let version = "3.8.0"

  /// Tool definition
  struct Tool {
    let name: String
    let description: String
    let inputSchema: [String: Any]
  }

  /// All available tools
  static let allTools: [Tool] = [
    Tool(
      name: "get_version",
      description: "Get xclaude version and build info. Use this to verify you're running the latest binary after /mcp reconnect.",
      inputSchema: [
        "type": "object",
        "properties": [:] as [String: Any],
        "required": [] as [String]
      ]
    ),
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
      name: "build_start",
      description: "Start a build in background. Returns immediately with job ID. Use build_logs to check progress.",
      inputSchema: [
        "type": "object",
        "properties": [
          "platform": [
            "type": "string",
            "description": "Target platform (iOS, iOSSimulator, macOS, etc.)",
            "default": "iOS"
          ],
          "configuration": [
            "type": "string",
            "description": "Build configuration (debug or release)",
            "default": "debug"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ],
          "clean": [
            "type": "boolean",
            "description": "Delete .build/ directory before building (clean build)",
            "default": false
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "build_status",
      description: "Check status of a build job. Returns running/success/failed status.",
      inputSchema: [
        "type": "object",
        "properties": [
          "job_id": [
            "type": "string",
            "description": "Build job ID (from build_start). If omitted, shows all recent jobs."
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "build_logs",
      description: "Read buffered build output. Non-blocking - returns immediately with available output.",
      inputSchema: [
        "type": "object",
        "properties": [
          "job_id": [
            "type": "string",
            "description": "Build job ID (from build_start)"
          ],
          "lines": [
            "type": "integer",
            "description": "Number of recent lines to return (default: all buffered)"
          ],
          "clear": [
            "type": "boolean",
            "description": "Clear buffer after reading (default: false)",
            "default": false
          ]
        ] as [String: Any],
        "required": ["job_id"] as [String]
      ]
    ),
    Tool(
      name: "build_cancel",
      description: "Cancel a running build job.",
      inputSchema: [
        "type": "object",
        "properties": [
          "job_id": [
            "type": "string",
            "description": "Build job ID to cancel"
          ]
        ] as [String: Any],
        "required": ["job_id"] as [String]
      ]
    ),
    Tool(
      name: "deploy",
      description: "Install an app to a device, simulator, or macOS (/Applications). Use target='macOS' for macOS, 'device' for iOS physical devices, 'simulator' for iOS Simulator.",
      inputSchema: [
        "type": "object",
        "properties": [
          "target": [
            "type": "string",
            "description": "Target: 'macOS' (install to /Applications), 'device' (iOS physical), 'simulator' (iOS Simulator), or UDID/name",
            "default": "device"
          ],
          "app_path": [
            "type": "string",
            "description": "Path to the .app bundle"
          ],
          "bundle_id": [
            "type": "string",
            "description": "App bundle identifier (for launching). Auto-detected from xclaude.toml if not provided."
          ],
          "launch": [
            "type": "boolean",
            "description": "Launch the app after installing",
            "default": true
          ]
        ] as [String: Any],
        "required": ["app_path"] as [String]
      ]
    ),
    Tool(
      name: "run",
      description: "Build and run an app directly from the build folder (not installed). Good for quick iteration on macOS and iOS Simulator. For permanent install, use build + deploy.",
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
      name: "remove_capability",
      description: "Remove an app capability from the project",
      inputSchema: [
        "type": "object",
        "properties": [
          "capability": [
            "type": "string",
            "description": "Capability name to remove (e.g. 'healthkit', 'push-notifications')"
          ],
          "path": [
            "type": "string",
            "description": "Path to the project directory"
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
      description: "Create a release build and package as .ipa for iOS distribution. IMPORTANT: For app-store/ad-hoc, requires 'Apple Distribution' certificate (NOT 'Developer ID Application' which is macOS-only).",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to the project directory"
          ],
          "export_method": [
            "type": "string",
            "description": "Distribution method: app-store (TestFlight/App Store, requires Apple Distribution cert), ad-hoc (direct install, requires Apple Distribution cert), development (testing), enterprise (in-house)",
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
      description: "Upload an app to App Store Connect. Auto-uses credentials from asc_configure if set, or provide them explicitly.",
      inputSchema: [
        "type": "object",
        "properties": [
          "path": [
            "type": "string",
            "description": "Path to .ipa file to upload"
          ],
          "profile": [
            "type": "string",
            "description": "ASC credential profile to use (default: 'default'). See asc_configure."
          ],
          "api_key": [
            "type": "string",
            "description": "Path to App Store Connect API key (.p8 file). Optional if asc_configure was used."
          ],
          "api_key_id": [
            "type": "string",
            "description": "App Store Connect API Key ID. Optional if asc_configure was used."
          ],
          "api_issuer": [
            "type": "string",
            "description": "App Store Connect API Issuer ID. Optional if asc_configure was used."
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
    // App Store Connect API tools
    Tool(
      name: "asc_configure",
      description: "Configure App Store Connect API credentials. Get these from App Store Connect → Users and Access → Keys. Use 'profile' to save multiple accounts (e.g., 'personal', 'work').",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Profile name to save credentials under (e.g., 'personal', 'work'). Defaults to 'default'"
          ],
          "issuer_id": [
            "type": "string",
            "description": "Issuer ID from App Store Connect"
          ],
          "key_id": [
            "type": "string",
            "description": "API Key ID (optional - auto-extracted from AuthKey_XXXXX.p8 filename)"
          ],
          "key_path": [
            "type": "string",
            "description": "Path to the .p8 private key file"
          ]
        ] as [String: Any],
        "required": ["issuer_id", "key_path"] as [String]
      ]
    ),
    Tool(
      name: "asc_status",
      description: "Check App Store Connect API configuration status and test the connection. Shows all configured profiles if no profile specified.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Profile name to check (shows all profiles if omitted)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "asc_list_devices",
      description: "List devices registered in App Store Connect. Useful to check if a device is already registered before attempting to register it.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "platform": [
            "type": "string",
            "description": "Filter by platform (IOS, MAC_OS, etc.)"
          ],
          "status": [
            "type": "string",
            "description": "Filter by status (ENABLED, DISABLED)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "asc_register_device",
      description: "Register a new device in App Store Connect. Use list_devices first to get the UDID. After registering, you'll need to regenerate provisioning profiles to include the new device.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "name": [
            "type": "string",
            "description": "Device name (e.g., 'John's iPhone 15 Pro')"
          ],
          "udid": [
            "type": "string",
            "description": "Device UDID (hardware identifier, not CoreDevice UUID)"
          ],
          "platform": [
            "type": "string",
            "description": "Platform (IOS, MAC_OS). Defaults to IOS"
          ]
        ] as [String: Any],
        "required": ["name", "udid"] as [String]
      ]
    ),
    Tool(
      name: "asc_list_profiles",
      description: "List provisioning profiles in App Store Connect. Shows profile name, type, state, and expiration.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "profile_type": [
            "type": "string",
            "description": "Filter by type: IOS_APP_DEVELOPMENT, IOS_APP_ADHOC, IOS_APP_STORE, MAC_APP_DEVELOPMENT, MAC_APP_STORE, MAC_APP_DIRECT"
          ],
          "bundle_id": [
            "type": "string",
            "description": "Filter by bundle identifier (e.g., 'com.example.myapp')"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "asc_create_profile",
      description: "Create a new provisioning profile. For development profiles, includes all registered devices. Use this to regenerate a profile with new devices.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "name": [
            "type": "string",
            "description": "Profile name (e.g., 'MyApp Development')"
          ],
          "bundle_id": [
            "type": "string",
            "description": "Bundle identifier (e.g., 'com.example.myapp')"
          ],
          "profile_type": [
            "type": "string",
            "description": "Profile type: IOS_APP_DEVELOPMENT, IOS_APP_ADHOC, IOS_APP_STORE. Defaults to IOS_APP_DEVELOPMENT"
          ]
        ] as [String: Any],
        "required": ["name", "bundle_id"] as [String]
      ]
    ),
    Tool(
      name: "asc_delete_profile",
      description: "Delete a provisioning profile by ID. Use asc_list_profiles to find the ID.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "profile_id": [
            "type": "string",
            "description": "Profile ID from asc_list_profiles"
          ]
        ] as [String: Any],
        "required": ["profile_id"] as [String]
      ]
    ),
    Tool(
      name: "asc_download_profile",
      description: "Download a provisioning profile to a file. Automatically installs to ~/Library/MobileDevice/Provisioning Profiles/ if no path specified.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "profile_id": [
            "type": "string",
            "description": "Profile ID from asc_list_profiles"
          ],
          "output_path": [
            "type": "string",
            "description": "Optional output path. Defaults to ~/Library/MobileDevice/Provisioning Profiles/<uuid>.mobileprovision"
          ]
        ] as [String: Any],
        "required": ["profile_id"] as [String]
      ]
    ),
    Tool(
      name: "asc_regenerate_profile",
      description: "Regenerate a provisioning profile with all current devices. Deletes the old profile and creates a new one with the same settings but including all registered devices.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "bundle_id": [
            "type": "string",
            "description": "Bundle identifier (e.g., 'com.example.myapp')"
          ],
          "profile_type": [
            "type": "string",
            "description": "Profile type: IOS_APP_DEVELOPMENT, IOS_APP_ADHOC. Defaults to IOS_APP_DEVELOPMENT"
          ]
        ] as [String: Any],
        "required": ["bundle_id"] as [String]
      ]
    ),
    // Certificate tools
    Tool(
      name: "asc_list_certificates",
      description: "List certificates in App Store Connect. Shows certificate type, name, expiration, and ID.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "certificate_type": [
            "type": "string",
            "description": "Filter by type: IOS_DEVELOPMENT, IOS_DISTRIBUTION, DEVELOPMENT, DISTRIBUTION, DEVELOPER_ID_APPLICATION, DEVELOPER_ID_KEXT, MAC_APP_DEVELOPMENT, MAC_APP_DISTRIBUTION"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "asc_create_certificate",
      description: "Create a new signing certificate. Generates a CSR, submits to Apple, downloads the certificate, and installs to keychain. For iOS App Store/TestFlight, use type 'DISTRIBUTION'. For development, use 'DEVELOPMENT'.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "certificate_type": [
            "type": "string",
            "description": "Certificate type: DISTRIBUTION (for App Store/TestFlight), DEVELOPMENT (for dev builds), DEVELOPER_ID_APPLICATION (macOS direct distribution)",
            "enum": ["DISTRIBUTION", "DEVELOPMENT", "DEVELOPER_ID_APPLICATION", "DEVELOPER_ID_KEXT", "IOS_DEVELOPMENT", "IOS_DISTRIBUTION", "MAC_APP_DEVELOPMENT", "MAC_APP_DISTRIBUTION"]
          ],
          "common_name": [
            "type": "string",
            "description": "Common name for the certificate (e.g., your name or company name). Defaults to current user."
          ]
        ] as [String: Any],
        "required": ["certificate_type"] as [String]
      ]
    ),
    Tool(
      name: "asc_revoke_certificate",
      description: "Revoke (delete) a certificate by ID. Use asc_list_certificates to find the ID. WARNING: This invalidates any apps signed with this certificate.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "certificate_id": [
            "type": "string",
            "description": "Certificate ID from asc_list_certificates"
          ]
        ] as [String: Any],
        "required": ["certificate_id"] as [String]
      ]
    ),
    // TestFlight tools
    Tool(
      name: "asc_list_testers",
      description: "List beta testers for TestFlight. Can filter by app or beta group.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "app_id": [
            "type": "string",
            "description": "Filter testers by app ID (from apps list)"
          ],
          "group_id": [
            "type": "string",
            "description": "Filter testers by beta group ID"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "asc_add_tester",
      description: "Add a beta tester to TestFlight. Optionally add to specific beta groups.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "email": [
            "type": "string",
            "description": "Tester's email address"
          ],
          "first_name": [
            "type": "string",
            "description": "Tester's first name (optional)"
          ],
          "last_name": [
            "type": "string",
            "description": "Tester's last name (optional)"
          ],
          "group_ids": [
            "type": "array",
            "items": ["type": "string"],
            "description": "Beta group IDs to add tester to (optional)"
          ]
        ] as [String: Any],
        "required": ["email"] as [String]
      ]
    ),
    Tool(
      name: "asc_remove_tester",
      description: "Remove a beta tester from TestFlight by email.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "email": [
            "type": "string",
            "description": "Tester's email address to remove"
          ]
        ] as [String: Any],
        "required": ["email"] as [String]
      ]
    ),
    Tool(
      name: "asc_list_groups",
      description: "List beta groups for TestFlight. Shows internal and external groups.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "app_id": [
            "type": "string",
            "description": "Filter by app ID (optional)"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "asc_list_builds",
      description: "List recent builds uploaded to App Store Connect.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "app_id": [
            "type": "string",
            "description": "App ID to list builds for (required)"
          ],
          "limit": [
            "type": "integer",
            "description": "Number of builds to return (default: 10)"
          ]
        ] as [String: Any],
        "required": ["app_id"] as [String]
      ]
    ),
    Tool(
      name: "asc_set_whats_new",
      description: "Set the 'What's New' text for a TestFlight build.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "build_id": [
            "type": "string",
            "description": "Build ID to update"
          ],
          "whats_new": [
            "type": "string",
            "description": "What's New text to display to testers"
          ],
          "locale": [
            "type": "string",
            "description": "Locale code (default: en-US)"
          ]
        ] as [String: Any],
        "required": ["build_id", "whats_new"] as [String]
      ]
    ),
    Tool(
      name: "asc_list_apps",
      description: "List apps in App Store Connect. Useful to get app IDs for other commands.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "asc_list_bundle_ids",
      description: "List all registered bundle identifiers in App Store Connect.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ]
        ] as [String: Any],
        "required": [] as [String]
      ]
    ),
    Tool(
      name: "asc_create_bundle_id",
      description: "Register a new bundle identifier in App Store Connect. Required before creating an app.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "identifier": [
            "type": "string",
            "description": "Bundle identifier (e.g., 'com.example.myapp')"
          ],
          "name": [
            "type": "string",
            "description": "Display name for this bundle ID"
          ],
          "platform": [
            "type": "string",
            "description": "Platform: IOS, MAC_OS (default: IOS)"
          ]
        ] as [String: Any],
        "required": ["identifier", "name"] as [String]
      ]
    ),
    Tool(
      name: "asc_create_app",
      description: "Create a new app in App Store Connect. NOTE: Apple's API does not actually support this - will return manual instructions instead. Requires bundle ID to be registered first.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "bundle_id": [
            "type": "string",
            "description": "Bundle identifier (must already be registered)"
          ],
          "name": [
            "type": "string",
            "description": "App name as it will appear on the App Store"
          ],
          "sku": [
            "type": "string",
            "description": "Unique app identifier for your records (e.g., 'my-app-v1')"
          ],
          "primary_locale": [
            "type": "string",
            "description": "Primary locale (default: en-US)"
          ]
        ] as [String: Any],
        "required": ["bundle_id", "name", "sku"] as [String]
      ]
    ),
    Tool(
      name: "asc_create_group",
      description: "Create a new TestFlight beta group for distributing builds to testers.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "app_id": [
            "type": "string",
            "description": "App ID to create group for"
          ],
          "name": [
            "type": "string",
            "description": "Group name (e.g., 'Family Testers', 'External Beta')"
          ],
          "is_internal": [
            "type": "boolean",
            "description": "Internal group (App Store Connect users) vs external (default: false)"
          ],
          "public_link_enabled": [
            "type": "boolean",
            "description": "Enable public link for joining (default: false)"
          ]
        ] as [String: Any],
        "required": ["app_id", "name"] as [String]
      ]
    ),
    Tool(
      name: "asc_delete_group",
      description: "Delete a TestFlight beta group.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "group_id": [
            "type": "string",
            "description": "Beta group ID to delete"
          ]
        ] as [String: Any],
        "required": ["group_id"] as [String]
      ]
    ),
    Tool(
      name: "asc_add_build_to_group",
      description: "Add a build to a beta group for distribution to testers.",
      inputSchema: [
        "type": "object",
        "properties": [
          "profile": [
            "type": "string",
            "description": "Credential profile to use (default: 'default')"
          ],
          "group_id": [
            "type": "string",
            "description": "Beta group ID"
          ],
          "build_id": [
            "type": "string",
            "description": "Build ID to add to the group"
          ]
        ] as [String: Any],
        "required": ["group_id", "build_id"] as [String]
      ]
    ),
  ]

  /// Call a tool by name
  static func call(name: String, arguments: [String: Any]) async throws -> String {
    switch name {
      case "get_version":
        return try await getVersion()
      case "discover_signing":
        return try await discoverSigning(arguments: arguments)
      case "get_signing_status":
        return try await getSigningStatus()
      case "list_simulators":
        return try await listSimulators(arguments: arguments)
      case "list_devices":
        return try await listDevices()
      case "build_start":
        return try await buildStart(arguments: arguments)
      case "build_status":
        return try await buildStatus(arguments: arguments)
      case "build_logs":
        return try await buildLogs(arguments: arguments)
      case "build_cancel":
        return try await buildCancel(arguments: arguments)
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
      case "remove_capability":
        return try await removeCapability(arguments: arguments)
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
      case "asc_configure":
        return try await ascConfigure(arguments: arguments)
      case "asc_status":
        return try await ascStatus(arguments: arguments)
      case "asc_list_devices":
        return try await ascListDevices(arguments: arguments)
      case "asc_register_device":
        return try await ascRegisterDevice(arguments: arguments)
      case "asc_list_profiles":
        return try await ascListProfiles(arguments: arguments)
      case "asc_create_profile":
        return try await ascCreateProfile(arguments: arguments)
      case "asc_delete_profile":
        return try await ascDeleteProfile(arguments: arguments)
      case "asc_download_profile":
        return try await ascDownloadProfile(arguments: arguments)
      case "asc_regenerate_profile":
        return try await ascRegenerateProfile(arguments: arguments)
      case "asc_list_certificates":
        return try await ascListCertificates(arguments: arguments)
      case "asc_create_certificate":
        return try await ascCreateCertificate(arguments: arguments)
      case "asc_revoke_certificate":
        return try await ascRevokeCertificate(arguments: arguments)
      case "asc_list_testers":
        return try await ascListTesters(arguments: arguments)
      case "asc_add_tester":
        return try await ascAddTester(arguments: arguments)
      case "asc_remove_tester":
        return try await ascRemoveTester(arguments: arguments)
      case "asc_list_groups":
        return try await ascListGroups(arguments: arguments)
      case "asc_list_builds":
        return try await ascListBuilds(arguments: arguments)
      case "asc_set_whats_new":
        return try await ascSetWhatsNew(arguments: arguments)
      case "asc_list_apps":
        return try await ascListApps(arguments: arguments)
      case "asc_list_bundle_ids":
        return try await ascListBundleIds(arguments: arguments)
      case "asc_create_bundle_id":
        return try await ascCreateBundleId(arguments: arguments)
      case "asc_create_app":
        return try await ascCreateApp(arguments: arguments)
      case "asc_create_group":
        return try await ascCreateGroup(arguments: arguments)
      case "asc_delete_group":
        return try await ascDeleteGroup(arguments: arguments)
      case "asc_add_build_to_group":
        return try await ascAddBuildToGroup(arguments: arguments)
      default:
        throw MCPError.unknownTool(name)
    }
  }

  // MARK: - Tool Implementations

  /// Version info result
  struct VersionInfo: Codable {
    let version: String
    let processStartTime: String
    let processId: Int32
    let swiftVersion: String
    let capabilities: Int
  }

  static func getVersion() async throws -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    let info = VersionInfo(
      version: MCPTools.version,
      processStartTime: formatter.string(from: processStartTime),
      processId: ProcessInfo.processInfo.processIdentifier,
      swiftVersion: "5.9+",
      capabilities: CapabilityManager.Capability.allCases.count
    )
    return encodeJSON(info)
  }

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
    // devicectl requires -j <path> to write JSON to a file
    let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("devices-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    _ = try await runCommand("/usr/bin/xcrun", arguments: ["devicectl", "list", "devices", "-j", tempFile.path])

    guard let data = try? Data(contentsOf: tempFile),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let result = json["result"] as? [String: Any],
          let devices = result["devices"] as? [[String: Any]] else {
      // Fall back to text output if parsing fails
      let textOutput = try await runCommand("/usr/bin/xcrun", arguments: ["devicectl", "list", "devices"])
      return textOutput
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

      // Fetch hardware UDID (used by provisioning profiles)
      // CoreDevice UUID != Hardware UDID, profiles use hardware UDID
      let hardwareUdid = await fetchHardwareUdid(coreDeviceUuid: udid)

      results.append(DeviceInfo(
        name: name,
        udid: udid,
        hardwareUdid: hardwareUdid,
        platform: platform,
        osVersion: osVersion,
        connectionType: transportType
      ))
    }

    return encodeJSON(results)
  }

  /// Fetch hardware UDID from CoreDevice UUID
  /// devicectl returns CoreDevice UUID (e.g., 97452CCA-E01F-5542-9E9B-CE54DA7031C2)
  /// but provisioning profiles use hardware UDID (e.g., 00008130-000605841AE0001C)
  static func fetchHardwareUdid(coreDeviceUuid: String) async -> String? {
    do {
      let output = try await runCommand(
        "/usr/bin/xcrun",
        arguments: ["devicectl", "device", "info", "details", "--device", coreDeviceUuid]
      )

      // Parse output to find: udid: 00008130-000605841AE0001C
      let lines = output.split(separator: "\n")
      for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Look for line like "• udid: 00008130-000605841AE0001C"
        if trimmed.hasPrefix("• udid:") || trimmed.hasPrefix("udid:") {
          let parts = trimmed.components(separatedBy: ":")
          if parts.count >= 2 {
            return parts[1].trimmingCharacters(in: .whitespaces)
          }
        }
      }
    } catch {
      // Device might not be available for detailed query
    }
    return nil
  }

  // MARK: - Async Build Response Types

  struct BuildStartResult: Codable {
    let success: Bool
    let jobId: String?
    let message: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
      case success, error, message
      case jobId = "job_id"
    }
  }

  struct BuildLogsResult: Codable {
    let jobId: String
    let status: String
    let lines: [String]
    let bufferedRemaining: Int

    enum CodingKeys: String, CodingKey {
      case status, lines
      case jobId = "job_id"
      case bufferedRemaining = "buffered_remaining"
    }
  }

  struct BuildCancelResult: Codable {
    let success: Bool
    let message: String
  }

  struct BuildJobsResult: Codable {
    let jobs: [BuildJobInfo]
  }

  struct BuildErrorResult: Codable {
    let success: Bool
    let error: String
  }

  // MARK: - Async Build Tools

  /// Track jobs that have been post-processed (asset catalog compiled)
  private static var postProcessedJobs: Set<String> = []
  private static let postProcessLock = NSLock()

  /// Post-process a completed build (compile asset catalog, re-sign)
  private static func postProcessBuild(job: BuildJob) async {
    // Check if already processed
    postProcessLock.lock()
    if postProcessedJobs.contains(job.id) {
      postProcessLock.unlock()
      return
    }
    postProcessedJobs.insert(job.id)
    postProcessLock.unlock()

    // Only process successful builds
    guard job.status == .success else { return }

    let projectURL = URL(fileURLWithPath: job.projectPath)
    guard let platform = BuildRunner.Platform(rawValue: job.platform) else { return }

    // Find the built app
    let buildDir = projectURL.appendingPathComponent(".build/bundler")
    guard let contents = try? FileManager.default.contentsOfDirectory(at: buildDir, includingPropertiesForKeys: nil),
          let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
      return
    }

    // Resolve signing info if needed
    var signing: SigningDiscovery.ResolvedSigning? = nil
    if platform.requiresSigning {
      let config = try? XClaudeConfig.load(from: projectURL)
      let bundleId = config?.app.bundleId ?? "com.example.app"
      let discovery = SigningDiscovery()
      signing = try? await discovery.resolveSigning(
        bundleId: bundleId,
        platform: platform.platformName,
        projectDirectory: projectURL,
        config: config
      )
    }

    // Compile asset catalog
    try? await BuildRunner.compileAssetCatalog(
      appPath: appURL.path,
      projectDirectory: projectURL,
      platform: platform,
      signing: signing
    )
  }

  static func buildStart(arguments: [String: Any]) async throws -> String {
    let platformStr = arguments["platform"] as? String ?? "iOS"
    let configStr = arguments["configuration"] as? String ?? "debug"
    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let clean = arguments["clean"] as? Bool ?? false

    guard let platform = BuildRunner.Platform(rawValue: platformStr) else {
      return encodeJSON(BuildStartResult(
        success: false,
        jobId: nil,
        message: nil,
        error: "Invalid platform: \(platformStr)"
      ))
    }

    let projectURL = URL(fileURLWithPath: pathStr)

    // Clean build directory if requested
    if clean {
      let buildDir = projectURL.appendingPathComponent(".build")
      try? FileManager.default.removeItem(at: buildDir)
    }

    // Detect project type and prepare config
    let projectType = ConfigTranslator.detectProjectType(at: projectURL)

    var configFileArg: String? = nil
    if projectType == .xclaude {
      let config = try XClaudeConfig.load(from: projectURL)
      let configPath = try ConfigTranslator.translate(config: config, projectDirectory: projectURL)
      configFileArg = configPath.path
    }

    // Find swift-bundler
    guard let bundlerPath = findSwiftBundler() else {
      return encodeJSON(BuildStartResult(
        success: false,
        jobId: nil,
        message: nil,
        error: "swift-bundler not found"
      ))
    }

    // Build arguments
    var args = ["bundle", "-p", platformStr, "-c", configStr]
    args.append("--directory")
    args.append(pathStr)

    if let configFile = configFileArg {
      args.append("--config-file")
      args.append(configFile)
    }

    // Resolve signing for device builds (xclaude projects only)
    if platform.requiresSigning && projectType == .xclaude {
      let config = try? XClaudeConfig.load(from: projectURL)
      let bundleId = config?.app.bundleId ?? "com.example.app"

      let discovery = SigningDiscovery()
      let signing = try await discovery.resolveSigning(
        bundleId: bundleId,
        platform: platform.platformName,
        projectDirectory: projectURL,
        config: config
      )

      args.append("--identity")
      args.append(signing.identity.name)
      args.append("--provisioning-profile")
      args.append(signing.profile.path)
      args.append("--entitlements")
      args.append(signing.entitlementsPath)
    } else if platform.requiresSigning {
      return encodeJSON(BuildStartResult(
        success: false,
        jobId: nil,
        message: nil,
        error: "Device builds require xclaude.toml with [signing] section"
      ))
    } else if platform == .macOS && projectType == .xclaude {
      // For macOS, sign with entitlements if they exist (for capabilities like keychain, network)
      let entitlementsPath = ConfigTranslator.derivedDirectory(for: projectURL)
        .appendingPathComponent("Entitlements.plist")
      if FileManager.default.fileExists(atPath: entitlementsPath.path) {
        let config = try? XClaudeConfig.load(from: projectURL)
        let identity = config?.signing?.identity ?? "Apple Development"

        args.append("--codesign")
        args.append("--identity")
        args.append(identity)
        args.append("--entitlements")
        args.append(entitlementsPath.path)
      }
    }

    // Start the build
    let job = try await BuildManager.shared.startBuild(
      projectPath: pathStr,
      platform: platformStr,
      configuration: configStr,
      arguments: args,
      swiftBundlerPath: bundlerPath
    )

    // Set expected app path based on project config
    if let config = try? XClaudeConfig.load(from: projectURL) {
      let appName = config.app.name
      let appPath = projectURL
        .appendingPathComponent(".build/bundler")
        .appendingPathComponent("\(appName).app")
        .path
      job.setAppPath(appPath)
    }

    return encodeJSON(BuildStartResult(
      success: true,
      jobId: job.id,
      message: "Build started. Use build_logs to check progress.",
      error: nil
    ))
  }

  static func buildStatus(arguments: [String: Any]) async throws -> String {
    if let jobId = arguments["job_id"] as? String {
      guard let job = await BuildManager.shared.getJob(jobId) else {
        return encodeJSON(BuildErrorResult(success: false, error: "Job not found: \(jobId)"))
      }
      // Post-process if build just succeeded
      if job.status == .success {
        await postProcessBuild(job: job)
      }
      return encodeJSON(BuildJobInfo(from: job))
    } else {
      // Return all recent jobs
      let jobs = await BuildManager.shared.recentJobs()
      // Post-process any successful builds
      for job in jobs where job.status == .success {
        await postProcessBuild(job: job)
      }
      let infos = jobs.map { BuildJobInfo(from: $0) }
      return encodeJSON(BuildJobsResult(jobs: infos))
    }
  }

  static func buildLogs(arguments: [String: Any]) async throws -> String {
    guard let jobId = arguments["job_id"] as? String else {
      throw ToolError.missingArgument("job_id")
    }

    guard let job = await BuildManager.shared.getJob(jobId) else {
      return encodeJSON(BuildErrorResult(success: false, error: "Job not found: \(jobId)"))
    }

    let lines = arguments["lines"] as? Int
    let clear = arguments["clear"] as? Bool ?? false
    let output = job.readOutput(count: lines, clear: clear)

    return encodeJSON(BuildLogsResult(
      jobId: jobId,
      status: job.status.rawValue,
      lines: output,
      bufferedRemaining: job.bufferedLineCount
    ))
  }

  static func buildCancel(arguments: [String: Any]) async throws -> String {
    guard let jobId = arguments["job_id"] as? String else {
      throw ToolError.missingArgument("job_id")
    }

    let cancelled = await BuildManager.shared.cancel(jobId)
    return encodeJSON(BuildCancelResult(
      success: cancelled,
      message: cancelled ? "Build cancelled" : "Job not found or already completed"
    ))
  }

  private static func findSwiftBundler() -> String? {
    // Check next to xclaude executable first
    if let execPath = Bundle.main.executablePath {
      let execDir = URL(fileURLWithPath: execPath).deletingLastPathComponent()
      let siblingPath = execDir.appendingPathComponent("swift-bundler").path
      if FileManager.default.isExecutableFile(atPath: siblingPath) {
        return siblingPath
      }
    }

    let candidates = [
      ".build/debug/swift-bundler",
      ".build/release/swift-bundler",
      "/usr/local/bin/swift-bundler",
      NSString(string: "~/.mint/bin/swift-bundler").expandingTildeInPath,
      NSString(string: "~/.local/bin/swift-bundler").expandingTildeInPath
    ]

    for candidate in candidates {
      if FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }

    return nil
  }

  static func deploy(arguments: [String: Any]) async throws -> String {
    guard let appPath = arguments["app_path"] as? String else {
      throw ToolError.missingArgument("app_path")
    }

    // Auto-detect bundle_id from xclaude.toml if not provided
    let bundleId: String
    if let providedBundleId = arguments["bundle_id"] as? String {
      bundleId = providedBundleId
    } else {
      // Try to find xclaude.toml - first check cwd, then walk up from app_path
      let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      if let config = try? XClaudeConfig.load(from: cwd) {
        bundleId = config.app.bundleId
      } else {
        // Walk up from app_path to find xclaude.toml (app is typically in .build/bundler/)
        var searchDir = URL(fileURLWithPath: appPath).deletingLastPathComponent()
        var foundConfig: XClaudeConfig? = nil
        for _ in 0..<5 {  // Max 5 levels up
          if let config = try? XClaudeConfig.load(from: searchDir) {
            foundConfig = config
            break
          }
          searchDir = searchDir.deletingLastPathComponent()
        }
        if let config = foundConfig {
          bundleId = config.app.bundleId
        } else {
          throw ToolError.missingArgument("bundle_id (could not auto-detect - no xclaude.toml found)")
        }
      }
    }

    let targetStr = arguments["target"] as? String ?? "device"
    let launch = arguments["launch"] as? Bool ?? true
    let target = DeployRunner.Target.parse(targetStr)

    // Determine if this is a simulator, device, or macOS target
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
    case .macOS:
      result = try await DeployRunner.deployToMacOS(
        appPath: appPath,
        bundleId: bundleId,
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

    guard let platform = BuildRunner.Platform(rawValue: platformStr) else {
      return encodeJSON(RunResult(
        success: false,
        buildResult: BuildRunner.BuildResult(
          success: false,
          appPath: nil,
          platform: platformStr,
          configuration: configStr,
          duration: 0,
          warnings: [],
          errors: [BuildRunner.BuildError(code: "INVALID_PLATFORM", message: "Invalid platform: \(platformStr)")]
        ),
        deployResult: nil
      ))
    }

    let projectURL = URL(fileURLWithPath: pathStr)

    // Detect project type and prepare config (same as buildStart)
    let projectType = ConfigTranslator.detectProjectType(at: projectURL)

    var configFileArg: String? = nil
    if projectType == .xclaude {
      let config = try XClaudeConfig.load(from: projectURL)
      let configPath = try ConfigTranslator.translate(config: config, projectDirectory: projectURL)
      configFileArg = configPath.path
    }

    // Find swift-bundler
    guard let bundlerPath = findSwiftBundler() else {
      return encodeJSON(RunResult(
        success: false,
        buildResult: BuildRunner.BuildResult(
          success: false,
          appPath: nil,
          platform: platformStr,
          configuration: configStr,
          duration: 0,
          warnings: [],
          errors: [BuildRunner.BuildError(code: "BUNDLER_NOT_FOUND", message: "swift-bundler not found")]
        ),
        deployResult: nil
      ))
    }

    // Build arguments
    var args = ["bundle", "-p", platformStr, "-c", configStr]
    args.append("--directory")
    args.append(pathStr)

    if let configFile = configFileArg {
      args.append("--config-file")
      args.append(configFile)
    }

    // Resolve signing for device builds (xclaude projects only)
    if platform.requiresSigning && projectType == .xclaude {
      let config = try? XClaudeConfig.load(from: projectURL)
      let bundleId = config?.app.bundleId ?? "com.example.app"

      let discovery = SigningDiscovery()
      let signing = try await discovery.resolveSigning(
        bundleId: bundleId,
        platform: platform.platformName,
        projectDirectory: projectURL,
        config: config
      )

      args.append("--identity")
      args.append(signing.identity.name)
      args.append("--provisioning-profile")
      args.append(signing.profile.path)
      args.append("--entitlements")
      args.append(signing.entitlementsPath)
    } else if platform.requiresSigning {
      return encodeJSON(RunResult(
        success: false,
        buildResult: BuildRunner.BuildResult(
          success: false,
          appPath: nil,
          platform: platformStr,
          configuration: configStr,
          duration: 0,
          warnings: [],
          errors: [BuildRunner.BuildError(code: "SIGNING_REQUIRED", message: "Device builds require xclaude.toml with [signing] section")]
        ),
        deployResult: nil
      ))
    } else if platform == .macOS && projectType == .xclaude {
      // For macOS, sign with entitlements if they exist (for capabilities like keychain, network)
      let entitlementsPath = ConfigTranslator.derivedDirectory(for: projectURL)
        .appendingPathComponent("Entitlements.plist")
      if FileManager.default.fileExists(atPath: entitlementsPath.path) {
        let config = try? XClaudeConfig.load(from: projectURL)
        let identity = config?.signing?.identity ?? "Apple Development"

        args.append("--codesign")
        args.append("--identity")
        args.append(identity)
        args.append("--entitlements")
        args.append(entitlementsPath.path)
      }
    }

    // Start async build (non-blocking)
    let job = try await BuildManager.shared.startBuild(
      projectPath: pathStr,
      platform: platformStr,
      configuration: configStr,
      arguments: args,
      swiftBundlerPath: bundlerPath
    )

    // Poll for completion (check every 500ms)
    while job.status == .running {
      try await Task.sleep(nanoseconds: 500_000_000) // 500ms
    }

    // Build completed - get result
    let buildSuccess = job.status == .success
    let buildOutput = job.readOutput()

    // Find app path
    let buildDir = projectURL.appendingPathComponent(".build/bundler")
    let appPath: String?
    if let contents = try? FileManager.default.contentsOfDirectory(at: buildDir, includingPropertiesForKeys: nil),
       let appURL = contents.first(where: { $0.pathExtension == "app" }) {
      appPath = appURL.path
    } else {
      appPath = nil
    }

    // Parse warnings/errors from build output
    let warnings = buildOutput.filter { $0.contains("warning:") }
    let errors: [BuildRunner.BuildError] = buildSuccess ? [] : [
      BuildRunner.BuildError(code: "BUILD_FAILED", message: buildOutput.joined(separator: "\n"))
    ]

    let buildResult = BuildRunner.BuildResult(
      success: buildSuccess,
      appPath: appPath,
      platform: platformStr,
      configuration: configStr,
      duration: job.duration,
      warnings: warnings,
      errors: errors
    )

    guard buildSuccess, let finalAppPath = appPath else {
      return encodeJSON(RunResult(
        success: false,
        buildResult: buildResult,
        deployResult: nil
      ))
    }

    // Post-process (compile asset catalog, etc.)
    await postProcessBuild(job: job)

    // Get bundle ID from config
    let config = try? XClaudeConfig.load(from: projectURL)
    let bundleId = config?.app.bundleId ?? "com.xclaude.app"

    // Handle platform-specific deployment
    let deployResult: DeployRunner.DeployResult

    if platform == .macOS {
      // For macOS, just open the .app directly
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      process.arguments = [finalAppPath]
      try process.run()
      process.waitUntilExit()

      let launchSuccess = process.terminationStatus == 0
      deployResult = DeployRunner.DeployResult(
        success: launchSuccess,
        target: DeployRunner.TargetInfo(type: .simulator, udid: "local", name: "macOS (local)"),
        appPath: finalAppPath,
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
          appPath: finalAppPath,
          bundleId: bundleId,
          target: target,
          launch: true
        )
      case .device, .deviceByName, .anyDevice:
        deployResult = try await DeployRunner.deployToDevice(
          appPath: finalAppPath,
          bundleId: bundleId,
          target: target,
          launch: true
        )
      case .macOS:
        // Should not reach here - macOS is handled above
        deployResult = DeployRunner.DeployResult(
          success: false,
          target: DeployRunner.TargetInfo(type: .macOS, udid: "local", name: "macOS"),
          appPath: finalAppPath,
          bundleId: bundleId,
          launched: false,
          error: "Unexpected macOS target in iOS deploy path"
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

  static func removeCapability(arguments: [String: Any]) async throws -> String {
    guard let capability = arguments["capability"] as? String else {
      throw ToolError.missingArgument("capability")
    }

    let pathStr = arguments["path"] as? String ?? FileManager.default.currentDirectoryPath
    let projectURL = URL(fileURLWithPath: pathStr)

    let result = try CapabilityManager.removeCapability(capability, from: projectURL)
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
      "/usr/local/bin/swift-bundler",
      "~/.mint/bin/swift-bundler",
      "~/.local/bin/swift-bundler"
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

    // Check xclaude.toml for explicit distribution signing config
    let signingMode: SigningMode = exportMethod == "development" ? .development : .distribution
    let configuredSigning = config.signing?.forPlatform("iOS", mode: signingMode)
    let configuredProfileName = configuredSigning?.profile
    let configuredIdentityName = configuredSigning?.identity
    let configuredTeamId = config.signing?.team

    // Map export method to expected profile type
    let expectedProfileType: ProfileType = {
      switch exportMethod {
      case "development": return .development
      case "app-store": return .appStore
      case "ad-hoc": return .adHoc
      case "enterprise": return .enterprise
      default: return .appStore
      }
    }()

    // Find matching profile for distribution
    let matchingProfiles = signingData.profiles.filter { profile in
      // CRITICAL: If team ID is configured, filter by it first to avoid profile name collisions
      if let teamId = configuredTeamId, profile.teamId != teamId {
        return false
      }

      // Must match bundle ID
      let matchesBundleId = profile.bundleIdPattern == bundleId ||
        (profile.isWildcard && (profile.bundleIdPattern == "*" ||
          bundleId.hasPrefix(profile.bundleIdPattern.replacingOccurrences(of: "*", with: ""))))

      guard matchesBundleId && !profile.isExpired else { return false }

      // If config specifies a profile name, match it - but prefer correct type when names collide
      if let configuredName = configuredProfileName {
        return profile.name == configuredName
      }

      // For distribution export methods, exclude development profiles
      if exportMethod != "development" {
        return profile.profileType != .development
      }

      return true
    }

    // Sort profiles: profile type match first, then exact bundle ID, then non-wildcard
    let sortedProfiles = matchingProfiles.sorted { a, b in
      // 0. Profile type matching export method takes top priority
      let aTypeMatch = a.profileType == expectedProfileType
      let bTypeMatch = b.profileType == expectedProfileType
      if aTypeMatch != bTypeMatch { return aTypeMatch }

      // 1. If configured name, prefer that
      if let configuredName = configuredProfileName {
        if a.name == configuredName && b.name != configuredName { return true }
        if b.name == configuredName && a.name != configuredName { return false }
      }

      // 2. Exact bundle ID match beats wildcard
      let aExact = a.bundleIdPattern == bundleId
      let bExact = b.bundleIdPattern == bundleId
      if aExact != bExact { return aExact }

      // 3. Non-wildcard beats wildcard
      if a.isWildcard != b.isWildcard { return !a.isWildcard }

      return false
    }

    guard let profile = sortedProfiles.first else {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "No matching provisioning profile found for '\(bundleId)' with export method '\(exportMethod)'. Available profiles: \(signingData.profiles.map { $0.name }.joined(separator: ", "))"
      ))
    }

    // Find distribution identity based on export method
    // iOS App Store/TestFlight requires "Apple Distribution" or "iPhone Distribution"
    // "Developer ID Application" is ONLY for macOS direct distribution (notarized apps outside App Store)
    let distributionIdentities = signingData.identities.filter { identity in
      guard identity.teamId == profile.teamId else { return false }

      if exportMethod == "development" {
        return true // Any identity works for development
      }

      // For iOS distribution (app-store, ad-hoc), require Distribution cert but NOT Developer ID
      // Developer ID is for macOS direct distribution only
      let isDistribution = identity.name.contains("Distribution")
      let isDeveloperId = identity.name.contains("Developer ID")

      return isDistribution && !isDeveloperId
    }

    // Check if user has Developer ID but not Apple Distribution (common mistake)
    let hasDeveloperIdOnly = signingData.identities.contains {
      $0.teamId == profile.teamId && $0.name.contains("Developer ID")
    } && distributionIdentities.isEmpty

    // Prefer configured identity from xclaude.toml [signing.iOS.distribution] if specified
    let identity: SigningIdentity?
    if let configuredName = configuredIdentityName {
      // Look for exact match first
      if let exact = signingData.identities.first(where: { $0.name == configuredName }) {
        identity = exact
      } else if let partial = signingData.identities.first(where: { $0.name.contains(configuredName) }) {
        // Fall back to partial match
        identity = partial
      } else {
        // Configured identity not found - fall back to auto-discovery
        identity = distributionIdentities.first ?? signingData.identities.first { $0.teamId == profile.teamId }
      }
    } else {
      identity = distributionIdentities.first ?? signingData.identities.first { $0.teamId == profile.teamId }
    }

    guard let identity = identity else {
      var message = "No signing identity found for team '\(profile.teamId)'"
      if hasDeveloperIdOnly {
        message = "Found 'Developer ID Application' certificate, but iOS App Store/TestFlight requires 'Apple Distribution' certificate. " +
          "Go to https://developer.apple.com/account/resources/certificates to create an Apple Distribution certificate."
      }
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: message
      ))
    }

    // Warn if using wrong certificate type (shouldn't happen after filter above, but safety check)
    if identity.name.contains("Developer ID") && (exportMethod == "app-store" || exportMethod == "ad-hoc") {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "Cannot use 'Developer ID Application' certificate for iOS \(exportMethod). " +
          "Developer ID is for macOS direct distribution only. " +
          "Create an 'Apple Distribution' certificate at https://developer.apple.com/account/resources/certificates"
      ))
    }

    // Step 3: Re-sign the app with distribution credentials
    // The app was signed during build with dev credentials, now re-sign for distribution
    let appURL = URL(fileURLWithPath: appPath)

    // Copy provisioning profile into app bundle
    let embeddedProfilePath = appURL.appendingPathComponent("embedded.mobileprovision").path
    do {
      // Remove existing profile if any
      try? FileManager.default.removeItem(atPath: embeddedProfilePath)
      // Copy distribution profile
      try FileManager.default.copyItem(atPath: profile.path, toPath: embeddedProfilePath)
    } catch {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "Failed to embed provisioning profile: \(error.localizedDescription)"
      ))
    }

    // Add required Info.plist keys for App Store submission
    let infoPlistPath = appURL.appendingPathComponent("Info.plist").path
    if FileManager.default.fileExists(atPath: infoPlistPath) {
      // Get Xcode/SDK info
      let xcodeVersion = (try? runCommandSync("/usr/bin/xcodebuild", arguments: ["-version"]).output)?
        .components(separatedBy: "\n").first?
        .replacingOccurrences(of: "Xcode ", with: "") ?? "16.0"
      let xcodeBuild = (try? runCommandSync("/usr/bin/xcodebuild", arguments: ["-version"]).output)?
        .components(separatedBy: "\n").dropFirst().first?
        .replacingOccurrences(of: "Build version ", with: "") ?? "16A242d"
      let sdkVersion = (try? runCommandSync("/usr/bin/xcrun", arguments: ["--show-sdk-version", "--sdk", "iphoneos"]).output)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "18.0"

      // Add DTPlatformName
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Add :DTPlatformName string iphoneos", infoPlistPath])
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Set :DTPlatformName iphoneos", infoPlistPath])

      // Add DTSDKName
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Add :DTSDKName string iphoneos\(sdkVersion)", infoPlistPath])
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Set :DTSDKName iphoneos\(sdkVersion)", infoPlistPath])

      // Add DTPlatformVersion
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Add :DTPlatformVersion string \(sdkVersion)", infoPlistPath])
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Set :DTPlatformVersion \(sdkVersion)", infoPlistPath])

      // Add DTXcode
      let dtXcode = xcodeVersion.replacingOccurrences(of: ".", with: "").padding(toLength: 4, withPad: "0", startingAt: 0)
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Add :DTXcode string \(dtXcode)", infoPlistPath])
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Set :DTXcode \(dtXcode)", infoPlistPath])

      // Add DTXcodeBuild
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Add :DTXcodeBuild string \(xcodeBuild)", infoPlistPath])
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Set :DTXcodeBuild \(xcodeBuild)", infoPlistPath])

      // Add UIRequiredDeviceCapabilities with arm64
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Add :UIRequiredDeviceCapabilities array", infoPlistPath])
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Add :UIRequiredDeviceCapabilities:0 string arm64", infoPlistPath])
    }

    // Generate distribution entitlements (get-task-allow = false for distribution)
    let distEntitlementsPath = projectURL.appendingPathComponent(".xclaude/derived/Entitlements-dist.plist").path
    let devEntitlementsPath = projectURL.appendingPathComponent(".xclaude/derived/Entitlements.plist").path

    if FileManager.default.fileExists(atPath: devEntitlementsPath) {
      // Copy dev entitlements and modify for distribution
      try? FileManager.default.removeItem(atPath: distEntitlementsPath)
      try? FileManager.default.copyItem(atPath: devEntitlementsPath, toPath: distEntitlementsPath)

      // Set get-task-allow to false for distribution
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Set :get-task-allow false", distEntitlementsPath])
      // Also check for the macOS variant key
      _ = try? runCommandSync("/usr/libexec/PlistBuddy",
        arguments: ["-c", "Set :com.apple.security.get-task-allow false", distEntitlementsPath])
    } else {
      // Create minimal distribution entitlements
      let minimalEntitlements = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>application-identifier</key>
          <string>\(profile.teamId).\(bundleId)</string>
          <key>get-task-allow</key>
          <false/>
        </dict>
        </plist>
        """
      try? minimalEntitlements.write(toFile: distEntitlementsPath, atomically: true, encoding: .utf8)
    }

    // Re-sign with distribution identity using distribution entitlements
    var codesignArgs = ["--force", "--sign", identity.name, "--timestamp"]
    if FileManager.default.fileExists(atPath: distEntitlementsPath) {
      codesignArgs += ["--entitlements", distEntitlementsPath]
    }
    codesignArgs.append(appPath)

    _ = try await runCommand("/usr/bin/codesign", arguments: codesignArgs)

    // Verify signing succeeded
    let verifyProcess = Process()
    verifyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    verifyProcess.arguments = ["--verify", "--deep", "--strict", appPath]
    verifyProcess.standardOutput = FileHandle.nullDevice
    verifyProcess.standardError = FileHandle.nullDevice
    try verifyProcess.run()
    verifyProcess.waitUntilExit()

    if verifyProcess.terminationStatus != 0 {
      return encodeJSON(ArchiveResult(
        success: false,
        ipaPath: nil,
        appPath: appPath,
        exportMethod: exportMethod,
        signingInfo: nil,
        message: "Code signing verification failed. The app may not be properly signed for \(exportMethod) distribution."
      ))
    }

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

  /// Synchronous command runner for simple commands (no async context needed)
  private static func runCommandSync(_ command: String, arguments: [String]) -> (exit: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""
      return (process.terminationStatus, output)
    } catch {
      return (-1, "")
    }
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
    var apiKey = arguments["api_key"] as? String
    var apiKeyId = arguments["api_key_id"] as? String
    var apiIssuer = arguments["api_issuer"] as? String
    let appleId = arguments["apple_id"] as? String
    let password = arguments["password"] as? String

    // Auto-load from stored ASC credentials if not explicitly provided
    if apiKey == nil || apiKeyId == nil || apiIssuer == nil {
      let profileName = arguments["profile"] as? String ?? ASCCredentialStore.defaultProfile
      if let stored = try? ASCCredentialStore.load(profile: profileName) {
        apiKey = apiKey ?? stored.privateKeyPath
        apiKeyId = apiKeyId ?? stored.keyId
        apiIssuer = apiIssuer ?? stored.issuerId
      }
    }

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
        message: "Authentication required. Use asc_configure to set up credentials (auto-used), or provide: (api_key + api_key_id + api_issuer) or (apple_id + password)",
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
    let udid: String  // CoreDevice UUID (e.g., 97452CCA-E01F-5542-9E9B-CE54DA7031C2)
    let hardwareUdid: String?  // Hardware UDID for provisioning profiles (e.g., 00008130-000605841AE0001C)
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

  // MARK: - App Store Connect API

  struct ASCConfigureResult: Encodable {
    let success: Bool
    let message: String?
    let error: String?
  }

  struct ASCStatusResult: Encodable {
    let configured: Bool
    let issuerId: String?
    let keyId: String?
    let keyPath: String?
    let connectionTest: String?
    let error: String?
  }

  static func ascConfigure(arguments: [String: Any]) async throws -> String {
    let profileName = arguments["profile"] as? String ?? ASCCredentialStore.defaultProfile

    guard let issuerId = arguments["issuer_id"] as? String else {
      throw ToolError.missingArgument("issuer_id")
    }
    guard let keyPath = arguments["key_path"] as? String else {
      throw ToolError.missingArgument("key_path")
    }

    // Auto-extract key_id from filename if not provided (AuthKey_XXXXX.p8)
    let keyId: String
    if let providedKeyId = arguments["key_id"] as? String {
      keyId = providedKeyId
    } else {
      let filename = URL(fileURLWithPath: keyPath).lastPathComponent
      if filename.hasPrefix("AuthKey_") && filename.hasSuffix(".p8") {
        keyId = String(filename.dropFirst(8).dropLast(3))  // Remove "AuthKey_" and ".p8"
      } else {
        throw ToolError.missingArgument("key_id (could not auto-extract from filename - expected AuthKey_XXXXX.p8)")
      }
    }

    // Copy key file to ~/.xclaude/ for safekeeping
    let expandedKeyPath = (keyPath as NSString).expandingTildeInPath
    let sourceURL = URL(fileURLWithPath: expandedKeyPath)
    let xclaudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".xclaude")
    let destURL = xclaudeDir.appendingPathComponent("AuthKey_\(keyId).p8")

    let finalKeyPath: String
    do {
      try FileManager.default.createDirectory(at: xclaudeDir, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: destURL.path) {
        try FileManager.default.removeItem(at: destURL)
      }
      try FileManager.default.copyItem(at: sourceURL, to: destURL)
      // Set restrictive permissions (owner read only)
      try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: destURL.path)
      finalKeyPath = destURL.path
    } catch {
      // Fall back to original path if copy fails
      finalKeyPath = expandedKeyPath
    }

    let credentials = AppStoreConnectClient.Credentials(
      issuerId: issuerId,
      keyId: keyId,
      privateKeyPath: finalKeyPath
    )

    do {
      // Validate and configure
      try await AppStoreConnectClient.shared.configure(credentials: credentials)

      // Save to disk under the specified profile
      try ASCCredentialStore.save(credentials, profile: profileName)

      // Test connection
      let testResult = try await AppStoreConnectClient.shared.testConnection()

      let keyLocation = finalKeyPath.contains(".xclaude") ? "Key copied to ~/.xclaude/. " : ""
      let profileInfo = profileName == ASCCredentialStore.defaultProfile ? "" : "Profile '\(profileName)' "
      return encodeJSON(ASCConfigureResult(
        success: true,
        message: "\(keyLocation)\(profileInfo)Credentials saved. \(testResult)",
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCConfigureResult(
        success: false,
        message: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCConfigureResult(
        success: false,
        message: nil,
        error: error.localizedDescription
      ))
    }
  }

  struct ASCProfileStatus: Encodable {
    let profile: String
    let issuerId: String
    let keyId: String
    let status: String
    let connectionTest: String?
    let error: String?
  }

  struct ASCMultiStatusResult: Encodable {
    let configured: Bool
    let profileCount: Int?
    let profiles: [ASCProfileStatus]?
    let error: String?
  }

  static func ascStatus(arguments: [String: Any]) async throws -> String {
    let requestedProfile = arguments["profile"] as? String

    // Get all configured profiles
    let profiles = ASCCredentialStore.listProfiles()

    if profiles.isEmpty {
      return encodeJSON(ASCMultiStatusResult(
        configured: false,
        profileCount: 0,
        profiles: nil,
        error: "No profiles configured. Use asc_configure to set up credentials."
      ))
    }

    // If specific profile requested, show just that one
    if let profileName = requestedProfile {
      guard let creds = try? ASCCredentialStore.load(profile: profileName) else {
        return encodeJSON(ASCMultiStatusResult(
          configured: false,
          profileCount: nil,
          profiles: nil,
          error: "Profile '\(profileName)' not found. Available: \(profiles.joined(separator: ", "))"
        ))
      }

      // Configure and test this profile
      try await AppStoreConnectClient.shared.configure(credentials: creds)

      do {
        let testResult = try await AppStoreConnectClient.shared.testConnection()
        return encodeJSON(ASCStatusResult(
          configured: true,
          issuerId: creds.issuerId,
          keyId: creds.keyId,
          keyPath: creds.privateKeyPath,
          connectionTest: testResult,
          error: nil
        ))
      } catch {
        return encodeJSON(ASCStatusResult(
          configured: true,
          issuerId: creds.issuerId,
          keyId: creds.keyId,
          keyPath: creds.privateKeyPath,
          connectionTest: nil,
          error: error.localizedDescription
        ))
      }
    }

    // Show all profiles with their status
    var profileStatuses: [ASCProfileStatus] = []

    for profileName in profiles {
      guard let creds = try? ASCCredentialStore.load(profile: profileName) else { continue }

      // Configure and test each profile
      try? await AppStoreConnectClient.shared.configure(credentials: creds)

      do {
        let testResult = try await AppStoreConnectClient.shared.testConnection()
        profileStatuses.append(ASCProfileStatus(
          profile: profileName,
          issuerId: creds.issuerId,
          keyId: creds.keyId,
          status: "connected",
          connectionTest: testResult,
          error: nil
        ))
      } catch {
        profileStatuses.append(ASCProfileStatus(
          profile: profileName,
          issuerId: creds.issuerId,
          keyId: creds.keyId,
          status: "error",
          connectionTest: nil,
          error: error.localizedDescription
        ))
      }
    }

    return encodeJSON(ASCMultiStatusResult(
      configured: true,
      profileCount: profiles.count,
      profiles: profileStatuses,
      error: nil
    ))
  }

  // MARK: - ASC Profile Helper

  /// Configures the ASC client for the specified profile
  /// Returns an error message if configuration fails, nil if successful
  static func configureASCClient(arguments: [String: Any]) async -> String? {
    let profileName = arguments["profile"] as? String ?? ASCCredentialStore.defaultProfile

    guard let credentials = try? ASCCredentialStore.load(profile: profileName) else {
      let profiles = ASCCredentialStore.listProfiles()
      if profiles.isEmpty {
        return "No profiles configured. Use asc_configure to set up credentials."
      } else {
        return "Profile '\(profileName)' not found. Available profiles: \(profiles.joined(separator: ", "))"
      }
    }

    do {
      try await AppStoreConnectClient.shared.configure(credentials: credentials)
      return nil  // Success
    } catch {
      return "Failed to configure ASC client: \(error.localizedDescription)"
    }
  }

  // MARK: - ASC Device Management

  struct ASCDeviceInfo: Encodable {
    let id: String
    let name: String
    let platform: String
    let udid: String
    let deviceClass: String
    let status: String
    let model: String?
  }

  struct ASCListDevicesResult: Encodable {
    let success: Bool
    let devices: [ASCDeviceInfo]?
    let count: Int?
    let error: String?
  }

  struct ASCRegisterDeviceResult: Encodable {
    let success: Bool
    let device: ASCDeviceInfo?
    let alreadyRegistered: Bool?
    let error: String?
  }

  static func ascListDevices(arguments: [String: Any]) async throws -> String {
    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCListDevicesResult(
        success: false,
        devices: nil,
        count: nil,
        error: error
      ))
    }

    let platform = arguments["platform"] as? String
    let status = arguments["status"] as? String

    do {
      let devices = try await AppStoreConnectClient.shared.listDevices(platform: platform, status: status)
      let deviceInfos = devices.map { device in
        ASCDeviceInfo(
          id: device.id,
          name: device.attributes.name,
          platform: device.attributes.platform,
          udid: device.attributes.udid,
          deviceClass: device.attributes.deviceClass,
          status: device.attributes.status,
          model: device.attributes.model
        )
      }
      return encodeJSON(ASCListDevicesResult(
        success: true,
        devices: deviceInfos,
        count: deviceInfos.count,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCListDevicesResult(
        success: false,
        devices: nil,
        count: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCListDevicesResult(
        success: false,
        devices: nil,
        count: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascRegisterDevice(arguments: [String: Any]) async throws -> String {
    guard let name = arguments["name"] as? String else {
      throw ToolError.missingArgument("name")
    }
    guard let udid = arguments["udid"] as? String else {
      throw ToolError.missingArgument("udid")
    }
    let platform = arguments["platform"] as? String ?? "IOS"

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCRegisterDeviceResult(
        success: false,
        device: nil,
        alreadyRegistered: nil,
        error: error
      ))
    }

    do {
      // Check if device already registered
      if let existing = try await AppStoreConnectClient.shared.findDevice(udid: udid) {
        let deviceInfo = ASCDeviceInfo(
          id: existing.id,
          name: existing.attributes.name,
          platform: existing.attributes.platform,
          udid: existing.attributes.udid,
          deviceClass: existing.attributes.deviceClass,
          status: existing.attributes.status,
          model: existing.attributes.model
        )
        return encodeJSON(ASCRegisterDeviceResult(
          success: true,
          device: deviceInfo,
          alreadyRegistered: true,
          error: nil
        ))
      }

      // Register new device
      let device = try await AppStoreConnectClient.shared.registerDevice(name: name, udid: udid, platform: platform)
      let deviceInfo = ASCDeviceInfo(
        id: device.id,
        name: device.attributes.name,
        platform: device.attributes.platform,
        udid: device.attributes.udid,
        deviceClass: device.attributes.deviceClass,
        status: device.attributes.status,
        model: device.attributes.model
      )
      return encodeJSON(ASCRegisterDeviceResult(
        success: true,
        device: deviceInfo,
        alreadyRegistered: false,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCRegisterDeviceResult(
        success: false,
        device: nil,
        alreadyRegistered: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCRegisterDeviceResult(
        success: false,
        device: nil,
        alreadyRegistered: nil,
        error: error.localizedDescription
      ))
    }
  }

  // MARK: - ASC Profile Management

  struct ASCProfileInfo: Encodable {
    let id: String
    let name: String
    let profileType: String
    let profileState: String
    let uuid: String?
    let expirationDate: String?
  }

  struct ASCListProfilesResult: Encodable {
    let success: Bool
    let profiles: [ASCProfileInfo]?
    let count: Int?
    let error: String?
  }

  struct ASCCreateProfileResult: Encodable {
    let success: Bool
    let profile: ASCProfileInfo?
    let error: String?
  }

  struct ASCDeleteProfileResult: Encodable {
    let success: Bool
    let error: String?
  }

  struct ASCDownloadProfileResult: Encodable {
    let success: Bool
    let path: String?
    let profileName: String?
    let error: String?
  }

  struct ASCRegenerateProfileResult: Encodable {
    let success: Bool
    let deletedProfile: String?
    let newProfile: ASCProfileInfo?
    let downloadPath: String?
    let deviceCount: Int?
    let error: String?
  }

  static func ascListProfiles(arguments: [String: Any]) async throws -> String {
    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCListProfilesResult(
        success: false,
        profiles: nil,
        count: nil,
        error: error
      ))
    }

    let profileType = arguments["profile_type"] as? String
    let bundleId = arguments["bundle_id"] as? String

    do {
      let profiles: [ProfileData]
      if let bundleId = bundleId {
        profiles = try await AppStoreConnectClient.shared.findProfiles(bundleId: bundleId, profileType: profileType)
      } else {
        profiles = try await AppStoreConnectClient.shared.listProfiles(profileType: profileType)
      }

      let profileInfos = profiles.map { profile in
        ASCProfileInfo(
          id: profile.id,
          name: profile.attributes.name,
          profileType: profile.attributes.profileType,
          profileState: profile.attributes.profileState,
          uuid: profile.attributes.uuid,
          expirationDate: profile.attributes.expirationDate
        )
      }

      return encodeJSON(ASCListProfilesResult(
        success: true,
        profiles: profileInfos,
        count: profileInfos.count,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCListProfilesResult(
        success: false,
        profiles: nil,
        count: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCListProfilesResult(
        success: false,
        profiles: nil,
        count: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascCreateProfile(arguments: [String: Any]) async throws -> String {
    guard let name = arguments["name"] as? String else {
      throw ToolError.missingArgument("name")
    }
    guard let bundleId = arguments["bundle_id"] as? String else {
      throw ToolError.missingArgument("bundle_id")
    }
    let profileType = arguments["profile_type"] as? String ?? "IOS_APP_DEVELOPMENT"

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCCreateProfileResult(
        success: false,
        profile: nil,
        error: error
      ))
    }

    do {
      // Find the bundle ID record
      guard let bundleIdRecord = try await AppStoreConnectClient.shared.findBundleId(identifier: bundleId) else {
        return encodeJSON(ASCCreateProfileResult(
          success: false,
          profile: nil,
          error: "Bundle ID '\(bundleId)' not found in App Store Connect"
        ))
      }

      // Get certificates
      let certificates: [CertificateListResponse.CertificateData]
      if profileType.contains("DEVELOPMENT") {
        certificates = try await AppStoreConnectClient.shared.findDevelopmentCertificates()
      } else {
        certificates = try await AppStoreConnectClient.shared.findDistributionCertificates()
      }

      guard !certificates.isEmpty else {
        return encodeJSON(ASCCreateProfileResult(
          success: false,
          profile: nil,
          error: "No valid certificates found for profile type \(profileType)"
        ))
      }

      // Get devices for development/adhoc profiles
      var deviceIds: [String]? = nil
      if profileType.contains("DEVELOPMENT") || profileType.contains("ADHOC") {
        let devices = try await AppStoreConnectClient.shared.listDevices(platform: "IOS", status: "ENABLED")
        deviceIds = devices.map { $0.id }
      }

      // Create the profile
      let profile = try await AppStoreConnectClient.shared.createProfile(
        name: name,
        profileType: profileType,
        bundleIdId: bundleIdRecord.id,
        certificateIds: certificates.map { $0.id },
        deviceIds: deviceIds
      )

      let profileInfo = ASCProfileInfo(
        id: profile.id,
        name: profile.attributes.name,
        profileType: profile.attributes.profileType,
        profileState: profile.attributes.profileState,
        uuid: profile.attributes.uuid,
        expirationDate: profile.attributes.expirationDate
      )

      return encodeJSON(ASCCreateProfileResult(
        success: true,
        profile: profileInfo,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCCreateProfileResult(
        success: false,
        profile: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCCreateProfileResult(
        success: false,
        profile: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascDeleteProfile(arguments: [String: Any]) async throws -> String {
    guard let profileId = arguments["profile_id"] as? String else {
      throw ToolError.missingArgument("profile_id")
    }

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCDeleteProfileResult(
        success: false,
        error: error
      ))
    }

    do {
      try await AppStoreConnectClient.shared.deleteProfile(id: profileId)
      return encodeJSON(ASCDeleteProfileResult(
        success: true,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCDeleteProfileResult(
        success: false,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCDeleteProfileResult(
        success: false,
        error: error.localizedDescription
      ))
    }
  }

  static func ascDownloadProfile(arguments: [String: Any]) async throws -> String {
    guard let profileId = arguments["profile_id"] as? String else {
      throw ToolError.missingArgument("profile_id")
    }
    let outputPath = arguments["output_path"] as? String

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCDownloadProfileResult(
        success: false,
        path: nil,
        profileName: nil,
        error: error
      ))
    }

    do {
      // Get profile details first to get UUID for filename
      let profile = try await AppStoreConnectClient.shared.getProfile(id: profileId)

      // Determine output path
      let finalPath: String
      if let outputPath = outputPath {
        finalPath = (outputPath as NSString).expandingTildeInPath
      } else {
        // Install to provisioning profiles directory
        let uuid = profile.attributes.uuid ?? profileId
        let profilesDir = FileManager.default.homeDirectoryForCurrentUser
          .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")
        // Create directory if needed
        try FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
        finalPath = profilesDir.appendingPathComponent("\(uuid).mobileprovision").path
      }

      try await AppStoreConnectClient.shared.downloadProfile(id: profileId, to: finalPath)

      return encodeJSON(ASCDownloadProfileResult(
        success: true,
        path: finalPath,
        profileName: profile.attributes.name,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCDownloadProfileResult(
        success: false,
        path: nil,
        profileName: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCDownloadProfileResult(
        success: false,
        path: nil,
        profileName: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascRegenerateProfile(arguments: [String: Any]) async throws -> String {
    guard let bundleId = arguments["bundle_id"] as? String else {
      throw ToolError.missingArgument("bundle_id")
    }
    let profileType = arguments["profile_type"] as? String ?? "IOS_APP_DEVELOPMENT"

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCRegenerateProfileResult(
        success: false,
        deletedProfile: nil,
        newProfile: nil,
        downloadPath: nil,
        deviceCount: nil,
        error: error
      ))
    }

    do {
      // Find existing profile
      let existingProfiles = try await AppStoreConnectClient.shared.findProfiles(bundleId: bundleId, profileType: profileType)
      var deletedProfileName: String? = nil

      // Delete existing profile if found
      if let existing = existingProfiles.first {
        deletedProfileName = existing.attributes.name
        try await AppStoreConnectClient.shared.deleteProfile(id: existing.id)
      }

      // Find bundle ID record
      guard let bundleIdRecord = try await AppStoreConnectClient.shared.findBundleId(identifier: bundleId) else {
        return encodeJSON(ASCRegenerateProfileResult(
          success: false,
          deletedProfile: deletedProfileName,
          newProfile: nil,
          downloadPath: nil,
          deviceCount: nil,
          error: "Bundle ID '\(bundleId)' not found in App Store Connect"
        ))
      }

      // Get certificates
      let certificates: [CertificateListResponse.CertificateData]
      if profileType.contains("DEVELOPMENT") {
        certificates = try await AppStoreConnectClient.shared.findDevelopmentCertificates()
      } else {
        certificates = try await AppStoreConnectClient.shared.findDistributionCertificates()
      }

      guard !certificates.isEmpty else {
        return encodeJSON(ASCRegenerateProfileResult(
          success: false,
          deletedProfile: deletedProfileName,
          newProfile: nil,
          downloadPath: nil,
          deviceCount: nil,
          error: "No valid certificates found for profile type \(profileType)"
        ))
      }

      // Get all enabled devices
      var deviceIds: [String]? = nil
      var deviceCount = 0
      if profileType.contains("DEVELOPMENT") || profileType.contains("ADHOC") {
        let devices = try await AppStoreConnectClient.shared.listDevices(platform: "IOS", status: "ENABLED")
        deviceIds = devices.map { $0.id }
        deviceCount = devices.count
      }

      // Create new profile with auto-generated name
      let profileName = deletedProfileName ?? "\(bundleId) \(profileType)"
      let profile = try await AppStoreConnectClient.shared.createProfile(
        name: profileName,
        profileType: profileType,
        bundleIdId: bundleIdRecord.id,
        certificateIds: certificates.map { $0.id },
        deviceIds: deviceIds
      )

      // Download and install the profile
      let uuid = profile.attributes.uuid ?? profile.id
      let profilesDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/MobileDevice/Provisioning Profiles")
      try FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
      let downloadPath = profilesDir.appendingPathComponent("\(uuid).mobileprovision").path

      try await AppStoreConnectClient.shared.downloadProfile(id: profile.id, to: downloadPath)

      let profileInfo = ASCProfileInfo(
        id: profile.id,
        name: profile.attributes.name,
        profileType: profile.attributes.profileType,
        profileState: profile.attributes.profileState,
        uuid: profile.attributes.uuid,
        expirationDate: profile.attributes.expirationDate
      )

      return encodeJSON(ASCRegenerateProfileResult(
        success: true,
        deletedProfile: deletedProfileName,
        newProfile: profileInfo,
        downloadPath: downloadPath,
        deviceCount: deviceCount,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCRegenerateProfileResult(
        success: false,
        deletedProfile: nil,
        newProfile: nil,
        downloadPath: nil,
        deviceCount: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCRegenerateProfileResult(
        success: false,
        deletedProfile: nil,
        newProfile: nil,
        downloadPath: nil,
        deviceCount: nil,
        error: error.localizedDescription
      ))
    }
  }

  // MARK: - Certificate Tools

  struct ASCCertificateInfo: Encodable {
    let id: String
    let name: String?
    let displayName: String?
    let certificateType: String
    let expirationDate: String?
    let serialNumber: String?
  }

  struct ASCListCertificatesResult: Encodable {
    let success: Bool
    let certificates: [ASCCertificateInfo]?
    let count: Int?
    let error: String?
  }

  struct ASCCreateCertificateResult: Encodable {
    let success: Bool
    let certificate: ASCCertificateInfo?
    let downloadPath: String?
    let keychainInstalled: Bool?
    let error: String?
    let hint: String?
  }

  struct ASCRevokeCertificateResult: Encodable {
    let success: Bool
    let certificateId: String?
    let error: String?
  }

  static func ascListCertificates(arguments: [String: Any]) async throws -> String {
    let certificateType = arguments["certificate_type"] as? String

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCListCertificatesResult(
        success: false,
        certificates: nil,
        count: nil,
        error: error
      ))
    }

    do {
      let certs = try await AppStoreConnectClient.shared.listCertificates(certificateType: certificateType)

      let certInfos = certs.map { cert in
        ASCCertificateInfo(
          id: cert.id,
          name: cert.attributes.name,
          displayName: cert.attributes.displayName,
          certificateType: cert.attributes.certificateType,
          expirationDate: cert.attributes.expirationDate,
          serialNumber: cert.attributes.serialNumber
        )
      }

      return encodeJSON(ASCListCertificatesResult(
        success: true,
        certificates: certInfos,
        count: certInfos.count,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCListCertificatesResult(
        success: false,
        certificates: nil,
        count: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCListCertificatesResult(
        success: false,
        certificates: nil,
        count: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascCreateCertificate(arguments: [String: Any]) async throws -> String {
    guard let certificateType = arguments["certificate_type"] as? String else {
      throw ToolError.missingArgument("certificate_type")
    }
    let commonName = arguments["common_name"] as? String ?? NSFullUserName()

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCCreateCertificateResult(
        success: false,
        certificate: nil,
        downloadPath: nil,
        keychainInstalled: nil,
        error: error,
        hint: nil
      ))
    }

    do {
      // Step 1: Generate a new private key and CSR using security command
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("xclaude-cert-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      let csrPath = tempDir.appendingPathComponent("CertificateSigningRequest.certSigningRequest").path
      let cerPath = tempDir.appendingPathComponent("certificate.cer").path

      // Generate CSR using openssl (more reliable than security command for CSR generation)
      let opensslKeyPath = tempDir.appendingPathComponent("private_key.pem").path

      // Generate private key
      let genKeyProcess = Process()
      genKeyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
      genKeyProcess.arguments = ["genrsa", "-out", opensslKeyPath, "2048"]
      try genKeyProcess.run()
      genKeyProcess.waitUntilExit()

      guard genKeyProcess.terminationStatus == 0 else {
        throw ToolError.commandFailed("Failed to generate private key")
      }

      // Generate CSR
      let genCsrProcess = Process()
      genCsrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
      genCsrProcess.arguments = [
        "req", "-new",
        "-key", opensslKeyPath,
        "-out", csrPath,
        "-subj", "/CN=\(commonName)/C=US"
      ]
      try genCsrProcess.run()
      genCsrProcess.waitUntilExit()

      guard genCsrProcess.terminationStatus == 0 else {
        throw ToolError.commandFailed("Failed to generate CSR")
      }

      // Read CSR content
      let csrContent = try String(contentsOfFile: csrPath, encoding: .utf8)

      // Step 2: Submit CSR to Apple
      let cert = try await AppStoreConnectClient.shared.createCertificate(
        csrContent: csrContent,
        certificateType: certificateType
      )

      // Step 3: Download certificate
      try await AppStoreConnectClient.shared.downloadCertificate(id: cert.id, to: cerPath)

      // Step 4: Import private key and certificate to keychain
      // Convert private key to PKCS12 format for import
      let p12Path = tempDir.appendingPathComponent("cert_with_key.p12").path

      // First we need to combine key and cert into p12
      // We need the cert in PEM format first
      let pemCertPath = tempDir.appendingPathComponent("certificate.pem").path
      let convertCertProcess = Process()
      convertCertProcess.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
      convertCertProcess.arguments = ["x509", "-inform", "DER", "-in", cerPath, "-out", pemCertPath]
      try convertCertProcess.run()
      convertCertProcess.waitUntilExit()

      // Create PKCS12 bundle
      let createP12Process = Process()
      createP12Process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
      createP12Process.arguments = [
        "pkcs12", "-export",
        "-inkey", opensslKeyPath,
        "-in", pemCertPath,
        "-out", p12Path,
        "-passout", "pass:"
      ]
      try createP12Process.run()
      createP12Process.waitUntilExit()

      // Import to keychain
      var keychainInstalled = false
      if createP12Process.terminationStatus == 0 {
        let importProcess = Process()
        importProcess.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        importProcess.arguments = [
          "import", p12Path,
          "-k", "login.keychain-db",
          "-P", "",
          "-T", "/usr/bin/codesign",
          "-T", "/usr/bin/security"
        ]
        try importProcess.run()
        importProcess.waitUntilExit()
        keychainInstalled = importProcess.terminationStatus == 0
      }

      // Save files to Downloads (keep .p12 which has private key + cert for manual import if needed)
      let baseName = (cert.attributes.name ?? certificateType).replacingOccurrences(of: ":", with: "")
      let finalCerPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/\(baseName)_\(cert.id.prefix(8)).cer").path
      let finalP12Path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/\(baseName)_\(cert.id.prefix(8)).p12").path
      try? FileManager.default.copyItem(atPath: cerPath, toPath: finalCerPath)
      try? FileManager.default.copyItem(atPath: p12Path, toPath: finalP12Path)
      try? FileManager.default.removeItem(at: tempDir)

      let certInfo = ASCCertificateInfo(
        id: cert.id,
        name: cert.attributes.name,
        displayName: cert.attributes.displayName,
        certificateType: cert.attributes.certificateType,
        expirationDate: cert.attributes.expirationDate,
        serialNumber: cert.attributes.serialNumber
      )

      var hint: String? = nil
      if !keychainInstalled {
        hint = "Certificate was created but automatic keychain import failed. Double-click the .p12 file at \(finalP12Path) to install manually (password is empty)."
      }

      return encodeJSON(ASCCreateCertificateResult(
        success: true,
        certificate: certInfo,
        downloadPath: finalCerPath,
        keychainInstalled: keychainInstalled,
        error: nil,
        hint: hint
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCCreateCertificateResult(
        success: false,
        certificate: nil,
        downloadPath: nil,
        keychainInstalled: nil,
        error: error.errorDescription,
        hint: nil
      ))
    } catch {
      return encodeJSON(ASCCreateCertificateResult(
        success: false,
        certificate: nil,
        downloadPath: nil,
        keychainInstalled: nil,
        error: error.localizedDescription,
        hint: nil
      ))
    }
  }

  static func ascRevokeCertificate(arguments: [String: Any]) async throws -> String {
    guard let certificateId = arguments["certificate_id"] as? String else {
      throw ToolError.missingArgument("certificate_id")
    }

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCRevokeCertificateResult(
        success: false,
        certificateId: nil,
        error: error
      ))
    }

    do {
      try await AppStoreConnectClient.shared.revokeCertificate(id: certificateId)

      return encodeJSON(ASCRevokeCertificateResult(
        success: true,
        certificateId: certificateId,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCRevokeCertificateResult(
        success: false,
        certificateId: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCRevokeCertificateResult(
        success: false,
        certificateId: nil,
        error: error.localizedDescription
      ))
    }
  }

  // MARK: - TestFlight Tools

  struct ASCTesterInfo: Encodable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let inviteType: String?
    let state: String?
  }

  struct ASCListTestersResult: Encodable {
    let success: Bool
    let testers: [ASCTesterInfo]?
    let count: Int?
    let error: String?
  }

  struct ASCAddTesterResult: Encodable {
    let success: Bool
    let tester: ASCTesterInfo?
    let alreadyExists: Bool?
    let error: String?
  }

  struct ASCRemoveTesterResult: Encodable {
    let success: Bool
    let error: String?
  }

  struct ASCGroupInfo: Encodable {
    let id: String
    let name: String
    let isInternal: Bool?
    let publicLinkEnabled: Bool?
  }

  struct ASCListGroupsResult: Encodable {
    let success: Bool
    let groups: [ASCGroupInfo]?
    let count: Int?
    let error: String?
  }

  struct ASCBuildInfo: Encodable {
    let id: String
    let version: String?
    let uploadedDate: String?
    let processingState: String?
    let expired: Bool?
  }

  struct ASCListBuildsResult: Encodable {
    let success: Bool
    let builds: [ASCBuildInfo]?
    let count: Int?
    let error: String?
  }

  struct ASCSetWhatsNewResult: Encodable {
    let success: Bool
    let locale: String?
    let whatsNew: String?
    let error: String?
  }

  struct ASCAppInfo: Encodable {
    let id: String
    let name: String
    let bundleId: String
  }

  struct ASCListAppsResult: Encodable {
    let success: Bool
    let apps: [ASCAppInfo]?
    let count: Int?
    let error: String?
  }

  static func ascListTesters(arguments: [String: Any]) async throws -> String {
    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCListTestersResult(
        success: false,
        testers: nil,
        count: nil,
        error: error
      ))
    }

    let appId = arguments["app_id"] as? String
    let groupId = arguments["group_id"] as? String

    do {
      let testers = try await AppStoreConnectClient.shared.listBetaTesters(appId: appId, groupId: groupId)
      let testerInfos = testers.map { tester in
        ASCTesterInfo(
          id: tester.id,
          email: tester.attributes.email,
          firstName: tester.attributes.firstName,
          lastName: tester.attributes.lastName,
          inviteType: tester.attributes.inviteType,
          state: tester.attributes.state
        )
      }
      return encodeJSON(ASCListTestersResult(
        success: true,
        testers: testerInfos,
        count: testerInfos.count,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCListTestersResult(
        success: false,
        testers: nil,
        count: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCListTestersResult(
        success: false,
        testers: nil,
        count: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascAddTester(arguments: [String: Any]) async throws -> String {
    guard let email = arguments["email"] as? String else {
      throw ToolError.missingArgument("email")
    }
    let firstName = arguments["first_name"] as? String
    let lastName = arguments["last_name"] as? String
    let groupIds = arguments["group_ids"] as? [String]

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCAddTesterResult(
        success: false,
        tester: nil,
        alreadyExists: nil,
        error: error
      ))
    }

    do {
      // Check if tester already exists
      if let existing = try await AppStoreConnectClient.shared.findBetaTester(email: email) {
        let testerInfo = ASCTesterInfo(
          id: existing.id,
          email: existing.attributes.email,
          firstName: existing.attributes.firstName,
          lastName: existing.attributes.lastName,
          inviteType: existing.attributes.inviteType,
          state: existing.attributes.state
        )
        return encodeJSON(ASCAddTesterResult(
          success: true,
          tester: testerInfo,
          alreadyExists: true,
          error: nil
        ))
      }

      // Create new tester
      let tester = try await AppStoreConnectClient.shared.createBetaTester(
        email: email,
        firstName: firstName,
        lastName: lastName,
        betaGroupIds: groupIds
      )
      let testerInfo = ASCTesterInfo(
        id: tester.id,
        email: tester.attributes.email,
        firstName: tester.attributes.firstName,
        lastName: tester.attributes.lastName,
        inviteType: tester.attributes.inviteType,
        state: tester.attributes.state
      )
      return encodeJSON(ASCAddTesterResult(
        success: true,
        tester: testerInfo,
        alreadyExists: false,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCAddTesterResult(
        success: false,
        tester: nil,
        alreadyExists: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCAddTesterResult(
        success: false,
        tester: nil,
        alreadyExists: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascRemoveTester(arguments: [String: Any]) async throws -> String {
    guard let email = arguments["email"] as? String else {
      throw ToolError.missingArgument("email")
    }

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCRemoveTesterResult(
        success: false,
        error: error
      ))
    }

    do {
      // Find tester by email
      guard let tester = try await AppStoreConnectClient.shared.findBetaTester(email: email) else {
        return encodeJSON(ASCRemoveTesterResult(
          success: false,
          error: "Tester not found: \(email)"
        ))
      }

      try await AppStoreConnectClient.shared.deleteBetaTester(id: tester.id)
      return encodeJSON(ASCRemoveTesterResult(
        success: true,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCRemoveTesterResult(
        success: false,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCRemoveTesterResult(
        success: false,
        error: error.localizedDescription
      ))
    }
  }

  static func ascListGroups(arguments: [String: Any]) async throws -> String {
    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCListGroupsResult(
        success: false,
        groups: nil,
        count: nil,
        error: error
      ))
    }

    let appId = arguments["app_id"] as? String

    do {
      let groups = try await AppStoreConnectClient.shared.listBetaGroups(appId: appId)
      let groupInfos = groups.map { group in
        ASCGroupInfo(
          id: group.id,
          name: group.attributes.name,
          isInternal: group.attributes.isInternalGroup,
          publicLinkEnabled: group.attributes.publicLinkEnabled
        )
      }
      return encodeJSON(ASCListGroupsResult(
        success: true,
        groups: groupInfos,
        count: groupInfos.count,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCListGroupsResult(
        success: false,
        groups: nil,
        count: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCListGroupsResult(
        success: false,
        groups: nil,
        count: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascListBuilds(arguments: [String: Any]) async throws -> String {
    guard let appId = arguments["app_id"] as? String else {
      throw ToolError.missingArgument("app_id")
    }
    let limit = arguments["limit"] as? Int ?? 10

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCListBuildsResult(
        success: false,
        builds: nil,
        count: nil,
        error: error
      ))
    }

    do {
      let builds = try await AppStoreConnectClient.shared.listBuilds(appId: appId, limit: limit)
      let buildInfos = builds.map { build in
        ASCBuildInfo(
          id: build.id,
          version: build.attributes.version,
          uploadedDate: build.attributes.uploadedDate,
          processingState: build.attributes.processingState,
          expired: build.attributes.expired
        )
      }
      return encodeJSON(ASCListBuildsResult(
        success: true,
        builds: buildInfos,
        count: buildInfos.count,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCListBuildsResult(
        success: false,
        builds: nil,
        count: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCListBuildsResult(
        success: false,
        builds: nil,
        count: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascSetWhatsNew(arguments: [String: Any]) async throws -> String {
    guard let buildId = arguments["build_id"] as? String else {
      throw ToolError.missingArgument("build_id")
    }
    guard let whatsNew = arguments["whats_new"] as? String else {
      throw ToolError.missingArgument("whats_new")
    }
    let locale = arguments["locale"] as? String ?? "en-US"

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCSetWhatsNewResult(
        success: false,
        locale: nil,
        whatsNew: nil,
        error: error
      ))
    }

    do {
      let localization = try await AppStoreConnectClient.shared.setWhatsNew(buildId: buildId, locale: locale, whatsNew: whatsNew)
      return encodeJSON(ASCSetWhatsNewResult(
        success: true,
        locale: localization.attributes.locale,
        whatsNew: localization.attributes.whatsNew,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCSetWhatsNewResult(
        success: false,
        locale: nil,
        whatsNew: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCSetWhatsNewResult(
        success: false,
        locale: nil,
        whatsNew: nil,
        error: error.localizedDescription
      ))
    }
  }

  static func ascListApps(arguments: [String: Any]) async throws -> String {
    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCListAppsResult(
        success: false,
        apps: nil,
        count: nil,
        error: error
      ))
    }

    do {
      let response: AppListResponse = try await AppStoreConnectClient.shared.get("apps", queryItems: [
        URLQueryItem(name: "limit", value: "200")
      ])
      let appInfos = response.data.map { app in
        ASCAppInfo(
          id: app.id,
          name: app.attributes.name,
          bundleId: app.attributes.bundleId
        )
      }
      return encodeJSON(ASCListAppsResult(
        success: true,
        apps: appInfos,
        count: appInfos.count,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCListAppsResult(
        success: false,
        apps: nil,
        count: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCListAppsResult(
        success: false,
        apps: nil,
        count: nil,
        error: error.localizedDescription
      ))
    }
  }

  // MARK: - ASC List Bundle IDs

  struct ASCListBundleIdsResult: Encodable {
    let success: Bool
    let bundleIds: [ASCBundleIdInfo]?
    let count: Int?
    let error: String?
  }

  struct ASCBundleIdInfo: Encodable {
    let id: String
    let identifier: String
    let name: String
    let platform: String?
  }

  static func ascListBundleIds(arguments: [String: Any]) async throws -> String {
    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCListBundleIdsResult(
        success: false,
        bundleIds: nil,
        count: nil,
        error: error
      ))
    }

    do {
      let bundleIds = try await AppStoreConnectClient.shared.listBundleIds()
      let infos = bundleIds.map { bid in
        ASCBundleIdInfo(
          id: bid.id,
          identifier: bid.attributes.identifier,
          name: bid.attributes.name,
          platform: bid.attributes.platform
        )
      }
      return encodeJSON(ASCListBundleIdsResult(
        success: true,
        bundleIds: infos,
        count: infos.count,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCListBundleIdsResult(
        success: false,
        bundleIds: nil,
        count: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCListBundleIdsResult(
        success: false,
        bundleIds: nil,
        count: nil,
        error: error.localizedDescription
      ))
    }
  }

  // MARK: - ASC Create Bundle ID

  struct ASCCreateBundleIdResult: Encodable {
    let success: Bool
    let bundleId: ASCBundleIdInfo?
    let error: String?
  }

  static func ascCreateBundleId(arguments: [String: Any]) async throws -> String {
    guard let identifier = arguments["identifier"] as? String else {
      throw ToolError.missingArgument("identifier")
    }
    guard let name = arguments["name"] as? String else {
      throw ToolError.missingArgument("name")
    }
    let platform = arguments["platform"] as? String ?? "IOS"

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCCreateBundleIdResult(
        success: false,
        bundleId: nil,
        error: error
      ))
    }

    do {
      let result = try await AppStoreConnectClient.shared.createBundleId(
        identifier: identifier,
        name: name,
        platform: platform
      )
      return encodeJSON(ASCCreateBundleIdResult(
        success: true,
        bundleId: ASCBundleIdInfo(
          id: result.id,
          identifier: result.attributes.identifier,
          name: result.attributes.name,
          platform: result.attributes.platform
        ),
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCCreateBundleIdResult(
        success: false,
        bundleId: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCCreateBundleIdResult(
        success: false,
        bundleId: nil,
        error: error.localizedDescription
      ))
    }
  }

  // MARK: - ASC Create App

  struct ASCCreateAppResult: Encodable {
    let success: Bool
    let app: ASCAppInfo?
    let error: String?
    let appleApiLimitation: Bool?
    let manualSteps: [String]?
  }

  static func ascCreateApp(arguments: [String: Any]) async throws -> String {
    guard let bundleIdIdentifier = arguments["bundle_id"] as? String else {
      throw ToolError.missingArgument("bundle_id")
    }
    guard let name = arguments["name"] as? String else {
      throw ToolError.missingArgument("name")
    }
    guard let sku = arguments["sku"] as? String else {
      throw ToolError.missingArgument("sku")
    }
    let primaryLocale = arguments["primary_locale"] as? String ?? "en-US"

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCCreateAppResult(
        success: false,
        app: nil,
        error: error,
        appleApiLimitation: nil,
        manualSteps: nil
      ))
    }

    do {
      // First find the bundle ID record
      guard let bundleIdRecord = try await AppStoreConnectClient.shared.findBundleId(identifier: bundleIdIdentifier) else {
        return encodeJSON(ASCCreateAppResult(
          success: false,
          app: nil,
          error: "Bundle ID '\(bundleIdIdentifier)' not found. Register it first with asc_create_bundle_id.",
          appleApiLimitation: nil,
          manualSteps: nil
        ))
      }

      let app = try await AppStoreConnectClient.shared.createApp(
        bundleIdId: bundleIdRecord.id,
        name: name,
        sku: sku,
        primaryLocale: primaryLocale
      )
      return encodeJSON(ASCCreateAppResult(
        success: true,
        app: ASCAppInfo(
          id: app.id,
          name: app.attributes.name,
          bundleId: app.attributes.bundleId
        ),
        error: nil,
        appleApiLimitation: nil,
        manualSteps: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      // Check for Apple's API limitation on creating apps
      if case .apiError(let code, _) = error, code == "FORBIDDEN_ERROR" {
        return encodeJSON(ASCCreateAppResult(
          success: false,
          app: nil,
          error: "Apple's App Store Connect API does not support creating apps programmatically. This is an Apple limitation, not a permissions issue.",
          appleApiLimitation: true,
          manualSteps: [
            "Go to https://appstoreconnect.apple.com",
            "Click the '+' button → 'New App'",
            "Select iOS platform",
            "Name: \(name)",
            "Bundle ID: \(bundleIdIdentifier) (select from dropdown)",
            "SKU: \(sku)",
            "Click 'Create'",
            "Then use asc_list_apps to get the app ID for further automation"
          ]
        ))
      }
      return encodeJSON(ASCCreateAppResult(
        success: false,
        app: nil,
        error: error.errorDescription,
        appleApiLimitation: nil,
        manualSteps: nil
      ))
    } catch {
      return encodeJSON(ASCCreateAppResult(
        success: false,
        app: nil,
        error: error.localizedDescription,
        appleApiLimitation: nil,
        manualSteps: nil
      ))
    }
  }

  // MARK: - ASC Create Group

  struct ASCCreateGroupResult: Encodable {
    let success: Bool
    let group: ASCGroupInfo?
    let error: String?
  }

  static func ascCreateGroup(arguments: [String: Any]) async throws -> String {
    guard let appId = arguments["app_id"] as? String else {
      throw ToolError.missingArgument("app_id")
    }
    guard let name = arguments["name"] as? String else {
      throw ToolError.missingArgument("name")
    }
    let isInternal = arguments["is_internal"] as? Bool ?? false
    let publicLinkEnabled = arguments["public_link_enabled"] as? Bool ?? false

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCCreateGroupResult(
        success: false,
        group: nil,
        error: error
      ))
    }

    do {
      let group = try await AppStoreConnectClient.shared.createBetaGroup(
        appId: appId,
        name: name,
        isInternal: isInternal,
        publicLinkEnabled: publicLinkEnabled
      )
      return encodeJSON(ASCCreateGroupResult(
        success: true,
        group: ASCGroupInfo(
          id: group.id,
          name: group.attributes.name,
          isInternal: group.attributes.isInternalGroup ?? false,
          publicLinkEnabled: group.attributes.publicLinkEnabled
        ),
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCCreateGroupResult(
        success: false,
        group: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCCreateGroupResult(
        success: false,
        group: nil,
        error: error.localizedDescription
      ))
    }
  }

  // MARK: - ASC Delete Group

  struct ASCDeleteGroupResult: Encodable {
    let success: Bool
    let groupId: String
    let error: String?
  }

  static func ascDeleteGroup(arguments: [String: Any]) async throws -> String {
    guard let groupId = arguments["group_id"] as? String else {
      throw ToolError.missingArgument("group_id")
    }

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCDeleteGroupResult(
        success: false,
        groupId: groupId,
        error: error
      ))
    }

    do {
      try await AppStoreConnectClient.shared.deleteBetaGroup(id: groupId)
      return encodeJSON(ASCDeleteGroupResult(
        success: true,
        groupId: groupId,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCDeleteGroupResult(
        success: false,
        groupId: groupId,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCDeleteGroupResult(
        success: false,
        groupId: groupId,
        error: error.localizedDescription
      ))
    }
  }

  // MARK: - ASC Add Build to Group

  struct ASCAddBuildToGroupResult: Encodable {
    let success: Bool
    let groupId: String?
    let buildId: String?
    let error: String?
  }

  static func ascAddBuildToGroup(arguments: [String: Any]) async throws -> String {
    guard let groupId = arguments["group_id"] as? String else {
      throw ToolError.missingArgument("group_id")
    }
    guard let buildId = arguments["build_id"] as? String else {
      throw ToolError.missingArgument("build_id")
    }

    if let error = await configureASCClient(arguments: arguments) {
      return encodeJSON(ASCAddBuildToGroupResult(
        success: false,
        groupId: nil,
        buildId: nil,
        error: error
      ))
    }

    do {
      try await AppStoreConnectClient.shared.addBuildToGroup(groupId: groupId, buildId: buildId)
      return encodeJSON(ASCAddBuildToGroupResult(
        success: true,
        groupId: groupId,
        buildId: buildId,
        error: nil
      ))
    } catch let error as AppStoreConnectClient.ASCError {
      return encodeJSON(ASCAddBuildToGroupResult(
        success: false,
        groupId: nil,
        buildId: nil,
        error: error.errorDescription
      ))
    } catch {
      return encodeJSON(ASCAddBuildToGroupResult(
        success: false,
        groupId: nil,
        buildId: nil,
        error: error.localizedDescription
      ))
    }
  }
}

enum ToolError: Error {
  case missingArgument(String)
  case commandFailed(String)
}
