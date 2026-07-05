/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * analgapes :: capabilities/correlation-analysis/impl/correlation-analysis.c
 *
 * Correlation engine. One pthread pool, three composable property bits
 * (INCREMENTAL, DETERMINISTIC, WEIGHTED). Clustering by (kind, locus-prefix)
 * with sort-then-hash cluster IDs, optional severity aggregation.
 * Real C, no Python. POSIX threads + libcrypto.
 */

#define _POSIX_C_SOURCE 200809L
#include "correlation.h"
#include "../../metacognition/consciousness/witness_chain.h"
#include "../../lib/avrs_shake.h"
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define BUCKET_BITS  10
#define N_BUCKETS    (1u << BUCKET_BITS)
#define BUCKET_MASK  (N_BUCKETS - 1u)

/* Internal cluster representation: bucketed by hash(kind || locus-prefix). */
typedef struct corr_node {
    corr_finding_t      finding;
    struct corr_node   *next;
} corr_node_t;

typedef struct corr_bucket {
    pthread_mutex_t  mu;
    corr_node_t     *head;
    size_t           count;
} corr_bucket_t;

typedef struct corr_inflight {
    corr_finding_t      *finding;
    struct corr_inflight *next;
} corr_inflight_t;

struct corr_engine {
    unsigned          mode_flags;
    int               n_workers;
    pthread_t        *workers;
    pthread_mutex_t   queue_mu;
    pthread_cond_t    queue_cv;
    corr_inflight_t  *queue_head;
    corr_inflight_t  *queue_tail;
    int               draining;
    corr_bucket_t     buckets[N_BUCKETS];
    /* Reap state */
    pthread_mutex_t   reap_mu;
    size_t            reap_bucket_idx;
    /* Metacog journal — adjacent to every cycle, in $ANALGAPES_WORKSPACE */
    witness_chain_t     *metacog;
};

/* FNV-1a 64-bit. Used for bucket assignment AND for cluster IDs (paired with
 * sort-then-hash member IDs for order-invariance — CORR_MODE_DETERMINISTIC). */
static uint64_t fnv1a64(const char *s, size_t n) {
    uint64_t h = 0xcbf29ce484222325ULL;
    for (size_t i = 0; i < n; i++) {
        h ^= (uint64_t)(unsigned char)s[i];
        h *= 0x100000001b3ULL;
    }
    return h;
}

/* --- Concatenative stages (honoring incremental property: each is a separable
 * transform; the worker composes them in sequence). Externally visible so
 * the architecture's concatenativity isn't a fiction. ----------------------*/

/* Stage 1: classify — for now, identity on kind (room for taxonomy later) */
const char *corr_stage_classify(const corr_finding_t *f) { return f->kind; }

/* Stage 2: normalize — locus prefix up to first ':'. Stable across orderings. */
size_t corr_stage_normalize_locus_prefix(const corr_finding_t *f, char *out, size_t cap) {
    const char *colon = strchr(f->locus, ':');
    size_t lp_len = colon ? (size_t)(colon - f->locus) : strlen(f->locus);
    if (lp_len >= cap) lp_len = cap - 1;
    memcpy(out, f->locus, lp_len);
    out[lp_len] = '\0';
    return lp_len;
}

/* Stage 3: bucket_assign — compose classify + normalize into a bucket index. */
uint32_t corr_stage_bucket_assign(const corr_finding_t *f) {
    char locus_pfx[256];
    size_t lp = corr_stage_normalize_locus_prefix(f, locus_pfx, sizeof(locus_pfx));
    const char *kind = corr_stage_classify(f);
    char key[256 + 32 + 2];
    int k = snprintf(key, sizeof(key), "%s|%.*s", kind, (int)lp, locus_pfx);
    if (k < 0) k = 0;
    if ((size_t)k > sizeof(key)) k = sizeof(key);
    return (uint32_t)(fnv1a64(key, (size_t)k) & BUCKET_MASK);
}

/* Back-compat: the old bucket_for() is now just the composed chain. */
static uint32_t bucket_for(const corr_finding_t *f) {
    return corr_stage_bucket_assign(f);
}

/* Worker: pop one finding, assign to bucket. Incremental property: no
 * batching, no global lock. Each worker grabs one finding and goes. */
