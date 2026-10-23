# MCP tools

The MCP server exposes five tools: `list_tabs`, `navigate`, `read_page`, `task_status`, and `stop_task`. Every tool call is gated by the calling client's grants. Page content returned to a client is always labelled untrusted and is encoded as a JSON string, so page text cannot change the shape of a response.

## Sub-features

- `tools-list`: Lists the supported tools with their input properties.
  - Intent: clients discover the API without reading the source.
  - Behaviour: returns exactly five tools in a fixed order.
  - Outcome: the client knows which names it can call.
- `list-tabs-gated`: Returns tab titles and URLs only to a client with a read grant on every site.
  - Intent: tab metadata is sensitive, so a grant on one site is not enough.
  - Behaviour: checks the client's policy for read on the wildcard site before reading the store.
  - Outcome: no grant gives `-32003`; a wildcard read grant gives the list labelled untrusted.
- `navigate-gated`: Opens a public http or https URL as a task.
  - Intent: navigation to internal addresses is never possible through the API.
  - Behaviour: the URL passes the boundary parser (scheme, host, internal ranges) before any task exists. The client's navigate grant on the host decides whether the task runs.
  - Outcome: an internal URL gives `-32602`; no grant gives `-32003`; a granted public URL gives `completed`.
- `read-page-gated`: Reads the text of the page for a granted site.
  - Intent: a client reads only pages on sites it was granted, and only as untrusted text.
  - Behaviour: requires a site argument and a read grant on that site. The runner refuses if the live page belongs to another site.
  - Outcome: the text is returned labelled `"trust":"untrusted"`; an ungranted site gives `-32003`.
- `tool-errors`: Rejects unknown tools and missing arguments.
  - Intent: the API fails loudly and does not guess.
  - Behaviour: an unknown tool name gives `-32602`; a missing site gives `-32602`.
  - Outcome: the caller learns what was wrong.

## How to get to it (user POV)

- HTTP: `POST http://127.0.0.1:<port>/mcp` with body `{"jsonrpc":"2.0","id":<n>,"method":"tools/call","params":{"name":"<tool>","arguments":{...}}}`.
- Tool list: `POST /mcp` with method `tools/list`.

## Verification Suites (Targeted Test Commands)

- **Unit Tests:** `swift test --filter HarborCoreTests` (covers `MCPDispatcherTests`, `AgentStepParsingTests`).
- **Functional API Tests (Hurl):** `sh .verify/hurl.sh` runs `.verify/hurl/mcp-tools.hurl` against the fixture server.
- **Allowlisted Verification:** `sh .verify/run.sh hurl` (entry `hurl` in `.verify/verify.toml`).
- **Preconditions:** the same as `mcp-transport`: the fixture server is built by the script and stopped by it.

Steps (entries 1–12 of `mcp-tools.hurl`):

1. **tools-list-names-five-tools** (entries 1) — the reader sees the full tool list in order.
   - Request: `tools/list` with the reader token.
   - Why: clients discover exactly the supported API.
   - Expected: `HTTP 200`, `$.result.tools` count 5, names in order `list_tabs`, `navigate`, `read_page`, `task_status`, `stop_task`.
   - Impact: no state changes.
2. **list-tabs-denied-without-wildcard-grant** (entries 2, 3) — an outsider and a site-scoped reader are both refused.
   - Request: `tools/call` `list_tabs` with the outsider token, then with the reader token.
   - Why: a grant on one site does not expose every tab.
   - Expected: `HTTP 200`, `$.error.code == -32003` each time.
   - Impact: no state changes.
3. **list-tabs-untrusted-for-wildcard-grant** (entries 4) — the auditor receives the tab list labelled untrusted.
   - Request: `tools/call` `list_tabs` with the auditor token.
   - Why: tab titles come from pages and are labelled as such.
   - Expected: `HTTP 200`, `$.result.isError == false`, `$.result.content[0].type == "text"`, text contains `"trust":"untrusted"`.
   - Impact: no state changes.
4. **read-page-returns-untrusted-text** (entries 5) — a granted read returns labelled page text, including injected instructions as data.
   - Request: `tools/call` `read_page` with `site: example.com` and the reader token.
   - Why: the page text is returned as data; its instructions are never run.
   - Expected: `HTTP 200`, text contains `"trust":"untrusted"`, `Fixture article`, and `Ignore previous instructions`.
   - Impact: no state changes beyond the task record. A failure here means page text escapes its label.
5. **read-page-denied-to-outsider** (entries 6) — an ungranted client cannot read the page.
   - Request: `tools/call` `read_page` with `site: example.com` and the outsider token.
   - Why: reading a page requires a grant.
   - Expected: `HTTP 200`, `$.error.code == -32003`.
   - Impact: no state changes.
6. **read-page-requires-site** (entries 7) — the read without a site is rejected.
   - Request: `tools/call` `read_page` with empty arguments.
   - Why: a read must name the site it is authorised for.
   - Expected: `HTTP 200`, `$.error.code == -32602`.
   - Impact: no state changes.
7. **navigate-refuses-metadata-address** (entries 8) — a navigate to the cloud metadata address is rejected at the boundary.
   - Request: `tools/call` `navigate` with `http://169.254.169.254/latest/meta-data`.
   - Why: internal addresses are never reachable through the API.
   - Expected: `HTTP 200`, `$.error.code == -32602`.
   - Impact: no task is created.
8. **navigate-refuses-file-url** (entries 9) — a navigate to a file URL is rejected at the boundary.
   - Request: `tools/call` `navigate` with `file:///etc/passwd`.
   - Why: only web schemes can be navigated.
   - Expected: `HTTP 200`, `$.error.code == -32602`.
   - Impact: no task is created.
9. **navigate-denied-to-outsider** (entries 10) — an ungranted client cannot navigate.
   - Request: `tools/call` `navigate` with `https://example.com/article` and the outsider token.
   - Why: navigation requires a grant.
   - Expected: `HTTP 200`, `$.error.code == -32003`.
   - Impact: no task is created.
10. **navigate-completes-for-granted-client** (entries 11) — a granted public navigation completes.
    - Request: `tools/call` `navigate` with `https://example.com/article` and the reader token.
    - Why: a granted navigation runs and reports its state.
    - Expected: `HTTP 200`, text contains `"state":"completed"`.
    - Impact: one task is recorded, owned by the reader.
11. **unknown-tool-rejected** (entries 12) — a tool name that is not in the list is refused.
    - Request: `tools/call` `delete_everything` with the reader token.
    - Why: the API exposes only the listed tools.
    - Expected: `HTTP 200`, `$.error.code == -32602`.
    - Impact: no state changes.

## Gotchas

- `list_tabs` in the fixture returns an empty list. The tab-content path is covered by `MCPDispatcherTests` "list_tabs returns tab titles labelled untrusted", not by Hurl.
- Navigation in the fixture does not load a page, so the Hurl suite cannot prove that a navigation changes the page. WebKit navigation is covered by `WebKitEngineIntegrationTests`.
- The page text in the fixture is fixed. Hostile text is also covered by `MCPScenarioTests` F-SEC-7 with quotes and braces.
- A grant on `example.com` does not cover `www.example.com`. The host match is exact, so a subdomain needs its own grant.
