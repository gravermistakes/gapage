#!/usr/bin/env bash
# cta-v1 :: scripts/trialectic.sh
# Phase 1 of CTA: compute trialectic congruence between two statements.
#
# Components:
#   L  logical:       antonym + modal-operator contradiction detection
#   S  semantic:      TF-cosine over normalized unigrams + bigram Jaccard
#   P  probabilistic: derived co-occurrence proxy (honest, corpus-free)
#   St structure:     predicate-pattern alignment
#   F  function:      goal/optimization keyword alignment
#   C  context:       domain-keyword overlap
#
# Output: JSON with components, weighted composite, synthesis-type recommendation.
#
# Usage:
#   ./trialectic.sh -x "statement X" -y "statement Y" [-d formal|natural|empirical|pragmatic|default]
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -f "$AVRS_ROOT/lib/cta/common.sh" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
source "$AVRS_ROOT/lib/cta/common.sh"
cta_require awk sed bc

X=""; Y=""; DOMAIN="default"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -x|--x) X="$2"; shift 2 ;;
        -y|--y) Y="$2"; shift 2 ;;
        -d|--domain) DOMAIN="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,18p' "$0"; exit 0 ;;
        *) cta_die "unknown arg: $1" ;;
    esac
done

[[ -z "$X" || -z "$Y" ]] && cta_die "both -x and -y required"

# ---------- domain weights ----------
case "$DOMAIN" in
    formal)    wL=0.40; wS=0.10; wP=0.10; wSt=0.30; wF=0.05; wC=0.05 ;;
    natural)   wL=0.10; wS=0.30; wP=0.20; wSt=0.10; wF=0.15; wC=0.15 ;;
    empirical) wL=0.15; wS=0.15; wP=0.35; wSt=0.15; wF=0.10; wC=0.10 ;;
    pragmatic) wL=0.05; wS=0.15; wP=0.15; wSt=0.10; wF=0.40; wC=0.15 ;;
    default)   wL=0.15; wS=0.15; wP=0.25; wSt=0.15; wF=0.15; wC=0.15 ;;
    *) cta_die "unknown domain: $DOMAIN" ;;
esac

# ---------- L: logical consistency ----------
compute_L() {
    local x="$1" y="$2"
    local antonym_hit=""
    local modal_hit=""
    if antonym_hit=$(cta_has_contradiction "$x" "$y"); then :; fi
    local tx ty
    tx=$(cta_modal_tags "$x")
    ty=$(cta_modal_tags "$y")
    if modal_hit=$(cta_modal_conflict "$tx" "$ty"); then :; fi
    local score=1.0 details="none"
    if [[ -n "$antonym_hit" && -n "$modal_hit" ]]; then
        score=0.05; details="antonym($antonym_hit) + modal($modal_hit)"
    elif [[ -n "$antonym_hit" ]]; then
        score=0.15; details="antonym($antonym_hit)"
    elif [[ -n "$modal_hit" ]]; then
        score=0.25; details="modal($modal_hit)"
    elif [[ "$tx $ty" == *"NOT"* ]]; then
        # Only one statement negated — possible underdetermined contradiction
        local x_neg=0 y_neg=0
        [[ "$tx" == *"NOT"* ]] && x_neg=1
        [[ "$ty" == *"NOT"* ]] && y_neg=1
        if [[ $x_neg -ne $y_neg ]]; then
            score=0.55; details="asymmetric_negation"
        fi
    fi
    printf '%s|%s' "$score" "$details"
}

