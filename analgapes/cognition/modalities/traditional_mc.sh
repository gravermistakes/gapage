#!/usr/bin/env bash
# cta-v1 :: scripts/traditional_mc.sh
# Modality I — Traditional Monte Carlo (△)  |  Δ(X) ~ P(X)
#
# Usage:
#   ./traditional_mc.sh --distribution normal:0:1 --n 10000 --seed 42 [--out samples.txt]
#   Distributions: normal:mu:sigma | uniform:lo:hi | lognormal:mu:sigma
#                  | exponential:rate | gamma:shape:rate
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -d "$AVRS_ROOT/lib/cta" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
exec Rscript "$AVRS_ROOT/lib/cta/r/traditional_mc.R" "$@"
