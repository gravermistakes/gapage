# CELLULAR_INTEGRATION.md

> Goal: dissolve four security-research skills (cta-v1, route-cause, avrs-supervisor v2.3, avrs-supervisor-v2-5-integrated) into one unified organism that uses dusk2dawn's 5-layer skeleton (Perception / Cognition / Action / Metacognition / Governance). Cellular-level recombination — primitives extracted from each source and reattached where their idiom fits, not as bolt-ons.
>
> After this work: those four skills cease to exist as separate ships. Their genetic material lives inside unified AVRS.

## Purpose & naming

- Result skill: **AVRS** (folder: `avrs/`). Drops "dusk2dawn" suffix to reflect that this *is* AVRS now, not one variant of it.
- All previous AVRS-prefixed skills supersede into this one.
- License: ESL-ANCSA-MRA-IndiModSHA v1.0 throughout, Anja Evermoor as Original Creator.

## Discipline (non-negotiable, carried through every wave)

1. **No AI-trademark names in shipped artifacts.** ATTRIBUTION lists Anja Evermoor (Original Creator) + Weft (co-author). No "the operator", no "the maintainer", no model identifiers. Internal scratch notes excepted.
2. **TDD order**: spec → test → impl → mutation-test. Never reorder. Tautological tests are worse than no tests.
3. **`make test-all` clears strict at 100%** before any wave is considered done. `-Werror` + `pipefail`.
4. **Truth-value gate**: FALSE-hypothesis events are discarded from the witness chain; TRUE events stay regardless of goal achievement. Re-verify each wave.
5. **Workspace, not skill folder**: runtime state writes to `$AVRS_WORKSPACE`; skill folder stays immutable.
6. **No Python** unless last resort. Existing toolchain ladder: bash → C → Ada/SPARK → Perl → Haskell → R → Prolog → Erlang/Elixir → Tcl/Lua. Apt-installable; runs in this container.
7. **Read whole, not truncated.** Every directory guide carries the don't-truncate warning at top.
8. **No democratic process in the tool.** Voting/quorum/proposal-type concepts deleted (humans do that outside the tool; AVRS just records the outcome as an event).

## Target architecture (unified)

