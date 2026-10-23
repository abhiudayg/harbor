#!/bin/sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/.verify/artifacts/$STAMP"
PHASE="${1:-all}"
FAILED=0

mkdir -p "$OUT"

run_step() {
    name="$1"
    shift
    dir="$(sed -n "/^name = \"$name\"/,/^$/p" "$ROOT/.verify/verify.toml" | sed -n 's/^working_dir = "\(.*\)"/\1/p')"
    command_line="$(sed -n "/^name = \"$name\"/,/^$/p" "$ROOT/.verify/verify.toml" | sed -n 's/^run = "\(.*\)"/\1/p')"
    (cd "$ROOT/$dir" && sh -c "$command_line") >"$OUT/$name.log" 2>&1
    status=$?
    echo "$name exit=$status" | tee -a "$OUT/summary.txt"
    if [ "$status" -ne 0 ]; then
        FAILED=1
    fi
}

case "$PHASE" in
    all) steps="doctor build unit integration functional ui hurl features coverage security" ;;
    doctor|build|unit|integration|functional|ui|hurl|features|coverage|security) steps="$PHASE" ;;
    *) echo "unknown phase: $PHASE"; exit 2 ;;
esac

for step in $steps; do
    run_step "$step"
done

echo "artifacts: $OUT"
exit "$FAILED"
