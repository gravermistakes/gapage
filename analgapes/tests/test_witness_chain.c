/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * route-cause :: c-base/test_metacog.c
 *
 * Tests written BEFORE witness_chain.c. Red phase: this file must compile but
 * fail to link until witness_chain.{c,h} exist. Each test corresponds to one
 * row of the test-design table in witness_chain_SPEC.md.
 *
 * Where assertions need to parse JSON from the journal, we shell out to jq
 * rather than embed a parser. Keeps the C lean; jq is already a dependency.
 */

#include "witness_chain.h"
#include "avrs_shake.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int failures = 0;

#define MUSTBE(cond, label) do { \
    if (!(cond)) { fprintf(stderr, "FAIL: %s\n", label); failures++; } \
    else         { fprintf(stderr, "PASS: %s\n", label); } \
} while (0)

static int run(const char *cmd) {
    int rc = system(cmd);
    return rc == -1 ? -1 : WEXITSTATUS(rc);
}

static long count_lines(const char *path) {
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "wc -l < '%s' 2>/dev/null | tr -d ' '", path);
    FILE *p = popen(cmd, "r");
    if (!p) return -1;
    char buf[64] = {0};
    if (!fgets(buf, sizeof(buf), p)) { pclose(p); return -1; }
    pclose(p);
    return atol(buf);
}

static int file_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISREG(st.st_mode);
}

/* Fresh workspace for each test */
static void fresh_workspace(char *out, size_t cap) {
    snprintf(out, cap, "/tmp/witness_chain_test_%d", (int)getpid());
    char cmd[2048];
    snprintf(cmd, sizeof(cmd), "rm -rf '%s' && mkdir -p '%s'", out, out);
    if (run(cmd) != 0) {
        fprintf(stderr, "fresh_workspace: setup failed\n");
        exit(2);
    }
}

/* Test 1: TRUE entry written → file exists, 1 line, JSON parseable */
static void test_true_written(void) {
    char ws[256]; fresh_workspace(ws, sizeof(ws));
    witness_chain_t *j = witness_chain_open(ws);
    MUSTBE(j != NULL, "test_1: open journal");
    if (!j) return;

    witness_chain_entry_t e = {
        .epoch = 1780000000, .cycle_id = "run-x:1",
        .from_node = "scorpion", .to_node = "correlation-analysis",
        .hypothesis = "auth.c contains a secret pattern",
        .truth_value = WC_TRUTH_TRUE, .goal_status = WC_GOAL_NOT_ACHIEVED,
        .evidence_json = "{\"matches\":3}",
    };
    MUSTBE(witness_chain_write(j, &e) == 0, "test_1: write returned 0");

    char path[512]; snprintf(path, sizeof(path), "%s/metacog.jsonl", ws);
    MUSTBE(file_exists(path),                   "test_1: journal file exists");
    MUSTBE(count_lines(path) == 1,              "test_1: journal has 1 line");

    char cmd[768];
    snprintf(cmd, sizeof(cmd),
        "jq -e '.truth_value == \"true\" and .from_node == \"scorpion\"' "
        "< '%s' > /dev/null", path);
    MUSTBE(run(cmd) == 0, "test_1: line is valid JSON with expected fields");

    witness_chain_close(j);
}

/* Test 2: FALSE entry NOT written (epistemology rule) */
static void test_false_not_written(void) {
    char ws[256]; fresh_workspace(ws, sizeof(ws));
    witness_chain_t *j = witness_chain_open(ws);
    if (!j) { MUSTBE(0, "test_2: open journal"); return; }

    witness_chain_entry_t e = {
        .epoch = 1780000000, .cycle_id = "run-x:1",
        .from_node = "nexus", .to_node = "correlation-analysis",
        .hypothesis = "this code path is reachable from a public entry",
        .truth_value = WC_TRUTH_FALSE, .goal_status = WC_GOAL_NOT_ACHIEVED,
        .evidence_json = "{\"reason\":\"guarded by access modifier\"}",
    };
    MUSTBE(witness_chain_write(j, &e) == 1, "test_2: write returned 1 (skipped)");

    char path[512]; snprintf(path, sizeof(path), "%s/metacog.jsonl", ws);
    long n = file_exists(path) ? count_lines(path) : 0;
    MUSTBE(n == 0, "test_2: journal has 0 lines (FALSE was discarded)");

    witness_chain_close(j);
}

/* Test 3: log_discard → discarded.jsonl, journal still empty */
static void test_discard_to_separate_file(void) {
    char ws[256]; fresh_workspace(ws, sizeof(ws));
    witness_chain_t *j = witness_chain_open(ws);
    if (!j) { MUSTBE(0, "test_3: open journal"); return; }

    witness_chain_entry_t e = {
        .epoch = 1780000000, .cycle_id = "run-x:1",
        .from_node = "exploit-development", .to_node = "test-first-poc-synthesis",
        .hypothesis = "buffer overflow exists at offset 0x40",
        .truth_value = WC_TRUTH_FALSE, .goal_status = WC_GOAL_NOT_ACHIEVED,
        .evidence_json = "{\"reason\":\"bounded by strncpy with valid n\"}",
    };
    MUSTBE(witness_chain_log_discard(j, &e) == 0, "test_3: log_discard returned 0");

    char journal[512], discarded[512];
    snprintf(journal,   sizeof(journal),   "%s/metacog.jsonl",   ws);
    snprintf(discarded, sizeof(discarded), "%s/discarded.jsonl", ws);

    MUSTBE(!file_exists(journal) || count_lines(journal) == 0,
           "test_3: journal still empty");
    MUSTBE(file_exists(discarded) && count_lines(discarded) == 1,
           "test_3: discarded.jsonl has the FALSE entry");

    witness_chain_close(j);
}

