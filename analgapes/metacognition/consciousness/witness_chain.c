/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * analgapes :: c-base/witness_chain.c
 *
 * Implementation. Behavior strictly per witness_chain_SPEC.md.
 */

#define _POSIX_C_SOURCE 200809L
#include "witness_chain.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

/* ---- canonical 45-symbol edge alphabet (kanji/Greek/structural) ---- */
static const uint32_t WC_EDGE_CP[] = {
    0x6E90, 0x6253, 0x5316, 0x4F59, 0x7387, 0x65AD, 0x9023, 0x95A2,
    0x5E73, 0x56DE, 0x96C6, 0x6642, 0x4E86, 0x6790, 0x5408, 0x5F71,
    0x4FEE, 0x6D41, 0x6838, 0x63A8, 0x76F8, 0x4FDD, 0x898B, 0x8AAD,
    0x8003, 0x533A, 0x754C, 0x518D, 0x6B62, 0x56E0, 0x679C, 0x03B4,
    0x03C1, 0x2192, 0x2190, 0x2191, 0x2193, 0x2212, 0x2714, 0x25CF,
    0x2605, 0x2606, 0x2640, 0x2634, 0x27E9,
};
#define WC_EDGE_CP_N (sizeof(WC_EDGE_CP)/sizeof(WC_EDGE_CP[0]))

static int wc_cp_member(uint32_t cp) {
    for (size_t i = 0; i < WC_EDGE_CP_N; i++)
        if (WC_EDGE_CP[i] == cp) return 1;
    return 0;
}

/* Decode one UTF-8 codepoint from s; advance *adv by bytes consumed.
 * Returns the codepoint, or 0xFFFFFFFF on malformed input. */
static uint32_t wc_utf8_next(const unsigned char *s, size_t *adv) {
    unsigned char c = s[0];
    if (c < 0x80)              { *adv = 1; return c; }
    if ((c & 0xE0) == 0xC0)    { *adv = 2; return ((c & 0x1F) << 6) |
                                            (s[1] & 0x3F); }
    if ((c & 0xF0) == 0xE0)    { *adv = 3; return ((c & 0x0F) << 12) |
                                            ((s[1] & 0x3F) << 6) | (s[2] & 0x3F); }
    if ((c & 0xF8) == 0xF0)    { *adv = 4; return ((c & 0x07) << 18) |
                                            ((s[1] & 0x3F) << 12) |
                                            ((s[2] & 0x3F) << 6) | (s[3] & 0x3F); }
    *adv = 1; return 0xFFFFFFFFu;
}

int wc_valid_edge_name(const char *e) {
    if (!e) return 0;
    const unsigned char *p = (const unsigned char *)e;
    while (*p) {
        size_t adv = 0;
        uint32_t cp = wc_utf8_next(p, &adv);
        if (cp == 0xFFFFFFFFu || !wc_cp_member(cp)) return 0;
        p += adv;
    }
    return 1; /* empty string is valid (no edge) */
}

struct witness_chain {
    char *journal_path;
    char *discard_path;
    FILE *journal_fp;     /* opened on first kept write */
    FILE *discard_fp;     /* opened on first discard log */
    uint8_t chain_tip[AVRS_SHAKE_LEN];   /* current tip (zero until first kept) */
    int have_tip;         /* 0 until first kept entry */
};

/* mkdir -p style helper */
static int mkdirp(const char *path) {
    char tmp[1024];
    size_t n = strlen(path);
    if (n == 0 || n >= sizeof(tmp)) { errno = EINVAL; return -1; }
    memcpy(tmp, path, n + 1);
    if (tmp[n - 1] == '/') tmp[n - 1] = '\0';
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            if (mkdir(tmp, 0755) != 0 && errno != EEXIST) return -1;
            *p = '/';
        }
    }
    if (mkdir(tmp, 0755) != 0 && errno != EEXIST) return -1;
    return 0;
}

/* On open: scan existing journal (if any) for the most recent this_hash, so
 * appending continues the chain. We tolerate a truncated final line. */
static void recover_chain_tip(witness_chain_t *j) {
    FILE *f = fopen(j->journal_path, "rb");
    if (!f) return;
    /* Read backwards-ish: simplest correct approach is forward scan, last
     * complete line wins. Journals are small in practice. */
    char *line = NULL;
    size_t cap = 0;
    ssize_t n;
    char last_tip_hex[AVRS_SHAKE_HEX] = {0};
    int found = 0;
    while ((n = getline(&line, &cap, f)) > 0) {
        /* extract "this_hash":"<128hex>" */
        const char *p = strstr(line, "\"this_hash\":\"");
        if (!p) continue;
        p += strlen("\"this_hash\":\"");
        const char *e = strchr(p, '"');
        if (!e || (size_t)(e - p) != AVRS_SHAKE_LEN * 2) continue;
        memcpy(last_tip_hex, p, AVRS_SHAKE_LEN * 2);
        last_tip_hex[AVRS_SHAKE_LEN * 2] = '\0';
        found = 1;
    }
    free(line);
    fclose(f);
    if (!found) return;
    /* hex → bytes */
    for (size_t i = 0; i < AVRS_SHAKE_LEN; i++) {
        unsigned int b;
        if (sscanf(last_tip_hex + 2 * i, "%2x", &b) != 1) return;
        j->chain_tip[i] = (uint8_t)b;
    }
    j->have_tip = 1;
}

