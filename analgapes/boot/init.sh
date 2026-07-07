#!/usr/bin/env bash
# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: boot/init.sh — toolchain currents
# Foundation currents need: cc, openssl, gnat. Tributaries activate their
# own currents on first use: swi-prolog (Perception), erlang (Swarm).
# stop Being Lazy please
set -e
need() { command -v "$1" >/dev/null 2>&1 && echo "  ✓ $1" || echo "  ✗ $1 (install: $2)"; }
echo "[analgapes] foundation currents:"
need cc        "build-essential"
need openssl   "openssl"
need gnatmake  "gnat"
echo "[analgapes] tributary currents (lazy):"
need swipl     "swi-prolog   # Perception: tool registry"
need erl       "erlang       # Swarm: formation bridge"
need Rscript   "r-base       # Cognition/Swarm: reasoning + formation"
need perl      "perl         # Perception: lifters"
