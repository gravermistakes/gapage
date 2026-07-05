# cta-v1 :: scripts/r/synthesis_gen.R
# Phase 6: Synthesis generator. Consumes Phase 1 (trialectic) JSON and
# optionally Phase 2 (invariant) JSON, emits a synthesis statement using the
# template table from the CTA spec.
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

args <- cta_args()
phase1_path <- cta_arg_str(args, "phase1", "")
phase2_path <- cta_arg_str(args, "phase2", "")
if (!nzchar(phase1_path)) cta_die("--phase1 required (path to trialectic.sh JSON output)")

p1 <- fromJSON(phase1_path, simplifyVector = TRUE)
synth_type <- p1$synthesis_type
X <- p1$statements$X
Y <- p1$statements$Y
L <- p1$components$logical
S <- p1$components$semantic
P <- p1$components$probabilistic
St <- p1$components$structure
F_ <- p1$components$`function`
C <- p1$components$context
congr <- p1$congruence

# Optional Phase 2 input gives us the invariant mask, used in some templates.
preserved <- NULL
if (nzchar(phase2_path) && file.exists(phase2_path)) {
    p2 <- fromJSON(phase2_path, simplifyVector = TRUE)
    preserved <- p2$dimensions_preserved
}

# Templates per synthesis type (from CTA spec § Trialectic Resolution table).
synth_text <- switch(synth_type,
    integration = sprintf(
        "Integration synthesis: '%s' and '%s' are extensionally equivalent under the normalization metric. The composite congruence is %.3f; logic, semantics, and structure all align. Treat as a single content node.",
        X, Y, congr),

    rejection = sprintf(
        "Rejection synthesis: '%s' and '%s' are logically incompatible (L = %.3f). %s Use Adverse (ð) at ε_max ≥ 1.5 to verify the fracture is systemic, then commit to whichever side dominates contextually.",
        X, Y, L,
        if (!is.null(p1$logical_detail)) sprintf("Detected: %s.", p1$logical_detail) else ""),

    complement = sprintf(
        "Complement synthesis: '%s' and '%s' occupy disjoint vocabulary but cohere under the same logical and contextual frame (L = %.3f, S = %.3f, C = %.3f). Hold both: each names what the other cannot. Apply Transverse (⊥) to confirm orthogonality of their nuisance dimensions.",
        X, Y, L, S, C),

    context_partition = sprintf(
        "Context-partition synthesis: '%s' and '%s' share the same domain vocabulary (C = %.3f) but diverge semantically (S = %.3f). The disagreement is conditional on subdomain; partition the context space and assign each statement to its region. Apply Extroverse (⬗) to mix the partitions.",
        X, Y, C, S),

    hierarchy = sprintf(
        "Hierarchy synthesis: '%s' and '%s' share predicate structure (St = %.3f) but differ in functional role (F = %.3f). One is a special case of the other or one operates at a meta-level. Reduce by identifying the containing scope.",
        X, Y, St, F_),

    tradeoff = sprintf(
        "Trade-off synthesis: '%s' and '%s' share structure and logic but conflict on function (F = %.3f). Neither can be maximized without cost to the other. Use Pareto frontier reasoning; pick the operating point matching current constraints. Apply Subverse (♆) to test sensitivity.",
        X, Y, F_),

    paradox = sprintf(
        "Paradox synthesis: '%s' and '%s' show high component-variance (no single component dominates) and composite congruence %.3f. This is irreducible tension. Document both, mark for rupture trigger if the paradox blocks downstream resolution. Apply Microversal (∴) to probe the Δ→0 limit.",
        X, Y, congr),

    dialectic = sprintf(
        "Dialectic synthesis: '%s' and '%s' are in productive tension (congruence %.3f, no single failure mode). Hold the contradiction; both inform the resolution at a higher level. Apply Perverse (♇) at λ ≈ 0.1 to find the mismatch-frontier.",
        X, Y, congr),

    sprintf("Unknown synthesis type '%s' for ('%s', '%s'). Manual review required.", synth_type, X, Y)
)

# Suggested next-phase operations based on synthesis type.
next_ops <- switch(synth_type,
    integration       = c("invariant_detect.sh: confirm structural preservation"),
    rejection         = c("adverse_mc.sh --epsilon-max 1.5: verify systemic fracture",
                          "rupture_trigger.sh: orthogonal jump if rejection is recurrent"),
    complement        = c("transverse_mc.sh: orthogonalization check",
                          "diverse_mc.sh: explore the complementary span"),
    context_partition = c("extroverse_mc.sh: mix the partitions"),
    hierarchy         = c("invariant_detect.sh: confirm scope nesting"),
    tradeoff          = c("subverse_mc.sh: sensitivity",
                          "introverse_mc.sh: jackknife stability"),
    paradox           = c("microversal_mc.sh: Δ→0 probe",
                          "rupture_trigger.sh: consider orthogonal jump"),
    dialectic         = c("perverse_mc.sh --lambda 0.1: mismatch frontier"),
    character(0)
)

cta_emit(list(
    phase = 6,
    synthesis_type = synth_type,
    congruence = congr,
    statements = list(X = X, Y = Y),
    components = list(L = L, S = S, P = P, St = St, F = F_, C = C),
    invariant_dimensions_preserved = preserved,
    synthesis_text = synth_text,
    next_phase_operations = next_ops
))
