import Foundation

struct ToolError: Error {
    let msg: String
    init(_ msg: String) { self.msg = msg }
}

enum Content {
    case text(String)
    case image(base64: String, mime: String)

    var json: [String: Any] {
        switch self {
        case .text(let t): return ["type": "text", "text": t]
        case .image(let d, let m): return ["type": "image", "data": d, "mimeType": m]
        }
    }
}

func jsonString(_ value: Any) -> String {
    let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes])
    return data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
}

final class Server {
    static let versions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
    static let instructions =
        "Drives the user's real Safari. Prefer read over screenshot. Refs (e12) come from read and die on navigation. `tab` defaults to the last tab used."

    private let tools = Tools()
    private let out = FileHandle.standardOutput

    func handle(_ line: String) {
        guard let data = line.data(using: .utf8),
              let msg = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            send(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Parse error"]])
            return
        }
        // Responses and notifications need no reply.
        guard let method = msg["method"] as? String, let id = msg["id"] else { return }
        let params = msg["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            let want = params["protocolVersion"] as? String ?? ""
            reply(id, [
                "protocolVersion": Server.versions.contains(want) ? want : Server.versions[0],
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "safari-mcp", "version": "0.1.0"],
                "instructions": Server.instructions,
            ])
        case "ping":
            reply(id, [String: Any]())
        case "tools/list":
            reply(id, ["tools": Tools.defs])
        case "tools/call":
            guard let name = params["name"] as? String, Tools.names.contains(name) else {
                fail(id, -32602, "Unknown tool: \(params["name"] as? String ?? "")")
                return
            }
            let args = params["arguments"] as? [String: Any] ?? [:]
            do {
                reply(id, ["content": try tools.call(name, args).map(\.json)])
            } catch let e as ToolError {
                reply(id, ["content": [Content.text(e.msg).json], "isError": true])
            } catch {
                reply(id, ["content": [Content.text("\(error)").json], "isError": true])
            }
        default:
            fail(id, -32601, "Method not found: \(method)")
        }
    }

    private func reply(_ id: Any, _ result: [String: Any]) {
        send(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private func fail(_ id: Any, _ code: Int, _ message: String) {
        send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    private func send(_ obj: [String: Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject: obj, options: [.withoutEscapingSlashes]) else { return }
        data.append(0x0A)
        out.write(data)
    }
}