witness_chain_t *witness_chain_open(const char *workspace_dir) {
    if (!workspace_dir) { errno = EINVAL; return NULL; }
    if (mkdirp(workspace_dir) != 0) return NULL;
    witness_chain_t *j = calloc(1, sizeof(*j));
    if (!j) return NULL;
    size_t wd = strlen(workspace_dir);
    j->journal_path = malloc(wd + 32);
    j->discard_path = malloc(wd + 32);
    if (!j->journal_path || !j->discard_path) {
        free(j->journal_path); free(j->discard_path); free(j);
        return NULL;
    }
    snprintf(j->journal_path, wd + 32, "%s/metacog.jsonl",   workspace_dir);
    snprintf(j->discard_path, wd + 32, "%s/discarded.jsonl", workspace_dir);
    recover_chain_tip(j);
    return j;
}

/* Goal status as wire-format string */
static const char *goal_str(wc_goal_t g) {
    switch (g) {
        case WC_GOAL_ACHIEVED:     return "achieved";
        case WC_GOAL_PARTIAL:      return "partial";
        case WC_GOAL_NOT_ACHIEVED: /* fall-through */
        default:                   return "not_achieved";
    }
}

/* Escape backslash and double-quote in a string for JSON. Writes into out
 * which must have room for 2*strlen(in)+1. */
static void jstring_escape(const char *in, char *out, size_t out_cap) {
    size_t o = 0;
    for (size_t i = 0; in[i] && o + 2 < out_cap; i++) {
        char c = in[i];
        if (c == '\\' || c == '"') { out[o++] = '\\'; out[o++] = c; }
        else if (c == '\n')        { out[o++] = '\\'; out[o++] = 'n'; }
        else if (c == '\t')        { out[o++] = '\\'; out[o++] = 't'; }
        else if ((unsigned char)c < 0x20) { /* skip control bytes */ }
        else                       { out[o++] = c; }
    }
    out[o] = '\0';
}

/* Serialize the "payload portion" of the entry (everything but prev_hash and
 * this_hash). This is what gets hashed into this_hash. */
static int serialize_payload(const witness_chain_entry_t *e, char *buf, size_t cap) {
    char esc_hyp[1024], esc_cycle[128], esc_from[128], esc_to[128], esc_edge[128];
    jstring_escape(e->hypothesis, esc_hyp,   sizeof(esc_hyp));
    jstring_escape(e->cycle_id,   esc_cycle, sizeof(esc_cycle));
    jstring_escape(e->from_node,  esc_from,  sizeof(esc_from));
    jstring_escape(e->to_node,    esc_to,    sizeof(esc_to));
    jstring_escape(e->edge_name,  esc_edge,  sizeof(esc_edge));
    int n = snprintf(buf, cap,
        "\"epoch\":%lu,"
        "\"cycle_id\":\"%s\","
        "\"from_node\":\"%s\","
        "\"to_node\":\"%s\","
        "\"edge_name\":\"%s\","
        "\"hypothesis\":\"%s\","
        "\"truth_value\":\"%s\","
        "\"goal_status\":\"%s\","
        "\"evidence\":%s,"
        "\"behavioral_signature\":%s",
        (unsigned long)e->epoch,
        esc_cycle, esc_from, esc_to, esc_edge, esc_hyp,
        e->truth_value == WC_TRUTH_TRUE ? "true" : "false",
        goal_str(e->goal_status),
        e->evidence_json && *e->evidence_json ? e->evidence_json : "{}",
        e->behavioral_signature && *e->behavioral_signature ? e->behavioral_signature : "null");
    return (n < 0 || (size_t)n >= cap) ? -1 : n;
}

