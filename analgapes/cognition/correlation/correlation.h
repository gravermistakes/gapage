/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * analgapes :: capabilities/correlation/impl/correlation.h
 *
 * Correlation engine. Three orthogonal property bits compose into one engine:
 *
 *   CORR_MODE_INCREMENTAL  — per-finding lockless worker pool; no batching
 *   CORR_MODE_DETERMINISTIC — order-invariant cluster IDs (sort-before-hash)
 *   CORR_MODE_WEIGHTED      — severity-aggregated clusters
 *
 * Default activates all three. Their composition yields a real-time
 * tamper-evident severity oracle — an emergent capability of the engine
 * as a whole. Provenance of contributing prior skills is recorded once in
 * ATTRIBUTION.json at the analgapes root, not in runtime emissions.
 */

#ifndef ANALGAPES_CORRELATION_ANALYSIS_H
#define ANALGAPES_CORRELATION_ANALYSIS_H

#include "../../lib/avrs_shake.h"
#include <stddef.h>
#include <stdint.h>

#define CORR_MODE_INCREMENTAL   (1u << 0)  /* stream-incremental ingestion     */
#define CORR_MODE_DETERMINISTIC   (1u << 1)  /* order-invariant cluster IDs      */
#define CORR_MODE_WEIGHTED   (1u << 2)  /* severity-weighted aggregate      */
#define CORR_MODE_DEFAULT  (CORR_MODE_INCREMENTAL | CORR_MODE_DETERMINISTIC | CORR_MODE_WEIGHTED)

/* A finding emitted by an AUDIT-kernel node. Read as one JSONL line per finding
 * from stdin; the parser is tolerant — unknown fields are passed through to
 * the cluster's provenance section. */
typedef struct {
    char     id[64];        /* finding identifier                         */
    char     kind[32];      /* e.g. "secret", "vuln", "smell"             */
    char     locus[256];    /* file:line, host:port, binary:offset, ...   */
    double   severity;      /* 0.0 .. 1.0; 0 if unknown                   */
    uint64_t epoch;         /* unix epoch of the observation              */
    char    *raw_json;      /* full source line (owned, freed on cluster) */
} corr_finding_t;

/* A cluster is what correlation produces. The merge ensures the same cluster
 * is yielded regardless of finding-arrival order (CORR_MODE_DETERMINISTIC). */
typedef struct {
    char     cluster_id[AVRS_SHAKE_HEX]; /* full SHAKE256-xoflen-64 hex + NUL */
    size_t   n_members;
    char   **member_ids;         /* heap-allocated array of strdup'd IDs   */
    double   aggregate_severity; /* set if CORR_MODE_WEIGHTED                */
    char    *attribution_chain;  /* JSONL of contributing source-diffs     */
} corr_cluster_t;

/* Open a correlation engine. Workers is the pthread pool size; 0 = ncpu.
 * Returns NULL on failure (errno set). Caller frees via corr_engine_close. */
typedef struct corr_engine corr_engine_t;
corr_engine_t *corr_engine_open(unsigned mode_flags, int workers);

/* Push a finding. Thread-safe. Returns 0 on success. Engine takes ownership
 * of finding->raw_json (must be heap-allocated by caller). */
int corr_engine_push(corr_engine_t *eng, corr_finding_t *finding);

/* Flush: signal end-of-input and wait for workers. Required before reap. */
int corr_engine_flush(corr_engine_t *eng);

/* Reap one cluster. Returns NULL when drained. Caller frees via
 * corr_cluster_free. */
corr_cluster_t *corr_engine_reap(corr_engine_t *eng);

/* Free a cluster reaped above. */
void corr_cluster_free(corr_cluster_t *c);

/* Close the engine. */
void corr_engine_close(corr_engine_t *eng);

#endif /* ANALGAPES_CORRELATION_ANALYSIS_H */
