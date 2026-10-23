# Security and jailbreak audit: HarborCore

Scope: `app/Sources/HarborCore` (agent runtime, permission engine, approvals, audit log, WebKit driver, MCP dispatcher and HTTP transport) and the `harbor-mcp-fixture` harness. Method: code review against the agstack `security-audit` checklist, a jailbreak and prompt-injection review of every path where page content can reach an action, static scan (`.verify/security.sh`), and live API tests (`.verify/hurl/`). Date: 2026-10-23.

## Summary

| Severity | Found | Fixed or mitigated | Open | Accepted |
|---|---|---|---|---|
| HIGH | 2 | 2 | 0 | 0 |
| MEDIUM | 5 | 2 | 2 | 1 |
| LOW | 4 | 0 | 3 | 1 |

No open HIGH findings remain. Open items are listed with their mitigations below.

## Findings

### [HIGH, fixed] Cross-site page read through `read_page`
- **What this is:** `read_page` takes a site from the client and reads whatever page the browser currently shows. A client granted `example.com` could read a page open on `bank.example`.
- **Threat vector / CWE:** CWE-639 (authorization bypass through user-controlled key). A granted client reads another site's content.
- **Defensive remediation:** `AgentRunner.process` refuses any page-acting step when `PageDriver.currentHost` differs from the task's site. Denials are audited with `denied: page is not on site`.
- **Proof of fix:** `AgentRunnerTests` "a page read is refused when the live page belongs to another site" and "a page read proceeds when the live page belongs to the granted site". Feature F-SEC-8.

### [HIGH, fixed] Driver navigated to non-public destinations
- **What this is:** The DTO boundary blocks internal URLs, but the driver accepted any `AgentStep.navigate` value, including `file://` URLs. The first integration run caught this: a `file://` navigation succeeded.
- **Threat vector / CWE:** CWE-918 (server-side request forgery) and local file read through the browser.
- **Defensive remediation:** `WebKitPageDriver` checks `DestinationPolicy.isAllowed` before loading. `NavigationWaiter` also cancels main-frame navigations to disallowed destinations and stops server redirects to them.
- **Proof of fix:** `WebKitPageDriverIntegrationTests` "the driver refuses to navigate to a non-public destination". Feature F-SEC-2.

### [MEDIUM, fixed] Secrets in audit URLs
- **What this is:** Audit records stored full navigation URLs, including query strings and fragments, which can carry tokens.
- **Threat vector / CWE:** CWE-532 (sensitive information in log files).
- **Defensive remediation:** `AgentStep.auditArguments` keeps only scheme, host, and path. Redaction by key name still applies to other arguments.
- **Proof of fix:** `AgentStepParsingTests` "audit arguments drop the query and fragment". Feature F-AUD-3.

### [MEDIUM, mitigated, not end to end] Redirect-based SSRF
- **What this is:** A public page can redirect the driver to `169.254.169.254` or another internal address. The initial destination check does not see redirects.
- **Defensive remediation:** `NavigationWaiter` implements `didReceiveServerRedirectForProvisionalNavigation` and `decidePolicyFor`, and stops navigation to disallowed destinations.
- **Gap:** No offline fixture can redirect to an internal address through a public hostname, so this path has no automated test. It is recorded as a known gap in the feature map.

### [MEDIUM, open] DNS rebinding
- **What this is:** `DestinationPolicy` checks host names and literal addresses. A public name that resolves to `127.0.0.1` passes the check.
- **Threat vector / CWE:** CWE-350 (reliance on reverse DNS) and rebinding.
- **Remediation options:** Resolve and pin addresses before navigation, which WebKit's public API does not allow directly. Route page traffic through a local proxy that enforces the policy on resolved addresses.
- **Status:** Open. Recorded as a known gap. It is not blocked in this build.

### [MEDIUM, open] Access-token lifecycle is not implemented in the app
- **What this is:** Tokens are generated and digested in `AccessToken`, but there is no issuance UI, Keychain storage, rotation, or revocation. The fixture server uses environment-supplied tokens.
- **Remediation:** Store the digest and show the token once at issuance. Store it in the Keychain, add revocation, and list clients in the privacy dashboard (ST-1, SEC-5).
- **Status:** Open. The server must not be started in the app until this exists.

