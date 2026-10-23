# F-MCP-1, F-MCP-2, F-MCP-5: transport, host, and framing over HTTP.

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize"
}
HTTP 200
Content-Type: application/json
[Asserts]
jsonpath "$.jsonrpc" == "2.0"
jsonpath "$.id" == 1
jsonpath "$.result.serverInfo.name" == "harbor"
jsonpath "$.result.protocolVersion" == "2025-06-18"

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer not-a-real-token
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "initialize"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == -32001

POST http://127.0.0.1:{{port}}/mcp
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "initialize"
}
HTTP 401
[Asserts]
jsonpath "$.error.message" == "unauthorized"

POST http://127.0.0.1:{{port}}/mcp
Authorization: Basic {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "initialize"
}
HTTP 401

POST http://127.0.0.1:{{port}}/mcp
Host: evil.example
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "initialize"
}
HTTP 403
[Asserts]
jsonpath "$.error.message" == "host not allowed"

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "initialize"
}
HTTP 200

POST http://127.0.0.1:{{port}}/other
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "initialize"
}
HTTP 404

GET http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
HTTP 405

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "method": "notifications/initialized"
}
HTTP 202

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
file,fixtures/malformed.json;
HTTP 400
[Asserts]
jsonpath "$.error.code" == -32700

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "1.0",
  "id": 9,
  "method": "initialize"
}
HTTP 400

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 10,
  "method": "resources/list"
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32601
