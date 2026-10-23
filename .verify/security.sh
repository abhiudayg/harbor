#!/bin/sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES="$ROOT/app/Sources"
FAILED=0

scan() {
    label="$1"
    pattern="$2"
    matches="$(grep -rnE "$pattern" "$SOURCES" 2>/dev/null)"
    if [ -n "$matches" ]; then
        echo "FAIL $label"
        echo "$matches"
        FAILED=1
    else
        echo "PASS $label"
    fi
}

scan "no shell or process execution" 'Process\(|(^|[^.A-Za-z_])system\(|popen\(|/bin/sh|/bin/bash|sh -c'
scan "no weak randomness" 'arc4random|rand\(\)|srand|Math\.random|drand48'
scan "no unsafe pointer escape hatches" 'unsafeBitCast|unsafeDowncast|withUnsafe|UnsafeMutableRawPointer'
scan "no print statements in production code" '(^|[^A-Za-z_.])print\('
scan "no hard-coded credentials" '(password|passwd|secret|api[_-]?key|token)[A-Za-z_]*[[:space:]]*[:=][[:space:]]*"[^"]{6,}"'
scan "no dynamic evaluation" 'NSExpression|eval\(|JSContext'
scan "no weak hashes" 'Insecure\.MD5|Insecure\.SHA1|CC_MD5|CC_SHA1'

if grep -rq 'requiredInterfaceType = .loopback' "$SOURCES/HarborCore/MCP/MCPHTTPServer.swift"; then
    echo "PASS MCP listener restricted to loopback"
else
    echo "FAIL MCP listener restricted to loopback"
    FAILED=1
fi

if grep -rq 'SecRandomCopyBytes' "$SOURCES/HarborCore/Security/AccessToken.swift"; then
    echo "PASS access tokens drawn from the OS CSPRNG"
else
    echo "FAIL access tokens drawn from the OS CSPRNG"
    FAILED=1
fi

exit "$FAILED"