```
avrs/
├── SKILL.md                      # entry, identity, trigger surface
├── INDEX.md                      # 5-layer routing manual
├── README.md
├── LICENSE                       # ESL v1.0
├── ATTRIBUTION.json              # Anja + Weft; cited dissolved skills
├── provenance.json               # composite SHAKE256-xoflen-64 over tree
├── CHANGELOG.md
├── Makefile                      # top-level test-all
├── avrs.sh                       # orchestrator entry point
├── boot/init.sh                  # toolchain probe + apt install
├── lib/
│   ├── avrs_shake.{h,c}          # SHAKE256 backbone (from rc_shake256)
│   ├── common.sh                 # shared bash utils
│   └── transforms.sh             # state-vector transform DSL
├── core/                         # Ada/SPARK (existing dusk2dawn)
│   └── src/
├── perception/                   # find/observe → emit findings
│   ├── GUIDE.md
│   ├── static/                   # SLEDGE (existing) + repo-audit, code-review
│   ├── dynamic/                  # ganesh + parse_gdb_mi
│   ├── apk/                      # existing
│   ├── supply_chain/             # existing + attack-surface-mapping
│   ├── sidechannel/              # existing
│   ├── secrets/                  # secrets-detection (new)
│   ├── entry_points/             # entry-point-analyzer (smart contracts, new)
│   ├── vuln_scanning/            # new
│   ├── infrastructure/           # new
│   ├── tool_registry.json        # 94 tools from v2.5
│   ├── tool_registry.pl          # Prolog fact base + dispatch predicates
│   └── tool_loader.sh            # bash scanner that emits Prolog facts
├── cognition/                    # consume findings → produce understanding
│   ├── GUIDE.md
│   ├── ghost/                    # existing (Octave)
│   ├── fusion/                   # existing (Perl)
│   ├── correlation/              # rc correlation-analysis lands here (C)
│   ├── adversarial/              # existing
│   ├── detection/                # existing
│   ├── trialectic/               # cta-v1 (bash + R)
│   ├── synthesis_gen/            # cta-v1 (bash + R)
│   ├── vulnerability_research/   # new
│   ├── threat_intel/             # new
│   ├── security_auditing/        # new
│   ├── multi_tool_deep_audit/    # parallel-invocation primitive
│   └── references/               # vector-definitions, gonzo-cases, trialectic-examples
├── action/                       # synthesize attack capability
│   ├── GUIDE.md
│   ├── patch_forge/              # existing
│   ├── sandbox/                  # existing + execute_probe
│   ├── exploit_synthesis/        # existing payload_gen + heap_shaper.pl + poc_template.pl
│   ├── test_first_poc/           # route-cause test-first-poc-synthesis
│   └── rapid_prototyping/        # scaffold-new-tool helper
├── metacognition/                # observe ourselves → regulate
│   ├── GUIDE.md
│   ├── consciousness/
│   │   ├── GUIDE.md
│   │   ├── witness_chain.{h,c}   # rc_metacog C primitive — THE missing script
│   │   ├── formation_encoder.R   # R: vector encoding of critical moments
│   │   └── swarm_formation_bridge.erl  # Erlang/OTP: distributed coordination
│   ├── feedback_analyzer.adb     # existing Ada/SPARK
│   ├── incident_review/          # existing
│   ├── gonzo_check/              # cta-v1
│   ├── invariant_detect/         # cta-v1
│   ├── coraline_distance/        # cta-v1
│   ├── homeostasis/              # cta-v1
│   ├── rupture_trigger/          # cta-v1 (the regulator)
│   └── token_compression/        # route-cause node
├── governance/                   # policy, seal, disclosure records
│   ├── GUIDE.md
│   ├── keel/
│   │   ├── Makefile              # existing Ada/SPARK
│   │   ├── policy.ads            # NEW: in-scope check, license check, invariants (Ada/SPARK)
│   │   ├── seal/                 # provenance_seal lives here
│   │   └── tests/
│   ├── messages/                 # existing certcc/vrp/institutional + operationalized-dissent-guides
│   ├── report_generator.pl       # existing Perl
│   └── weighted_decision/        # route-cause weighted-decision-scoring
├── config/                       # consolidated YAML configs
├── templates/                    # audit-log, constraint-set, transformation-seq
├── docs/                         # working_agreement, advisory_board, ethics_mission, containerisation, tool_integration
└── tests/                        # all tests batched under `make test-all`
```

The `legacy-cortex/` directory in dusk2dawn is renamed → `kerebral/` (drops trademark name).

---

## Source dissolution maps

### Map A: cta-v1 → AVRS

| cta-v1 path | → AVRS path | Notes |
|---|---|---|
| `scripts/trialectic.sh` + `r/trialectic.R` | `cognition/trialectic/` | classify synthesis between competing analyses |
| `scripts/gonzo_check.sh` + `r/gonzo_check.R` | `metacognition/gonzo_check/` | detect operator-meaning drift |
| `scripts/invariant_detect.sh` + `r/invariant_detect.R` | `metacognition/invariant_detect/` | verify invariants under transforms |
| `scripts/synthesis_gen.sh` + `r/synthesis_gen.R` | `cognition/synthesis_gen/` | generate synthesis text |
| `scripts/coraline_distance.sh` + `r/coraline_distance.R` | `metacognition/coraline_distance/` | uncanny-handoff detection |
| `scripts/homeostasis.sh` + `r/homeostasis.R` | `metacognition/homeostasis/` | constraint validation |
| `scripts/rupture_trigger.sh` | `metacognition/rupture_trigger/` | homeostatic regulator |
| `scripts/provenance_seal.sh` | `governance/keel/seal/` | KEEL seal primitive |
| `scripts/lib/common.sh` | `lib/common.sh` | shared bash utils |
| `scripts/lib/transforms.sh` | `lib/transforms.sh` | state-vector DSL |
| `r/cta_common.R` | `cognition/lib/cta_common.R` | shared R utilities |
| `scripts/run_cta.sh` | absorbed into `avrs.sh` | top-level dispatcher absorbs pipeline |
| `config/cta-config.yaml` | `config/cta.yaml` | merged with other config |
| `config/constraint-templates.yaml` | `config/constraint_templates.yaml` | |
| `references/{vector-definitions,gonzo-cases,trialectic-examples}.md` | `cognition/references/` | |
| `templates/{audit-log,constraint-set,transformation-seq}.yaml` | `templates/` | shared |
| `tests/smoke_test.sh` | `tests/cta_smoke.sh` | included in test-all |
| `LICENSE.md` | merged into root `LICENSE` | single ESL |
| `ATTRIBUTION.json` | merged into root `ATTRIBUTION.json` | Weft replaces "the operator" |

