# MCP task ownership

A task belongs to the client that created it. A client can read the status of, and stop, only its own tasks. Any other client, and any unknown identifier, gets the same `-32004` error, so a caller cannot tell whether another client's task exists.

## Sub-features

- `task-created-by-read`: A granted read or navigation creates a task owned by the calling client.
  - Intent: ownership is set by the server, never by the caller.
  - Behaviour: the task's owner is the client that made the call.
  - Outcome: the task identifier is returned in the response.
- `task-status-owner-only`: Reads the status of a task only for its owner.
  - Intent: one client cannot read another client's page output.
  - Behaviour: the owner check runs before the status is returned.
  - Outcome: the owner sees the state; anyone else gets `-32004`.
- `task-stop-owner-only`: Stops a task only for its owner.
  - Intent: one client cannot cancel another client's work.
  - Behaviour: the same owner check runs before the stop.
  - Outcome: the owner stops it; anyone else gets `-32004`.
- `unknown-task-indistinguishable`: An unknown identifier and a foreign identifier look the same.
  - Intent: a client cannot probe which identifiers exist.
  - Behaviour: both paths return `-32004` with `unknown task`.
  - Outcome: no information leaks through the error.

## How to get to it (user POV)

- HTTP: `POST http://127.0.0.1:<port>/mcp` with method `tools/call`, tool `task_status` or `stop_task`, and argument `taskId` set to the identifier returned by `read_page` or `navigate`.

## Verification Suites (Targeted Test Commands)

- **Unit Tests:** `swift test --filter HarborCoreTests` (covers `MCPDispatcherTests` "a client cannot read or stop another client's task").
- **Functional API Tests (Hurl):** `sh .verify/hurl.sh` runs `.verify/hurl/mcp-ownership.hurl`. The first request captures the task identifier from the response body with a regex and reuses it in later requests.
- **Allowlisted Verification:** `sh .verify/run.sh hurl`.
- **Preconditions:** the same as `mcp-transport`.

Steps (entries 1–5 of `mcp-ownership.hurl`):

1. **create-and-capture-task** (entries 1) — the reader creates a task and its identifier is captured.
   - Request: `tools/call` `read_page` with `site: example.com` and the reader token.
   - Why: a task exists that other clients can be tested against.
   - Expected: `HTTP 200`, the body contains a UUID captured as `task_id`, text contains `"state":"completed"`.
   - Impact: one task owned by the reader is recorded. A failure means the capture cannot run and every later step is meaningless.
2. **owner-reads-status** (entries 2) — the owner sees its own task.
   - Request: `tools/call` `task_status` with `taskId: {{task_id}}` and the reader token.
   - Why: the owner can follow its own work.
   - Expected: `HTTP 200`, text contains `"state":"completed"`.
   - Impact: no state changes.
3. **other-client-cannot-read-status** (entries 3) — the outsider cannot read the reader's task.
   - Request: `tools/call` `task_status` with `taskId: {{task_id}}` and the outsider token.
   - Why: page output stays with its owner.
   - Expected: `HTTP 200`, `$.error.code == -32004`.
   - Impact: no state changes.
4. **other-client-cannot-stop** (entries 4) — the outsider cannot stop the reader's task.
   - Request: `tools/call` `stop_task` with `taskId: {{task_id}}` and the outsider token.
   - Why: cancellation stays with its owner.
   - Expected: `HTTP 200`, `$.error.code == -32004`.
   - Impact: the task keeps its state. A failure here is a cross-client control bug.
5. **unknown-identifier-same-error** (entries 5) — an identifier that does not exist gets the same error as a foreign one.
   - Request: `tools/call` `task_status` with the all-zero UUID and the reader token.
   - Why: a client cannot tell foreign tasks from missing ones.
   - Expected: `HTTP 200`, `$.error.code == -32004`.
   - Impact: no state changes.

## Gotchas

- The capture regex matches the escaped `\"id\":\"` pair inside the JSON text. A change in how the server encodes the payload breaks step 1 first, and the failure looks like a missing capture, not an ownership bug.
- Ownership is checked against the client identifier. Two tokens that map to the same client identifier share tasks; the fixture never does this.
- Tasks are held in memory with no eviction. Long-running fixtures accumulate them. This is a recorded open finding (LOW) in `docs/security-audit.md`.
