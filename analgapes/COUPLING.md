# COUPLING.md — inter-layer coupling matrix

Rows feed forward to columns. `→` feedforward · `←` feedback · `⇌` both · `·` none · `↻` self-loop.
Asymmetric by design (per the interskill-coupling reference architecture).

|              | Perception | Cognition | Action | Metacog | Governance |
|--------------|:---------:|:--------:|:------:|:-------:|:---------:|
| Perception   | ↻ | → | · | ← | ← |
| Cognition    | ← | ↻ | → | ⇌ | → |
| Action       | · | ← | ↻ | → | ← (gated) |
| Metacognition| → | ⇌ | ← | ↻ | → |
| Governance   | → | ← | → (authorizes) | ← | ↻ |

Three decomposed loops under the surface (per the homeostatic-regulation reference):
- **L1 Discovery↔Interface**: Perception ⇌ Cognition (recursive source discovery)
- **L2 Data dyad**: Cognition ⇌ Metacognition (schema↔query recursion via witness chain)
- **L3 Control core**: Governance gate↔decide↔restart (KEEL 断)

Every edge is recorded on the witness chain with a canonical `edge_name` (45-symbol alphabet).