int witness_chain_write(witness_chain_t *j, const witness_chain_entry_t *e) {
    if (!j || !e) { errno = EINVAL; return -1; }
    /* Reject malformed edge_name before anything enters the chain. */
    if (!wc_valid_edge_name(e->edge_name)) { errno = EINVAL; return -1; }
    /* Storage rule: FALSE → discard (skip). Return 1 (not -1, not 0). */
    if (e->truth_value != WC_TRUTH_TRUE) return 1;

    /* Open journal lazily on first kept write */
    if (!j->journal_fp) {
        j->journal_fp = fopen(j->journal_path, "ab");
        if (!j->journal_fp) return -1;
    }

    char payload[4096];
    int plen = serialize_payload(e, payload, sizeof(payload));
    if (plen < 0) return -1;

    /* Chain hash: prev_hash || payload */
    uint8_t this_hash[AVRS_SHAKE_LEN];
    if (j->have_tip) {
        if (avrs_shake256_chain(j->chain_tip, AVRS_SHAKE_LEN, payload, (size_t)plen, this_hash) != 0)
            return -1;
    } else {
        if (avrs_shake256(payload, (size_t)plen, this_hash) != 0) return -1;
    }

    char prev_hex[AVRS_SHAKE_HEX], this_hex[AVRS_SHAKE_HEX];
    if (j->have_tip) {
        avrs_shake256_hex(j->chain_tip, prev_hex);
    } else {
        memset(prev_hex, '0', AVRS_SHAKE_LEN * 2);
        prev_hex[AVRS_SHAKE_LEN * 2] = '\0';
    }
    avrs_shake256_hex(this_hash, this_hex);

    if (fprintf(j->journal_fp,
            "{%s,\"prev_hash\":\"%s\",\"this_hash\":\"%s\"}\n",
            payload, prev_hex, this_hex) < 0) return -1;
    fflush(j->journal_fp);

    memcpy(j->chain_tip, this_hash, AVRS_SHAKE_LEN);
    j->have_tip = 1;
    return 0;
}

int witness_chain_log_discard(witness_chain_t *j, const witness_chain_entry_t *e) {
    if (!j || !e) { errno = EINVAL; return -1; }
    if (!j->discard_fp) {
        j->discard_fp = fopen(j->discard_path, "ab");
        if (!j->discard_fp) return -1;
    }
    char payload[4096];
    int plen = serialize_payload(e, payload, sizeof(payload));
    if (plen < 0) return -1;
    /* discarded entries are NOT chain-hashed (per spec) */
    if (fprintf(j->discard_fp, "{%s}\n", payload) < 0) return -1;
    fflush(j->discard_fp);
    return 0;
}

int witness_chain_chain_tip(witness_chain_t *j, char *tip_hex) {
    if (!j || !tip_hex) { errno = EINVAL; return -1; }
    if (!j->have_tip) {
        memset(tip_hex, '0', AVRS_SHAKE_LEN * 2);
        tip_hex[AVRS_SHAKE_LEN * 2] = '\0';
        return 0;
    }
    avrs_shake256_hex(j->chain_tip, tip_hex);
    return 0;
}

void witness_chain_close(witness_chain_t *j) {
    if (!j) return;
    if (j->journal_fp) fclose(j->journal_fp);
    if (j->discard_fp) fclose(j->discard_fp);
    free(j->journal_path);
    free(j->discard_path);
    free(j);
}

#ifdef WITNESS_CHAIN_MAIN
/* CLI: witness-chain <workspace> <from> <to> <edge> <hypothesis> <truth:1|0> <goal:0|1|2> [evidence_json]
 * Lets the bash orchestrator emit edge-named entries. Edge validated; FALSE discarded. */
#include <time.h>
int main(int argc, char **argv) {
    if (argc < 8) { fprintf(stderr,
        "usage: %s <ws> <from> <to> <edge> <hypothesis> <truth0|1> <goal0|1|2> [evidence]\n", argv[0]);
        return 2; }
    witness_chain_t *j = witness_chain_open(argv[1]);
    if (!j) { perror("open"); return 1; }
    witness_chain_entry_t e; memset(&e, 0, sizeof e);
    e.epoch = (uint64_t)time(NULL);
    snprintf(e.from_node, sizeof e.from_node, "%s", argv[2]);
    snprintf(e.to_node,   sizeof e.to_node,   "%s", argv[3]);
    snprintf(e.edge_name, sizeof e.edge_name, "%s", argv[4]);
    snprintf(e.hypothesis,sizeof e.hypothesis,"%s", argv[5]);
    e.truth_value = atoi(argv[6]) ? WC_TRUTH_TRUE : WC_TRUTH_FALSE;
    e.goal_status = (wc_goal_t)atoi(argv[7]);
    e.evidence_json = (argc >= 9) ? argv[8] : "{}";
    int rc = witness_chain_write(j, &e);
    char tip[AVRS_SHAKE_HEX]; 
    if (rc == 0 && witness_chain_chain_tip(j, tip) == 0) printf("%s\n", tip);
    witness_chain_close(j);
    return rc < 0 ? 1 : 0;  /* 0=written, 1(skip FALSE) also ok */
}
#endif
