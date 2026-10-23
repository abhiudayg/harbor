# Feature map

Index of Harbor's behaviour and the tests that prove it. Run everything with `sh .verify/run.sh all`.

## Feature contracts (Hurl, network API)

Each contract lists sub-features, entry points, the exact commands, and one step per Hurl entry.

| Contract | Behaviour | Hurl entries |
|---|---|---|
| [mcp-transport](features/mcp-transport.md) | Loopback listener, bearer auth, host check, JSON-RPC framing, request limits, routing | 12 |
| [mcp-tools](features/mcp-tools.md) | Tool list, gated tab listing, gated navigate, gated page read, untrusted output, tool errors | 12 |
| [mcp-ownership](features/mcp-ownership.md) | Task ownership for status and stop, indistinguishable unknown identifiers | 5 |

## Engine and browsing (PRD 7.1, 7.2, 7.3)

| ID | Behaviour | Suites |
|---|---|---|
| F-ENG-1 | Background contexts never use the persistent data store | WebKitEngineIntegrationTests |
| F-ENG-2 | Loading HTML and file URLs completes and exposes text | WebKitEngineIntegrationTests |
| F-ENG-3 | Navigation failures surface as typed errors | WebKitEngineIntegrationTests |
| F-TAB-1 | Spaces: create with trimmed name, reject blank | BrowserStoreTests |
| F-TAB-2 | Tabs open only in existing spaces; move between spaces | BrowserStoreTests |
| F-TAB-3 | Stale tabs (3 days) archive; pinned tabs never archive | BrowserStoreTests |
| F-TAB-4 | Activation restores archived tabs; hibernation keeps the space | BrowserStoreTests |
| F-TAB-5 | Unknown space or tab operations are rejected | BrowserStoreTests |

## Permissions and approvals (PRD 7.4.2, SEC-2, SEC-3)

| ID | Behaviour | Suites |
|---|---|---|
| F-PERM-1 | Default deny for ungranted ordinary actions | PermissionPolicyTests |
| F-PERM-2 | Sensitive actions require approval unless explicitly allowed | PermissionPolicyTests |
| F-PERM-3 | Explicit deny overrides allow; rules are site and action scoped | PermissionPolicyTests |
| F-APP-1 | Approvals start pending and resolve once | ApprovalServiceTests |
| F-APP-2 | Scope (once, task, site) is recorded | ApprovalServiceTests, AgentRunnerTests |

## Audit (PRD 7.7 ST-3, SEC-6, SEC-13)

| ID | Behaviour | Suites |
|---|---|---|
| F-AUD-1 | Entries form a SHA-256 hash chain; tampering, removal, and misplacement are detected | AuditLogTests |
| F-AUD-2 | Secret-named arguments are redacted | AuditLogTests |
| F-AUD-3 | Typed text is audited as length only; URLs drop query and fragment | AgentStepParsingTests, AgentRunnerTests |
| F-AUD-4 | Every step and every MCP call is audited, and the chain verifies | AgentRunnerTests, MCPDispatcherTests, AgentScenarioTests |

## Agent runtime (PRD 7.4.2, BG-1 to BG-6)

| ID | Behaviour | Suites |
|---|---|---|
| F-AGENT-1 | Steps are parsed and validated at the boundary (types, URLs, selectors, text limits) | AgentStepParsingTests |
| F-AGENT-2 | Allowed steps run; outputs are stored as untrusted text | AgentRunnerTests, AgentWebKitIntegrationTests |
| F-AGENT-3 | Sensitive steps wait for approval and never run before it | AgentRunnerTests, AgentScenarioTests |
| F-AGENT-4 | Denied approval fails the task without running the step | AgentRunnerTests, AgentScenarioTests |
| F-AGENT-5 | Site-scoped approval persists; task-scoped does not | AgentRunnerTests, AgentScenarioTests |
| F-AGENT-6 | Stop halts a waiting task; a held step never runs after stop | AgentRunnerTests, AgentScenarioTests |
| F-AGENT-7 | Driver errors fail the task and are audited | AgentRunnerTests |
| F-AGENT-8 | Driver executes clicks, typing, and reads against a live page | WebKitPageDriverIntegrationTests, AgentWebKitIntegrationTests |

## MCP server, in-process (PRD 7.5, MCP-1 to MCP-8, SEC-1, SEC-5)

| ID | Behaviour | Suites |
|---|---|---|
| F-MCP-1 | Loopback-only transport; other hosts rejected (DNS rebinding) | MCPDispatcherTests, MCPHTTPIntegrationTests |
| F-MCP-2 | Per-client bearer tokens; wrong, missing, or non-bearer credentials rejected | MCPDispatcherTests, MCPHTTPIntegrationTests |
| F-MCP-3 | Tokens are 32 CSPRNG bytes, stored as SHA-256 digests, compared in constant time | AccessTokenTests |
| F-MCP-4 | Body and header size limits enforced before parsing | HTTPRequestParserTests, MCPDispatcherTests, MCPHTTPIntegrationTests |
| F-MCP-5 | JSON-RPC 2.0 framing, notifications, method and tool errors | MCPDispatcherTests |
| F-MCP-6 | Client-level grants gate every tool; no grant means forbidden | MCPDispatcherTests, MCPScenarioTests |
| F-MCP-7 | Tasks are owner-scoped; other clients see unknown-task | MCPDispatcherTests |
| F-MCP-8 | Page text is labelled untrusted in every tool response | MCPDispatcherTests, MCPWebKitIntegrationTests, MCPScenarioTests |
| F-MCP-9 | End to end over HTTP against live WebKit | MCPWebKitIntegrationTests |

## Security and prompt injection (`docs/security-audit.md`)

| ID | Behaviour | Suites |
|---|---|---|
| F-SEC-1 | SSRF: internal and metadata addresses and non-web schemes are blocked at the boundary | DestinationPolicyTests, AgentStepParsingTests |
| F-SEC-2 | SSRF: the live driver refuses non-public destinations, including `file://` | WebKitPageDriverIntegrationTests |
| F-SEC-3 | Selectors and text are passed to JavaScript as bound data, not code | WebKitPageDriverIntegrationTests |
| F-SEC-4 | Page instructions cannot add steps or trigger actions (indirect prompt injection) | AgentRunnerTests, AgentWebKitIntegrationTests, MCPScenarioTests |
| F-SEC-5 | The access token never appears in audit records | MCPScenarioTests |
| F-SEC-6 | Static scan: no process execution, weak randomness, unsafe pointers, prints, hard-coded secrets, dynamic evaluation, weak hashes; loopback listener; CSPRNG tokens | `.verify/security.sh` |
| F-SEC-7 | Page text with quotes and braces cannot break the tool envelope | MCPScenarioTests |
| F-SEC-8 | A page read is refused when the live page belongs to another site | AgentRunnerTests |

## Known gaps (tracked, not yet proven)

- Redirect SSRF is enforced in code but has no offline fixture that redirects to an internal address through a public name. See `docs/security-audit.md`.
- DNS rebinding is not blocked. The policy checks names only.
- No connection-count or timeout limits on the HTTP listener.
- Tasks and audit entries are held in memory with no eviction or persistence.
- The app does not yet issue tokens, show approvals, or list clients. The fixture server uses environment-supplied tokens.
- The Hurl suites do not send bodies over 64 KiB, so the `413` path is proven only in-process.
