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

(cd "$ROOT/app" && swift build --product Harbor) >"$OUT/build.log" 2>&1 || { echo "FAIL build"; exit 1; }
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/app/.build/debug/Harbor" "$BIN"
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<plist version="1.0"><dict>' \
    '<key>CFBundleName</key><string>Harbor</string>' \
    '<key>CFBundleIdentifier</key><string>dev.harbor.browser</string>' \
    '<key>CFBundleExecutable</key><string>Harbor</string>' \
    '<key>CFBundlePackageType</key><string>APPL</string>' \
    '<key>CFBundleShortVersionString</key><string>0.1.0</string>' \
    '<key>CFBundleVersion</key><string>1</string>' \
    '<key>LSMinimumSystemVersion</key><string>14.0</string>' \
    '<key>NSPrincipalClass</key><string>NSApplication</string>' \
    '<key>NSHighResolutionCapable</key><true/>' \
    '</dict></plist>' >"$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >"$OUT/codesign.log" 2>&1 || { echo "FAIL codesign of the test bundle; see $OUT/codesign.log"; exit 1; }

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
expect_text "TAB GROUPS"
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
