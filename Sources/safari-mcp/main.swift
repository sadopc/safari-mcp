import Foundation

// `safari-mcp --grab <json>` is the screenshot helper the server spawns for one capture.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--grab" {
    exit(Capture.helperMain(CommandLine.arguments[2]))
}

// stdio MCP server: one JSON-RPC message per line. Blocks on stdin when idle.
let server = Server()
while let line = readLine(strippingNewline: true) {
    if line.isEmpty { continue }
    autoreleasepool { server.handle(line) }
}
