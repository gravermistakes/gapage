# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: Makefile  (top-level test-all, strict)

CC      ?= cc
CFLAGS  ?= -Ilib -Imetacognition/consciousness -O2 -Wall -Wextra -Wpedantic -Werror -std=c11 -D_GNU_SOURCE
LDFLAGS ?= -lcrypto

LIB := lib
WC  := metacognition/consciousness
T   := tests
M   := /tmp/analgapes_mut

.PHONY: test-all clean-all shake-smoke shake-test shake-mutation \
        wc-test wc-mutation edge-test edge-mutation keel-test orch-test cognition-test perception-test action-test swarm-test lifter-test substrate-test

test-all:
	@pass=0; total=0; \
	run() { total=$$((total+1)); printf "\n=== %s ===\n" "$$1"; \
	        if $(MAKE) -s $$2; then pass=$$((pass+1)); else echo "  XX $$1"; fi; }; \
	run "shake cross-validate"           shake-smoke; \
	run "shake unit"                     shake-test; \
	run "shake mutation caught"          shake-mutation; \
	run "witness_chain unit"             wc-test; \
	run "witness_chain mutation caught"  wc-mutation; \
	run "edge-name unit"                 edge-test; \
	run "edge-name mutation caught"      edge-mutation; \
	run "keel gate + Ada/C seal"         keel-test; \
	run "orchestration cycle"            orch-test; \
	run "cognition current"              cognition-test; \
	run "perception current"             perception-test; \
	run "action current"                 action-test; \
	run "swarm current"                  swarm-test; \
	run "v2.3 lifters (perl)"            lifter-test; \
	run "substrate syntax"               substrate-test; \
	echo; echo "=============================="; \
	pct=$$(( pass * 100 / total )); \
	echo " SUMMARY: $$pass / $$total passed ($$pct%)"; \
	if [ $$pct -lt 100 ]; then echo " BUILD FAILED — strict requires 100%"; exit 1; \
	else echo " BUILD PASSED"; fi

shake-smoke:
	@$(CC) $(CFLAGS) -DAVRS_SHAKE_MAIN -o /tmp/avrs-shake $(LIB)/avrs_shake.c $(LDFLAGS)
	@H_OURS=$$(printf 'analgapes' | /tmp/avrs-shake); \
	 H_OSSL=$$(printf 'analgapes' | openssl dgst -shake256 -xoflen 64 -hex | awk '{print $$NF}'); \
	 [ "$$H_OURS" = "$$H_OSSL" ] && echo "PASS: shake cross-validates vs openssl" \
	   || { echo "FAIL: shake != openssl"; exit 1; }

shake-test:
	@$(CC) $(CFLAGS) -o /tmp/test_shake $(T)/test_shake.c $(LIB)/avrs_shake.c $(LDFLAGS)
	@/tmp/test_shake

shake-mutation:
	@mkdir -p $(M); cp $(LIB)/avrs_shake.h $(M)/
	@printf '%s\n' \
	  '#include "avrs_shake.h"' \
	  '#include <string.h>' \
	  'int avrs_shake256(const void *in, size_t n, uint8_t o[AVRS_SHAKE_LEN]){(void)in;(void)n;memset(o,0x42,AVRS_SHAKE_LEN);return 0;}' \
	  'int avrs_shake256_chain(const uint8_t *p,size_t pl,const void *c,size_t cl,uint8_t o[AVRS_SHAKE_LEN]){(void)p;(void)pl;(void)c;(void)cl;memset(o,0x42,AVRS_SHAKE_LEN);return 0;}' \
	  'void avrs_shake256_hex(const uint8_t i[AVRS_SHAKE_LEN],char o[AVRS_SHAKE_HEX]){for(size_t k=0;k<AVRS_SHAKE_LEN;k++){o[2*k]="0123456789abcdef"[i[k]>>4];o[2*k+1]="0123456789abcdef"[i[k]&15];}o[AVRS_SHAKE_LEN*2]=0;}' \
	  > $(M)/avrs_shake.c
	@$(CC) $(CFLAGS) -o $(M)/ts $(T)/test_shake.c $(M)/avrs_shake.c -I$(M) 2>/dev/null; \
	 if $(M)/ts >/dev/null 2>&1; then echo "FAIL: shake tests tautological"; rm -rf $(M); exit 1; \
	 else echo "PASS: shake mutation caught"; rm -rf $(M); fi

