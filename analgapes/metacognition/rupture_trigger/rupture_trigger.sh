#!/usr/bin/env bash
# cta-v1 :: scripts/rupture_trigger.sh
#
# Monitor a series of congruence/diagnostic scores. If the series stagnates
# (low variance, no upward trend) for >= patience steps, emit an orthogonal
# jump vector that the orchestrator can use to escape the local minimum.
# The jump is seeded from the Rule30 epoch stream so the rupture itself
# carries provenance.
#
# Inputs:
#   --scores "0.3,0.31,0.30,0.305"     observed score series (latest last)
#   --current-state "1.0,0.5,0.2"      current state vector (for jump direction)
#   --patience 4                       steps of stagnation before rupture
#   --epsilon 0.03                     variance threshold for "stagnant"
#   --magnitude 1.0                    L2 norm of the emitted jump
#
# Output: JSON with trigger decision, jump_vector (if triggered), and seed.
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -f "$AVRS_ROOT/lib/cta/common.sh" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
source "$AVRS_ROOT/lib/cta/common.sh"
cta_require awk

SCORES=""
STATE=""
PATIENCE="$CTA_PATIENCE_DEFAULT"
EPSILON="$CTA_EPSILON_DEFAULT"
MAGNITUDE=1.0
SEED_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scores) SCORES="$2"; shift 2 ;;
        --current-state) STATE="$2"; shift 2 ;;
        --patience) PATIENCE="$2"; shift 2 ;;
        --epsilon) EPSILON="$2"; shift 2 ;;
        --magnitude) MAGNITUDE="$2"; shift 2 ;;
        --seed) SEED_OVERRIDE="$2"; shift 2 ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) cta_die "unknown arg: $1" ;;
    esac
done

[[ -z "$SCORES" ]] && cta_die "--scores required (comma-separated series)"
[[ -z "$STATE"  ]] && cta_die "--current-state required (comma-separated vector)"

# Parse score series
mapfile -t SCORE_ARR < <(cta_parse_vector "$SCORES")
NS=${#SCORE_ARR[@]}
[[ $NS -lt $PATIENCE ]] && {
    cta_json \
        triggered=false \
        reason="insufficient_history" \
        scores_observed="$NS" \
        patience_required="$PATIENCE" \
        timestamp_epoch="$(cta_epoch)"
    exit 0
}

# Take last `patience` scores
RECENT=("${SCORE_ARR[@]: -$PATIENCE}")
RECENT_FILE=$(mktemp); trap 'rm -f "$RECENT_FILE"' EXIT
printf '%s\n' "${RECENT[@]}" > "$RECENT_FILE"

VAR=$(cta_variance < "$RECENT_FILE")
TREND=$(cta_trend_slope < "$RECENT_FILE")
MEAN=$(cta_mean < "$RECENT_FILE")

# Trigger conditions:
#   (a) variance below epsilon (stagnant), OR
#   (b) absolute trend below epsilon AND mean is in mediocre band (0.3, 0.7)
TRIGGER=false
REASON="continuing"
if cta_lt "$VAR" "$EPSILON"; then
    TRIGGER=true; REASON="low_variance_stagnant"
else
    abs_trend=$(cta_bc "if ($TREND < 0) -($TREND) else $TREND")
    if cta_lt "$abs_trend" "$EPSILON" && cta_gt "$MEAN" 0.3 && cta_lt "$MEAN" 0.7; then
        TRIGGER=true; REASON="flat_trend_mediocre_band"
    fi
fi

# Build jump vector if triggered.
JUMP=""
SEED_USED=""
if [[ "$TRIGGER" == "true" ]]; then
    SEED_USED="${SEED_OVERRIDE:-$(cta_epoch)}"
    # Use Rule30 stream to generate orthogonal direction bytes.
    # We need `dim` floats. Generate (dim*4) hex bytes -> dim Int32 -> normalize to [-1,1].
    DIM=$(printf '%s' "$STATE" | awk -F',' '{print NF}')
    NBYTES=$(( DIM * 4 ))
    RAW_HEX=$(cta_rule30 "$SEED_USED" "$NBYTES")

    # Convert hex stream to floats in [-1, 1]
    JUMP_RAW=$(awk -v hex="$RAW_HEX" -v dim="$DIM" '
        BEGIN {
            out = ""
            for (i = 0; i < dim; i++) {
                h = substr(hex, i*8 + 1, 8)
                # parse hex as integer
                v = 0
                for (k = 1; k <= 8; k++) {
                    c = substr(h, k, 1)
                    if (c >= "0" && c <= "9") d = c - "0"
                    else if (c >= "a" && c <= "f") d = c - "a" + 10
                    else d = 0
                    v = v * 16 + d
                }
                # Map to [-1, 1]
                f = (v / 4294967295.0) * 2 - 1
                out = out (i > 0 ? "," : "") sprintf("%.6f", f)
            }
            print out
        }')

    # Gram-Schmidt: subtract projection of JUMP onto STATE
    JUMP=$(awk -v jr="$JUMP_RAW" -v st="$STATE" -v mag="$MAGNITUDE" '
        BEGIN {
            n_j = split(jr, j, /,/)
            n_s = split(st, s, /,/)
            # dot products
            dot = 0; sq = 0
            for (i = 1; i <= n_j; i++) {
                dot += j[i] * s[i]
                sq  += s[i] * s[i]
            }
            # orthogonalize: j_perp = j - (dot/sq) * s
            scale = (sq > 0) ? dot / sq : 0
            norm2 = 0
            for (i = 1; i <= n_j; i++) {
                ortho[i] = j[i] - scale * s[i]
                norm2 += ortho[i] * ortho[i]
            }
            norm = sqrt(norm2)
            if (norm == 0) norm = 1
            # rescale to magnitude
            out = ""
            for (i = 1; i <= n_j; i++) {
                ortho[i] = ortho[i] / norm * mag
                out = out (i > 1 ? "," : "") sprintf("%.6f", ortho[i])
            }
            print out
        }')
fi

# Output
if [[ -n "$JUMP" ]]; then
    jump_json="[$(echo "$JUMP" | sed 's/,/, /g')]"
else
    jump_json="null"
fi
scores_json="[$(echo "$SCORES" | sed 's/,/, /g')]"

cta_json \
    triggered="$TRIGGER" \
    reason="$REASON" \
    patience="$PATIENCE" \
    epsilon="$EPSILON" \
    scores_observed="$NS" \
    recent_variance="$VAR" \
    recent_trend="$TREND" \
    recent_mean="$MEAN" \
    scores="$scores_json" \
    seed_used="${SEED_USED:-null}" \
    magnitude="$MAGNITUDE" \
    jump_vector="$jump_json" \
    timestamp_epoch="$(cta_epoch)"
