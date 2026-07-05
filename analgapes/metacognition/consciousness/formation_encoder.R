#!/usr/bin/env Rscript
# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: metacognition/consciousness/formation_encoder.R
# Encodes a "formation vector": assumption vs reality → delta + semantic_state.
# args: assumption_confidence reality_confidence  (both in [0,1])
a <- suppressWarnings(as.numeric(commandArgs(TRUE)[1])); if (is.na(a)) a <- 0.5
r <- suppressWarnings(as.numeric(commandArgs(TRUE)[2])); if (is.na(r)) r <- 0.5
delta <- abs(a - r)
state <- if (delta < 0.15) "aligned" else if (delta < 0.4) "tension" else "rupture"
cat(sprintf('{"assumption":%.3f,"reality":%.3f,"delta":%.3f,"semantic_state":"%s"}\n',
            a, r, delta, state))
