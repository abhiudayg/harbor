#!/bin/sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${HARBOR_VERIFY_OUT:-$ROOT/.verify/artifacts/hurl}"
FIXTURE="$ROOT/app/.build/debug/HarborFixtureServer"
PORT_FILE="$OUT/fixture.port"
TIMEOUT_TICKS=100
mkdir -p "$OUT"
rm -f "$PORT_FILE"

if [ ! -x "$FIXTURE" ]; then
    (cd "$ROOT/app" && swift build --product HarborFixtureServer) || exit 1
fi

READER_TOKEN="$(openssl rand -base64 32)"
OUTSIDER_TOKEN="$(openssl rand -base64 32)"
AUDITOR_TOKEN="$(openssl rand -base64 32)"

HARBOR_FIXTURE_TOKEN_READER="$READER_TOKEN" \
HARBOR_FIXTURE_TOKEN_OUTSIDER="$OUTSIDER_TOKEN" \
HARBOR_FIXTURE_TOKEN_AUDITOR="$AUDITOR_TOKEN" \
HARBOR_FIXTURE_PORT_FILE="$PORT_FILE" \
"$FIXTURE" >"$OUT/fixture.log" 2>&1 &
FIXTURE_PID=$!

ticks=0
while [ ! -s "$PORT_FILE" ] && [ "$ticks" -lt "$TIMEOUT_TICKS" ]; do
    if ! kill -0 "$FIXTURE_PID" 2>/dev/null; then
        echo "fixture exited before publishing its port; see $OUT/fixture.log"
        exit 1
    fi
    sleep 0.2
    ticks=$((ticks + 1))
done
if [ ! -s "$PORT_FILE" ]; then
    kill "$FIXTURE_PID" 2>/dev/null
    echo "fixture did not publish a port within 20 seconds"
    exit 1
fi
PORT="$(cat "$PORT_FILE")"

cd "$ROOT/.verify/hurl" || exit 1
hurl --test \
    --variable "port=$PORT" \
    --variable "reader_token=$READER_TOKEN" \
    --variable "outsider_token=$OUTSIDER_TOKEN" \
    --variable "auditor_token=$AUDITOR_TOKEN" \
    mcp-transport.hurl mcp-tools.hurl mcp-ownership.hurl >"$OUT/hurl.log" 2>&1
status=$?

kill "$FIXTURE_PID" 2>/dev/null
wait "$FIXTURE_PID" 2>/dev/null
echo "hurl exit=$status port=$PORT"
echo "artifacts: $OUT"
exit "$status"