### [MEDIUM, accepted] Plain HTTP on loopback
- **What this is:** The MCP transport is HTTP on `127.0.0.1` only. The bearer token is visible to any process that can read loopback traffic, which requires elevated privilege on macOS.
- **Decision:** Accepted for local MCP. A Unix domain socket with file permissions would remove the exposure and is the preferred follow-up.

### [LOW, open] No connection limits or timeouts on the listener
- **What this is:** `MCPHTTPServer` accepts unlimited concurrent connections and has no read timeout. A local process can hold connections open.
- **Threat vector / CWE:** CWE-400 (uncontrolled resource consumption).
- **Remediation:** Cap concurrent connections and add an idle timeout.

### [LOW, open] Unbounded in-memory tasks and audit entries
- **What this is:** Every `navigate` and `read_page` call creates a task and an audit entry. Nothing evicts them, and the audit log is not persisted yet. A client with a valid token can grow memory without bound.
- **Remediation:** Per-client quotas, task eviction after terminal states, and persisted audit with rotation.

### [LOW, open] Origin header is not checked
- **What this is:** Requests with an `Origin` header are not refused. Browser cross-origin requests cannot set `Authorization` without a CORS preflight, which the server does not answer, so the token requirement blocks this in practice.
- **Remediation:** Refuse any request that carries an `Origin` header. Defense in depth only.

### [LOW, accepted] Credential fill is not implemented
- **What this is:** `fillCredential` throws `unsupported` in the driver. No credential value can reach an agent.
- **Decision:** SEC-4 holds trivially today. When the Keychain path is added, it must follow the same approval gate and must never return the value to the runtime or the audit log.

## Jailbreak and prompt-injection assessment

The agent has no free-form action channel. Every action is a typed `AgentStep` produced by `AgentStep(dto:)`, which validates type, URL, selector, and text limits at the boundary. Page content is wrapped as `UntrustedText` and is only ever returned as output.

| Attack | Where it could land | Control | Evidence |
|---|---|---|---|
| Page text tells the agent to navigate or submit | Agent runtime | Steps are never derived from page text | `AgentRunnerTests` "page text containing instructions cannot add or run steps"; `AgentWebKitIntegrationTests` "a page instructing the agent to click does not make it click"; F-SEC-4 |
| Page text breaks out of the MCP response | JSON envelope | Page text is encoded as a JSON string value | `MCPScenarioTests` F-SEC-7; Hurl `mcp-tools.hurl` |
| Connected client is told by a page to act on another site | Client gating | Read and navigate are scoped by client grants and by the live page host | F-MCP-6, F-SEC-8 |
| Connected client asks for a sensitive action | Runner | Sensitive actions wait for approval unless explicitly allowed | `AgentRunnerTests` approval suite; F-AGENT-3 |
| Client reads another client's task | Ownership | Owner check on `task_status` and `stop_task` | `MCPDispatcherTests` "a client cannot read or stop another client's task"; `mcp-ownership.hurl` |
| Selector or text injected into page script | WebKit driver | Values bound as script arguments, never concatenated | `WebKitPageDriverIntegrationTests` "a selector that tries to break out of the script is passed as data, not code"; F-SEC-3 |

**Residual risk.** A connected LLM client can still be persuaded by a page to request actions that its own grants already allow, for example a read or navigation on a site it may use. The browser cannot control what a third-party model decides. The mitigations are narrow client grants, approval for sensitive actions, untrusted labelling, and the audit trail. The client-side model must be treated as untrusted input.

**Planner requirement.** When an LLM planner is added to the agent runtime, its output must enter only through `AgentStep(dto:)`. Any path that builds an `AgentStep` some other way is a regression and must fail review.

## Verification evidence

- `.verify/run.sh all` passes: unit 106, integration 23, functional 11, UI 3, Hurl 29 requests across 3 files, coverage 94.9% of lines in `HarborCore`, static scan 9 checks.
- Artifacts are kept under `.verify/artifacts/`.
