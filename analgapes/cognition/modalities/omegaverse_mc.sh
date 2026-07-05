#!/usr/bin/env bash
# cta-v1 :: scripts/omegaverse_mc.sh
# Modality XXIII — Omegaverse Monte Carlo (Ω) — STUB
# License: ESL-ANCSA-MRA-IndiModSHA v1.0
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -d "$AVRS_ROOT/lib/cta" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
exec Rscript "$AVRS_ROOT/lib/cta/r/omegaverse_mc.R" "$@"
