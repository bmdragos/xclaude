import XClaudeCore
import Foundation

// xclaude MCP server entry point
// Communicates via JSON-RPC over stdio

@main
struct XClaudeServer {
  static func main() async {
    await MCPServer.run()
  }
}
