/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * analgapes :: c-base/avrs_shake.c
 *
 * Thin wrapper around OpenSSL EVP_shake256 in XOF mode. All hashes in the
 * analgapes rhizome — cluster IDs, metacog chain links, run-level seals —
 * go through this one primitive.
 */

#include "avrs_shake.h"
#include <openssl/evp.h>
#include <stdio.h>
#include <string.h>

int avrs_shake256(const void *in, size_t in_len, uint8_t out_64[AVRS_SHAKE_LEN]) {
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (!ctx) return -1;
    int rc = -1;
    if (EVP_DigestInit_ex(ctx, EVP_shake256(), NULL) != 1) goto out;
    if (EVP_DigestUpdate(ctx, in, in_len) != 1) goto out;
    if (EVP_DigestFinalXOF(ctx, out_64, AVRS_SHAKE_LEN) != 1) goto out;
    rc = 0;
out:
    EVP_MD_CTX_free(ctx);
    return rc;
}

int avrs_shake256_chain(const uint8_t *prev_hash, size_t prev_len,
                      const void *current, size_t cur_len,
                      uint8_t out_64[AVRS_SHAKE_LEN]) {
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (!ctx) return -1;
    int rc = -1;
    if (EVP_DigestInit_ex(ctx, EVP_shake256(), NULL) != 1) goto out;
    if (prev_hash && prev_len > 0) {
        if (EVP_DigestUpdate(ctx, prev_hash, prev_len) != 1) goto out;
    }
    if (current && cur_len > 0) {
        if (EVP_DigestUpdate(ctx, current, cur_len) != 1) goto out;
    }
    if (EVP_DigestFinalXOF(ctx, out_64, AVRS_SHAKE_LEN) != 1) goto out;
    rc = 0;
out:
    EVP_MD_CTX_free(ctx);
    return rc;
}

void avrs_shake256_hex(const uint8_t in_64[AVRS_SHAKE_LEN],
                     char out_hex[AVRS_SHAKE_HEX]) {
    static const char H[] = "0123456789abcdef";
    for (size_t i = 0; i < AVRS_SHAKE_LEN; i++) {
        out_hex[i * 2]     = H[(in_64[i] >> 4) & 0x0f];
        out_hex[i * 2 + 1] = H[ in_64[i]       & 0x0f];
    }
    out_hex[AVRS_SHAKE_LEN * 2] = '\0';
}

#ifdef AVRS_SHAKE_MAIN
/* CLI: reads stdin, prints SHAKE256-64 hex. Used by tests and as a sanity
 * check that the openssl path is working. */
int main(int argc, char **argv) {
    (void)argc; (void)argv;
    uint8_t buf[65536];
    size_t total = 0;
    /* Slurp stdin up to 4 MiB; chain into hash incrementally for larger. */
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (!ctx) { perror("EVP_MD_CTX_new"); return 1; }
    if (EVP_DigestInit_ex(ctx, EVP_shake256(), NULL) != 1) { perror("init"); return 1; }
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), stdin)) > 0) {
        if (EVP_DigestUpdate(ctx, buf, n) != 1) { perror("update"); return 1; }
        total += n;
    }
    uint8_t out[AVRS_SHAKE_LEN];
    if (EVP_DigestFinalXOF(ctx, out, AVRS_SHAKE_LEN) != 1) { perror("final"); return 1; }
    EVP_MD_CTX_free(ctx);
    char hex[AVRS_SHAKE_HEX];
    avrs_shake256_hex(out, hex);
    printf("%s\n", hex);
    fprintf(stderr, "bytes-hashed: %zu\n", total);
    return 0;
}
#endif
