#!/usr/bin/env bash
# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: perception/tool_loader.sh
# Lifts the JSON tool registry into Prolog facts: tool(Name,Category,Desc).
set -euo pipefail
REG="${1:-$(dirname "$0")/tool_registry.json}"
OUT="${2:-/tmp/analgapes_tools.pl}"
jq -r '.tools | to_entries[] |
  "tool(" + (.key|@json) + ", " + (.value.category|@json) + ", " + (.value.description|@json) + ")."' \
  "$REG" > "$OUT"
echo "$OUT"
