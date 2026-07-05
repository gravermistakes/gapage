# Component Vector Definitions

The trialectic congruence score (Phase 1) decomposes into **six components**.
Each is a value in `[0, 1]` where `1` means "perfect alignment on this axis"
and `0` means "complete disagreement". The composite congruence is a
domain-weighted sum.

## L — Logical Consistency

Detects logical incompatibility between statements X and Y.

| Signal | Score | Mechanism |
|---|---|---|
| direct antonym pair found AND modal conflict | 0.05 | `cta_has_contradiction` + `cta_modal_conflict` |
| direct antonym pair found | 0.15 | antonym dictionary lookup |
| modal conflict (MUST/NEVER, UNIV/NEG) | 0.25 | modal-operator parsing |
| asymmetric negation (only one side negates) | 0.55 | heuristic |
| no contradiction signal | 1.00 | default |

Antonym dictionary lives inline in `lib/common.sh` and includes ~60 pairs
covering polarity, modality, security, scale, and structural opposites
(centralized/decentralized, encrypted/plaintext, etc.).

## S — Semantic Similarity

A blend of unigram TF-cosine and bigram Jaccard on normalized tokens.

```
S = 0.7 · cos(TF_unigram(X), TF_unigram(Y))
  + 0.3 · |bigrams(X) ∩ bigrams(Y)| / |bigrams(X) ∪ bigrams(Y)|
```

Tokenization pipeline: lowercase → strip punctuation → remove stopwords
(retaining modals/quantifiers) → Porter-lite stem. Stopwords list and stemmer
are in `lib/common.sh`.

## P — Probabilistic Co-occurrence

A corpus-free proxy. Because we have no external corpus, we derive an
honest sigmoid-shaped score from content-overlap with an antonym penalty:

```
overlap = |shared_tokens| / |union_tokens|
penalty = 0.25 if contradiction else 0
P = clamp(0.5 + 0.5 · (overlap - penalty - 0.3) / 0.4, [0, 1])
```

This is **not** a true joint probability. It is labelled `corpus-free proxy`
in the implementation comments and should be replaced with a real co-occurrence
estimator when a domain corpus is available.

## St — Structural Alignment

Compares predicate-pattern density.

For each statement, count occurrences of:

- **copula** verbs: is, are, was, were, be, …
- **modal** verbs: must, may, can, should, …
- **action** verbs: do, make, optimize, verify, …
- **conditional** markers: if, when, unless, …

Normalize each statement's counts to a probability vector over the four
categories. `St = 1 − L1_distance(p_X, p_Y) / 2`.

## F — Functional / Goal Alignment

Counts goal-positive (`optimize`, `maximize`, `ensure`, `preserve`, …) and
goal-negative (`degrade`, `break`, `damage`, `compromise`, …) tokens in each
statement. The net intent score per side is `optimize - harm`. F is `1` minus
the normalized absolute difference of net intents. Neutral statements (no
goal words) get `F = 0.6` (slightly above midpoint).

## C — Context / Domain Overlap

Eight pre-defined domain keyword sets:

| Domain | Keywords |
|---|---|
| safety | safety, safe, risk, hazard, danger, verify, … |
| performance | speed, fast, latency, throughput, bandwidth, … |
| reliability | reliable, stable, consistent, durable, robust, … |
| security | secure, attack, adversary, threat, exploit, … |
| quality | accuracy, precision, correctness, defect, … |
| cost | cost, budget, price, expensive, economical, … |
| time | time, deadline, urgent, immediate, schedule, … |
| scale | scale, scalable, grow, shrink, elastic, … |

For each statement, count domains hit. `C = |domains_both_hit| / |domains_either_hit|`.
If neither statement hits any domain, C = 0.5 (neutral).

## Composite Congruence

`congruence = wL·L + wS·S + wP·P + wSt·St + wF·F + wC·C`

Weights chosen by **domain** (see `config/cta-config.yaml`):

- **formal**: privilege L and St (proof/structure)
- **natural**: privilege S and P (vocabulary/empirics)
- **empirical**: privilege P (data co-occurrence)
- **pragmatic**: privilege F (goal-alignment)
- **default**: balanced
