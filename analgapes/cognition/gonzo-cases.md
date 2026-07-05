# Gonzo Diagnosis: Canonical Cases

The Gonzo test (Phase 3) detects whether a transformation operator changes its
own meaning under iterated application. Diagnosis is one of `stable`,
`diverging`, `converging`, or `oscillating`.

The decision uses **relative variance** (variance / mean²) of the inter-step
distance series, after 3-point moving-average smoothing. This is
scale-invariant: doubling every distance does not change the diagnosis.

## stable

The operator preserves its semantics. Consecutive-state distances are
constant (within noise floor).

**Example: rotation in 2D**
```bash
./gonzo_check.sh --initial "1,0" --transform "rotate:0:1:0.7854" --iterations 20
```
A π/4 rotation traces a regular octagon. Every step traverses an equal arc;
distances are constant. Diagnosis: `stable`.

**Example: identity**
```bash
./gonzo_check.sh --initial "1,2,3" --transform "identity" --iterations 5
```
Zero motion → zero variance → `stable`.

## diverging

The operator amplifies. Distances grow over iterations; trend slope is
positive and exceeds the relative-trend threshold.

**Example: uniform scaling > 1**
```bash
./gonzo_check.sh --initial "1,1,1" --transform "scale_all:2" --iterations 10
```
Each step doubles. Distances form a geometric series with ratio 2. The trend
slope on the smoothed distances is strongly positive. Diagnosis: `diverging`.

This is the prototypical case where the operator's *meaning* changes under
iteration: "double" applied repeatedly is not the same operator as "double"
applied once — the destination space is no longer bounded.

## converging

The operator contracts. Distances shrink; trend slope is negative.

**Example: uniform shrinking**
```bash
./gonzo_check.sh --initial "10,10,10" --transform "scale_all:0.5" --iterations 10
```
Each step halves the state. Geometric series with ratio 0.5. Trend slope
negative; relative variance still high (because variance/mean² is
scale-invariant). Diagnosis: `converging`.

## oscillating

High relative variance but no sustained trend. The operator changes meaning
in a bounded, cyclical way.

**Example: noisy rotation with damping that approximates a limit cycle**
```bash
./gonzo_check.sh --initial "1,0" --transform "noise:0.3" --iterations 30 --threshold 0.1
```
Random walks visit different distances at each step but stay bounded. Trend
is near zero, variance is high → `oscillating`.

## Reading the smoothed series

The output contains both `distances` (raw) and `smoothed_distances`. If the
raw series looks chaotic but smoothed is monotone, the operator is
*signal-stable, noise-divergent* — usually a numerical issue rather than a
semantic one. Increase `--smooth` if needed.

## When the diagnosis disagrees with intuition

- A 2D rotation by π/2 over 4 iterations returns to the origin → variance is
  zero → `stable`. But the rotation by an irrational angle (e.g. 1 radian)
  never returns, distances are constant, still `stable`. The operator IS
  stable in the gonzo sense even though the orbit is dense — what matters is
  whether **the magnitude of change per step is changing**.
- A linear operator with eigenvalue exactly 1 is `stable`; >1 diverges; <1 converges.
- Non-linear operators (`noise:σ`, gradient-descent steps) can flip between
  diagnoses as state moves through different regions; consider running
  multiple gonzo checks at different initial states and aggregating.

## Mapping to action

| diagnosis | next operator |
|---|---|
| stable     | safe to chain in pipelines; no special handling |
| diverging  | apply `Adverse` to bound, or `Subverse` to measure fracture |
| converging | apply `Reverse` (▽) to amplify tail before info is lost |
| oscillating| apply `Microversal` (∴) to locate the cycle's limit |
