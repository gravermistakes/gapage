#!/usr/bin/env bash
# cta-v1 :: scripts/sacroverse_mc.sh
# Modality XVII — Sacroverse Monte Carlo (🜏) — STUB
# License: ESL-ANCSA-MRA-IndiModSHA v1.0
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -d "$AVRS_ROOT/lib/cta" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
exec Rscript "$AVRS_ROOT/lib/cta/r/sacroverse_mc.R" "$@"
