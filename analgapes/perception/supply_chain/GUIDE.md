---
name: phoenix-supply-chain-oracle
description: >
  Phoenix – Supply Chain Vulnerability Oracle. Maps binary dependencies,
  queries CVEs, verifies vulnerable code presence via capability lifting,
  produces KEEL-sealed accountability graph. Use when the user wants to
  audit a binary's supply chain, check for known CVEs in linked libraries,
  verify whether vendor backports actually patched a vulnerability, or
  produce a cryptographically sealed dependency provenance chain. Triggers
  on: "audit supply chain", "check dependencies for CVEs", "verify patches",
  "dependency graph", "supply chain analysis", "SBOM", "bill of materials",
  "what libraries does this binary use", or any request involving recursive
  binary dependency analysis with vulnerability correlation. Also trigger
  when the user references a specific binary and asks about its security
  posture or transitive dependencies.
arguments:
  - name: target_binary
    type: string
    description: Path to ELF binary to analyze.
  - name: max_depth
    type: integer
    default: 5
    description: Maximum dependency recursion depth.
  - name: timeout_seconds
    type: integer
    default: 120
  - name: output_format
    type: string
    default: json
    enum: [json, dot, markdown]
allowed_tools: [bash_tool]
user_invocable: true
---

# Phoenix – Supply Chain Vulnerability Oracle

## Overview

Phoenix analyzes a binary, recursively discovers all linked shared libraries,
fetches known CVEs, and uses **capability lifting** (SLEDGE) to verify whether
the vulnerable code is actually present — accounting for vendor backports.

## Components

| Component | Language | Role |
|-----------|----------|------|
| Strix | OCaml | ELF dependency parser + symbol resolution |
| Chimera | Perl | CVE feed aggregator (NVD, OSV, GitHub) |
| Sphinx | Ada/SPARK | Provenance graph builder with formal contracts |
| KEEL | GNU Make | Cryptographic sealing of entire analysis |
| Oracle | Perl | Patch verification via capability lifting |

## Execution Flow

```
Phase 1: STRIX   — Parse ELF, extract NEEDED, resolve paths, enumerate symbols
Phase 2: CHIMERA — For each library, query NVD/OSV for known CVEs
Phase 3: ORACLE  — For each CVE, verify vulnerable function presence in binary
Phase 4: SPHINX  — Build provenance graph linking binary → lib → CVE → verdict
Phase 5: KEEL    — SHA-256 seal every artifact, generate provenance chain
```

## Quick Start

```bash
/phoenix-supply-chain-oracle
  target_binary: /usr/bin/nginx
  max_depth: 3
  output_format: json
```

## Compiler Requirements

| Tool | Required | Fallback |
|------|----------|----------|
| ocamlopt | Preferred | readelf + awk |
| gnatmake | Preferred | JSON-only graph (no SPARK contracts) |
| perl + JSON + LWP | Required | No CVE lookup without these |
| readelf, nm, objdump | Required | Core ELF tooling |
| sha256sum | Required | KEEL sealing |
| jq | Preferred | Python json fallback |

Missing compilers trigger graceful degradation, not hard failure.
The orchestrator (`scripts/phoenix_main.sh`) detects available tools
and routes accordingly.

## Output

- `results/dependency_graph.json` — Full audit with CVE verdicts
- `results/phoenix_report.md` — Human-readable summary
- `seals/*.seal` — KEEL provenance for every artifact
- `provenance_chain.txt` — Signed chain of custody

## License

GNU GPL v3.0 or later.
