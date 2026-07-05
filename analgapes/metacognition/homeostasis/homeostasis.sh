#!/usr/bin/env bash
# cta-v1 :: scripts/homeostasis.sh
# Phase 5 — Homeostatic validation
# License: ESL-ANCSA-MRA-IndiModSHA v1.0
#
# Usage:
#   ./homeostasis.sh --state "1.0,0.5,0.2" \
#       --constraint "sum:1.7" --constraint "min:0.0" --constraint "max:1.0" \
#       --epsilon 0.03
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -d "$AVRS_ROOT/lib/cta" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
exec Rscript "$AVRS_ROOT/lib/cta/r/homeostasis.R" "$@"