static void *worker_loop(void *arg) {
    struct corr_engine *eng = (struct corr_engine *)arg;
    for (;;) {
        pthread_mutex_lock(&eng->queue_mu);
        while (!eng->queue_head && !eng->draining)
            pthread_cond_wait(&eng->queue_cv, &eng->queue_mu);
        if (!eng->queue_head && eng->draining) {
            pthread_mutex_unlock(&eng->queue_mu);
            return NULL;
        }
        corr_inflight_t *it = eng->queue_head;
        eng->queue_head = it->next;
        if (!eng->queue_head) eng->queue_tail = NULL;
        pthread_mutex_unlock(&eng->queue_mu);

        uint32_t bi = bucket_for(it->finding);
        corr_bucket_t *b = &eng->buckets[bi];
        pthread_mutex_lock(&b->mu);
        corr_node_t *n = (corr_node_t *)calloc(1, sizeof(*n));
        if (n) {
            n->finding = *(it->finding);
            n->next = b->head;
            b->head = n;
            b->count++;
        }
        pthread_mutex_unlock(&b->mu);
        free(it->finding);  /* finding struct itself; raw_json now owned by node */
        free(it);
    }
}

corr_engine_t *corr_engine_open(unsigned mode_flags, int workers) {
    if (workers <= 0) workers = (int)sysconf(_SC_NPROCESSORS_ONLN);
    if (workers <= 0) workers = 2;
    struct corr_engine *eng = (struct corr_engine *)calloc(1, sizeof(*eng));
    if (!eng) return NULL;
    eng->mode_flags = mode_flags ? mode_flags : CORR_MODE_DEFAULT;
    eng->n_workers = workers;
    pthread_mutex_init(&eng->queue_mu, NULL);
    pthread_cond_init(&eng->queue_cv, NULL);
    pthread_mutex_init(&eng->reap_mu, NULL);
    for (unsigned i = 0; i < N_BUCKETS; i++)
        pthread_mutex_init(&eng->buckets[i].mu, NULL);
    eng->workers = (pthread_t *)calloc((size_t)workers, sizeof(pthread_t));
    if (!eng->workers) { free(eng); return NULL; }
    for (int i = 0; i < workers; i++)
        pthread_create(&eng->workers[i], NULL, worker_loop, eng);

    /* Open metacog journal if workspace is set. Skill folder is read-only;
     * journal lives in $ANALGAPES_WORKSPACE (workspace-local). */
    const char *ws = getenv("ANALGAPES_WORKSPACE");
    if (ws && *ws) {
        char path[1024];
        snprintf(path, sizeof(path), "%s/runs/correlation-analysis", ws);
        eng->metacog = witness_chain_open(path);
        /* If metacog open fails, we continue without journaling rather than
         * abort the security work. Failure is logged to stderr. */
        if (!eng->metacog)
            fprintf(stderr, "warn: metacog open failed at %s (errno=%d)\n", path, errno);
    }

    return eng;
}

int corr_engine_push(corr_engine_t *eng, corr_finding_t *finding) {
    if (!eng || !finding) return EINVAL;
    corr_inflight_t *it = (corr_inflight_t *)calloc(1, sizeof(*it));
    corr_finding_t  *f  = (corr_finding_t *)malloc(sizeof(*f));
    if (!it || !f) { free(it); free(f); return ENOMEM; }
    *f = *finding;
    it->finding = f;
    pthread_mutex_lock(&eng->queue_mu);
    if (eng->queue_tail) eng->queue_tail->next = it;
    else                 eng->queue_head = it;
    eng->queue_tail = it;
    pthread_cond_signal(&eng->queue_cv);
    pthread_mutex_unlock(&eng->queue_mu);
    return 0;
}

int corr_engine_flush(corr_engine_t *eng) {
    if (!eng) return EINVAL;
    pthread_mutex_lock(&eng->queue_mu);
    eng->draining = 1;
    pthread_cond_broadcast(&eng->queue_cv);
    pthread_mutex_unlock(&eng->queue_mu);
    for (int i = 0; i < eng->n_workers; i++)
        pthread_join(eng->workers[i], NULL);
    return 0;
}

/* Compare strdup'd IDs for sort-then-hash (CORR_MODE_DETERMINISTIC). */
static int cmp_strp(const void *a, const void *b) {
    return strcmp(*(const char *const *)a, *(const char *const *)b);
}

