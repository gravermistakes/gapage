#!/bin/bash
# Phoenix integration test: audit OpenSSL
# Copyright (C) 2026 Anja Evermoor
# GNU GPL v3.0 or later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo " Phoenix Test: OpenSSL Supply Chain Audit"
echo "============================================"

# Find an OpenSSL library to test
TARGET=""
for candidate in \
    /usr/lib/x86_64-linux-gnu/libssl.so.3 \
    /usr/lib/x86_64-linux-gnu/libssl.so \
    /usr/lib/libssl.so \
    /usr/lib64/libssl.so; do
    if [ -f "$candidate" ]; then
        TARGET="$candidate"
        break
    fi
done

if [ -z "$TARGET" ]; then
    # Try to find any libssl
    TARGET=$(find /usr/lib* /lib* -name 'libssl.so*' -type f 2>/dev/null | head -1 || true)
fi

if [ -z "$TARGET" ]; then
    echo "[TEST] No libssl found on this system"
    echo "[TEST] Trying /usr/bin/openssl instead"
    TARGET="/usr/bin/openssl"
fi

if [ ! -f "$TARGET" ]; then
    echo "[TEST] SKIP: No suitable OpenSSL binary/library found"
    exit 0
fi

echo "[TEST] Target: $TARGET"
echo ""

# Run Phoenix
bash "$SKILL_DIR/scripts/phoenix_main.sh" "$TARGET" 2

# Verify outputs
echo ""
echo "=== Verification ==="
for f in \
    /home/claude/phoenix/results/dependency_graph.json \
    /home/claude/phoenix/results/phoenix_report.md \
    /home/claude/phoenix/provenance_chain.txt; do
    if [ -f "$f" ]; then
        echo "  OK: $(basename $f) ($(wc -c < "$f") bytes)"
    else
        echo "  FAIL: $(basename $f) missing"
    fi
done

# Verify seals
seal_count=$(ls /home/claude/phoenix/seals/*.seal 2>/dev/null | wc -l || echo 0)
echo "  Seals: $seal_count artifacts sealed"

echo ""
echo "[TEST] Complete"
