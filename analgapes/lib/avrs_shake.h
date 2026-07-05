/* SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
 * analgapes :: c-base/avrs_shake.h
 *
 * Unified hash primitive for the analgapes rhizome.
 *
 * Why SHAKE256-xoflen-64:
 *   - Matches cta-v1's Seal of Inherited Provenance (same provenance contract).
 *   - 64-byte (512-bit) output: more than enough to be collision-resistant for
 *     cluster IDs, metacog chain links, and run-level seals.
 *   - XOF (extendable-output) — can produce any length, but we standardize
 *     on 64 bytes everywhere. One primitive, one length, no flavor confusion.
 *   - NIST-standard (FIPS 202), available in any modern libcrypto.
 *
 * Two operations cover all use sites:
 *   avrs_shake256()        — content-addressed hash of one buffer
 *   avrs_shake256_chain()  — hash-chain link: H(prev || current) for metacog
 */

#ifndef AVRS_SHAKE_H
#define AVRS_SHAKE_H

#include <stddef.h>
#include <stdint.h>

#define AVRS_SHAKE_LEN 64           /* 64 bytes = 512 bits, xoflen-64    */
#define AVRS_SHAKE_HEX (AVRS_SHAKE_LEN * 2 + 1)  /* hex string buffer size */

/* Hash one buffer. Writes AVRS_SHAKE_LEN bytes to out_64. Returns 0 on success,
 * -1 on libcrypto failure (errno preserved when meaningful). */
int avrs_shake256(const void *in, size_t in_len, uint8_t out_64[AVRS_SHAKE_LEN]);

/* Chain link: hash = SHAKE256-64(prev_hash || current_payload).
 * If prev_hash is NULL, behaves like avrs_shake256(current). Used by the metacog
 * journal: each entry's hash links to the prior entry's hash. */
int avrs_shake256_chain(const uint8_t *prev_hash, size_t prev_len,
                      const void *current, size_t cur_len,
                      uint8_t out_64[AVRS_SHAKE_LEN]);

/* Convenience: write hex (lowercase, no newline) into out_hex. out_hex must
 * be at least AVRS_SHAKE_HEX bytes. Always null-terminates. */
void avrs_shake256_hex(const uint8_t in_64[AVRS_SHAKE_LEN],
                     char out_hex[AVRS_SHAKE_HEX]);

#endif /* AVRS_SHAKE_H */
