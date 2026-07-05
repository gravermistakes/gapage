#!/usr/bin/env bash
# cta-v1 :: scripts/run_cta.sh
# End-to-end CTA orchestrator. Chains all phases with file-based handoff so
# the pipeline scales to large sample counts without per-cycle shell forks.
#
# Modes:
#   --mode trialectic    Run Phase 1 (trialectic) + Phase 6 (synthesis) only.
#                         Args: --x STMT --y STMT [--domain D]
#   --mode dynamics      Run Phase 2 (invariant) + Phase 3 (gonzo) on a state.
#                         Args: --state VEC --transform OP [--transform OP ...]
#                               --gonzo-transform OP --gonzo-iter N
#   --mode mc-pipeline   Run a Monte Carlo modality chain. Default chain:
#                         Traditional -> Obverse -> Adverse -> Reverse
#                         Args: --distribution D --n N --seed S [--chain "a,b,c"]
#   --mode full          Run trialectic + dynamics + mc-pipeline if all inputs given.
#
# All output JSONs are written to --workspace (default ./cta-run-<epoch>).
# A final audit-log.json summarizes the run and applies the provenance seal.
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
AVRS_ROOT="$SCRIPT_DIR"
while [ "$AVRS_ROOT" != "/" ] && [ ! -f "$AVRS_ROOT/lib/cta/common.sh" ]; do AVRS_ROOT="$(dirname "$AVRS_ROOT")"; done
source "$AVRS_ROOT/lib/cta/common.sh"

MODE=""
WS=""
X=""; Y=""; DOMAIN="default"
STATE=""; TRANSFORMS=(); GONZO_TRANSFORM=""; GONZO_ITER=12
DISTRIBUTION="normal:0:1"; N=5000; SEED="${CTA_SEED:-42}"
CHAIN="traditional,obverse,adverse,reverse"
SEAL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --workspace) WS="$2"; shift 2 ;;
        --x) X="$2"; shift 2 ;;
        --y) Y="$2"; shift 2 ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        --state) STATE="$2"; shift 2 ;;
        --transform) TRANSFORMS+=("$2"); shift 2 ;;
        --gonzo-transform) GONZO_TRANSFORM="$2"; shift 2 ;;
        --gonzo-iter) GONZO_ITER="$2"; shift 2 ;;
        --distribution) DISTRIBUTION="$2"; shift 2 ;;
        --n) N="$2"; shift 2 ;;
        --seed) SEED="$2"; shift 2 ;;
        --chain) CHAIN="$2"; shift 2 ;;
        --seal) SEAL=true; shift 1 ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) cta_die "unknown arg: $1" ;;
    esac
done

[[ -z "$MODE" ]] && cta_die "--mode required (trialectic | dynamics | mc-pipeline | full)"

# Workspace
[[ -z "$WS" ]] && WS="./cta-run-$(cta_epoch)"
mkdir -p "$WS"
cta_info "workspace: $WS"

# Make sure R is set up
"$SCRIPT_DIR/cta_setup.sh" >&2

declare -a ARTIFACTS=()

run_trialectic() {
    [[ -z "$X" || -z "$Y" ]] && cta_die "trialectic mode needs --x and --y"
    cta_info "Phase 1: trialectic congruence"
    "$SCRIPT_DIR/trialectic.sh" -x "$X" -y "$Y" -d "$DOMAIN" > "$WS/phase1_trialectic.json"
    ARTIFACTS+=("$WS/phase1_trialectic.json")
    cta_info "Phase 6: synthesis"
    "$SCRIPT_DIR/synthesis_gen.sh" --phase1 "$WS/phase1_trialectic.json" > "$WS/phase6_synthesis.json"
    ARTIFACTS+=("$WS/phase6_synthesis.json")
}