/* Test 4: two consecutive TRUE writes link via hash chain */
static void test_chain_links(void) {
    char ws[256]; fresh_workspace(ws, sizeof(ws));
    witness_chain_t *j = witness_chain_open(ws);
    if (!j) { MUSTBE(0, "test_4: open journal"); return; }

    witness_chain_entry_t e1 = {
        .epoch = 1780000000, .cycle_id = "run-x:1",
        .from_node = "scorpion", .to_node = "correlation-analysis",
        .hypothesis = "h1", .truth_value = WC_TRUTH_TRUE,
        .goal_status = WC_GOAL_PARTIAL, .evidence_json = "{}",
    };
    witness_chain_entry_t e2 = {
        .epoch = 1780000001, .cycle_id = "run-x:2",
        .from_node = "correlation-analysis", .to_node = "weighted-decision-scoring",
        .hypothesis = "h2", .truth_value = WC_TRUTH_TRUE,
        .goal_status = WC_GOAL_ACHIEVED, .evidence_json = "{}",
    };
    MUSTBE(witness_chain_write(j, &e1) == 0, "test_4: first write");
    MUSTBE(witness_chain_write(j, &e2) == 0, "test_4: second write");

    char cmd[4096], path[512];
    snprintf(path, sizeof(path), "%s/metacog.jsonl", ws);
    snprintf(cmd, sizeof(cmd),
        "test \"$(jq -r 'select(.cycle_id == \"run-x:1\") | .this_hash' < '%s')\" "
        "= "
        "\"$(jq -r 'select(.cycle_id == \"run-x:2\") | .prev_hash' < '%s')\"",
        path, path);
    MUSTBE(run(cmd) == 0, "test_4: entry[1].prev_hash == entry[0].this_hash");

    witness_chain_close(j);
}

/* Test 6: first entry has zero-hash prev */
static void test_first_entry_zero_prev(void) {
    char ws[256]; fresh_workspace(ws, sizeof(ws));
    witness_chain_t *j = witness_chain_open(ws);
    if (!j) { MUSTBE(0, "test_6: open journal"); return; }

    witness_chain_entry_t e = {
        .epoch = 1780000000, .cycle_id = "run-x:1",
        .from_node = "any", .to_node = "any2",
        .hypothesis = "first", .truth_value = WC_TRUTH_TRUE,
        .goal_status = WC_GOAL_NOT_ACHIEVED, .evidence_json = "{}",
    };
    MUSTBE(witness_chain_write(j, &e) == 0, "test_6: write first entry");

    char cmd[4096], path[512];
    snprintf(path, sizeof(path), "%s/metacog.jsonl", ws);
    snprintf(cmd, sizeof(cmd),
        "jq -e '.prev_hash == \"%0*d\"' < '%s' > /dev/null",
        128, 0, path);
    MUSTBE(run(cmd) == 0, "test_6: first entry's prev_hash is 128 zeros");

    witness_chain_close(j);
}

/* Test 7: chain_tip returns most recent this_hash after 3 entries */
static void test_chain_tip(void) {
    char ws[256]; fresh_workspace(ws, sizeof(ws));
    witness_chain_t *j = witness_chain_open(ws);
    if (!j) { MUSTBE(0, "test_7: open journal"); return; }

    for (int i = 0; i < 3; i++) {
        witness_chain_entry_t e = {
            .epoch = 1780000000ULL + (uint64_t)i,
            .from_node = "any", .to_node = "any2",
            .hypothesis = "h", .truth_value = WC_TRUTH_TRUE,
            .goal_status = WC_GOAL_PARTIAL, .evidence_json = "{}",
        };
        snprintf(e.cycle_id, sizeof(e.cycle_id), "run-x:%d", i + 1);
        if (witness_chain_write(j, &e) != 0) { MUSTBE(0, "test_7: write"); witness_chain_close(j); return; }
    }

    char tip[AVRS_SHAKE_HEX] = {0};
    MUSTBE(witness_chain_chain_tip(j, tip) == 0, "test_7: chain_tip returns 0");

    char cmd[4096], path[512];
    snprintf(path, sizeof(path), "%s/metacog.jsonl", ws);
    snprintf(cmd, sizeof(cmd),
        "test \"%s\" = \"$(tail -n1 '%s' | jq -r .this_hash)\"",
        tip, path);
    MUSTBE(run(cmd) == 0, "test_7: tip matches last entry's this_hash");

    witness_chain_close(j);
}

int main(void) {
    test_true_written();
    test_false_not_written();
    test_discard_to_separate_file();
    test_chain_links();
    test_first_entry_zero_prev();
    test_chain_tip();
    if (failures == 0) { fprintf(stderr, "\nALL PASS\n"); return 0; }
    fprintf(stderr, "\nFAILURES: %d\n", failures);
    return 1;
}
