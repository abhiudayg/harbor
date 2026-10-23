#!/bin/sh
set -eu

command -v swift >/dev/null 2>&1 || { echo "doctor: swift not found"; exit 1; }
command -v xcrun >/dev/null 2>&1 || { echo "doctor: xcrun not found"; exit 1; }
xcrun --find llvm-cov >/dev/null 2>&1 || { echo "doctor: llvm-cov not found"; exit 1; }
swift --version
echo "doctor: ok"