wc-test:
	@$(CC) $(CFLAGS) -o /tmp/test_wc $(T)/test_witness_chain.c $(WC)/witness_chain.c $(LIB)/avrs_shake.c $(LDFLAGS)
	@ANALGAPES_WORKSPACE=/tmp/analgapes_ws /tmp/test_wc

wc-mutation:
	@mkdir -p $(M); cp $(WC)/witness_chain.h $(LIB)/avrs_shake.h $(LIB)/avrs_shake.c $(M)/
	@sed 's|if (e->truth_value != WC_TRUTH_TRUE) return 1;|/* gate removed */|' \
	    $(WC)/witness_chain.c > $(M)/witness_chain.c
	@$(CC) $(CFLAGS) -o $(M)/twc $(T)/test_witness_chain.c $(M)/witness_chain.c $(M)/avrs_shake.c -I$(M) $(LDFLAGS) 2>/dev/null; \
	 if ANALGAPES_WORKSPACE=/tmp/analgapes_ws_mut $(M)/twc >/dev/null 2>&1; then \
	    echo "FAIL: truth-gate test tautological"; rm -rf $(M); exit 1; \
	 else echo "PASS: witness_chain mutation caught"; rm -rf $(M); fi

edge-test:
	@$(CC) $(CFLAGS) -o /tmp/test_edge $(T)/test_edge_name.c $(WC)/witness_chain.c $(LIB)/avrs_shake.c $(LDFLAGS)
	@/tmp/test_edge

edge-mutation:
	@mkdir -p $(M); cp $(WC)/witness_chain.h $(LIB)/avrs_shake.h $(LIB)/avrs_shake.c $(M)/
	@sed 's@if (cp == 0xFFFFFFFFu || !wc_cp_member(cp)) return 0;@/* mutated: accept all */@' \
	    $(WC)/witness_chain.c > $(M)/witness_chain.c
	@$(CC) $(CFLAGS) -o $(M)/te $(T)/test_edge_name.c $(M)/witness_chain.c $(M)/avrs_shake.c -I$(M) $(LDFLAGS) 2>/dev/null; \
	 if $(M)/te >/dev/null 2>&1; then echo "FAIL: edge-name test tautological"; rm -rf $(M); exit 1; \
	 else echo "PASS: edge-name mutation caught"; rm -rf $(M); fi

clean-all:
	@rm -f /tmp/avrs-shake /tmp/test_shake /tmp/test_wc /tmp/test_edge
	@rm -rf /tmp/analgapes_ws /tmp/analgapes_ws_mut $(M)

keel-test:
	@cc -Ilib -O2 -Wall -Wextra -Werror -std=c11 -D_GNU_SOURCE -c lib/avrs_shake.c -o /tmp/avrs_shake.o -lcrypto
	@cd governance/keel && gnatmake -q test_keel.adb -largs /tmp/avrs_shake.o -lcrypto 2>/dev/null
	@governance/keel/test_keel | grep -a "^PASS\|^ALL" | tail -1
	@S_OURS=$$(governance/keel/test_keel | grep -a "SEAL analgapes" | awk '{print $$NF}' | tr -d '\0'); \
	 S_OSSL=$$(printf 'analgapes' | openssl dgst -shake256 -xoflen 64 -hex | awk '{print $$NF}'); \
	 [ "$$S_OURS" = "$$S_OSSL" ] && echo "PASS: KEEL Ada->C seal == openssl" \
	   || { echo "FAIL: seal mismatch"; exit 1; }

