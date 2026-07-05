#!/usr/bin/env bash
# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: avrs.sh — orchestrator (流 current)
#
# Routes a request through the five layers (Perception→Cognition→Action,
# wrapped by Metacognition + Governance) — an intelligence cycle (JP 2-0),
# not a kill chain. Every layer transition is recorded on the witness chain
# with a canonical edge_name. KEEL gates before any action.
set -euo pipefail

AVRS_ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${ANALGAPES_WORKSPACE:=$HOME/.analgapes}"
RUN_ID="${RUN_ID:-$(date +%s)}"
WS="$ANALGAPES_WORKSPACE/runs/$RUN_ID"
mkdir -p "$WS"
WITNESS="${WITNESS_BIN:-$AVRS_ROOT/bin/witness-chain}"

edge() {  # edge <from> <to> <edge_name> <hypothesis> <truth0|1> <goal0|1|2>
  [ -x "$WITNESS" ] && "$WITNESS" "$WS" "$@" >/dev/null || true
}

usage() { cat <<USAGE
analgapes — Accelerated Novel Adversarial Lifting, Generating,
            Architectural Pattern Engagement System
usage: avrs.sh --target <path|url> [--mode auto|repo|binary|apk]
Layers: 見 perception · 析 cognition · 打 action · 影 metacognition · 断 governance
USAGE
}

MODE=auto TARGET=""
while [ $# -gt 0 ]; do case "$1" in
  --target) TARGET="$2"; shift 2;;
  --mode)   MODE="$2"; shift 2;;
  -h|--help) usage; exit 0;;
  *) echo "unknown arg: $1" >&2; usage; exit 2;;
esac; done
[ -n "$TARGET" ] || { usage; exit 2; }

echo "[analgapes] run=$RUN_ID mode=$MODE target=$TARGET ws=$WS"
# 見 perception: observe the target
edge perception perception "見" "observe target: $TARGET" 1 1
# 析 cognition: analyze + correlate
edge perception cognition "源見→析" "route observations to cognition" 1 1
# 断 governance gate (KEEL) before any action
edge cognition governance "析→断" "request action authorization" 1 1
# 打 action (only conceptually here; real action gated by KEEL at call site)
edge governance action "断→打" "authorized action surface" 1 1
# 影 metacognition: seal the run
edge action metacognition "了保" "run concluded, persist witness" 1 1
echo "[analgapes] witness chain: $WS/metacog.jsonl"
