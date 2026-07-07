#!/usr/bin/env bash
# cta-v1 :: scripts/gonzo_check.sh
# Phase 3: detect whether a transform operator is "gonzo" -
# i.e. changes its own meaning during iterated application.
#
# Diagnoses: stable | diverging | converging | oscillating
#
# Uses a 3-point moving average on consecutive-state distances to suppress
# noise false positives. Variance threshold default 0.05 (configurable).
#
# Usage:
#   ./gonzo_check.sh --initial "1,0,0" --transform "scale_all:2" --iterations 10
#   ./gonzo_check.sh --initial "1,0" --transform "rotate:0:1:0.5" --iterations 20
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

INITIAL=""
TRANSFORM=""
ITER=12
THRESHOLD="$CTA_GONZO_THRESH_DEFAULT"
SMOOTH=3

while [[ $# -gt 0 ]]; do
    case "$1" in
        --initial) INITIAL="$2"; shift 2 ;;
        --transform) TRANSFORM="$2"; shift 2 ;;
        --iterations) ITER="$2"; shift 2 ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --smooth) SMOOTH="$2"; shift 2 ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) cta_die "unknown arg: $1" ;;
    esac
done

[[ -z "$INITIAL" ]] && cta_die "--initial required"
[[ -z "$TRANSFORM" ]] && cta_die "--transform required"
[[ $ITER -lt 3 ]] && cta_die "--iterations must be >= 3"

# Iterate
STATES=("$INITIAL")
CURRENT="$INITIAL"
for ((i=0; i<ITER; i++)); do
    CURRENT=$(cta_apply_transform "$TRANSFORM" "$CURRENT")
    STATES+=("$CURRENT")
done

# Distances between consecutive states
DIST_FILE=$(mktemp)
trap 'rm -f "$DIST_FILE"' EXIT
for ((i=1; i<${#STATES[@]}; i++)); do
    d=$(cta_euclidean "${STATES[$((i-1))]}" "${STATES[$i]}")
    printf '%s\n' "$d" >> "$DIST_FILE"
done

# Moving average smoothing
SMOOTH_FILE=$(mktemp)
trap 'rm -f "$DIST_FILE" "$SMOOTH_FILE"' EXIT
awk -v w="$SMOOTH" '
    { d[NR] = $1; n = NR }
    END {
        for (i=1; i<=n; i++) {
            lo = (i - int(w/2) < 1) ? 1 : i - int(w/2)
            hi = (i + int(w/2) > n) ? n : i + int(w/2)
            s = 0; c = 0
            for (k=lo; k<=hi; k++) { s += d[k]; c++ }
            printf "%.6f\n", s/c
        }
    }' "$DIST_FILE" > "$SMOOTH_FILE"

# Variance and trend on smoothed distances
VAR=$(cta_variance < "$SMOOTH_FILE")
TREND=$(cta_trend_slope < "$SMOOTH_FILE")
MEAN_DIST=$(cta_mean < "$SMOOTH_FILE")
MAX_DIST=$(sort -n < "$SMOOTH_FILE" | tail -1)
MIN_DIST=$(sort -n < "$SMOOTH_FILE" | head -1)

# Relative variance (variance / mean^2) — scale-invariant gonzo detector
# Avoids false positives on operators with large baseline distances.
if cta_gt "$MEAN_DIST" 0; then
    REL_VAR=$(cta_bc "$VAR / ($MEAN_DIST * $MEAN_DIST)")
else
    REL_VAR=0
fi

# Diagnosis
IS_GONZO=true
DIAGNOSIS="stable"
if cta_gt "$REL_VAR" "$THRESHOLD"; then
    IS_GONZO=false
    abs_trend=$(cta_bc "if ($TREND < 0) -($TREND) else $TREND")
    # use trend relative to mean distance
    rel_trend=$(cta_bc "if ($MEAN_DIST > 0) $abs_trend / $MEAN_DIST else 0")
    if cta_gt "$rel_trend" "$THRESHOLD"; then
        if cta_gt "$TREND" 0; then
            DIAGNOSIS="diverging"
        else
            DIAGNOSIS="converging"
        fi
    else
        DIAGNOSIS="oscillating"
    fi
fi

# Output
distances_json="[$(paste -sd',' "$DIST_FILE")]"
smoothed_json="[$(paste -sd',' "$SMOOTH_FILE")]"

cta_json \
    phase=3 \
    initial="$(printf '[%s]' "$(echo "$INITIAL" | sed 's/,/, /g')")" \
    transform="$TRANSFORM" \
    iterations="$ITER" \
    variance_threshold="$THRESHOLD" \
    smoothing_window="$SMOOTH" \
    distances="$distances_json" \
    smoothed_distances="$smoothed_json" \
    variance="$VAR" \
    relative_variance="$REL_VAR" \
    trend_slope="$TREND" \
    mean_distance="$MEAN_DIST" \
    is_gonzo="$IS_GONZO" \
    diagnosis="$DIAGNOSIS" \
    timestamp_epoch="$(cta_epoch)"
