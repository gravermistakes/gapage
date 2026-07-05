# BUILD_STATUS

`make test-all` → 15/15 strict (−Werror, mutation-gated). What that covers:

## Verified-flowing (compiled + tested in this container)
- Core: avrs_shake (C, vs openssl), witness_chain (C, edge-name schema, truth-gate, behavioral_signature)
- KEEL: keel_policy + keel_seal (Ada/SPARK) — gate 6/6, Ada→C seal == openssl
- Orchestration: avrs.sh — 5 edge-named entries per cycle
- Cognition: correlation (C, deterministic clustering), trialectic + MC modalities (bash/R)
- Perception: tool_registry (Prolog, 94 tools), parse_gdb_mi + build_graph + heap_shaper (Perl)
- Action: poc_template (Perl, gated), test_first_poc gate
- Swarm: swarm_formation_bridge (Erlang/OTP), formation_encoder (R)
- Substrate Perl: ganesh.pl (2 bugs FIXED), axml, dexdump, apk/*, detection/* — all syntax-valid

## Known-partial (source present, NOT yet compiling here)
- Legacy substrate Ada: core/src/avrs_core.adb + perception/static/src/sledge.adb carry
  pre-existing dusk2dawn compile errors (Spawn API mismatch, type resolution). Two bugs fixed
  (ambiguous Append ×2, string-literal index); more remain. These are legacy lifters, NOT part
  of the verified integration spine. KEEL (the governance Ada) compiles and is tested.
- ghost.m is MERCURY (logic language), not Octave — my plan mislabeled it. Mercury compiler (mmc) is not apt-available here, so it cannot be compiled in this container. Source present + correctly attributed.

Honest scope: the integration organism (currents + recombined primitives) is green end-to-end.
The folded-in legacy substrate is present and syntax-swept where possible; legacy Ada needs a
GNAT-version reconciliation pass before it compiles.

## Update — follow-up push (legacy Ada + write-through)
- Legacy substrate Ada now COMPILES + LINKS: avrs_core.adb (Spawn → function form ×2;
  ambiguous Append qualified ×2), sledge.adb (Natural xor → modular conversion;
  string-literal index → constant; limited Standard_Output → /dev/stdout open),
  feedback_analyzer.adb. substrate-test now compiles them (not just presence-checks).
  NOTE: sledge links but crashes at runtime (STORAGE_ERROR) on trivial input — a deeper
  legacy bug, honestly unfixed; compilation is what the gate asserts.
- ghost.m re-attributed: it is MERCURY, not Octave (my plan was wrong). mmc not apt-available.
- Cellular write-through: correlation engine now writes a ρ edge (cognition→governance)
  directly to the unified witness chain. Asserted in cognition-test. legacy workspace env-var
  leftovers fully removed (0 non-doc).
