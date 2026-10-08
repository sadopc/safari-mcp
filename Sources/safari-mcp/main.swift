import Foundation

// `safari-mcp --grab <json>` is the screenshot helper the server spawns for one capture.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--grab" {
    exit(Capture.helperMain(CommandLine.arguments[2]))
}

// stdio MCP server: one JSON-RPC message per line, handled in order on the main thread.
// stdin is read on its own thread so the main run loop stays free when idle: the first
// Apple Event registers the process with the window server, which then expects it to take
// events and otherwise reports it as "Not Responding" after the next app switch.
let server = Server()
Thread.detachNewThread {
    while let line = readLine(strippingNewline: true) {
        if line.isEmpty { continue }
        DispatchQueue.main.async { autoreleasepool { server.handle(line) } }
    }
    // Queued behind the requests already read, so they are answered before exiting.
    DispatchQueue.main.async { exit(0) }
}
RunLoop.main.run()
