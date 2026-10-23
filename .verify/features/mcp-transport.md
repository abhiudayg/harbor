# MCP transport

The MCP server listens on the loopback interface only and answers JSON-RPC 2.0 over HTTP POST on `/mcp`. Each request must present a valid bearer token and a loopback Host header. Malformed, oversized, or unauthorised requests are refused before any tool runs, and each refusal has a fixed status code and JSON-RPC error.

## Sub-features

- `loopback-only-listener`: Accepts connections only on the loopback interface.
  - Intent: a remote host must never reach the browser's agent API.
  - Behaviour: the listener binds with a loopback-only interface requirement, and the dispatcher accepts only the Host names `127.0.0.1` and `localhost`.
  - Outcome: a request with any other Host header gets `403` with `host not allowed`.
- `bearer-auth`: Requires `Authorization: Bearer <token>` on every request.
  - Intent: only a client that was given a token may use the API.
  - Behaviour: the presented token is hashed and compared in constant time against each client's stored digest.
  - Outcome: a missing, wrong, or non-bearer credential gets `401` with `unauthorized`.
- `json-rpc-framing`: Parses JSON-RPC 2.0 envelopes and answers notifications.
  - Intent: clients use a standard protocol and get standard error codes.
  - Behaviour: malformed JSON gives `400` with `-32700`; a version other than `2.0` gives `400`; a request without an id gets `202` and no body; an unknown method gets `-32601` inside a `200`.
  - Outcome: the caller always receives a parseable JSON-RPC envelope.
- `request-limits`: Rejects oversized requests before parsing them.
  - Intent: a local client cannot exhaust memory with one request.
  - Behaviour: headers over 8 KiB get `431`; a declared body over 64 KiB gets `413`; a missing or non-numeric content length gets `400`.
  - Outcome: the connection is answered and closed without reading the oversized body.
- `routing`: Only `POST /mcp` reaches the dispatcher.
  - Intent: no other path or method exposes behaviour.
  - Behaviour: other paths get `404`; other methods on `/mcp` get `405`.
  - Outcome: the caller learns only the status.

## How to get to it (user POV)

- HTTP: `POST http://127.0.0.1:<port>/mcp` with headers `Authorization: Bearer <token>` and `Content-Type: application/json`. The port is chosen by the OS and published by the running app.
- The local base address is always `127.0.0.1`. The server does not listen on any other interface.

## Verification Suites (Targeted Test Commands)

- **Unit Tests:** `swift test --filter HarborCoreTests` (covers `HTTPRequestParserTests`, `MCPDispatcherTests`, `AccessTokenTests`).
- **Functional API Tests (Hurl):** `sh .verify/hurl.sh` runs `.verify/hurl/mcp-transport.hurl` against the `HarborFixtureServer` process it starts and stops.
- **Allowlisted Verification:** `sh .verify/run.sh hurl` (entry `hurl` in `.verify/verify.toml`).
- **Preconditions:** `swift build --product HarborFixtureServer` (the script builds it when missing), `openssl` for per-run tokens, and `hurl` 8 or later on `PATH`. The script sets no environment the caller must provide.

Steps (entries 1–12 of `mcp-transport.hurl`):

1. **initialize-with-valid-token** (entries 1, 6) — a reader client initialises the session.
   - Request: `POST /mcp`, reader bearer token, body `initialize` with id 1.
   - Why: a valid token reaches the dispatcher and receives server identity.
   - Expected: `HTTP 200`, `$.result.serverInfo.name == "harbor"`, `$.result.protocolVersion == "2025-06-18"`.
   - Impact: the session is initialised. A failure here means authentication or framing is broken for every client.
2. **reject-bad-credentials** (entries 2, 3, 4) — a wrong token, no token, and a Basic scheme all fail the same way.
   - Request: `POST /mcp` with `Bearer not-a-real-token`, with no Authorization header, and with `Basic <token>`.
   - Why: a credential that is not a valid bearer token never reaches a tool.
   - Expected: `HTTP 401` each time, `$.error.code == -32001` and `$.error.message == "unauthorized"` on the first two.
   - Impact: no state changes. A failure means an unauthenticated caller can reach the dispatcher.
3. **reject-foreign-host** (entries 5) — a request with `Host: evil.example` is refused.
   - Request: `POST /mcp` with `Host: evil.example` and a valid token.
   - Why: DNS-rebinding requests from a web page must not reach the API.
   - Expected: `HTTP 403`, `$.error.message == "host not allowed"`.
   - Impact: no state changes. A failure means a rebinding attack could reach the API.
4. **unknown-path-and-method** (entries 7, 8) — other paths and methods do not reach the API.
   - Request: `POST /other`, and `GET /mcp`, each with a valid token.
   - Why: only the one endpoint is exposed.
   - Expected: `HTTP 404` for `/other`, `HTTP 405` for `GET`.
   - Impact: no state changes.
5. **notification-has-no-body** (entries 9) — a notification gets `202`.
   - Request: `POST /mcp` with `notifications/initialized` and no id.
   - Why: notifications never produce a response body.
   - Expected: `HTTP 202`.
   - Impact: no state changes.
6. **malformed-json-rejected** (entries 10) — truncated JSON gets a parse error.
   - Request: `POST /mcp` with the body from `fixtures/malformed.json` (raw bytes, not valid JSON).
   - Why: framing errors are reported with the standard code.
   - Expected: `HTTP 400`, `$.error.code == -32700`.
   - Impact: no state changes.
7. **wrong-json-rpc-version-rejected** (entries 11) — a `jsonrpc` value other than `2.0` gets `400`.
   - Request: `POST /mcp` with `"jsonrpc": "1.0"`.
   - Why: only JSON-RPC 2.0 is accepted.
   - Expected: `HTTP 400`.
   - Impact: no state changes.
8. **unknown-method** (entries 12) — an unsupported method gets method-not-found.
   - Request: `POST /mcp` with method `resources/list`.
   - Why: unsupported methods fail with the standard code, not a crash.
   - Expected: `HTTP 200`, `$.error.code == -32601`.
   - Impact: no state changes.

## Gotchas

- The Hurl suite runs against a fixture server with fixed, known clients. It does not test the app's token issuance, which is not built yet.
- The Hurl suite cannot send a body over 64 KiB, so the `413` path is proven only by `HTTPRequestParserTests` and `MCPHTTPIntegrationTests`.
- The Host check accepts a bare `localhost` name. A process that can resolve `localhost` to something else on the machine is outside this threat model.
- Loopback is plain HTTP. Tokens are visible to any process with privileged access to loopback traffic. This is an accepted risk recorded in `docs/security-audit.md`.