corr_cluster_t *corr_engine_reap(corr_engine_t *eng) {
    if (!eng) return NULL;
    pthread_mutex_lock(&eng->reap_mu);
    while (eng->reap_bucket_idx < N_BUCKETS) {
        corr_bucket_t *b = &eng->buckets[eng->reap_bucket_idx];
        pthread_mutex_lock(&b->mu);
        if (!b->head) {
            pthread_mutex_unlock(&b->mu);
            eng->reap_bucket_idx++;
            continue;
        }
        size_t n = b->count;
        char **ids = (char **)calloc(n, sizeof(char *));
        double sev_sum = 0.0;
        size_t i = 0;
        corr_node_t *cur = b->head;
        while (cur) {
            ids[i++] = strdup(cur->finding.id);
            sev_sum += cur->finding.severity;
            corr_node_t *next = cur->next;
            free(cur->finding.raw_json);
            free(cur);
            cur = next;
        }
        b->head = NULL;
        b->count = 0;
        pthread_mutex_unlock(&b->mu);

        /* deterministic: sort member IDs before hashing → order-invariant cluster_id */
        if (eng->mode_flags & CORR_MODE_DETERMINISTIC)
            qsort(ids, n, sizeof(char *), cmp_strp);

        /* Concat sorted IDs and hash → cluster_id via SHAKE256 (provenance-unified
         * with cta-v1; replaces FNV-1a here, which still bucket-assigns above) */
        size_t cat_cap = 0;
        for (i = 0; i < n; i++) cat_cap += strlen(ids[i]) + 1;
        char *cat = (char *)malloc(cat_cap + 1);
        cat[0] = '\0';
        for (i = 0; i < n; i++) { strcat(cat, ids[i]); strcat(cat, "|"); }
        uint8_t cid_bytes[AVRS_SHAKE_LEN];
        if (avrs_shake256(cat, strlen(cat), cid_bytes) != 0) {
            free(cat);
            pthread_mutex_unlock(&eng->reap_mu);
            return NULL;
        }
        char cid_hex[AVRS_SHAKE_HEX];
        avrs_shake256_hex(cid_bytes, cid_hex);
        free(cat);

        corr_cluster_t *out = (corr_cluster_t *)calloc(1, sizeof(*out));
        memcpy(out->cluster_id, cid_hex, AVRS_SHAKE_HEX);
        out->n_members = n;
        out->member_ids = ids;
        /* weighted: severity weighting → aggregate score = mean × size-factor */
        if (eng->mode_flags & CORR_MODE_WEIGHTED)
            out->aggregate_severity = (n > 0 ? sev_sum / (double)n : 0.0) *
                                      (1.0 + 0.1 * (double)n);
        out->attribution_chain = strdup(
            "{\"properties\":[\"stream-incremental\",\"order-invariant\",\"severity-weighted\"]}");

        /* Metacog write: each emitted cluster IS a verified correlation
         * (truth_value=TRUE). goal_status reflects whether the cluster is
         * "interesting" (n > 1 = ACHIEVED partial chaining; n == 1 =
         * NOT_ACHIEVED isolated finding, still verified and kept). */
        if (eng->metacog) {
            char ev[1024];
            snprintf(ev, sizeof(ev),
                "{\"cluster_id\":\"%s\",\"n\":%zu,\"severity\":%.4f}",
                cid_hex, n, out->aggregate_severity);
            witness_chain_entry_t e = {
                .epoch = (uint64_t)time(NULL),
                .truth_value = WC_TRUTH_TRUE,
                .goal_status = (n > 1 ? WC_GOAL_PARTIAL : WC_GOAL_NOT_ACHIEVED),
                .evidence_json = ev,
            };
            snprintf(e.cycle_id, sizeof(e.cycle_id), "corr:%s", out->cluster_id);
            snprintf(e.from_node, sizeof(e.from_node), "cognition");
            snprintf(e.to_node,   sizeof(e.to_node),   "governance");
            snprintf(e.edge_name, sizeof(e.edge_name), "\xcf\x81");  /* ρ correlation */
            snprintf(e.hypothesis, sizeof(e.hypothesis),
                "%zu finding%s share kind+locus-prefix bucket",
                n, n == 1 ? "" : "s");
            (void)witness_chain_write(eng->metacog, &e);
        }

        pthread_mutex_unlock(&eng->reap_mu);
        return out;
    }
    pthread_mutex_unlock(&eng->reap_mu);
    return NULL;
}

