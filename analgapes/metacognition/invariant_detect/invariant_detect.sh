#!/usr/bin/env bash
# cta-v1 :: scripts/invariant_detect.sh
# Phase 2: detect invariant dimensions across a sequence of transformations.
#
# Transformation DSL (one op per --transform arg, repeatable):
#   negate:i           flip sign of dimension i (0-indexed)
#   scale:i:k          multiply dim i by k
#   shift:i:k          add k to dim i
#   swap:i:j           swap dims i and j
#   permute:p0,p1,p2   reorder dims to specified permutation
#   rotate:i:j:theta   rotate dims i,j by theta radians (in the i-j plane)
#   noise:sigma        add Gaussian noise (sigma) to every dim, Box-Muller via awk
#   mirror:i           alias for negate:i
#   identity           no-op
#
# Usage:
#   ./invariant_detect.sh --state "1.0,2.0,0.5,3.0" \
#       --transform negate:0 --transform scale:1:1.618 --transform swap:2:3 \
#       --percentile 25
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -f "$AVRS_ROOT/lib/cta/common.sh" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
source "$AVRS_ROOT/lib/cta/common.sh"
# shellcheck source=lib/transforms.sh
source "$AVRS_ROOT/lib/cta/transforms.sh"
cta_require awk bc

STATE=""
TRANSFORMS=()
PERCENTILE="$CTA_VARIANCE_PCTL_DEFAULT"
SEED="${CTA_SEED:-1}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --state) STATE="$2"; shift 2 ;;
        --transform) TRANSFORMS+=("$2"); shift 2 ;;
        --percentile) PERCENTILE="$2"; shift 2 ;;
        --seed) SEED="$2"; shift 2 ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) cta_die "unknown arg: $1" ;;
    esac
done

[[ -z "$STATE" ]] && cta_die "--state required (e.g. \"1.0,2.0,0.5\")"
[[ ${#TRANSFORMS[@]} -eq 0 ]] && cta_die "at least one --transform required"

# Parse state into array
mapfile -t STATE_ARR < <(cta_parse_vector "$STATE")
DIM=${#STATE_ARR[@]}
[[ $DIM -lt 1 ]] && cta_die "state must have at least 1 dimension"

# ---------- collect snapshots ----------
SNAPSHOTS=("$STATE")
CURRENT="$STATE"
for op in "${TRANSFORMS[@]}"; do
    CURRENT=$(cta_apply_transform "$op" "$CURRENT")
    SNAPSHOTS+=("$CURRENT")
done

# ---------- per-dimension variance ----------
# Build a temp table: each row is a snapshot, each column a dimension.
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
for snap in "${SNAPSHOTS[@]}"; do
    printf '%s\n' "$snap" | tr ',' ' '
done > "$TMP"

VARIANCES=$(awk -v dim="$DIM" '
    {
        for (i=1; i<=dim; i++) {
            v[i,NR] = $i
            sum[i] += $i
        }
        n = NR
    }
    END {
        out = ""
        for (i=1; i<=dim; i++) {
            mean = sum[i]/n
            ss = 0
            for (k=1; k<=n; k++) ss += (v[i,k] - mean)^2
            varv = (n>1 ? ss/(n-1) : 0)
            out = out (i>1?",":"") sprintf("%.6f", varv)
        }
        print out
    }' "$TMP")

# Percentile threshold
THRESHOLD=$(printf '%s\n' "$VARIANCES" | tr ',' '\n' | cta_percentile "$PERCENTILE")

# Build invariant mask (true if variance <= threshold)
MASK=""
IFS=',' read -ra VAR_ARR <<< "$VARIANCES"
for v in "${VAR_ARR[@]}"; do
    if cta_le "$v" "$THRESHOLD"; then
        MASK+="true,"
    else
        MASK+="false,"
    fi
done
MASK=${MASK%,}

# Count preserved dimensions
PRESERVED=$(echo "$MASK" | tr ',' '\n' | grep -c '^true$' || true)

# ---------- emit JSON ----------
mask_json="[$(echo "$MASK" | sed 's/,/, /g')]"
var_json="[$VARIANCES]"

# Snapshots as 2D array
snap_json="["
for i in "${!SNAPSHOTS[@]}"; do
    [[ $i -gt 0 ]] && snap_json+=","
    snap_json+="[$(printf '%s' "${SNAPSHOTS[$i]}" | sed 's/,/, /g')]"
done
snap_json+="]"

cta_json \
    phase=2 \
    initial_state="$(printf '[%s]' "$(echo "$STATE" | sed 's/,/, /g')")" \
    transforms_applied="$(printf '[%s]' "$(printf '"%s",' "${TRANSFORMS[@]}" | sed 's/,$//')")" \
    dimensions="$DIM" \
    snapshots="$snap_json" \
    variances="$var_json" \
    threshold_percentile="$PERCENTILE" \
    threshold_value="$THRESHOLD" \
    invariant_mask="$mask_json" \
    dimensions_preserved="$PRESERVED" \
    timestamp_epoch="$(cta_epoch)"