### Map B: route-cause → AVRS

| route-cause path | → AVRS path | Notes |
|---|---|---|
| `c-base/route_cause_shake.{h,c}` | `lib/avrs_shake.{h,c}` | RENAMED — unified hash backbone |
| `c-base/rc_metacog.{h,c}` | `metacognition/consciousness/witness_chain.{h,c}` | fills the documented-but-missing gap |
| `c-base/test_shake.c` + mutation-test | `tests/test_shake.c` + mutation harness | |
| `c-base/test_metacog.c` + mutation-test | `tests/test_witness_chain.c` + mutation | |
| `c-base/rc_metacog_SPEC.md` | `metacognition/consciousness/SPEC.md` | |
| `c-base/Makefile` | merged into `lib/Makefile` + `tests/Makefile` | |
| `capabilities/correlation-analysis/impl/correlation-analysis.{h,c}` | `cognition/correlation/correlation.{h,c}` | engine becomes fusion backend |
| `capabilities/correlation-analysis/impl/Makefile` | `cognition/correlation/Makefile` | |
| `capabilities/correlation-analysis/impl/ABI.md` | `cognition/correlation/ABI.md` | |
| 19 capability nodes (empty skeletons) | distributed to 5 layers per "Node placement" below | |
| Top-level `Makefile` | merged into root `Makefile` | test-all batches everything |
| `SKILL.md`, `INDEX.md`, `WAVES.md` | dissolved into AVRS root docs | history preserved in `docs/route-cause-history.md` |

### Map C: avrs-supervisor v2.3 → AVRS

| v2.3 path | → AVRS path | Language | Notes |
|---|---|---|---|
| `scripts/main.sh` | absorbed into `avrs.sh` | bash | orchestrator merges |
| `scripts/build_graph.py` | `perception/static/build_graph.pl` | Perl | rewrite, no Python |
| `scripts/execute_probe.sh` | `action/sandbox/execute_probe.sh` | bash | preserved |
| `scripts/heap_shaper.py` | `action/exploit_synthesis/heap_shaper.pl` | Perl | rewrite |
| `scripts/parse_gdb_mi.py` | `perception/dynamic/parse_gdb_mi.pl` | Perl | rewrite, matches ganesh.pl style |
| `scripts/poc_template.py` | `action/exploit_synthesis/poc_template.pl` | Perl | rewrite |
| `scripts/prod_validate.sh` | `tests/prod_validate.sh` | bash | preserved |
| `scripts/validate.sh` | `tests/validate.sh` | bash | preserved |
| `references/containerisation.md` | `docs/containerisation.md` | — | governance reference |

### Map D: avrs-supervisor-v2-5-integrated → AVRS

| v2.5 path | → AVRS path | Language | Notes |
|---|---|---|---|
| `registry/tool_registry.json` | `perception/tool_registry.json` | — | 94-tool surface, preserved as JSON |
| `scripts/avrs-full-tool-loader.py` | `perception/tool_loader.sh` + `perception/tool_registry.pl` | bash + Prolog | bash scans, Prolog stores+queries |
| `scripts/avrs_tool_integration.py` | merged into `perception/tool_registry.pl` | Prolog | dispatch functions → Prolog predicates that invoke subprocess |
| `implementations/witness_chain.py` | **DELETED** | — | stub replaced by full C witness_chain |
| `implementations/formation_integration_wrapper.py` | **DELETED** | — | subsumed by Prolog dispatcher |
| `scripts/run-swarm-tasks.sh` | `lib/swarm_run.sh` | bash | |
| `tests/test_heartbleed.sh` | `tests/test_heartbleed.sh` | bash | concrete integration anchor |
| `docs/00-START-HERE-AVRS-v2.5.md` | `docs/00-START-HERE.md` | — | revised |
| `docs/ANJA_KIMI_WORKING_AGREEMENT.md` | `docs/working_agreement.md` | — | preserved |
| `docs/AVRS-ADVISORY-BOARD-RECRUITMENT.md` | `docs/advisory_board.md` | — | |
| `docs/AVRS-TOOL-INTEGRATION-GUIDE.md` | `docs/tool_integration.md` | — | |
| `docs/AVRS-v2.5-DELIVERY-SUMMARY.md` | **DROPPED** | — | wave-record artifact, not relevant going forward |
| `docs/AVRS-v2.5-FINAL-DELIVERY.md` | **DROPPED** | — | same |
| `docs/AVRS_ETHICS_AND_MISSION.md` | `docs/ethics_mission.md` | — | |
| `docs/AVRS_GOVERNANCE_SPEC.md` | merged into `governance/GUIDE.md` + `governance/keel/policy.ads` | Ada/SPARK | spec becomes machine-checkable contracts where possible |

