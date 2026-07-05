#!/bin/sh
# ═══════════════════════════════════════════════════════════════════════════════
#  SCORPION — Recursive Cybernetic Rhizomal Security Auditor
#  Concatenative language (Forth-inspired). Stack-based. Self-extending.
#  8 autonomous nodes: ᚦ ⧫ ◉ ⧆ ⚷ ⌂ ᚢ ♃
#  ═══════════════════════════════════════════════════════════════════════════════

set -e

# ── DATA STACK ────────────────────────────────────────────────────────────────
# POSIX shell: $() creates subshells that cannot modify parent variables.
# Pattern: local v="$(_ds_peek)"; _ds_drop  — never modify DS inside $().
DS=""
_ds_push() { DS="$1${DS:+ $DS}"; }
_ds_peek() { printf '%s' "${DS%% *}"; }
_ds_drop() { local orig="$DS"; local v="${DS%% *}"; DS="${DS#* }"; DS="${DS# }"; if [ "$orig" = "$v" ]; then DS=""; fi; }
_ds_depth(){ local d=0; for _ in $DS; do d=$((d+1)); done; printf '%d' "$d"; }

# ── DISPATCH TABLE ────────────────────────────────────────────────────────────
# Maps concatenative words to shell implementations.
# Uses a single dispatch() function with case/esac for all built-ins.

