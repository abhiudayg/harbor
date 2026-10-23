#!/bin/sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${HARBOR_VERIFY_OUT:-$ROOT/.verify/artifacts/ui-live}"
APP="$ROOT/app/.build/Harbor.app"
BIN="$APP/Contents/MacOS/Harbor"
FAILED=0
mkdir -p "$OUT"

if pgrep -f "Harbor.app/Contents/MacOS/Harbor" >/dev/null 2>&1; then
    echo "FAIL another Harbor instance is running; quit it first (this script does not stop processes it did not start)"
    exit 1
fi

(cd "$ROOT" && task bundle) >"$OUT/build.log" 2>&1 || { echo "FAIL bundle; see $OUT/build.log"; exit 1; }

"$BIN" >"$OUT/harbor.log" 2>&1 &
APP_PID=$!

window_count() {
    osascript -e 'tell application "System Events" to tell process "Harbor" to get the count of windows' 2>/dev/null || echo 0
}

snapshot() {
    osascript -e 'tell application "System Events" to tell process "Harbor" to get entire contents of window 1' 2>>"$OUT/ax-error.log"
}

windows=0
ticks=0
while [ "$windows" -eq 0 ] && [ "$ticks" -lt 60 ]; do
    sleep 1
    ticks=$((ticks + 1))
    windows="$(window_count)"
done

if [ "$windows" -eq 0 ]; then
    echo "FAIL the Harbor window did not appear within 60 seconds"
    kill "$APP_PID" 2>/dev/null
    exit 1
fi
echo "PASS window appeared after ${ticks}s"

sleep 3
tree="$(snapshot)"
printf '%s\n' "$tree" >"$OUT/window-tree-initial.txt"

expect_text() {
    if printf '%s' "$tree" | grep -q "$1"; then
        echo "PASS window shows: $1"
    else
        echo "FAIL window does not show: $1"
        FAILED=1
    fi
}

expect_text "Cognitive Ergonomics"
expect_text "PINNED"
expect_text "Research"
expect_text "WORKSPACES"
expect_text "harbor://reading"
expect_text "SPACES"
expect_text "Systems"

if printf '%s' "$tree" | grep -q "ACTIONS"; then
    echo "FAIL command bar was already open at launch"
    FAILED=1
else
    echo "PASS command bar starts closed"
fi

kill "$APP_PID" 2>/dev/null
wait "$APP_PID" 2>/dev/null
echo "artifacts: $OUT"
exit "$FAILED"
