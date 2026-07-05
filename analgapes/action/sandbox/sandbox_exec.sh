#!/bin/bash
# SANDBOX EXEC – bwrap isolated execution for PoC validation
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

TARGET="${1:?Usage: sandbox_exec.sh <target_binary> <payload.pl>}"
PAYLOAD="${2:-/dev/null}"
WORKSPACE="${AVRS_WORKSPACE:-/home/user/A51/avrs-cybernetic}"
CANARY="/tmp/avrs_pwned_$$"

echo "[Sandbox] Target:  $TARGET"
echo "[Sandbox] Payload: $PAYLOAD"

# bwrap: unshared namespaces, all caps dropped, die-with-parent
bwrap \
    --new-session \
    --unshare-all \
    --cap-drop ALL \
    --die-with-parent \
    --ro-bind  "$TARGET"  /target \
    --ro-bind  "$PAYLOAD" /payload.pl \
    --bind     /tmp       /tmp \
    --tmpfs    /home \
    --proc     /proc \
    --dev      /dev \
    -- timeout 15 perl /payload.pl /target 2>&1

EXIT=$?
echo "[Sandbox] Exit code: $EXIT"

# Check for canary written by payload (evidence of arbitrary write / RCE)
if [ -f "$CANARY" ]; then
    echo "[Sandbox] ✓ CANARY FOUND – exploit confirmed write primitive"
    cp "$CANARY" "$WORKSPACE/results/canary_evidence.txt"
    rm -f "$CANARY"
fi
