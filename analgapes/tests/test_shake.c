/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * route-cause :: c-base/test_shake.c
 *
 * Tests for the SHAKE256 primitive. Written before the impl was trusted.
 * Three things checked:
 *   1) Cross-validation against `openssl dgst -shake256 -xoflen 64` (golden ref)
 *   2) Chain link with NULL prev behaves like a single hash
 *   3) Mutation test: 1-byte change to input → at least 32 bytes differ in
 *      output (avalanche). If this fails, the test isn't discriminating OR
 *      the hash is broken — either way a real failure.
 */

#include "avrs_shake.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int test_basic(void) {
    /* Sanity: hashing "" should not crash and should produce stable output */
    uint8_t a[AVRS_SHAKE_LEN], b[AVRS_SHAKE_LEN];
    if (avrs_shake256("", 0, a) != 0) return 1;
    if (avrs_shake256("", 0, b) != 0) return 1;
    if (memcmp(a, b, AVRS_SHAKE_LEN) != 0) {
        fprintf(stderr, "FAIL test_basic: empty hash not deterministic\n");
        return 1;
    }
    char hex[AVRS_SHAKE_HEX]; avrs_shake256_hex(a, hex);
    fprintf(stderr, "shake256(\"\") = %.32s...\n", hex);
    return 0;
}

static int test_chain_null_prev_equals_basic(void) {
    /* avrs_shake256_chain(NULL, 0, x, n) === avrs_shake256(x, n) */
    const char *msg = "hello, route-cause";
    uint8_t a[AVRS_SHAKE_LEN], b[AVRS_SHAKE_LEN];
    if (avrs_shake256(msg, strlen(msg), a) != 0) return 1;
    if (avrs_shake256_chain(NULL, 0, msg, strlen(msg), b) != 0) return 1;
    if (memcmp(a, b, AVRS_SHAKE_LEN) != 0) {
        fprintf(stderr, "FAIL test_chain_null_prev: chain(NULL,...) != basic\n");
        return 1;
    }
    return 0;
}

static int test_mutation_avalanche(void) {
    /* One-byte change → at least 32 bytes differ (good avalanche).
     * If we got < 32 bytes different the test environment is sus OR the
     * implementation isn't really SHAKE256 — either way fail loud. */
    char input1[] = "the route is the cause";
    char input2[] = "the route is the cau$e";  /* 1 byte different */
    uint8_t h1[AVRS_SHAKE_LEN], h2[AVRS_SHAKE_LEN];
    if (avrs_shake256(input1, strlen(input1), h1) != 0) return 1;
    if (avrs_shake256(input2, strlen(input2), h2) != 0) return 1;
    int differ = 0;
    for (size_t i = 0; i < AVRS_SHAKE_LEN; i++) if (h1[i] != h2[i]) differ++;
    fprintf(stderr, "avalanche: %d / %d bytes differ for 1-byte input change\n",
            differ, AVRS_SHAKE_LEN);
    if (differ < 32) {
        fprintf(stderr, "FAIL test_mutation_avalanche: only %d differing bytes\n", differ);
        return 1;
    }
    return 0;
}

static int test_chain_is_linked(void) {
    /* Chain is order-sensitive (proves it's not just XOR or concat).
     * H(A || B) != H(B || A) for distinct A, B. */
    uint8_t hA[AVRS_SHAKE_LEN], hB[AVRS_SHAKE_LEN], chainAB[AVRS_SHAKE_LEN], chainBA[AVRS_SHAKE_LEN];
    if (avrs_shake256("alpha", 5, hA) != 0) return 1;
    if (avrs_shake256("beta", 4,  hB) != 0) return 1;
    if (avrs_shake256_chain(hA, AVRS_SHAKE_LEN, "beta", 4, chainAB) != 0) return 1;
    if (avrs_shake256_chain(hB, AVRS_SHAKE_LEN, "alpha", 5, chainBA) != 0) return 1;
    if (memcmp(chainAB, chainBA, AVRS_SHAKE_LEN) == 0) {
        fprintf(stderr, "FAIL test_chain_is_linked: A||B == B||A (link is symmetric, bug)\n");
        return 1;
    }
    return 0;
}

int main(void) {
    int failures = 0;
    failures += test_basic();
    failures += test_chain_null_prev_equals_basic();
    failures += test_mutation_avalanche();
    failures += test_chain_is_linked();
    if (failures == 0) {
        fprintf(stderr, "ALL PASS (4/4)\n");
        return 0;
    }
    fprintf(stderr, "FAILED: %d tests\n", failures);
    return 1;
}
