import Foundation

/// MCP (Model Context Protocol) server implementation
/// Uses JSON-RPC 2.0 over stdio
public enum MCPServer {
  /// Server information
  static let name = "xclaude"
  static let version = "0.1.0"

  /// Run the MCP server, reading from stdin and writing to stdout
  public static func run() async {
    // Set up unbuffered I/O
    setbuf(stdout, nil)
    setbuf(stderr, nil)

    log("xclaude MCP server starting...")

    while let line = readLine() {
      guard !line.isEmpty else { continue }

      do {
        let response = try await handleRequest(line)
        print(response)
      } catch {
        let errorResponse = makeErrorResponse(id: nil, code: -32700, message: "Parse error: \(error)")
        print(errorResponse)
      }
    }
  }

  /// Handle a single JSON-RPC request
  static func handleRequest(_ json: String) async throws -> String {
    guard let data = json.data(using: .utf8) else {
      throw MCPError.invalidJSON
    }

    let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

    switch request.method {
      case "initialize":
        return handleInitialize(request)
      case "tools/list":
        return handleToolsList(request)
      case "tools/call":
        return await handleToolCall(request)
      default:
        return makeErrorResponse(
          id: request.id,
          code: -32601,
          message: "Method not found: \(request.method)"
        )
    }
  }

  /// Handle initialize request
  static func handleInitialize(_ request: JSONRPCRequest) -> String {
    let result: [String: Any] = [
      "protocolVersion": "2024-11-05",
      "capabilities": [
        "tools": [:] as [String: Any]
      ],
      "serverInfo": [
        "name": name,
        "version": version
      ]
    ]
    return makeSuccessResponse(id: request.id, result: result)
  }

  /// Handle tools/list request
  static func handleToolsList(_ request: JSONRPCRequest) -> String {
    let tools = MCPTools.allTools.map { tool in
      [
        "name": tool.name,
        "description": tool.description,
        "inputSchema": tool.inputSchema
      ] as [String: Any]
    }
    return makeSuccessResponse(id: request.id, result: ["tools": tools])
  }

  /// Handle tools/call request
  static func handleToolCall(_ request: JSONRPCRequest) async -> String {
    guard let params = request.params,
          let name = params["name"] as? String else {
      return makeErrorResponse(id: request.id, code: -32602, message: "Invalid params")
    }

    let arguments = params["arguments"] as? [String: Any] ?? [:]

    do {
      let result = try await MCPTools.call(name: name, arguments: arguments)
      return makeSuccessResponse(id: request.id, result: ["content": [["type": "text", "text": result]]])
    } catch {
      return makeErrorResponse(id: request.id, code: -32000, message: "\(error)")
    }
  }

  /// Create a success response
  static func makeSuccessResponse(id: RequestID?, result: [String: Any]) -> String {
    var response: [String: Any] = [
      "jsonrpc": "2.0",
      "result": result
    ]
    if let id = id {
      response["id"] = id.value
    }
    return toJSON(response)
  }

  /// Create an error response
  static func makeErrorResponse(id: RequestID?, code: Int, message: String) -> String {
    var response: [String: Any] = [
      "jsonrpc": "2.0",
      "error": [
        "code": code,
        "message": message
      ]
    ]
    if let id = id {
      response["id"] = id.value
    }
    return toJSON(response)
  }

  /// Convert dictionary to JSON string
  static func toJSON(_ dict: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let string = String(data: data, encoding: .utf8) else {
      return "{\"error\": \"Failed to serialize response\"}"
    }
    return string
  }

  /// Log to stderr (not stdout, which is for MCP communication)
  static func log(_ message: String) {
    FileHandle.standardError.write("\(message)\n".data(using: .utf8)!)
  }
}

/// JSON-RPC request structure
struct JSONRPCRequest: Decodable {
  let jsonrpc: String
  let method: String
  let id: RequestID?
  let params: [String: Any]?

  enum CodingKeys: String, CodingKey {
    case jsonrpc, method, id, params
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
    method = try container.decode(String.self, forKey: .method)
    id = try container.decodeIfPresent(RequestID.self, forKey: .id)

    // Decode params as raw JSON
    if let paramsData = try? container.decode(AnyCodable.self, forKey: .params) {
      params = paramsData.value as? [String: Any]
    } else {
      params = nil
    }
  }
}

/// Request ID can be string or number
struct RequestID: Decodable {
  let value: Any

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let intValue = try? container.decode(Int.self) {
      value = intValue
    } else if let stringValue = try? container.decode(String.self) {
      value = stringValue
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid ID type")
      )
    }
  }
}

/// Helper for decoding arbitrary JSON
struct AnyCodable: Decodable {
  let value: Any

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      value = NSNull()
    } else if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let array = try? container.decode([AnyCodable].self) {
      value = array.map { $0.value }
    } else if let dict = try? container.decode([String: AnyCodable].self) {
      value = dict.mapValues { $0.value }
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
      )
    }
  }
}

/// MCP errors
enum MCPError: Error {
  case invalidJSON
  case unknownTool(String)
}