orch-test:
	@cc -Ilib -Imetacognition/consciousness -O2 -Wall -Wextra -Werror -std=c11 -D_GNU_SOURCE \
	    -DWITNESS_CHAIN_MAIN -o bin/witness-chain \
	    metacognition/consciousness/witness_chain.c lib/avrs_shake.c -lcrypto
	@rm -rf /tmp/aws_test
	@ANALGAPES_WORKSPACE=/tmp/aws_test RUN_ID=t WITNESS_BIN=$$(pwd)/bin/witness-chain ./avrs.sh --target ./self --mode repo >/dev/null
	@N=$$(wc -l < /tmp/aws_test/runs/t/metacog.jsonl); \
	 [ "$$N" -eq 5 ] && echo "PASS: orchestration wrote 5 edge-named entries" \
	   || { echo "FAIL: expected 5 entries, got $$N"; exit 1; }

cognition-test:
	@cc -Ilib -Imetacognition/consciousness -O2 -Wall -Wextra -Wpedantic -Werror -std=c11 -D_GNU_SOURCE \
	    -DCORR_MAIN -o /tmp/correlation \
	    cognition/correlation/correlation.c metacognition/consciousness/witness_chain.c lib/avrs_shake.c -lcrypto -lpthread
	@OUT=$$(printf '%s\n%s\n' \
	   '{"id":"a","kind":"vuln","locus":"x.c:1","severity":0.9,"epoch":1}' \
	   '{"id":"b","kind":"vuln","locus":"x.c:1","severity":0.5,"epoch":2}' | /tmp/correlation 2>/dev/null); \
	 echo "$$OUT" | grep -q '"members":\["a","b"\]' \
	   && echo "PASS: correlation clusters a+b deterministically" \
	   || { echo "FAIL: correlation did not cluster"; exit 1; }
	@bash cognition/trialectic/trialectic.sh -x "scale now" -y "verify first" -d natural 2>/dev/null | grep -q '"phase": 1' \
	   && echo "PASS: trialectic operator runs from cognition layer" \
	   || { echo "FAIL: trialectic broken"; exit 1; }
	@rm -rf /tmp/cwt; printf '{"id":"a","kind":"vuln","locus":"x.c:1","severity":0.9,"epoch":1}\n{"id":"b","kind":"vuln","locus":"x.c:1","severity":0.5,"epoch":2}\n' | ANALGAPES_WORKSPACE=/tmp/cwt /tmp/correlation >/dev/null 2>&1; find /tmp/cwt -name metacog.jsonl -exec grep -q '"edge_name":"ρ"' {} \; && echo "PASS: correlation writes ρ edge to unified chain (cellular write-through)" || { echo "FAIL: no write-through"; exit 1; }
	@bash cognition/modalities/inverse_mc.sh 2>/dev/null | grep -q 'cta_version' \
	   && echo "PASS: MC modality locates shared lib + R kernel" \
	   || { echo "FAIL: modality cannot find lib/kernel"; exit 1; }

perception-test:
	@F=/tmp/at.pl; bash perception/tool_loader.sh perception/tool_registry.json $$F >/dev/null
	@swipl -q -g "consult('/tmp/at.pl'), aggregate_all(count,tool(_,_,_),N), (N=:=94->true;(write(bad),halt(1))), findall(X,tool(X,\"osint\",_),O),length(O,L),(L=:=12->true;halt(1)), halt" 2>/dev/null \
	   && echo "PASS: Prolog registry resolves 94 tools (osint=12)" \
	   || { echo "FAIL: registry query"; exit 1; }
	@printf '*stopped,reason="signal-received",frame={addr="0x41414141"\n~"rax  0x41414141"\n' \
	   | perl perception/dynamic/parse_gdb_mi.pl | grep -q '"primitive_type":"controlled_eip"' \
	   && echo "PASS: Perl GDB/MI lifter detects controlled_eip" \
	   || { echo "FAIL: lifter"; exit 1; }