# ---------- S: semantic similarity ----------
# Cosine over TF vectors of normalized tokens + Jaccard over raw bigrams.
compute_S() {
    local x="$1" y="$2"
    local nx ny
    nx=$(cta_normalize "$x")
    ny=$(cta_normalize "$y")
    # Build TF maps and compute cosine in awk
    local cosine
    cosine=$(awk -v src="$nx" -v dst="$ny" '
        BEGIN {
            n = split(src, ax, /\n/); for (i=1; i<=n; i++) if (length(ax[i])) tfx[ax[i]]++
            n = split(dst, ay, /\n/); for (i=1; i<=n; i++) if (length(ay[i])) tfy[ay[i]]++
            for (w in tfx) { dot += tfx[w] * (tfy[w] ? tfy[w] : 0); nx2 += tfx[w]*tfx[w] }
            for (w in tfy) { ny2 += tfy[w]*tfy[w] }
            if (nx2 == 0 || ny2 == 0) { print "0.5"; exit }
            printf "%.6f", dot / (sqrt(nx2) * sqrt(ny2))
        }')
    # Bigram Jaccard (raw lowercased tokens, no stemming, to catch phrase patterns)
    local jac
    jac=$(awk -v src="$(cta_tokenize "$x" | paste -sd' ' -)" \
              -v dst="$(cta_tokenize "$y" | paste -sd' ' -)" '
        function bigrams(s, arr,    n, w, i) {
            n = split(s, w, / +/)
            for (i = 1; i < n; i++) arr[w[i] "_" w[i+1]] = 1
        }
        BEGIN {
            bigrams(src, bx); bigrams(dst, by)
            for (k in bx) { union[k]=1; if (k in by) inter++ }
            for (k in by) union[k]=1
            for (k in union) u++
            if (u == 0) { print "0.5"; exit }
            printf "%.6f", inter / u
        }')
    cta_bc "0.7 * $cosine + 0.3 * $jac"
}

# ---------- P: probabilistic co-occurrence (corpus-free proxy) ----------
# We do not have a real corpus, so we derive a calibrated estimate:
# P = sigmoid(content_overlap - antonym_penalty)
# This is documented as a proxy, not a true joint probability.
compute_P() {
    local x="$1" y="$2"
    local nx ny shared total
    nx=$(cta_normalize "$x" | sort -u)
    ny=$(cta_normalize "$y" | sort -u)
    shared=$(comm -12 <(echo "$nx") <(echo "$ny") | wc -l)
    total=$( { echo "$nx"; echo "$ny"; } | sort -u | grep -c .)
    [[ "$total" -eq 0 ]] && { printf '0.5'; return; }
    local overlap
    overlap=$(cta_bc "$shared / $total")
    local penalty=0
    cta_has_contradiction "$x" "$y" >/dev/null && penalty=0.25
    # logistic-shaped on [0,1]
    local centered raw
    centered=$(cta_bc "$overlap - $penalty")
    raw=$(cta_bc "0.5 + 0.5 * ( ($centered - 0.3) / (0.3 + 0.1) )")
    cta_clamp "$raw" 0.0 1.0
}

# ---------- St: structure (predicate-pattern alignment) ----------
# Count predicate cues: copular (is/are/be), modal-verb, action-verb, conditional.
# Score = 1 - L1 distance of normalized counts.
compute_St() {
    local x_lower y_lower
    x_lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    y_lower=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
    awk -v x="$x_lower" -v y="$y_lower" '
        function count(s, pat,   c, n, parts) {
            n = gsub(pat, "&", s)
            return n
        }
        BEGIN {
            # categories
            copula = "\\<(is|are|was|were|be|been|being|am)\\>"
            modal  = "\\<(must|shall|should|may|might|could|can|will|would)\\>"
            action = "\\<(do|does|did|make|made|takes|took|cause|causes|produce|optimize|verify|deploy|test|build|break|create|destroy)\\>"
            cond   = "\\<(if|when|unless|whenever|provided)\\>"
            cx[1] = count(x, copula); cx[2] = count(x, modal); cx[3] = count(x, action); cx[4] = count(x, cond)
            cy[1] = count(y, copula); cy[2] = count(y, modal); cy[3] = count(y, action); cy[4] = count(y, cond)
            sx = cx[1]+cx[2]+cx[3]+cx[4]; sy = cy[1]+cy[2]+cy[3]+cy[4]
            if (sx == 0) sx = 1
            if (sy == 0) sy = 1
            d = 0
            for (i=1;i<=4;i++) {
                px = cx[i]/sx; py = cy[i]/sy
                d += (px - py < 0 ? py - px : px - py)
            }
            # L1 distance on probability vectors is in [0, 2]; map to [0, 1]
            printf "%.6f", 1 - d/2
        }'
}

# ---------- F: function (goal/optimization alignment) ----------
compute_F() {
    local x_lower y_lower
    x_lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    y_lower=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
    awk -v x="$x_lower" -v y="$y_lower" '
        function match_any(s, words,   n, arr, i, c) {
            n = split(words, arr, " ")
            for (i=1;i<=n;i++) if (s ~ "\\<" arr[i] "\\>") c++
            return c
        }
        BEGIN {
            optimize = "optimize optimizes optimized optimizing maximize maximizes maximize minimize minimizes balance ensure ensures improve improves preserve preserves protect protects"
            harm     = "degrade degrades break breaks damage damages weaken weakens compromise compromises destroy destroys harm"
            ox = match_any(x, optimize); oy = match_any(y, optimize)
            hx = match_any(x, harm);     hy = match_any(y, harm)
            # net positive intent score per statement, mapped to [0,1]
            ix = (ox - hx)
            iy = (oy - hy)
            # alignment = 1 - normalized abs difference; if both zero, neutral 0.6
            if (ix == 0 && iy == 0) { printf "%.6f", 0.60; exit }
            d = (ix - iy < 0 ? iy - ix : ix - iy)
            maxd = (ox+hx > oy+hy ? ox+hx : oy+hy)
            if (maxd == 0) maxd = 1
            printf "%.6f", 1 - (d / (maxd + 1))
        }'
}

# ---------- C: context (domain overlap) ----------
compute_C() {
    local x_lower y_lower
    x_lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    y_lower=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
    awk -v x="$x_lower" -v y="$y_lower" '
        function has_any(s, words,   n, arr, i) {
            n = split(words, arr, " ")
            for (i=1;i<=n;i++) if (s ~ "\\<" arr[i] "\\>") return 1
            return 0
        }
        BEGIN {
            d["safety"]      = "safety safe risk hazard danger casualty harm injury verify verification"
            d["performance"] = "speed fast latency throughput performance bandwidth efficiency"
            d["reliability"] = "reliability reliable stable consistent durable robust availability uptime"
            d["security"]    = "security secure attack adversary threat exploit credential confidential"
            d["quality"]     = "quality accuracy precision correctness fidelity defect"
            d["cost"]        = "cost budget expensive cheap price economical resource"
            d["time"]        = "time deadline urgent immediate schedule late early"
            d["scale"]       = "scale scalable large small grow shrink elastic"
            sx = sy = inter = union = 0
            for (k in d) {
                hx = has_any(x, d[k]); hy = has_any(y, d[k])
                if (hx) sx++; if (hy) sy++
                if (hx && hy) inter++
                if (hx || hy) union++
            }
            if (union == 0) { printf "%.6f", 0.50; exit }   # no detected domain -> neutral
            printf "%.6f", inter / union
        }'
}

# ---------- compute components ----------
L_full=$(compute_L "$X" "$Y")
L=${L_full%|*}; L_detail=${L_full#*|}
S=$(compute_S "$X" "$Y")
P=$(compute_P "$X" "$Y")
St=$(compute_St "$X" "$Y")
F=$(compute_F "$X" "$Y")
C=$(compute_C "$X" "$Y")

# ---------- composite congruence ----------
CONGR=$(cta_bc "$wL*$L + $wS*$S + $wP*$P + $wSt*$St + $wF*$F + $wC*$C")

# ---------- synthesis type recommendation ----------
classify() {
    local l="$1" s="$2" p="$3" st="$4" f="$5" c="$6" comp="$7"
    # Compute variance of the six components
    local var
    var=$(printf '%s\n' "$l" "$s" "$p" "$st" "$f" "$c" | cta_variance)
    # Count components below 0.30
    local low=0
    for v in "$l" "$s" "$p" "$st" "$f" "$c"; do
        cta_lt "$v" 0.30 && low=$((low+1)) || true
    done
    local max_comp
    max_comp=$(printf '%s\n' "$l" "$s" "$p" "$st" "$f" "$c" | sort -nr | head -1)

    # Rejection requires REAL logical incompatibility, not just low vocab overlap.
    # Either L itself is low, or many components are low (>=3, including non-vocab ones).
    if cta_lt "$l" 0.30; then echo "rejection"; return; fi
    if [[ $low -ge 3 ]]; then echo "rejection"; return; fi

    # Integration: very high alignment on logic + structure + context
    if cta_gt "$comp" 0.80 && cta_gt "$l" 0.80 && cta_gt "$st" 0.70 && cta_gt "$c" 0.70; then
        echo "integration"; return
    fi

    # Context-partition: different vocab but shared/comparable domains
    if cta_gt "$c" 0.65 && cta_lt "$s" 0.60; then echo "context_partition"; return; fi

    # Hierarchy: same structural form, different functional roles
    if cta_gt "$st" 0.65 && cta_lt "$f" 0.55; then echo "hierarchy"; return; fi

    # Complement: low vocab overlap (S) but high L and reasonable C
    if cta_lt "$s" 0.45 && cta_gt "$l" 0.65; then
        local min_lc
        min_lc=$(printf '%s\n' "$l" "$c" | sort -n | head -1)
        if cta_gt "$min_lc" 0.45; then echo "complement"; return; fi
    fi

    # Trade-off: function tension with structural similarity
    if cta_lt "$f" 0.50; then
        local mean_lst
        mean_lst=$(cta_bc "($l + $st) / 2")
        if cta_gt "$mean_lst" 0.60; then echo "tradeoff"; return; fi
    fi

    # Paradox: high variance, no dominant component
    if cta_gt "$var" 0.03 && cta_lt "$max_comp" 0.80; then echo "paradox"; return; fi

    echo "dialectic"
}
SYNTH=$(classify "$L" "$S" "$P" "$St" "$F" "$C" "$CONGR")

# Identity shortcut: if X and Y normalize to the same content, force integration.
if [[ "$(cta_normalize "$X" | sort)" == "$(cta_normalize "$Y" | sort)" ]]; then
    SYNTH="integration"
fi

# ---------- emit JSON ----------
components=$(cta_json \
    logical="$L" \
    semantic="$S" \
    probabilistic="$P" \
    structure="$St" \
    function="$F" \
    context="$C")

weights=$(cta_json \
    L="$wL" S="$wS" P="$wP" St="$wSt" F="$wF" C="$wC")

cta_json \
    phase=1 \
    statements="$(cta_json X="$X" Y="$Y")" \
    domain="$DOMAIN" \
    weights="$weights" \
    components="$components" \
    logical_detail="$L_detail" \
    congruence="$CONGR" \
    synthesis_type="$SYNTH" \
    timestamp_epoch="$(cta_epoch)"
