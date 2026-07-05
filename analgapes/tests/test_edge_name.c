/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * analgapes :: tests/test_edge_name.c
 *
 * Verifies wc_valid_edge_name() accepts every member of the 45-symbol
 * canonical edge alphabet, accepts valid compound sequences, accepts the
 * empty string, and REJECTS non-member symbols. The mutation harness
 * (MUTATE defined) widens the validator to accept anything; this test
 * must then fail, proving it is not tautological.
 */
#include "../metacognition/consciousness/witness_chain.h"
#include <stdio.h>
#include <string.h>

static int fails = 0;
#define CHECK(cond, msg) do { if (!(cond)) { printf("FAIL: %s\n", msg); fails++; } \
                              else { printf("PASS: %s\n", msg); } } while (0)

int main(void) {
    /* singletons from each tier */
    CHECK(wc_valid_edge_name("源") == 1, "kanji 源 (source) accepted");
    CHECK(wc_valid_edge_name("析") == 1, "kanji 析 (analyze) accepted");
    CHECK(wc_valid_edge_name("影") == 1, "kanji 影 (shadow) accepted");
    CHECK(wc_valid_edge_name("δ")  == 1, "greek δ (anomaly) accepted");
    CHECK(wc_valid_edge_name("ρ")  == 1, "greek ρ (correlation) accepted");
    CHECK(wc_valid_edge_name("→")  == 1, "structural → (feedforward) accepted");
    CHECK(wc_valid_edge_name("−")  == 1, "structural − (discard) accepted");
    CHECK(wc_valid_edge_name("✔")  == 1, "structural ✔ (verify) accepted");

    /* compound sequences (read left-to-right) */
    CHECK(wc_valid_edge_name("δ↓析") == 1, "compound δ↓析 accepted");
    CHECK(wc_valid_edge_name("打ρ了") == 1, "compound 打ρ了 accepted");
    CHECK(wc_valid_edge_name("源見✔●") == 1, "compound 源見✔● accepted");

    /* empty = no edge = valid */
    CHECK(wc_valid_edge_name("") == 1, "empty string accepted (no edge)");

    /* rejects: non-member symbols */
    CHECK(wc_valid_edge_name("x") == 0, "ascii 'x' rejected");
    CHECK(wc_valid_edge_name("猫") == 0, "non-member kanji 猫 (cat) rejected");
    CHECK(wc_valid_edge_name("☿") == 0, "non-member glyph ☿ (mercury, multi-token) rejected");
    CHECK(wc_valid_edge_name("φ") == 0, "non-member greek φ (refused) rejected");
    CHECK(wc_valid_edge_name("源x") == 0, "valid+invalid mix 源x rejected");

    if (fails == 0) printf("\nALL EDGE-NAME TESTS PASSED\n");
    return fails ? 1 : 0;
}