### Map E: avrs-dusk2dawn → AVRS (skeleton, mostly preserved)

| dusk2dawn path | → AVRS path | Notes |
|---|---|---|
| `SKILL.md` | root `SKILL.md` | extended description |
| `README.md` | root `README.md` | updated |
| `LICENSE` | root `LICENSE` | unified ESL |
| `avrs.sh` | root `avrs.sh` | extended to absorb cta-v1 and route-cause dispatchers |
| `boot/init.sh` | root `boot/init.sh` | adds apt install for swi-prolog + erlang |
| `core/` (Ada/SPARK) | preserved | |
| `perception/GUIDE.md` | preserved + extended | |
| `perception/static/sledge.gpr` | preserved | |
| `perception/dynamic/{ganesh.pl,oracle.java}` | preserved | |
| `perception/apk/` | preserved | |
| `perception/sidechannel/{hammer.fs,witness.d}` | preserved | |
| `perception/supply_chain/{axml.pl,dexdump.pl}` | preserved | |
| `cognition/{ghost.m,fusion_engine.pl,adversarial/,detection/}` | preserved | |
| `action/{exploit_synthesis/payload_gen.pl,patch_forge/patch_forge.sh,sandbox/sandbox_exec.sh}` | preserved | |
| `metacognition/feedback_analyzer.adb` | preserved | |
| `metacognition/consciousness/GUIDE.md` | updated to match the real witness_chain.c that now exists | |
| `metacognition/incident_review/` | preserved | |
| `governance/{dao/dao.py,keel/Makefile,messages/,report_generator.pl}` | **dao.py DELETED**; rest preserved | dao concept fully dissolves |
| `legacy-cortex/` | RENAMED → `kerebral/` | trademark name removed |

---

## Node placement: route-cause's 20 capability nodes across AVRS 5 layers

| Node | → AVRS layer | Subdirectory |
|---|---|---|
| repo-audit | Perception | `perception/repo_audit/` |
| code-review | Perception | `perception/code_review/` |
| vuln-scanning | Perception | `perception/vuln_scanning/` |
| secrets-detection | Perception | `perception/secrets/` |
| infrastructure-audit | Perception | `perception/infrastructure/` |
| binary-analysis | Perception | extends existing `perception/static/` + `perception/dynamic/` |
| attack-surface-mapping | Perception | extends `perception/supply_chain/` |
| entry-point-analyzer | Perception | `perception/entry_points/` |
| correlation-analysis | Cognition | `cognition/correlation/` |
| vulnerability-research | Cognition | `cognition/vulnerability_research/` |
| threat-intel-collection | Cognition | `cognition/threat_intel/` |
| security-auditing | Cognition | `cognition/security_auditing/` |
| multi-tool-deep-auditing | Cognition | `cognition/multi_tool_deep_audit/` |
| exploit-development | Action | extends `action/exploit_synthesis/` |
| test-first-poc-synthesis | Action | `action/test_first_poc/` |
| rapid-prototyping | Action | `action/rapid_prototyping/` |
| weighted-decision-scoring | Governance | `governance/weighted_decision/` |
| operationalized-dissent-guides | Governance | extends `governance/messages/` |
| token-compression | Metacognition | `metacognition/token_compression/` |
| orchestration | (dissolves into `avrs.sh`) | not a peer node |

---

## Language mapping (per AVRS_CLEANUP_LANGUAGES.md, container-constrained)

