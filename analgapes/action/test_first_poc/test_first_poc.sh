#!/usr/bin/env bash
# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: action/test_first_poc/test_first_poc.sh
# Test-first discipline for exploitation: a PoC may only be generated AFTER
# a reproducing test (the crash) is demonstrated. No test ⇒ no PoC.
set -euo pipefail
CRASH_PROOF="${1:-}"
[ -n "$CRASH_PROOF" ] && [ -s "$CRASH_PROOF" ] \
  || { echo '{"error":"no reproducing crash proof — refusing to synthesize PoC (test-first)"}'; exit 1; }
echo '{"gate":"test-first satisfied","may_synthesize":true}'
