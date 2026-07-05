# cta-v1 :: scripts/r/homeostasis.R
# Phase 5: Homeostatic validation. Given a state vector and a constraint set,
# verify all constraints hold within epsilon tolerance. The synthesis (Phase 6)
# is only valid if homeostasis returns true.
#
# Constraints DSL (one --constraint arg, repeatable):
#   sum:k                  sum of vector elements equals k
#   mean:k                 mean equals k
#   min:k                  min equals k (lower bound preserved)
#   max:k                  max equals k (upper bound preserved)
#   range:lo:hi            all elements in [lo, hi]
#   norm:k                 L2 norm equals k
#   variance:k             sample variance equals k
#   monotonic:asc          values weakly increasing
#   monotonic:desc         values weakly decreasing
#   dim_equal:i:k          dimension i equals k
#   dim_in:i:lo:hi         dimension i in [lo, hi]
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

source(file.path(dirname(sub("^--file=", "",
    grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1])),
    "cta_common.R"))

# Parse args. --constraint is repeatable, so we extract manually.
raw <- commandArgs(trailingOnly = TRUE)
constraints <- character()
state_str <- NULL
epsilon <- 0.03
i <- 1
while (i <= length(raw)) {
    if (raw[i] == "--state") { state_str <- raw[i + 1]; i <- i + 2 }
    else if (raw[i] == "--constraint") { constraints <- c(constraints, raw[i + 1]); i <- i + 2 }
    else if (raw[i] == "--epsilon") { epsilon <- as.numeric(raw[i + 1]); i <- i + 2 }
    else i <- i + 1
}

if (is.null(state_str)) cta_die("--state required (e.g. \"1,0.5,0.2\")")
if (length(constraints) == 0) cta_die("at least one --constraint required")

x <- as.numeric(strsplit(gsub("[\\[\\]\\s]+", "", state_str, perl = TRUE), ",")[[1]])
x <- x[!is.na(x)]
n <- length(x)
if (n < 1) cta_die("state must be non-empty")

check_one <- function(spec) {
    parts <- strsplit(spec, ":", fixed = TRUE)[[1]]
    kind <- parts[1]
    args_v <- if (length(parts) > 1) suppressWarnings(as.numeric(parts[-1])) else numeric(0)
    arg_str <- if (length(parts) > 1) parts[-1] else character(0)
    result <- switch(kind,
        sum      = list(observed = sum(x),  expected = args_v[1], pass = abs(sum(x)  - args_v[1]) <= epsilon),
        mean     = list(observed = mean(x), expected = args_v[1], pass = abs(mean(x) - args_v[1]) <= epsilon),
        min      = list(observed = min(x),  expected = args_v[1], pass = abs(min(x)  - args_v[1]) <= epsilon),
        max      = list(observed = max(x),  expected = args_v[1], pass = abs(max(x)  - args_v[1]) <= epsilon),
        range    = list(observed = c(min(x), max(x)), expected = c(args_v[1], args_v[2]),
                        pass = (min(x) >= args_v[1] - epsilon) && (max(x) <= args_v[2] + epsilon)),
        norm     = list(observed = sqrt(sum(x^2)), expected = args_v[1],
                        pass = abs(sqrt(sum(x^2)) - args_v[1]) <= epsilon),
        variance = list(observed = if (n >= 2) var(x) else 0, expected = args_v[1],
                        pass = abs((if (n >= 2) var(x) else 0) - args_v[1]) <= epsilon),
        monotonic = {
            if (arg_str[1] == "asc")  list(observed = all(diff(x) >= -epsilon), expected = TRUE, pass = all(diff(x) >= -epsilon))
            else if (arg_str[1] == "desc") list(observed = all(diff(x) <= epsilon), expected = TRUE, pass = all(diff(x) <= epsilon))
            else list(observed = NA, expected = NA, pass = FALSE)
        },
        dim_equal = {
            idx <- as.integer(arg_str[1]) + 1L
            if (idx < 1 || idx > n) list(observed = NA, expected = args_v[2], pass = FALSE)
            else list(observed = x[idx], expected = args_v[2], pass = abs(x[idx] - args_v[2]) <= epsilon)
        },
        dim_in = {
            idx <- as.integer(arg_str[1]) + 1L
            if (idx < 1 || idx > n) list(observed = NA, expected = c(args_v[2], args_v[3]), pass = FALSE)
            else list(observed = x[idx], expected = c(args_v[2], args_v[3]),
                      pass = (x[idx] >= args_v[2] - epsilon) && (x[idx] <= args_v[3] + epsilon))
        },
        list(observed = NA, expected = NA, pass = FALSE, error = paste("unknown constraint:", kind))
    )
    result$constraint <- spec
    result
}

results <- lapply(constraints, check_one)
overall <- all(vapply(results, function(r) isTRUE(r$pass), logical(1)))

cta_emit(list(
    phase = 5,
    state = x,
    epsilon = epsilon,
    n_constraints = length(constraints),
    results = results,
    homeostasis = overall
))