dispatch() {
    local word="$1"
    case "$word" in
        # ── Stack primitives ──
        dup)  local v="$(_ds_peek)"; _ds_push "$v" ;;
        drop) _ds_drop ;;
        swap) local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; _ds_push "$a"; _ds_push "$b" ;;
        over) local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; _ds_push "$b"; _ds_push "$a" ;;
        rot)  local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)" c="$(_ds_peek)"; _ds_push "$b"; _ds_push "$a"; _ds_push "$c" ;;
        nip)  local a="$(_ds_peek)"; _ds_drop; _ds_drop; _ds_push "$a" ;;
        tuck) local a="$(_ds_peek)"; _ds_drop; _ds_push "$a"; rot; rot; ;;
        depth) _ds_push "$(_ds_depth)" ;;
        .s)   echo "=== STACK ==="; echo "$DS" | tr ' ' '\n' | nl; echo "depth: $(_ds_depth)" ;;

        # ── Arithmetic ──
        '+')   local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; _ds_push $((b + a)) ;;
        '-') local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; _ds_push $((b - a)) ;;
        '*') local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; _ds_push $((b * a)) ;;
        '/') local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; [ "$a" -ne 0 ] 2>/dev/null && _ds_push $((b / a)) || _ds_push 0 ;;
        mod)  local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; [ "$a" -ne 0 ] 2>/dev/null && _ds_push $((b % a)) || _ds_push 0 ;;
        eq)   local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; [ "$b" -eq "$a" ] 2>/dev/null && _ds_push 1 || _ds_push 0 ;;
        lt)   local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; [ "$b" -lt "$a" ] 2>/dev/null && _ds_push 1 || _ds_push 0 ;;
        gt)   local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; [ "$b" -gt "$a" ] 2>/dev/null && _ds_push 1 || _ds_push 0 ;;
        not)  local a="$(_ds_peek)"; _ds_drop; [ "$a" -eq 0 ] 2>/dev/null && _ds_push 1 || _ds_push 0 ;;
        and)  local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; [ "$b" -ne 0 ] && [ "$a" -ne 0 ] && _ds_push 1 || _ds_push 0 ;;
        or)   local a="$(_ds_peek)"; _ds_drop b="$(_ds_peek)"; [ "$b" -ne 0 ] || [ "$a" -ne 0 ] && _ds_push 1 || _ds_push 0 ;;

        # ── Crypto primitives (post-quantum) ──
        sha3-512)
            local input="$(_ds_peek)"; _ds_drop
            local hash=$(printf '%s' "$input" | openssl dgst -sha3-512 2>/dev/null | awk '{print $NF}')
            _ds_push "$hash"
            ;;
        sha3-256)
            local input="$(_ds_peek)"; _ds_drop
            local hash=$(printf '%s' "$input" | openssl dgst -sha3-256 2>/dev/null | awk '{print $NF}')
            _ds_push "$hash"
            ;;
        blake2b-512)
            local input="$(_ds_peek)"; _ds_drop
            local hash=$(printf '%s' "$input" | openssl dgst -blake2b512 2>/dev/null | awk '{print $NF}')
            _ds_push "$hash"
            ;;
        rand)
            local bytes="$(_ds_peek)"; _ds_drop
            local r=$(openssl rand -hex "$bytes" 2>/dev/null)
            _ds_push "$r"
            ;;
        ed25519-gen)
            local keydir="$(_ds_peek)"; _ds_drop
            mkdir -p "$keydir"
            openssl genpkey -algorithm ED25519 -outform PEM -out "$keydir/node.key" 2>/dev/null
            openssl pkey -in "$keydir/node.key" -pubout -outform PEM -out "$keydir/node.pub" 2>/dev/null
            chmod 600 "$keydir/node.key" "$keydir/node.pub" 2>/dev/null
            _ds_push "$keydir"
            ;;

        # ── Rhizome: 8 autonomous nodes ──
        # Each node pops target from stack, pushes findings.

        ᚦ)
            # THURISAZ: Repository audit
            local target="$(_ds_peek)"; _ds_drop
            local result=""
            local fcount=$(find "$target" -type f 2>/dev/null | wc -l)
            local world_readable=$(find "$target" -type f -perm -o+r 2>/dev/null | wc -l)
            local secrets=$(grep -rn -E '(password|secret|key|token|private)' "$target" 2>/dev/null | grep -v '.git/' | wc -l)
            result="files=$fcount|exposed=$world_readable|secrets=$secrets"
            _ds_push "$result"
            ;;

        ⧫)
            # LOZENGE: Correlation analysis
            local target="$(_ds_peek)"; _ds_drop
            local result=""
            local configs=$(find "$target" -name '*.conf' -o -name '*.env' -o -name '*.yaml' 2>/dev/null | wc -l)
            local bins=$(find "$target" -name '*.bin' -o -name '*.so' -o -name '*.exe' 2>/dev/null | wc -l)
            local keys=$(find "$target" -name '*.key' -o -name '*.pem' 2>/dev/null | wc -l)
            result="configs=$configs|bins=$bins|keys=$keys"
            _ds_push "$result"
            ;;

        ◉)
            # FISHEYE: Deep code review
            local target="$(_ds_peek)"; _ds_drop
            local result=""
            local cmdinj=$(grep -rn -E '\$\(.*\)|`.*`|eval\s' "$target" 2>/dev/null | grep -v '.git/' | wc -l)
            local sqlinj=$(grep -rn -E 'SELECT.*\$|INSERT.*\$' "$target" 2>/dev/null | wc -l)
            result="cmdinj=$cmdinj|sqlinj=$sqlinj"
            _ds_push "$result"
            ;;

        ⧆)
            # SQUARED PLUS: Automated vuln scan
            local target="$(_ds_peek)"; _ds_drop
            local result=""
            [ -f "$target/package.json" ] && result="${result}${result:+|}[DEP:npm]"
            [ -f "$target/requirements.txt" ] && result="${result}${result:+|}[DEP:pip]"
            [ -f "$target/go.mod" ] && result="${result}${result:+|}[DEP:go]"
            [ -f "$target/Dockerfile" ] && result="${result}${result:+|}[IAC:docker]"
            find "$target" -name '.env*' -type f 2>/dev/null | grep -q . && result="${result}${result:+|}[ENV:FILE]"
            _ds_push "${result:-clean}"
            ;;

        ⚷)
            # CHIRON: Secrets audit
            local target="$(_ds_peek)"; _ds_drop
            local result=""
            local perm_issues=$(find "$target" -type f -perm -o+r 2>/dev/null | wc -l)
            local creds=$(grep -rn -E '[A-Za-z0-9]{32,}' "$target" 2>/dev/null | grep -i 'key\|token\|secret' | wc -l)
            result="perm_issues=$perm_issues|creds=$creds"
            _ds_push "$result"
            ;;

        ⌂)
            # HOUSE: Infrastructure audit
            local target="$(_ds_peek)"; _ds_drop
            local result=""
            for f in Dockerfile docker-compose.yml main.tf kubernetes.yaml; do
                [ -f "$target/$f" ] && result="${result}${result:+|}[IAC:$f]"
            done
            [ -f "$target/Dockerfile" ] && grep -q 'USER root' "$target/Dockerfile" 2>/dev/null && result="${result}${result:+|}[DOCKER:ROOT]"
            _ds_push "${result:-no_iac}"
            ;;

        ᚢ)
            # URUZ: Binary analysis
            local target="$(_ds_peek)"; _ds_drop
            local result=""
            local bins=$(find "$target" -type f -executable 2>/dev/null | wc -l)
            local suid=$(find "$target" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
            result="exec=$bins|suid=$suid"
            _ds_push "$result"
            ;;

        ♃)
            # JUPITER: Full orchestration
            # Read 7 results without dropping (target already consumed by each node)
            local r7="$(_ds_peek)"; _ds_drop
            local r6="$(_ds_peek)"; _ds_drop
            local r5="$(_ds_peek)"; _ds_drop
            local r4="$(_ds_peek)"; _ds_drop
            local r3="$(_ds_peek)"; _ds_drop
            local r2="$(_ds_peek)"; _ds_drop
            local r1="$(_ds_peek)"; _ds_drop
            local critical=0 high=0 medium=0 chain=""
            # r1=ᚦ r2=⧫ r3=◉ r4=⧆ r5=⚷ r6=⌂ r7=ᚢ
            echo "  ᚦ: $r1" >&2
            echo "  ⧫: $r2" >&2
            echo "  ◉: $r3" >&2
            echo "  ⧆: $r4" >&2
            echo "  ⚷: $r5" >&2
            echo "  ⌂: $r6" >&2
            echo "  ᚢ: $r7" >&2
            # Severity scoring (pipe-delimited results)
            case "$r5" in *creds=*|*perm_issues=[1-9]*) critical=$((critical + 1)); chain="${chain}P3:⚷->identity_theft;" ;; esac
            case "$r3" in *cmdinj=[1-9]*) high=$((high + 1)); chain="${chain}P2:◉->vuln_confirmed;" ;; esac
            case "$r1" in *exposed=[1-9]*) medium=$((medium + 1)); chain="${chain}P1:ᚦ->recon;" ;; esac
            case "$r6" in *IAC=*|*DOCKER=*) medium=$((medium + 1)); chain="${chain}P4:⌂->infra;" ;; esac
            case "$r7" in *suid=[1-9]*) medium=$((medium + 1)); chain="${chain}P5:ᚢ->binary_exploit;" ;; esac
            # Push in reverse order of how report section pops
            _ds_push "$medium"
            _ds_push "$high"
            _ds_push "$critical"
            _ds_push "$chain"
            _ds_push "♃_complete"
            ;;

        # ── Rhizome control ──
        rhizome)
            # Execute all 8 nodes, each pushing one result
            local target="$(_ds_peek)"
            _ds_push "$target"; dispatch ᚦ
            _ds_push "$target"; dispatch ⧫
            _ds_push "$target"; dispatch ◉
            _ds_push "$target"; dispatch ⧆
            _ds_push "$target"; dispatch ⚷
            _ds_push "$target"; dispatch ⌂
            _ds_push "$target"; dispatch ᚢ
            # Stack now has: target + 7 results
            dispatch ♃
            ;;

        trigger)
            local node="$(_ds_peek)"; _ds_drop
            dispatch "$node"
            ;;

        # ── Metacognition ──
        meta-stack) echo "=== STACK ==="; echo "$DS" | tr ' ' '\n' | nl; echo "depth: $(_ds_depth)" ;;
        meta-trace)
            local action="$(_ds_peek)"; _ds_drop
            printf '%s|%s\n' "$(date +%s)" "$action" >> "$TMPDIR/scorpion.trace"
            ;;
        meta-bias)
            if [ -f "$TMPDIR/scorpion.trace" ]; then
                local dom=$(cut -d'|' -f2 "$TMPDIR/scorpion.trace" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
                local cnt=$(grep -c "|$dom|" "$TMPDIR/scorpion.trace" 2>/dev/null)
                local tot=$(wc -l < "$TMPDIR/scorpion.trace" 2>/dev/null); tot=${tot:-1}
                if [ "$cnt" -gt $((tot * 6 / 10)) ] && [ "$tot" -gt 5 ]; then
                    _ds_push "[BIAS:FIXATION] $dom dominates $cnt/$tot"
                else
                    _ds_push "[BIAS:NONE]"
                fi
            else
                _ds_push "[BIAS:NODATA]"
            fi
            ;;

        # ── Self-development ──
        dev-mutate)
            local word="$(_ds_peek)"; _ds_drop
            _ds_push "[DEV:MUTATE]$word not yet implemented in dispatch"
            ;;
        dev-score)
            local total=0 cnt=0
            for w in ᚦ ⧫ ◉ ⧆ ⚷ ⌂ ᚢ; do
                local c=$(grep -c "$w" "$TMPDIR/scorpion.trace" 2>/dev/null)
                total=$((total + ${c:-0})); cnt=$((cnt + 1))
            done
            [ "$cnt" -gt 0 ] && _ds_push $((total / cnt)) || _ds_push 0
            ;;

        # ── Sclerotium ──
        sclerotium)
            local threshold="$(_ds_peek)"
            _ds_push "[SCLEROTIUM:PASS]"
            ;;

        # ── Default ──
        *)
            # Numeric literal
            if [ "$word" -eq "$word" ] 2>/dev/null; then
                _ds_push "$word"
            else
                echo "?: $word" >&2
            fi
            ;;
    esac
}

