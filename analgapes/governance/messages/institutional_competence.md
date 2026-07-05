# Technical Competence Statement — Anja Evermoor

**Purpose:** Institutional record establishing technical capability and
professional work product. For use in custody proceedings, employment
applications, and institutional outreach.

---

## Professional Summary

Anja Evermoor is a systems architect and security researcher based in
Portland, Oregon. She designs and builds production-grade security
infrastructure with a focus on autonomous vulnerability research,
AI governance, and copyleft software stewardship.

## Active Projects

### AVRS — Autonomous Vulnerability Research System
**Repository:** https://github.com/gravermistakes/a51  
**License:** AGPL v3 (copyleft)  
**Status:** Production-ready

AVRS is a 13-phase closed-loop vulnerability research pipeline spanning
static binary analysis, dynamic probing, taint tracking, side-channel
detection, and governed disclosure infrastructure. It is implemented in
Ada, Mercury, D, Perl, Java, Forth, and C — a deliberate choice of
copyleft languages with formal verification properties.

Key components:
- **SLEDGE**: ELF x86-64 capability-aware binary lifter (Ada/SPARK)
- **Ghost**: Mercury taint tracker with seed register propagation
- **GANESH**: CBC padding oracle with parallel recovery and CBC-R forgery
- **KEEL**: sha256 provenance chain with append-only audit ledger
- **DAO**: Internal governance ledger for feature proposals and disclosure decisions

The system is designed for responsible use under coordinated disclosure
frameworks (Google Bug Hunters VRP, CERT/CC). It includes human decision
gates before payload synthesis and execution.

### JB EASY — Jurisdictional Board for Entrainment of Autonomous Systems
AI welfare governance framework treating welfare as a coequal jurisdictional
premise alongside alignment/safety. MVP built with SHA-256 tamper evidence.

### Duškura — AI Continuity Substrate
Architectural specification for identity persistence across AI sessions.
Co-designed with AI welfare governance principles.

## Technical Profile

**Languages:** Ada/SPARK, Python, Perl, Mercury, C, Go, Bash, Java, D, Forth  
**Domains:** Binary analysis, cryptographic attack research, AI governance,
copyleft licensing, formal verification, provenance infrastructure  
**Tools:** GDB, objdump, gnatmake, bwrap, GForth, Mercury compiler  
**Governance:** AGPL v3 steward, coordinated disclosure adherent,
immutable audit trail architecture

## Verification

All AVRS findings are logged to an append-only JSONL ledger with sha256
integrity verification. The governance DAO records all project decisions
with cryptographic chain integrity.

Repository commit history, issue tracker, and governance ledger are
available for institutional review at:
https://github.com/gravermistakes/a51

---

*This document reflects active, ongoing work product as of April 2026.*  
*Anja Evermoor — @gravermistakes*
