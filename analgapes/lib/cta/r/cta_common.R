# cta-v1 :: scripts/r/cta_common.R
# Shared R helpers. Sourced by every R compute engine.
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0
# Original Creator: Anja Evermoor (@161evermoorFAFO / @gravermistakes)

suppressPackageStartupMessages({
    library(jsonlite)
    library(stats)
})

# Force UTF-8 locale so ESL/CTA glyphs (⇋ ▽ ☿ ð etc.) survive JSON serialization.
suppressWarnings(Sys.setlocale("LC_ALL", "C.UTF-8"))
options(encoding = "UTF-8")

# ---------- argument parsing ----------
# Parse --key value pairs from commandArgs into a named list.
cta_args <- function() {
    raw <- commandArgs(trailingOnly = TRUE)
    out <- list()
    i <- 1
    while (i <= length(raw)) {
        if (substr(raw[i], 1, 2) == "--") {
            key <- substring(raw[i], 3)
            if (i + 1 <= length(raw) && substr(raw[i + 1], 1, 2) != "--") {
                out[[key]] <- raw[i + 1]
                i <- i + 2
            } else {
                out[[key]] <- TRUE
                i <- i + 1
            }
        } else {
            i <- i + 1
        }
    }
    out
}

# ---------- I/O ----------
# Read a one-column numeric file (one value per line, ignoring blanks).
cta_read_samples <- function(path) {
    if (!file.exists(path)) stop(paste("file not found:", path))
    x <- scan(path, what = numeric(), quiet = TRUE)
    x[!is.na(x)]
}

cta_write_samples <- function(x, path) {
    writeLines(format(x, digits = 8, scientific = FALSE, trim = TRUE), path)
}

# ---------- stats helpers ----------
cta_stats <- function(x) {
    list(
        n = length(x),
        mean = mean(x),
        variance = if (length(x) >= 2) var(x) else 0,
        sd = if (length(x) >= 2) sd(x) else 0,
        min = if (length(x) > 0) min(x) else NA,
        max = if (length(x) > 0) max(x) else NA,
        median = if (length(x) > 0) median(x) else NA,
        p05 = if (length(x) > 0) unname(quantile(x, 0.05, names = FALSE)) else NA,
        p25 = if (length(x) > 0) unname(quantile(x, 0.25, names = FALSE)) else NA,
        p75 = if (length(x) > 0) unname(quantile(x, 0.75, names = FALSE)) else NA,
        p95 = if (length(x) > 0) unname(quantile(x, 0.95, names = FALSE)) else NA
    )
}

# ---------- JSON emission ----------
# Emit a JSON object to stdout. Always adds a CTA provenance header.
cta_emit <- function(payload) {
    payload$timestamp_epoch <- as.integer(Sys.time())
    payload$cta_version <- "v1.0.0"
    payload$license <- "ESL-ANCSA-MRA-IndiModSHA v1.0"
    cat(toJSON(payload, auto_unbox = TRUE, digits = 8, pretty = TRUE, na = "null"))
    cat("\n")
}

# ---------- distribution samplers ----------
# Parse a "kind:p1:p2" spec, return n samples.
cta_sample_distribution <- function(spec, n, seed = 1L) {
    set.seed(as.integer(seed))
    parts <- strsplit(spec, ":", fixed = TRUE)[[1]]
    kind <- parts[1]
    p1 <- as.numeric(parts[2])
    p2 <- if (length(parts) >= 3) as.numeric(parts[3]) else NA
    switch(kind,
        normal    = rnorm(n, mean = p1, sd = p2),
        uniform   = runif(n, min = p1, max = p2),
        lognormal = rlnorm(n, meanlog = p1, sdlog = p2),
        exponential = rexp(n, rate = p1),
        gamma     = rgamma(n, shape = p1, rate = p2),
        stop(paste("unknown distribution kind:", kind))
    )
}

# Bool argument handling
cta_arg_num <- function(args, key, default) {
    if (!is.null(args[[key]])) as.numeric(args[[key]]) else default
}
cta_arg_int <- function(args, key, default) {
    if (!is.null(args[[key]])) as.integer(args[[key]]) else as.integer(default)
}
cta_arg_str <- function(args, key, default) {
    if (!is.null(args[[key]])) as.character(args[[key]]) else default
}

# Seed: use CTA_SEED env if not set on CLI
cta_seed <- function(args) {
    if (!is.null(args[["seed"]])) return(as.integer(args[["seed"]]))
    env_seed <- Sys.getenv("CTA_SEED", unset = "")
    if (nzchar(env_seed)) return(as.integer(env_seed))
    1L
}

# Die with a JSON error to stdout, exit 1
cta_die <- function(msg) {
    cat(toJSON(list(error = msg, cta_version = "v1.0.0"), auto_unbox = TRUE), "\n")
    quit(status = 1, save = "no")
}