void corr_cluster_free(corr_cluster_t *c) {
    if (!c) return;
    for (size_t i = 0; i < c->n_members; i++) free(c->member_ids[i]);
    free(c->member_ids);
    free(c->attribution_chain);
    free(c);
}

void corr_engine_close(corr_engine_t *eng) {
    if (!eng) return;
    if (eng->metacog) witness_chain_close(eng->metacog);
    free(eng->workers);
    for (unsigned i = 0; i < N_BUCKETS; i++)
        pthread_mutex_destroy(&eng->buckets[i].mu);
    pthread_mutex_destroy(&eng->queue_mu);
    pthread_mutex_destroy(&eng->reap_mu);
    pthread_cond_destroy(&eng->queue_cv);
    free(eng);
}

#ifdef CORR_MAIN
/* CLI: reads JSONL findings from stdin, emits clusters as JSONL on stdout.
 * Field-tolerant parser: extracts id, kind, locus, severity from raw JSON.
 * For more robust parsing, pipe through jq first. */
static char *jstr(const char *line, const char *key) {
    char k[64]; snprintf(k, sizeof(k), "\"%s\"", key);
    const char *p = strstr(line, k); if (!p) return NULL;
    p = strchr(p + strlen(k), ':'); if (!p) return NULL; p++;
    while (*p == ' ' || *p == '\t') p++;
    if (*p != '"') return NULL;
    p++;
    const char *e = strchr(p, '"'); if (!e) return NULL;
    size_t n = (size_t)(e - p);
    char *out = (char *)malloc(n + 1);
    memcpy(out, p, n); out[n] = '\0';
    return out;
}
static double jnum(const char *line, const char *key) {
    char k[64]; snprintf(k, sizeof(k), "\"%s\"", key);
    const char *p = strstr(line, k); if (!p) return 0.0;
    p = strchr(p + strlen(k), ':'); if (!p) return 0.0; p++;
    return strtod(p, NULL);
}
int main(int argc, char **argv) {
    unsigned mode = CORR_MODE_DEFAULT;
    int workers = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--incremental-only")) mode = CORR_MODE_INCREMENTAL;
        else if (!strcmp(argv[i], "--no-deterministic")) mode &= ~CORR_MODE_DETERMINISTIC;
        else if (!strcmp(argv[i], "--no-weighted")) mode &= ~CORR_MODE_WEIGHTED;
        else if (!strcmp(argv[i], "--workers") && i+1 < argc) workers = atoi(argv[++i]);
    }
    corr_engine_t *eng = corr_engine_open(mode, workers);
    if (!eng) { perror("corr_engine_open"); return 1; }
    char *line = NULL; size_t cap = 0; ssize_t len;
    while ((len = getline(&line, &cap, stdin)) != -1) {
        if (len < 2) continue;
        corr_finding_t f = {0};
        char *id = jstr(line, "id"), *kind = jstr(line, "kind"), *locus = jstr(line, "locus");
        if (!id || !kind || !locus) { free(id); free(kind); free(locus); continue; }
        strncpy(f.id, id, sizeof(f.id)-1);
        strncpy(f.kind, kind, sizeof(f.kind)-1);
        strncpy(f.locus, locus, sizeof(f.locus)-1);
        f.severity = jnum(line, "severity");
        f.epoch = (uint64_t)jnum(line, "epoch");
        f.raw_json = strdup(line);
        free(id); free(kind); free(locus);
        corr_engine_push(eng, &f);
    }
    free(line);
    corr_engine_flush(eng);
    corr_cluster_t *c;
    while ((c = corr_engine_reap(eng))) {
        printf("{\"cluster_id\":\"%s\",\"n\":%zu,\"severity\":%.4f,\"attribution\":%s,\"members\":[",
               c->cluster_id, c->n_members, c->aggregate_severity, c->attribution_chain);
        for (size_t i = 0; i < c->n_members; i++)
            printf("%s\"%s\"", i ? "," : "", c->member_ids[i]);
        printf("]}\n");
        corr_cluster_free(c);
    }
    corr_engine_close(eng);
    return 0;
}
#endif
