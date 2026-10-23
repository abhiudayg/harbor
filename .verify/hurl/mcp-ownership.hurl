# F-MCP-7: a task belongs to the client that created it. Other clients get unknown-task.

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 40,
  "method": "tools/call",
  "params": { "name": "read_page", "arguments": { "site": "example.com" } }
}
HTTP 200
[Captures]
task_id: regex /\\"id\\":\\"([0-9A-Fa-f-]{36})/
[Asserts]
jsonpath "$.result.content[0].text" contains "\"state\":\"completed\""

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 41,
  "method": "tools/call",
  "params": { "name": "task_status", "arguments": { "taskId": "{{task_id}}" } }
}
HTTP 200
[Asserts]
jsonpath "$.result.content[0].text" contains "\"state\":\"completed\""

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{outsider_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 42,
  "method": "tools/call",
  "params": { "name": "task_status", "arguments": { "taskId": "{{task_id}}" } }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32004

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{outsider_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 43,
  "method": "tools/call",
  "params": { "name": "stop_task", "arguments": { "taskId": "{{task_id}}" } }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32004

POST http://127.0.0.1:{{port}}/mcp
Authorization: Bearer {{reader_token}}
Content-Type: application/json
{
  "jsonrpc": "2.0",
  "id": 44,
  "method": "tools/call",
  "params": { "name": "task_status", "arguments": { "taskId": "00000000-0000-0000-0000-000000000000" } }
}
HTTP 200
[Asserts]
jsonpath "$.error.code" == -32004
