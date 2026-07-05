---
name: analgapes
description: Use this skill for security research — repo, binary, APK, and supply-chain audit; correlation and exploit synthesis under a KEEL governance gate; swarm coordination. ANALGAPES is a unified five-layer organism (Perception/Cognition/Action/Metacognition/Governance) on a cybernetic loop with a SHAKE256 witness chain recording every layer transition as a canonical edge symbol. Triggers on "audit this repo", "analyze this binary", "audit APK", "supply chain check", "verify patch / catches backports", "build PoC", "exploit synthesis", "correlation analysis", "incident review", "postmortem", "scorpion scan", "phoenix supply chain", "SLEDGE lift", "ganesh analysis", or any request invoking ANALGAPES directly. Authorized for use under Immunefi, Bugcrowd, and written-scope engagements; offensive C2 ships separately and is not loaded by default.
---

# ANALGAPES

An intelligence cycle with cybernetic regulation — **not** a kill chain (no
linear pipe). Layers map to Joint Intelligence Process (JP 2-0) stages:

| Layer (kanji) | JP 2-0 alias | Role |
|---|---|---|
| 見 Perception | Collection | observe → emit findings |
| 析 Cognition | Processing + Analysis/Production | correlate, reason, synthesize |
| 打 Action | Dissemination/Integration | synthesize capability (test-first, gated) |
| 影 Metacognition | Evaluation/Feedback | witness chain, formation, regulation |
| 断 Governance | Planning/Direction | KEEL policy gate + seal |

## Currents (not stages)

Perpetual: **核** core (C: avrs_shake + witness_chain) · **断** KEEL (Ada/SPARK
policy + seal) · **流** orchestration (avrs.sh). Tributaries: 析 cognition,
見 perception, 打 action, 影 swarm — joining the flow, overlapping where
independent. Everything writes to the witness chain; everything is sealed by KEEL.

## Witness chain edge alphabet (45 symbols, single-token)

Kanji carry operational verbs, Greek the two iconic relations, structurals the
control flow. Edges read as terse sentences: `δ↓析` (anomaly drills into
analysis), `源見✔●` (source observed, verified, committed), `−` (false discarded).
See `tools/edge_alphabet.json`.

## Run

```
./boot/init.sh                       # probe/activate toolchain currents
./avrs.sh --target <path> --mode repo
make test-all                        # strict 100%, mutation-gated
```

## Governance

KEEL gates before any action: in-scope ∧ ESL-compliant ∧ chain-intact ∧
agency-safe (Goodhart-guarded ∧ corrigible). No democratic process. Disclosure
timing is per-engagement, never hardcoded. Offensive C2 ships separately.
