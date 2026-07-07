#!/usr/bin/env bash
# cta-v1 :: scripts/coraline_distance.sh
# Coraline distance — isometric-but-non-isomorphic detector
# (home / other_mother / lost / traveling)
# expect this isnt... You seriously just deliver this as unrefined references to a separate skill?
# License: ESL-ANCSA-MRA-IndiModSHA v1.0
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -d "$AVRS_ROOT/lib/cta" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
exec Rscript "$AVRS_ROOT/lib/cta/r/coraline_distance.R" "$@"