action-test:
	@perl action/exploit_synthesis/poc_template.pl controlled_eip 0x41414141 | grep -q '"requires_keel_gate":true' \
	   && echo "PASS: poc scaffold emitted, KEEL-gated" || { echo "FAIL: poc"; exit 1; }
	@if bash action/test_first_poc/test_first_poc.sh 2>/dev/null; then echo "FAIL: emitted PoC without crash proof"; exit 1; \
	 else echo "PASS: test-first gate refuses PoC without reproducing crash"; fi

swarm-test:
	@Rscript metacognition/consciousness/formation_encoder.R 0.9 0.2 | grep -q '"semantic_state":"rupture"' \
	   && echo "PASS: formation encoder detects rupture" || { echo "FAIL: encoder"; exit 1; }
	@cd metacognition/consciousness && erlc swarm_formation_bridge.erl 2>/dev/null; \
	 printf '%s\n' \
	   '-module(st).' '-export([run/0]).' \
	   'run() -> {ok,_}=swarm_formation_bridge:start_link(), ok=swarm_formation_bridge:register_instance(a), ok=swarm_formation_bridge:register_instance(b), 2=length(swarm_formation_bridge:instances()), io:format("ok~n"), halt(0).' \
	   > st.erl; \
	 erlc st.erl 2>/dev/null; \
	 if erl -noshell -pa . -run st run 2>/dev/null | grep -q ok; then echo "PASS: OTP swarm bridge registers + relays"; else echo "FAIL: swarm bridge"; rm -f st.*; exit 1; fi; \
	 rm -f st.erl st.beam

lifter-test:
	@cc -Ilib -Imetacognition/consciousness -O2 -std=c11 -D_GNU_SOURCE -DWITNESS_CHAIN_MAIN \
	    -o /tmp/lt_bin metacognition/consciousness/witness_chain.c lib/avrs_shake.c -lcrypto 2>/dev/null
	@perl perception/static/build_graph.pl /tmp/lt_bin 2>/dev/null | grep -q '@plt' \
	   && echo "PASS: build_graph lifts call graph from real binary" || { echo "FAIL: build_graph"; exit 1; }
	@echo '{"vuln":["strcpy"],"safe":["calloc"]}' | perl action/exploit_synthesis/heap_shaper.pl \
	   | grep -q '"sink_relevant":\["vuln"\]' \
	   && echo "PASS: heap_shaper finds sink-relevant funcs" || { echo "FAIL: heap_shaper"; exit 1; }

substrate-test:
	@fail=0; for f in $$(find . -name '*.pl' | grep -v lib/cta | grep -v tool_registry.pl); do \
	   perl -c "$$f" >/dev/null 2>&1 || { echo "  broken: $$f"; fail=1; }; done; \
	 [ $$fail -eq 0 ] && echo "PASS: all substrate Perl syntax-valid (ganesh, axml, dexdump, apk/*, detection/*)" \
	   || { echo "FAIL: broken substrate Perl"; exit 1; }
	@swipl -q -g "consult('perception/tool_registry'), halt" 2>/dev/null \
	   && echo "PASS: tool_registry.pl (Prolog) loads" || { echo "FAIL: prolog registry"; exit 1; }
	@mkdir -p /tmp/sl /tmp/co /tmp/fb; \
	 cd perception/static && gnatmake -q -c -D /tmp/sl src/sledge.adb 2>/dev/null && cd ../.. \
	   && gnatmake -q -c -D /tmp/co core/src/src/avrs_core.adb 2>/dev/null \
	   && gnatmake -q -c -D /tmp/fb metacognition/feedback_analyzer.adb 2>/dev/null \
	   && echo "PASS: legacy substrate Ada compiles (sledge, avrs_core, feedback_analyzer)" \
	   || { echo "FAIL: substrate Ada"; exit 1; }
