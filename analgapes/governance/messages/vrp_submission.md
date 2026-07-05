# Google VRP Submission — Template

**Platform:** https://bughunts.google.com  
**Submission Type:** Security Vulnerability Report

---

## Summary

[One sentence: what the vulnerability is and where.]

## Affected Product / Scope

**Product:** [Chrome / Android / Google Cloud / etc.]  
**Version:** [Specific version tested]  
**Component:** [Binary / service / endpoint]  
**In Scope per VRP rules:** [Yes — cite the relevant scope entry]

## Vulnerability Details

**Class:** [Memory corruption / cryptographic weakness / auth bypass / etc.]  
**CVSS (self-assessed):** [Score] [Vector string]

### Root Cause

[2–3 sentences: the specific code path, missing check, or incorrect assumption
that creates the vulnerability.]

### Reproduction Steps

1. [Step 1]
2. [Step 2]
3. [Step 3 — what you observe]

### Proof of Concept

[Describe what the PoC does. Attach as separate file.
For memory corruption: include crash log, registers, backtrace.
For crypto: include plaintext recovered, request/response transcript.]

## Impact

[What an attacker can do. Privilege level, data access, code execution, etc.
Be specific — "arbitrary code execution as renderer process" not "could be serious."]

## Suggested Fix

[Specific change: function name, check to add, API to use instead.]

## Discovery Method

Discovered using AVRS (Autonomous Vulnerability Research System) —
open-source vulnerability research pipeline.
Repository: https://github.com/gravermistakes/a51 (AGPL v3)

## Timeline

- [Date]: Vulnerability identified via AVRS pipeline
- [Date]: PoC confirmed in sandboxed environment  
- [Date]: This submission

---

*Submitted under Google VRP rules. Requesting coordinated disclosure.*
