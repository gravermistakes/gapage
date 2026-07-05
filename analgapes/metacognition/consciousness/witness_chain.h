/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * analgapes :: c-base/witness_chain.h
 *
 * Metacog journal: persistent record of EVERY VERIFIED (truth_value=true)
 * cycle in the rhizome, including those that did not achieve the goal.
 * False hypotheses are discarded — they are noise about our own model error,
 * not signal about the target.
 *
 * Storage: JSONL file at $ANALGAPES_WORKSPACE/runs/<run-id>/metacog.jsonl
 * Hash chain: every kept entry links to the prior kept entry via
 * avrs_shake256_chain(prev_hash, current_payload). Tamper-evident.
 *
 * Storage rule:
 *   truth_value == TRUE  -> WRITE
 *   truth_value == FALSE -> DISCARD (not even logged to journal)
 *
 * Optional: a separate "discarded.jsonl" can record DISCARDED hypotheses
 * for accounting only (witness_chain_log_discard). It does not participate
 * in the hash chain. The orchestrator does not read it.
 */

#ifndef ANALGAPES_WITNESS_CHAIN_H
#define ANALGAPES_WITNESS_CHAIN_H

#include "avrs_shake.h"
#include <stddef.h>
#include <stdint.h>

typedef enum { WC_TRUTH_FALSE = 0, WC_TRUTH_TRUE = 1 } wc_truth_t;
typedef enum {
    WC_GOAL_NOT_ACHIEVED = 0,
    WC_GOAL_ACHIEVED     = 1,
    WC_GOAL_PARTIAL      = 2
} wc_goal_t;

/* One metacog entry. evidence_json is heap-owned by caller; the writer
 * does not free it (caller frees after witness_chain_write returns). */
typedef struct {
    uint64_t   epoch;
    char       cycle_id[160];    /* fits any prefix + AVRS_SHAKE_HEX + NUL  */
    char       from_node[64];
    char       to_node[64];
    char       edge_name[64];    /* UTF-8; sequence of the 45 canonical edge
                                  * symbols (kanji/Greek/structural). Validated
                                  * by wc_valid_edge_name() before write. */
    char       hypothesis[512];
    wc_truth_t truth_value;
    wc_goal_t  goal_status;
    const char *evidence_json;   /* arbitrary JSON object */
    /* Optional operator-set signature: decision_making, ethical_weighting,
     * emotional_regulation, linguistic_cadence, curiosity_distribution,
     * symbolic_grammar, relational_schema, narrative_identity_scaffolding.
     * NULL/"" = omitted. Never auto-stamped. */
    const char *behavioral_signature;
} witness_chain_entry_t;

/* Open a journal. workspace_dir is $ANALGAPES_WORKSPACE/runs/<run-id>;
 * the directory is created if missing. Returns NULL on failure. */
typedef struct witness_chain witness_chain_t;
witness_chain_t *witness_chain_open(const char *workspace_dir);

/* Write an entry, IF AND ONLY IF truth_value == WC_TRUTH_TRUE.
 * False entries are silently skipped (the system has no opinion on
 * a hypothesis it disproved). Returns:
 *   0  on successful write
 *   1  on skip (truth_value == FALSE) — not an error
 *  -1  on real failure (disk full, etc.)
 *
 * Computes this_hash = avrs_shake256_chain(prev_hash, serialized_entry)
 * and writes the entry plus prev_hash + this_hash to the journal. */
int witness_chain_write(witness_chain_t *j, const witness_chain_entry_t *e);

/* Optional accounting: record a discarded (FALSE) hypothesis to a
 * separate file. Does NOT participate in the hash chain. The
 * orchestrator does not read this file when planning. Returns 0/-1. */
int witness_chain_log_discard(witness_chain_t *j, const witness_chain_entry_t *e);

/* Get the current chain tip (most recent this_hash). Useful for
 * passing to a child process or sealing the run. Writes hex to
 * tip_hex (must be AVRS_SHAKE_HEX bytes). Returns 0/-1. */
int witness_chain_chain_tip(witness_chain_t *j, char *tip_hex);

/* Close and flush. */
void witness_chain_close(witness_chain_t *j);

/* Validate an edge_name: returns 1 if every UTF-8 codepoint in `e`
 * belongs to the 45-symbol canonical edge alphabet (kanji/Greek/
 * structural), else 0. An empty string is valid (no edge). Used by
 * witness_chain_write to reject malformed edges before they enter
 * the hash chain. */
int wc_valid_edge_name(const char *e);

#endif /* ANALGAPES_WITNESS_CHAIN_H */
