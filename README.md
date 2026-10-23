# Harbor: an open-source, agent-native browser for macOS

Harbor is a calm, sidebar-first web browser for macOS built on WebKit. It helps you triage tabs, and it lets AI agents work in the background on your behalf, with explicit permissions, approval gates, and a tamper-evident audit log. Harbor exposes a local [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server so compatible agents can read and act on browser state, under the same permissions you grant directly.

> **Status: pre-alpha.** The core engine is built and tested. The app shell is connected to it. The MCP server exists but the app does not start it yet, because token issuance is not built. See [Status](#status).

## Why Harbor

- **Agents with brakes.** Every agent action goes through one permission engine. Sensitive actions such as submitting forms, sending messages, purchases, deletions, downloads, and credential use pause for your approval.
- **Pages are data, not instructions.** Page content is labelled untrusted everywhere it leaves the browser, and no page text can add or run an action.
- **Local first.** The browser, the agent runtime, and the MCP server all run on your Mac. The MCP server listens on the loopback interface only.
- **Tab clutter, reduced.** Tabs idle for three days move to an archive. Pinned tabs never archive. Nothing closes without you.
- **Auditable.** Every agent step and every MCP call is recorded in a SHA-256 hash-chained log, with secret arguments redacted.

## Features

| Area | What works today |
|---|---|
| Spaces and tabs | Create spaces, open tabs in a space, move, pin, hibernate, archive stale tabs |
| Permissions | Default deny for ordinary actions. Sensitive actions require approval unless explicitly allowed. Explicit deny beats allow. |
| Approvals | Approve once, for a task, or for a site. Deny. Each request resolves once. |
| Agent runtime | Typed steps (navigate, read page, click, type, submit, send, download, fill credential). Validated at the boundary. Outputs stored as untrusted text. Stop at any time. |
| WebKit engine | Background contexts that never use the persistent data store. A driver that clicks, types, and reads live pages. Navigation that refuses non-public destinations. |
| MCP server | JSON-RPC 2.0 over HTTP on `127.0.0.1`. Bearer tokens compared in constant time. Host header check. Body and header size limits. Five tools: `list_tabs`, `navigate`, `read_page`, `task_status`, `stop_task`. |
| Audit log | Hash-chained entries. Typed text recorded as length only. URLs recorded without query strings. |
| macOS app | SwiftUI shell with a native chrome header, a sidebar of real tabs, and a live approval card that approves or denies pending agent actions. |

## Architecture

```
app/
├── Sources/
│   ├── HarborCore/        Engine, permissions, agent runtime, MCP server, audit (no UI)
│   │   ├── Agent/         Steps, tasks, the runner that enforces permissions
│   │   ├── Approvals/     Approval requests and decisions
│   │   ├── Audit/         Hash-chained audit log
│   │   ├── Content/       Untrusted-text wrapper
│   │   ├── Domain/        Spaces and tabs
│   │   ├── Engine/        WebKit engine and page driver
│   │   ├── MCP/           JSON-RPC dispatcher, HTTP transport, tools
│   │   ├── Permissions/   Action classes and the policy
│   │   ├── Security/      Access tokens and destination policy
│   │   └── Store/         Browser store (spaces, tabs, archiving)
│   ├── Harbor/            SwiftUI app shell
│   └── HarborFixtureServer/  Deterministic MCP server used by the API tests
└── Tests/                 Unit, integration, functional, and UI tests
.verify/                   Verification harness: allowlist, runners, Hurl suites, feature map
docs/                      Security audit
```

`HarborCore` has no UI dependency, so the engine is tested without a window.

## Quick start

Requirements: macOS 14 or later, Xcode 16 or later (Swift 6), and [Hurl](https://hurl.dev) for the API suites.

```sh
git clone https://github.com/abhiudayg/harbor.git
cd harbor/app
swift build
swift run Harbor
```

Run the full verification harness:

```sh
sh .verify/run.sh all
```

The harness runs its phases in order and writes logs to `.verify/artifacts/`. Run one phase with `sh .verify/run.sh unit` (or `integration`, `functional`, `ui`, `hurl`, `features`, `coverage`, `security`).

## MCP API

The server listens on `http://127.0.0.1:<port>/mcp`. Every request needs a bearer token and a loopback `Host` header.

```sh
curl -s http://127.0.0.1:$HARBOR_PORT/mcp \
  -H "Authorization: Bearer $HARBOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

Tools are granted per client. A client with no grant gets `-32003 forbidden`. Page text is returned inside a JSON string labelled `"trust":"untrusted"`.

| Tool | Purpose |
|---|---|
| `list_tabs` | List tabs (requires a read grant on all sites) |
| `navigate` | Open a public http or https URL |
| `read_page` | Read the text of a granted site's page |
| `task_status` | Read a task you own |
| `stop_task` | Stop a task you own |

The full contract for each endpoint, with step-by-step expectations, lives in [`.verify/features/`](.verify/features).

## Security

Harbor is built against an explicit threat model: indirect prompt injection from web pages, over-broad agent access, credential exposure, unauthorised local clients, and server-side request forgery. The audit, the controls behind each finding, and the open items are in [`docs/security-audit.md`](docs/security-audit.md).

Report security issues privately to the maintainer. Do not open a public issue for a vulnerability.

## Testing and verification

- **Unit** (`HarborCoreTests`): policy, store, approvals, audit, tokens, parsing, dispatcher.
- **Integration** (`HarborIntegrationTests`): real WebKit and real loopback sockets.
- **Functional** (`HarborFunctionalTests`): end-to-end agent and MCP scenarios, including prompt-injection regressions.
- **UI** (`HarborTests`): app model flows.
- **API** (`.verify/hurl/`): Hurl suites against a live server, one step per request, mapped in [`.verify/feature-map.md`](.verify/feature-map.md).
- **Static security scan** (`.verify/security.sh`): process execution, weak randomness, unsafe pointers, prints, hard-coded secrets, dynamic evaluation, weak hashes.

## Status

Built and verified:

- The core engine, with the policy, approval, audit, store, and runner logic covered by unit and functional tests.
- The WebKit engine and page driver, covered by integration tests against real pages.
- The MCP server over HTTP, covered by in-process tests and by Hurl suites against a live server.
- The app shell, bound to the core for tabs and approvals.

Not yet built:

- Token issuance, storage in the Keychain, rotation, and revocation. The app therefore does not start the MCP server.
- A privacy dashboard that lists connected clients.
- Persistent tasks and audit entries (they are in memory today).
- DNS-rebinding protection and connection limits on the listener (see the security audit).
- A planner. Steps are typed and entered by code. A language-model planner must enter through the same validated step boundary.
- Windows and Linux. Harbor targets macOS first.

The product requirements are maintained privately.

## Contributing

Work in small, reviewable commits. Use the [Conventional Commits](https://www.conventionalcommits.org) style: `feat:`, `fix:`, `test:`, `docs:`, `chore:`, `refactor:`, `perf:`, or `ci:`. Before you open a change, run `sh .verify/run.sh all` and make sure it passes. New behaviour needs a test, and a bug fix needs a regression test. Keep changes to a single outcome.

## License

Not yet decided. The proposal is MPL 2.0 for the browser and Apache 2.0 for the SDKs and the MCP server, pending legal review.