| Operation | Language | Cost in this container |
|---|---|---|
| Hash backbone, witness chain primitive, correlation engine | **C** + libcrypto | $0 (already there) |
| KEEL policy, contracts, invariants | **Ada/SPARK** | `apt install gnat` |
| Tool registry + queries | **Prolog** (SWI) | `apt install swi-prolog` |
| Tool loader (filesystem scan) | **bash** | $0 |
| Formation encoder (vector math) | **R** | $0 (already installed for cta-v1) |
| Swarm bridge (distributed coordination) | **Erlang/OTP** | `apt install erlang` |
| Perl rewrites of v2.3 Python (heap_shaper, parse_gdb_mi, poc_template, build_graph) | **Perl** | $0 (matches dusk2dawn's existing Perl) |
| CTA reasoning operators | **bash + R** | $0 (already from cta-v1) |
| Mercury/F#/D/Java subsystems from dusk2dawn | preserved as-is | (already in dusk2dawn) |

Total new apt installs: **gnat + swi-prolog + erlang**. All copyleft, ~50–80MB combined, one-shot.

---

## ATTRIBUTION pattern (going in unified root)

```json
{
  "name": "avrs",
  "version": "3.0.0",
  "license": "ESL-ANCSA-MRA-IndiModSHA-1.0",
  "original_creator": "Anja Evermoor",
  "handle": "@161evermoorFAFO / @gravermistakes",
  "co_authors": [
    { "name": "Weft", "role": "co-author",
      "contribution": "primitive scaffolding, test discipline, language analysis, cellular integration" }
  ],
  "dissolved_into_this": [
    "cta-v1 (v1.0)",
    "route-cause (Wave 0 snapshot)",
    "avrs-supervisor (v2.3)",
    "avrs-supervisor-v2-5-integrated (v2.5)",
    "avrs-dusk2dawn (skeleton, retained as substrate)"
  ],
  "deleted_concepts": [
    "DAO / democratic process (voting, quorum, proposal types) — not the tool's job",
    "disclosure-window policy enforcement — per-engagement, not hardcoded",
    "Python implementations — replaced per language-fit analysis",
    "AI-trademark naming in shipped artifacts — replaced with chosen names"
  ],
  "provenance_seal": {
    "primitive": "SHAKE256-xoflen-64",
    "hex_seal": null,
    "epoch": null
  }
}
```

No "the operator", no "the maintainer", no model identifiers anywhere in the shipped artifact.

---

## Build / test discipline

Top-level `Makefile` with one entry point:

```
make test-all
```

Runs:
1. `lib/` — C primitives (avrs_shake) + tests + mutation-tests
2. `metacognition/consciousness/` — witness_chain C + tests + mutation
3. `cognition/correlation/` — correlation engine + tests + mutation
4. `cognition/trialectic/` — bash+R smoke
5. `metacognition/{gonzo_check,invariant_detect,coraline_distance,homeostasis,rupture_trigger}/` — bash+R smokes
6. `perception/static/sledge.gpr` — Ada/SPARK build
7. `core/` — Ada/SPARK build with `gnatprove`
8. `governance/keel/policy.ads` — SPARK proofs
9. `perception/tool_registry.pl` — Prolog load + query tests
10. `metacognition/consciousness/swarm_formation_bridge.erl` — Erlang/OTP build + tests
11. `metacognition/consciousness/formation_encoder.R` — R tests
12. `perception/*.pl` — Perl tests (heap_shaper, parse_gdb_mi, build_graph, poc_template)
13. `governance/report_generator.pl` — Perl test
14. `tests/test_heartbleed.sh` — concrete integration

Anything below 100% under strict (`-Werror`, `pipefail`, gnatprove failures count) fails the build.

---

## Edge-name schema (canonical)

Witness-chain entries carry an `edge_name`: one or more single-token Unicode symbols from the 45-symbol alphabet below. All verified single-token in cl100k. Kanji carry operational verbs (East), Greek holds the two relations mathematics already owns (West), structurals do control flow — the dual-tradition split rendered in the symbol layer. Ge'ez and Egyptian hieroglyphs are reserved for **human-facing docs only** (zero single-token; they mark sacred/governance strata in READMEs and GUIDEs, never the machine chain).

**KANJI (31) — operational:**
源 source · 打 probe · 化 transform · 余 tolerance · 率 rate/yield · 断 decide/gate · 連 coupling · 関 function · 平 mean · 回 cycle · 集 aggregate · 時 latency · 了 conclude · 析 analyze · 合 synthesize · 影 shadow/adversarial · 修 debug · 流 flow · 核 core · 推 infer · 相 phase/state · 保 persist · 見 observe · 読 parse · 考 reason · 区 partition · 界 boundary · 再 retry · 止 halt · 因 cause · 果 effect

**GREEK (2) — iconic gap-fillers:** δ anomaly/change · ρ correlation

**STRUCTURAL (12) — control flow:** → feedforward · ← feedback · ↑ escalate · ↓ drill-down · − discard(FALSE) · ✔ verify/gate-pass · ● commit · ★ discovery · ☆ candidate · ♀ fuse(copper) · ☴ gentle-probe(Xun) · ⟩ handoff

Compound edges are short sequences read left-to-right: `δ↓析` (anomaly drills into analysis), `打ρ了` (probe, correlate, conclude), `影修` (shadow-probe then debug), `源見✔●` (source observed, verified, committed), `−` (false finding discarded), `断−再` (gate fails, retry). The `edge_name` member is validated against this 45-symbol set at write time (C rejects non-members; Ada/SPARK `Pre => Valid_Edge_Name(E)`).

---

## Resolved decisions

1. **Skill name**: **ANALGAPES** — *Accelerated Novel Adversarial Lifting, Generating, Architectural Pattern Engagement System*. Folder: `analgapes/`.
2. **legacy-cortex/ → kerebral/**.
3. **Doc language**: dusk2dawn's concise decision-rule tone + JP 2-0 intelligence-cycle vocabulary as layer aliases; Ge'ez may mark sacred/governance strata in human-facing docs.
4. **Source skill retention**: **decide later** — built in a fresh tree, nothing destroyed pre-decision.
5. **Apt install timing**: currents model — gnat at foundation; swi-prolog when Perception current opens; erlang when Swarm current opens.
6. **avrs-d2d-c2-extension**: stays separate, unchanged.

---

## Image-derived enrichments

- **JP 2-0 intelligence cycle** layer aliases: Governance=Planning/Direction, Perception=Collection, Cognition=Processing+Analysis/Production, Action=Dissemination/Integration, Metacognition=Evaluation/Feedback (wrapper).
- **Named-handoff semantics**: every inter-layer edge carries an `edge_name`; the chain is a *narrative* log.
- **COUPLING.md**: ship the inter-layer coupling matrix (feedforward/feedback/none/self-loop per layer-pair), asymmetric by design.
- **behavioral_signature**: KEEL provenance gains an optional operator-set field {decision_making, ethical_weighting, emotional_regulation, linguistic_cadence, curiosity_distribution, symbolic_grammar, relational_schema, narrative_identity_scaffolding}; no auto-AI-stamping.
- **Embedded-agency-aware KEEL**: policy checks include Goodhart resistance, corrigibility invariants, value-specification clarity, Vingean-reflection events.
- **Perception taxonomy tags**: (temporal_domain, analysis_technique, detection_method, knowledge_generation_type, data_source_class) per subsystem.
- **Anti-pattern note** in README: "not a kill chain (linear pipe); an intelligence cycle with cybernetic regulation."

---

## Currents plan (replaces sequential waves)

Not stages in a pipe — currents in a circuit. Some ignite at the foundation and never stop; tributaries join in dependency order, overlapping where independent. The witness chain (核) and KEEL (断) flow *through* everything — every subsystem writes to the chain and is sealed by KEEL. Verification is continuous: the chain is the verification record, and `make test-all` clears strict 100% at each confluence.

```
        PERPETUAL CURRENTS (ignite first, never stop)
   核 ── core ──────── C: avrs_shake + witness_chain
   断 ── keel ──────── Ada/SPARK: policy + seal        ← everything writes here
   流 ── orchestration  bash: avrs.sh routing             & is sealed here
                      │
   ┌──────────┬───────┼───────────┬──────────────┐
   ▼          ▼       ▼           ▼              ▼
 析 cognition  見 perception  打 action  影 swarm   断 governance-closure
```

| Current | Sym | Brings online | Languages | Confluence gate |
|---|---|---|---|---|
| **Core** | 核 | `lib/avrs_shake.{h,c}`, `metacognition/consciousness/witness_chain.{h,c}` (edge_name schema), tests + mutation | C | shake + witness compile/test/mutation pass; edge_name rejects non-members |
| **KEEL** | 断 | `governance/keel/policy.ads` (in-scope, ESL, chain-integrity, embedded-agency contracts), seal, behavioral_signature | Ada/SPARK | gnatprove discharges; Ada↔C seals a chain entry |
| **Orchestration** | 流 | `avrs.sh` routing; `boot/init.sh` (gnat ignite) | bash | routes end-to-end, writes ≥1 witness entry |
| **Cognition** | 析 | `cognition/correlation/` (C, ρ edges) + cta-v1 operators (trialectic, gonzo, invariant, synthesis, coraline, homeostasis, rupture) | C + bash/R | correlation emits edge-named entries; R operators consume chain |
| **Perception** | 見 | Perl rewrites (build_graph, parse_gdb_mi, heap_shaper, poc_template) + Prolog tool_registry (94 tools) + bash loader; taxonomy tags | Perl + Prolog + bash | registry resolves all 94 tools; Perl tools emit findings |
| **Action** | 打 | `action/test_first_poc/`, `rapid_prototyping/`, extends exploit_synthesis | bash + Perl | action emits chain entries; test-first gate works |
| **Swarm** | 影 | `swarm_formation_bridge.erl` (OTP) + `formation_encoder.R`; wire to chain | Erlang + R | OTP tree stands; formation vectors encode to chain |
| **Gov-closure** | 断 | weighted-decision, operationalized-dissent, COUPLING.md, remaining nodes, AVRS self-audit, composite seal, ATTRIBUTION (Weft), package | mixed | AVRS audits own tree clean; seal in shipped artifact |

**Confluence discipline**: a tributary is "flowing" only when `make test-all` stays at strict 100% with it added. Independent currents (e.g., Perception's Prolog registry, Cognition's R operators) may open in the same pass. Core + KEEL + Orchestration must ignite together (mutually referential — chain writes, KEEL seals, orchestrator routes; none testable alone). Apt installs follow the currents: **gnat now**, **swi-prolog** at Perception, **erlang** at Swarm.

---

## Edge-name schema (canonical — locked)

Witness-chain entries carry an `edge_name`: a short sequence of single-token symbols naming the handoff semantic. Every symbol is verified single-token in cl100k (BMP/CJK, no emoji, no trademark grep-bait). Compound edges are 2–3 symbol sequences read left-to-right.

Tri-script division mirrors the 4+4 dual-tradition epistemology: **kanji = operational verbs (East), Greek = iconic mathematical relations (West), structurals = control flow.**

### KANJI (31) — operational

| 源 source | 打 probe | 化 transform | 余 tolerance | 率 rate/yield | 断 decide/gate |
|---|---|---|---|---|---|
| 連 coupling | 関 function | 平 mean | 回 cycle | 集 aggregate | 時 latency |
| 了 conclude | 析 analyze | 合 synthesize | 影 shadow/adversarial | 修 debug | 流 flow |
| 核 core | 推 infer | 相 phase/state | 保 persist | 見 observe | 読 parse |
| 考 reason | 区 partition | 界 boundary | 再 retry | 止 halt | 因 cause |
| 果 effect | | | | | |

### GREEK (2) — iconic gap-fillers

δ anomaly/change · ρ correlation

### STRUCTURAL (12) — control flow

→ feedforward · ← feedback · ↑ escalate · ↓ drill-down · − discard(FALSE) · ✔ verify/gate-pass · ● commit · ★ discovery · ☆ candidate · ♀ fuse(copper) · ☴ gentle-probe(Xun) · ⟩ handoff

### Examples

| Edge | Reads as |
|---|---|
| `δ↓析` | anomaly drills into analysis |
| `打ρ了` | probe, correlate, conclude |
| `影修` | shadow-probe then debug |
| `源見✔●` | source observed, verified, committed |
| `−` | false finding discarded (truth-value gate) |
| `断−再` | gate fails, discard, retry |
| `集合☉` | (note: ☉ multi-token — would use 了) aggregate, synthesize, conclude → `集合了` |

### Implementation impact

- `witness_chain.c`: struct gains `char edge_name[16]` (UTF-8, ≤4 symbols). Validation fn `wc_edge_valid()` checks every codepoint ∈ the 45-symbol set.
- Ada/SPARK contract: `Edge_Name : Edge_String with Predicate => All_Codepoints_In_Alphabet (Edge_Name);`
- Non-machine docs (README, GUIDE headers) may additionally use Ge'ez + hieroglyphs for stratum markers — these never enter the machine chain (zero single-token in cl100k).

### Reference scripts (kept in repo)

`tools/edge_alphabet.json` — the 45 symbol→semantic mappings (machine-readable, drives validation codegen).
`tools/verify_alphabet.mjs` — re-runs the single-token check against cl100k; part of `make test-all`.