run_dynamics() {
    [[ -z "$STATE" ]] && cta_die "dynamics mode needs --state"
    if [[ ${#TRANSFORMS[@]} -gt 0 ]]; then
        cta_info "Phase 2: invariant detection across ${#TRANSFORMS[@]} transforms"
        local args=(--state "$STATE")
        for t in "${TRANSFORMS[@]}"; do args+=(--transform "$t"); done
        "$SCRIPT_DIR/invariant_detect.sh" "${args[@]}" > "$WS/phase2_invariant.json"
        ARTIFACTS+=("$WS/phase2_invariant.json")
    fi
    if [[ -n "$GONZO_TRANSFORM" ]]; then
        cta_info "Phase 3: gonzo diagnosis ($GONZO_ITER iterations of $GONZO_TRANSFORM)"
        "$SCRIPT_DIR/gonzo_check.sh" --initial "$STATE" --transform "$GONZO_TRANSFORM" --iterations "$GONZO_ITER" > "$WS/phase3_gonzo.json"
        ARTIFACTS+=("$WS/phase3_gonzo.json")
    fi
}

run_mc_pipeline() {
    cta_info "Phase 4: MC pipeline ($CHAIN)"
    IFS=',' read -ra STEPS <<< "$CHAIN"
    local prev=""
    for step in "${STEPS[@]}"; do
        step="${step// /}"
        local out="$WS/mc_${step}.txt"
        local json="$WS/mc_${step}.json"
        case "$step" in
            traditional)
                "$SCRIPT_DIR/traditional_mc.sh" --distribution "$DISTRIBUTION" --n "$N" --seed "$SEED" --out "$out" > "$json"
                ;;
            inverse)
                [[ -z "$prev" ]] && cta_die "inverse needs a prior step in chain"
                "$SCRIPT_DIR/inverse_mc.sh" --in "$prev" --out "$out" > "$json"
                ;;
            obverse)
                [[ -z "$prev" ]] && cta_die "obverse needs a prior step"
                "$SCRIPT_DIR/obverse_mc.sh" --in "$prev" --out "$out" > "$json"
                ;;
            reverse)
                [[ -z "$prev" ]] && cta_die "reverse needs a prior step"
                "$SCRIPT_DIR/reverse_mc.sh" --in "$prev" --inverse "x" --reweight harmonic --out "$out" > "$json"
                ;;
            adverse)
                [[ -z "$prev" ]] && cta_die "adverse needs a prior step"
                "$SCRIPT_DIR/adverse_mc.sh" --in "$prev" --out "$out" > "$json"
                ;;
            transverse|diverse|subverse|microversal|introverse)
                [[ -z "$prev" ]] && cta_die "$step needs a prior step"
                "$SCRIPT_DIR/${step}_mc.sh" --in "$prev" --out "$out" > "$json"
                ;;
            *)
                cta_warn "skipping unsupported chain step: $step"
                continue
                ;;
        esac
        ARTIFACTS+=("$json")
        prev="$out"
        cta_info "  ✓ $step  ->  $(basename "$out")"
    done
}

case "$MODE" in
    trialectic)  run_trialectic ;;
    dynamics)    run_dynamics ;;
    mc-pipeline) run_mc_pipeline ;;
    full)
        [[ -n "$X" && -n "$Y" ]] && run_trialectic
        [[ -n "$STATE" ]] && run_dynamics
        run_mc_pipeline
        ;;
    *) cta_die "unknown mode: $MODE" ;;
esac

# Audit log
AUDIT="$WS/audit-log.json"
artifacts_json="["
for i in "${!ARTIFACTS[@]}"; do
    [[ $i -gt 0 ]] && artifacts_json+=","
    artifacts_json+="\"${ARTIFACTS[$i]}\""
done
artifacts_json+="]"

cta_json \
    cta_version="v1.0.0" \
    license="ESL-ANCSA-MRA-IndiModSHA v1.0" \
    original_creator="Anja Evermoor" \
    mode="$MODE" \
    workspace="$WS" \
    epoch_start="$(cta_epoch)" \
    artifacts="$artifacts_json" \
    > "$AUDIT"

# Optional provenance seal over all artifacts
if [[ "$SEAL" == "true" && ${#ARTIFACTS[@]} -gt 0 ]]; then
    cta_info "applying ESL Seal of Inherited Provenance"
    SEAL_ARGS=()
    for a in "${ARTIFACTS[@]}"; do SEAL_ARGS+=(--input "$a"); done
    SEAL_ARGS+=(--input "$AUDIT" --temperature 1.0 --entropy "cta-run-$MODE" --out "$WS/seal.json")
    "$SCRIPT_DIR/provenance_seal.sh" "${SEAL_ARGS[@]}" > /dev/null
    cta_info "seal: $WS/seal.json"
fi

cta_info "done. artifacts in $WS"
printf '%s\n' "$WS"