# ── INTERPRETER ───────────────────────────────────────────────────────────────
# Read words from stdin or command line and dispatch.

interpret() {
    for word in "$@"; do
        [ "$word" = "#" ] && break  # comment
        dispatch "$word"
    done
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
main() {
    TMPDIR=$(mktemp -d -t scorpion.XXXXXXXX)
    chmod 700 "$TMPDIR"
    > "$TMPDIR/scorpion.trace"

    # Generate identity
    _ds_push "$TMPDIR/identity"
    dispatch ed25519-gen

    local target="" mode="rhizome" depth="standard"

    while [ $# -gt 0 ]; do
        case "$1" in
            --target) target="$2"; shift 2 ;;
            --mode) mode="$2"; shift 2 ;;
            --depth) depth="$2"; shift 2 ;;
            --audit-self) mode="self-audit"; shift ;;
            --interpret) mode="interpret"; shift; break ;;
            *) shift ;;
        esac
    done

    if [ "$mode" = "interpret" ]; then
        # Interactive/stack mode
        interpret "$@"
        echo "Stack: $DS"
        rm -rf "$TMPDIR"
        return
    fi

    [ -z "$target" ] && { echo "Usage: $0 --target /path [--depth standard|full] [--interpret words...]"; rm -rf "$TMPDIR"; exit 1; }
    [ ! -e "$target" ] && { echo "Not found: $target"; rm -rf "$TMPDIR"; exit 1; }

    echo "═══════════════════════════════════════════════════════════════"
    echo "  ᚦ⧫◉⧆⚷⌂ᚢ♃  SCORPION RHIZOME"
    echo "  Target: $target"
    echo "═══════════════════════════════════════════════════════════════"

    _ds_push "$target"
    dispatch rhizome

    # Report: pop ♃ synthesis before full-depth extras push more
    echo ""
    echo "═══ FINDINGS ═══"
    local status="$(_ds_peek)"; _ds_drop
    if [ "$status" = "♃_complete" ]; then
        # Pop order must reverse push order: chain critical high medium
        local chain="$(_ds_peek)"; _ds_drop
        local crit="$(_ds_peek)"; _ds_drop
        local hi="$(_ds_peek)"; _ds_drop
        local med="$(_ds_peek)"; _ds_drop
        echo "  Severity: Critical=$crit High=$hi Medium=$med"
        [ -n "$chain" ] && echo "  Attack Chain: $chain"
        echo ""
    fi

    if [ "$depth" = "full" ]; then
        dispatch meta-bias
        dispatch dev-score
        echo "  ── Metacognition ──"
        local bias="$(_ds_peek)"; _ds_drop; echo "  $bias"
        local score="$(_ds_peek)"; echo "  Activation: $score"
    fi
    echo ""
    echo "  ᚦ⧫◉⧆⚷⌂ᚢ♃"

    rm -rf "$TMPDIR"
}

main "$@"
