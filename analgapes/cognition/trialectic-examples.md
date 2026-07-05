# Trialectic Examples: One Pair per Synthesis Type

The synthesis classifier (Phase 1 → Phase 6) maps each pair `(X, Y)` to one
of eight types. Below: a canonical example pair for each, with the
components that drive the classification.

All examples are reproducible with:
```bash
./scripts/trialectic.sh -x "..." -y "..."
```

## integration — `congruence > 0.80, L > 0.80, St > 0.70, C > 0.70`

> **X**: "The system must verify before deployment"
> **Y**: "The system must verify before deployment"

After normalization, X and Y are textually identical. The classifier
short-circuits to `integration` whenever `normalize(X) = normalize(Y)`,
regardless of context score. Otherwise, requires high L, St, and C.

## rejection — `L < 0.30 OR ≥ 3 components < 0.30`

> **X**: "All squares are circles"
> **Y**: "No circle is a square"

Antonym pair `all/none` triggers `L = 0.15`. Plus low S and P from disjoint
content vocabulary. Three components below 0.30 → rejection.

A second example with modal-conflict only:

> **X**: "Code must always be reviewed"
> **Y**: "Code may sometimes ship without review"

The `MUST` in X conflicts with `MAY` in Y, and `always` conflicts with the
implicit `not always` of "sometimes". Modal conflict → `L = 0.25` → rejection.

## complement — `S < 0.45 AND L > 0.65`

> **X**: "Analysis breaks problems into parts"
> **Y**: "Intuition perceives wholes"

Different vocabulary (S ≈ 0), no logical contradiction (L = 1.0), structurally
similar (both copular-action). The two statements are NOT in tension — they
describe orthogonal cognitive faculties. Hold both.

## context_partition — `C > 0.65 AND S < 0.60`

> **X**: "In production, prefer reliability over speed"
> **Y**: "In benchmark mode, prefer speed over reliability"

Both statements share the same domain vocabulary (performance + reliability)
but disagree semantically. They are reconciled by **partitioning the context
space**: each holds in its own region.

## hierarchy — `St > 0.65 AND F < 0.55`

> **X**: "Every prime is a natural number"
> **Y**: "Every natural number is an integer"

Same structural pattern ("every X is Y"). Different functional roles:
inclusion in different sets. Synthesis: one statement names a sub-scope of
the other. Reduce by identifying the containing scope.

## tradeoff — `F < 0.50 AND mean(L, St) > 0.60`

> **X**: "Maximize throughput"
> **Y**: "Minimize latency"

Both are imperatives (high St), logically compatible (L = 1.0), but
functionally opposed (`maximize` vs `minimize` on coupled quantities). No
single operating point optimizes both; trade-off frontier reasoning required.

## paradox — `variance > 0.03 AND max_component < 0.80`

> **X**: "This statement is false"
> **Y**: "This statement is true"

Components disperse: L tries to evaluate, S sees identical structure, P sees
collapse. No component dominates. The pair is irreducibly paradoxical.
Apply `microversal_mc` to probe the Δ→0 limit of any computed statistic.

## dialectic — fallback (productive tension, no specific failure mode)

> **X**: "Speed optimizes throughput"
> **Y**: "Reliability optimizes throughput"

Composite congruence ≈ 0.74. L, St, F all reasonable. C ≈ 0.5 (both touch
performance domain but X doesn't hit reliability). No single component fails
or dominates → `dialectic`. Hold the tension; apply Perverse at λ ≈ 0.1.

## When the classifier disagrees with your intuition

The classifier is heuristic. If you expect `complement` but get
`context_partition`, your C score is probably above 0.65 — meaning the
statements share more domain vocabulary than you thought. Check the
`components` block in the JSON output, identify which threshold is being
crossed, and either:

- Adjust the input statements to disambiguate, or
- Pass `--domain formal | natural | empirical | pragmatic` to reweight, or
- Tune the thresholds in `config/cta-config.yaml`.
