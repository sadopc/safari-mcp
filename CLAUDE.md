# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`safari-mcp`: a local stdio MCP server that lets Claude Code drive the user's real Safari through Apple Events. One Swift binary, no dependencies, no browser extension, no daemon. It is an independent project; do not copy code from Anthropic's Claude in Chrome extension, do not use its OAuth token or bridge, and keep "Claude" out of the product name.

The README is written in Turkish and is the user-facing reference for setup, permissions and known limits.

## Commands

```bash
swift build -c release          # the binary Claude Code runs: .build/release/safari-mcp
Tests/smoke.sh                  # protocol test, needs no Safari permission
Tests/smoke.sh .build/debug/safari-mcp
```

Only Command Line Tools are installed (no Xcode), so there is no XCTest target; `Tests/smoke.sh` is the only automated test and covers the JSON-RPC layer only.

The page script is a JS string inside Swift. Syntax-check it after editing:

```bash
awk '/static let source = #"""/{f=1;next} /^    """#/{f=0} f' Sources/safari-mcp/PageAgent.swift > /tmp/agent.js && node --check /tmp/agent.js
```

Drive a tool by hand by piping JSON-RPC lines into the binary:

```bash
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"tabs","arguments":{}}}' | .build/release/safari-mcp
```

The server is registered at user scope (`claude mcp add --scope user safari -- <path>/.build/release/safari-mcp`). A running Claude Code session keeps the binary it started with: `mcp__safari__*` tools in the current session do not reflect a rebuild. Test a new build by piping into it, not through those tools.

Real-page behaviour can only be tested against the user's live Safari. Open your own tab with `tabs new`, work only there, and close it afterwards; the user is browsing in the same window.

## Architecture

Request path: `main.swift` (line loop on stdin) → `MCP.swift` (`Server`: JSON-RPC, lifecycle, tool errors as `isError`) → `Tools.swift` (the 8 tools and all tab/navigation logic) → `Safari.swift` (Apple Events) → `PageAgent.swift` (JS that runs inside the page).

### Safari bridge (`Safari.swift`)

One AppleScript source is compiled once; handlers are invoked by name with parameters via a subroutine Apple Event, so nothing is string-escaped or recompiled per call. `Safari` is created lazily because loading the AppleScript runtime costs about 25 MB.

Every tab-targeted handler takes an `Expect` (window tab count and tab URL) and checks it inside Safari, in the same Apple Event, before acting. A mismatch returns `"!"` and nothing runs. This is what stops a stale position from hitting another tab; do not add a tab-targeted handler without it.

### Tab identity (`Tools.swift`)

Safari only addresses tabs by `window id` + index, which shifts when tabs open, close or move. The server gives the model stable ids (`t3`) and maps them to positions:

- `sync()` re-lists tabs and carries ids over by aligning the old and new URL sequence per window (LCS). Unmatched tabs we have worked in are found by a handle stored in the page agent (`__smcp.h`); otherwise they are dropped and the model gets a "gone" error.
- `exec` runs checked JS (count + URL), `poll` runs it with the URL check off for use while a navigation is in flight, and both keep the tracked URL fresh. `guardedOp` is the same retry-after-`sync` loop for non-JS operations.
- A same-position URL change is trusted only within one host for tabs carrying a handle. This strictness is deliberate: losing an id costs the model one `tabs` call, adopting the wrong tab acts on the user's page.
- The default tab is the last one used. Once it is closed, `defaultLost` makes calls without `tab` fail instead of falling back to the user's visible tab.

### Navigation waits

`waitLoad` decides when a page change is done. Signals, in order of reliability:

- a marker (`window.__smcpOld = <mark>`) set on the document being left; `mark` is bumped after every wait so a marked page restored from the back-forward cache is not taken for the old one;
- Safari's tab URL versus `location.href`: they differ while a navigation is pending but not committed (`PageState.pending`);
- a `beforeunload` flag in the agent ("leaving").

`navigate` marks then waits; `act` and `js` call `settle`/a short check afterwards and append `→ title | url` when the page changed. When changing this code, the failure to avoid is a result that describes the previous page.

### Page agent (`PageAgent.swift`)

Injected once per document (`window.__smcp`), then each call is one small Apple Event. It owns: the element scan behind `read` (modes `interactive`/`all`/`text`, `query` search), the ref map (`e12` → `WeakRef`), synthetic input for `act`, console/fetch/XHR hooks for `logs`, and result slots for async `js`.

- Every `__smcp.call` carries the tab's handle and is a no-op on mismatch.
- `do JavaScript` does not await promises, so `js` starts the code, stores the result in a slot and polls `__smcp.take`.
- User code for `js` is embedded as an async function body, never `eval`'d (page CSP would block it).
- Clicks are dispatched to the innermost element under the target's centre (including through open shadow roots), as a real click would be.

### Screenshots (`Capture.swift`)

Capture uses ScreenCaptureKit in a child process: the server re-executes itself as `safari-mcp --grab <json>` and kills it after 6 s. A capture that never calls back blocks all later captures from processes of the same executable, so it must stay out of the long-lived server. macOS does not render windows on an inactive Space; when the window is not on screen, `screenshot` raises Safari briefly and then reactivates the previous app.

`Input.swift` sends real mouse/keyboard events via CGEvent for `os: true`. It needs Accessibility permission, raises Safari, and maps viewport coordinates to the screen through the page's scroll area found with the Accessibility API. Typed events must clear modifier flags, or a preceding key combo (cmd+a) leaks into them.

## Design constraints

- Token cost is a primary goal. Tool descriptions and schemas are sent every session (about 730 tokens total; `Tests/smoke.sh` prints the size). Tool results are terse single lines, `read` is capped by `max_chars` with an `offset` continuation, and screenshots are opt-in JPEGs. Keep additions equally short.
- No dependencies and no Xcode-only APIs. Deployment target is macOS 14 (ScreenCaptureKit screenshot API).
- stdout carries only JSON-RPC messages, one per line; anything else goes to stderr.
