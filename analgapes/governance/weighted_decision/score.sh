#!/usr/bin/env bash
# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: governance/weighted_decision/score.sh
# Weighted multi-criteria score. stdin: lines "option w1*s1 w2*s2 ..."; emits ranked.
set -euo pipefail
awk '{ s=0; for(i=2;i<=NF;i++){split($i,p,"*"); s+=p[1]*p[2]} printf "%.4f\t%s\n", s, $1 }' | sort -rn
