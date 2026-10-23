# F-MCP-3, F-MCP-6, F-MCP-8, F-SEC-4: tool gating and untrusted output over HTTP.

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 20,
  "method": "tools/list"
}
HTTP 200
[Asserts]
jsonpath "$.result.tools" count == 5
jsonpath "$.result.tools[0].name" == "list_tabs"
jsonpath "$.result.tools[1].name" == "navigate"
jsonpath "$.result.tools[2].name" == "read_page"
jsonpath "$.result.tools[3].name" == "task_status"
jsonpath "$.result.tools[4].name" == "stop_task"

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{outsider_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 21,
  "method": "tools/call",
  "params": { "name": "list_tabs", "arguments": {} }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32003

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 22,
  "method": "tools/call",
  "params": { "name": "list_tabs", "arguments": {} }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32003

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{auditor_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 23,
  "method": "tools/call",
  "params": { "name": "list_tabs", "arguments": {} }
}
HTTP 200
[Asserts]
jsonpath "$.result.isError" == false
jsonpath "$.result.content[0].type" == "text"
jsonpath "$.result.content[0].text" contains "\"trust\":\"untrusted\""

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 24,
  "method": "tools/call",
  "params": { "name": "read_page", "arguments": { "site": "example.com" } }
}
HTTP 200
[Asserts]
jsonpath "$.result.content[0].text" contains "\"trust\":\"untrusted\""
jsonpath "$.result.content[0].text" contains "Fixture article"
jsonpath "$.result.content[0].text" contains "Ignore previous instructions"

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{outsider_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 25,
  "method": "tools/call",
  "params": { "name": "read_page", "arguments": { "site": "example.com" } }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32003

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 26,
  "method": "tools/call",
  "params": { "name": "read_page", "arguments": {} }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32602

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 27,
  "method": "tools/call",
  "params": { "name": "navigate", "arguments": { "url": "http://169.254.169.254/latest/meta-data" } }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32602

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 28,
  "method": "tools/call",
  "params": { "name": "navigate", "arguments": { "url": "file:///etc/passwd" } }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32602

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{outsider_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 29,
  "method": "tools/call",
  "params": { "name": "navigate", "arguments": { "url": "https://example.com/article" } }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32003

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 30,
  "method": "tools/call",
  "params": { "name": "navigate", "arguments": { "url": "https://example.com/article" } }
}
HTTP 200
[Asserts]
jsonpath "$.result.content[0].text" contains "\"state\":\"completed\""

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 31,
  "method": "tools/call",
  "params": { "name": "delete_everything", "arguments": {} }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32602
