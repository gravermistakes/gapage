# cta-v1 :: scripts/r/averse_mc.R
# Modality XVI: Averse Monte Carlo (∇)
# Functional form: ⩮ᵀ ⊗ Ω ⊗ ⚹
# Semantics (planned): transpose-mismatch under Ω weighting
# Status: NOT IMPLEMENTED — placeholder. See SKILL.md "Unimplemented Modalities".
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

cta_emit(list(
    modality = "averse_mc",
    symbol = "∇",
    equation = "⩮ᵀ ⊗ Ω ⊗ ⚹",
    planned_semantics = "transpose-mismatch under Ω weighting",
    status = "not_implemented",
    message = paste("Modality XVI (Averse) is reserved.",
                    "Equation form is canonical; implementation pending.",
                    "See SKILL.md for the open-implementation queue.")
))
quit(status = 2, save = "no")
