# cta-v1 :: scripts/lib/common.sh
# Shared utilities. Source this from any phase script.
# Requires: bash >= 4, awk, sed, bc, openssl. Optional: jq (falls back to printf).
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0  (Original Creator: Anja Evermoor)

# ---------- guard against double-sourcing ----------
[[ -n "${__CTA_COMMON_LOADED:-}" ]] && return 0
__CTA_COMMON_LOADED=1

# ---------- environment ----------
CTA_ROOT="${CTA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CTA_LIB="$CTA_ROOT/scripts/lib"
CTA_CONFIG="$CTA_ROOT/config/cta-config.yaml"
CTA_EPSILON_DEFAULT="0.03"
CTA_PATIENCE_DEFAULT="4"
CTA_VARIANCE_PCTL_DEFAULT="25"
CTA_GONZO_THRESH_DEFAULT="0.05"

# ---------- logging ----------
# All logs go to stderr so stdout stays pure JSON for piping.
_cta_log() {
    local level="$1"; shift
    printf '[cta:%s] %s\n' "$level" "$*" >&2
}
cta_info() { _cta_log info "$*"; }
cta_warn() { _cta_log warn "$*"; }
cta_err()  { _cta_log err  "$*"; }
cta_die()  { _cta_log err  "$*"; exit 1; }

# ---------- dependency check ----------
cta_require() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        cta_die "missing required commands: ${missing[*]}"
    fi
}

# ---------- math (bc wrappers) ----------
# Floating-point math via bc. Always returns leading 0 for values < 1.
cta_bc() {
    local result
    result=$(printf 'scale=6; %s\n' "$1" | bc -l 2>/dev/null)
    [[ "$result" == .* ]] && result="0$result"
    [[ "$result" == -.* ]] && result="-0${result#-}"
    printf '%s' "${result:-0}"
}

cta_lt() { [[ $(cta_bc "if($1 < $2) 1 else 0") == "1" ]]; }
cta_gt() { [[ $(cta_bc "if($1 > $2) 1 else 0") == "1" ]]; }
cta_le() { [[ $(cta_bc "if($1 <= $2) 1 else 0") == "1" ]]; }
cta_ge() { [[ $(cta_bc "if($1 >= $2) 1 else 0") == "1" ]]; }

# Clamp x to [lo, hi]
cta_clamp() {
    local x="$1" lo="$2" hi="$3"
    cta_lt "$x" "$lo" && { printf '%s' "$lo"; return; }
    cta_gt "$x" "$hi" && { printf '%s' "$hi"; return; }
    printf '%s' "$x"
}

# ---------- timestamp (unix epoch per Anja's preference) ----------
cta_epoch() { date +%s; }
cta_epoch_ns() { date +%s%N 2>/dev/null || printf '%s000000000' "$(date +%s)"; }

# ---------- tokenization ----------
# Lowercase, strip punctuation (keep apostrophes inside words for contractions),
# collapse whitespace, emit one token per line.
cta_tokenize() {
    printf '%s\n' "$*" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E "s/[^a-z0-9' ]+/ /g; s/  +/ /g; s/^ //; s/ $//" \
        | tr ' ' '\n' \
        | sed '/^$/d'
}

# Built-in stopword list (English, conservative — keeps modals and quantifiers).
# Note: we deliberately retain "not, never, no, all, must, may, can, should"
# because they carry logical weight for Phase 1.
__CTA_STOPWORDS=" a an the of to in on at by for from with into onto upon
                  is are was were be been being am
                  i you we they he she it me us them him her
                  this that these those there here
                  and or but if then so as than
                  do does did done doing
                  have has had having
                  about over under above below
                  s t re ll ve d m "

cta_strip_stopwords() {
    awk -v sw="$__CTA_STOPWORDS" '
        BEGIN { n = split(sw, arr, /[ \n\t]+/); for (i=1;i<=n;i++) stop[arr[i]] = 1 }
        { if (!($0 in stop) && length($0) > 0) print $0 }
    '
}

# Tiny Porter-lite stemmer: strip common English suffixes.
# Order matters; longest first.
cta_stem() {
    awk '{
        w = $0
        # ational -> ate
        if (match(w, /ational$/) && RLENGTH > 0) w = substr(w, 1, length(w)-7) "ate"
        else if (match(w, /tional$/) && RLENGTH > 0) w = substr(w, 1, length(w)-6) "tion"
        else if (match(w, /ization$/) && RLENGTH > 0) w = substr(w, 1, length(w)-7) "ize"
        else if (match(w, /izer$/) && RLENGTH > 0) w = substr(w, 1, length(w)-4) "ize"
        else if (match(w, /iveness$/) && RLENGTH > 0) w = substr(w, 1, length(w)-7) "ive"
        else if (match(w, /fulness$/) && RLENGTH > 0) w = substr(w, 1, length(w)-7) "ful"
        else if (match(w, /ousness$/) && RLENGTH > 0) w = substr(w, 1, length(w)-7) "ous"
        else if (match(w, /ities$/) && RLENGTH > 0) w = substr(w, 1, length(w)-5) "ity"
        else if (match(w, /ically$/) && RLENGTH > 0) w = substr(w, 1, length(w)-6) "ic"
        else if (match(w, /ingly$/) && RLENGTH > 0) w = substr(w, 1, length(w)-5)
        else if (match(w, /ation$/) && length(w) > 6) w = substr(w, 1, length(w)-5) "ate"
        else if (match(w, /ables?$/) && length(w) > 6) sub(/ables?$/, "able", w)
        else if (match(w, /ities$/) && length(w) > 6) sub(/ities$/, "ity", w)
        else if (match(w, /ing$/) && length(w) > 5) w = substr(w, 1, length(w)-3)
        else if (match(w, /edly$/) && length(w) > 6) w = substr(w, 1, length(w)-4)
        else if (match(w, /ied$/) && length(w) > 5) w = substr(w, 1, length(w)-3) "y"
        else if (match(w, /ies$/) && length(w) > 5) w = substr(w, 1, length(w)-3) "y"
        else if (match(w, /ed$/)  && length(w) > 4) w = substr(w, 1, length(w)-2)
        else if (match(w, /es$/)  && length(w) > 4) w = substr(w, 1, length(w)-2)
        else if (match(w, /ly$/)  && length(w) > 4) w = substr(w, 1, length(w)-2)
        else if (match(w, /s$/)   && length(w) > 3 && substr(w, length(w)-1, 1) != "s") w = substr(w, 1, length(w)-1)
        print w
    }'
}

# Pipeline: tokenize -> stopwords -> stem
cta_normalize() {
    cta_tokenize "$@" | cta_strip_stopwords | cta_stem
}

# ---------- antonym / contradiction dictionary ----------
# Format: one space-separated pair per line. Bidirectional.
# Embedded here so the skill is self-contained.
__cta_antonyms() {
    cat <<'EOF'
always never
all none
all no
must may
must never
required optional
required forbidden
true false
yes no
secure insecure
safe unsafe
present absent
include exclude
accept reject
increase decrease
grow shrink
maximize minimize
optimize degrade
fast slow
high low
strong weak
hot cold
big small
hard soft
open closed
public private
visible hidden
known unknown
right wrong
correct incorrect
valid invalid
prove disprove
allow deny
permit forbid
enable disable
start stop
begin end
create destroy
build break
add remove
gain lose
win lose
agree disagree
forward backward
ascend descend
expand contract
centralized decentralized
central decentral
hierarchical flat
top-down bottom-up
synchronous asynchronous
stateful stateless
mutable immutable
encrypted plaintext
trusted untrusted
explicit implicit
strict lenient
EOF
}

# Returns 1 if statements X and Y contain antonymous tokens, 0 otherwise.
cta_has_contradiction() {
    local x="$1" y="$2"
    local x_tokens y_tokens
    x_tokens=$(cta_tokenize "$x" | tr '\n' ' ')
    y_tokens=$(cta_tokenize "$y" | tr '\n' ' ')
    while read -r a b; do
        [[ -z "$a" || -z "$b" ]] && continue
        if [[ " $x_tokens " == *" $a "* && " $y_tokens " == *" $b "* ]] \
           || [[ " $x_tokens " == *" $b "* && " $y_tokens " == *" $a "* ]]; then
            printf '%s vs %s' "$a" "$b"
            return 0
        fi
    done < <(__cta_antonyms)
    return 1
}

# ---------- modal / quantifier detection ----------
# Returns space-separated tags found in input.
cta_modal_tags() {
    local s
    s=$(printf '%s' "$*" | tr '[:upper:]' '[:lower:]')
    local tags=()
    [[ "$s" =~ (^| )(must|shall|required|necessary)( |$|[[:punct:]]) ]] && tags+=("MUST")
    [[ "$s" =~ (^| )(may|might|could|optional)( |$|[[:punct:]]) ]] && tags+=("MAY")
    [[ "$s" =~ (^| )(never|forbidden|disallowed|prohibited)( |$|[[:punct:]]) ]] && tags+=("NEVER")
    [[ "$s" =~ (^| )(always|every|all|each)( |$|[[:punct:]]) ]] && tags+=("UNIV")
    [[ "$s" =~ (^| )(some|few|several|exists)( |$|[[:punct:]]) ]] && tags+=("EXIST")
    [[ "$s" =~ (^| )(no|none|nothing)( |$|[[:punct:]]) ]] && tags+=("NEG")
    [[ "$s" =~ (^| )(not|isnt|aren\'t|wasn\'t|don\'t|doesn\'t|won\'t)( |$|[[:punct:]]) ]] && tags+=("NOT")
    printf '%s\n' "${tags[*]:-}"
}

# Modal contradiction: e.g. MUST in X conflicts with MAY in Y on same content,
# or UNIV+POSITIVE in X conflicts with NEG in Y.
cta_modal_conflict() {
    local tx="$1" ty="$2"
    if [[ "$tx" == *"MUST"* && "$ty" == *"NEVER"* ]] || [[ "$tx" == *"NEVER"* && "$ty" == *"MUST"* ]]; then
        printf 'MUST/NEVER'; return 0
    fi
    if [[ "$tx" == *"UNIV"* && "$ty" == *"NEG"* ]] || [[ "$tx" == *"NEG"* && "$ty" == *"UNIV"* ]]; then
        printf 'UNIV/NEG'; return 0
    fi
    return 1
}

# ---------- JSON output ----------
# Prefer jq if present; fall back to a minimal JSON emitter.
cta_have_jq() { command -v jq >/dev/null 2>&1; }

# Emit a JSON object from key=value pairs. Values that look like numbers,
# arrays (start with [), objects (start with {), or booleans are emitted raw;
# everything else is string-escaped.
# Usage: cta_json k1=v1 k2=v2 ...
cta_json() {
    if cta_have_jq; then
        local jq_args=() filter='{}'
        local i=0
        for kv in "$@"; do
            local key="${kv%%=*}"
            local val="${kv#*=}"
            if [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] \
                || [[ "$val" == "true" || "$val" == "false" || "$val" == "null" ]] \
                || [[ "$val" == \[* || "$val" == \{* ]]; then
                jq_args+=(--argjson "v$i" "$val")
                filter+=" | .${key} = \$v${i}"
            else
                jq_args+=(--arg "v$i" "$val")
                filter+=" | .${key} = \$v${i}"
            fi
            i=$((i+1))
        done
        jq -n "${jq_args[@]}" "$filter"
    else
        # Minimal fallback: assumes string values are already shell-safe.
        printf '{'
        local first=1
        for kv in "$@"; do
            local key="${kv%%=*}"
            local val="${kv#*=}"
            [[ $first -eq 0 ]] && printf ','
            first=0
            printf '"%s":' "$key"
            if [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] \
                || [[ "$val" == "true" || "$val" == "false" || "$val" == "null" ]] \
                || [[ "$val" == \[* || "$val" == \{* ]]; then
                printf '%s' "$val"
            else
                printf '"%s"' "${val//\"/\\\"}"
            fi
        done
        printf '}\n'
    fi
}

# ---------- vector parsing ----------
# Accept "1.0,2.0,3.5" or "[1.0, 2.0, 3.5]" -> emit one number per line.
cta_parse_vector() {
    printf '%s' "$1" \
        | sed -E 's/[][[:space:]]+//g' \
        | tr ',' '\n' \
        | sed '/^$/d'
}

# Vector arithmetic: euclidean distance between two comma-separated vectors.
cta_euclidean() {
    local a="$1" b="$2"
    paste <(cta_parse_vector "$a") <(cta_parse_vector "$b") \
        | awk '{ d = $1 - $2; sum += d*d } END { printf "%.6f", sqrt(sum) }'
}

# L2 norm of a single vector
cta_l2_norm() {
    cta_parse_vector "$1" | awk '{ sum += $1*$1 } END { printf "%.6f", sqrt(sum) }'
}

# Mean of a list of numbers (one per line on stdin)
cta_mean() {
    awk '{ s += $1; n++ } END { if (n>0) printf "%.6f", s/n; else print "0" }'
}

# Sample variance (n-1) of a list of numbers
cta_variance() {
    awk '{ a[NR] = $1; s += $1; n++ }
         END {
             if (n < 2) { print "0"; exit }
             mean = s/n
             for (i=1; i<=n; i++) ss += (a[i]-mean)^2
             printf "%.6f", ss/(n-1)
         }'
}

# Standard deviation
cta_stddev() {
    awk '{ a[NR] = $1; s += $1; n++ }
         END {
             if (n < 2) { print "0"; exit }
             mean = s/n
             for (i=1; i<=n; i++) ss += (a[i]-mean)^2
             printf "%.6f", sqrt(ss/(n-1))
         }'
}

# Percentile (linear interpolation) of values on stdin. Arg 1 = percentile (0-100).
# Uses external `sort -n` to avoid gawk-only asort().
cta_percentile() {
    local p="${1:-25}"
    sort -n | awk -v p="$p" '
        { a[NR] = $1; n++ }
        END {
            if (n == 0) { print "0"; exit }
            if (n == 1) { printf "%.6f\n", a[1]; exit }
            rank = (p/100) * (n - 1) + 1
            lo = int(rank); hi = lo + 1
            frac = rank - lo
            if (hi > n) hi = n
            printf "%.6f\n", a[lo] + frac*(a[hi] - a[lo])
        }'
}

# Linear regression slope (least squares) over a series y[1..n] with x = 1..n
cta_trend_slope() {
    awk '{ y[NR]=$1; n++ }
         END {
             if (n < 2) { print "0"; exit }
             for (i=1; i<=n; i++) { sx+=i; sy+=y[i]; sxy+=i*y[i]; sx2+=i*i }
             denom = n*sx2 - sx*sx
             if (denom == 0) { print "0"; exit }
             printf "%.6f", (n*sxy - sx*sy) / denom
         }'
}

# ---------- hashing ----------
# SHAKE256 with 512-bit (64-byte) output. NOTE: NIST FIPS 202 defines
# SHAKE128 and SHAKE256 as the only standard XOFs. "SHAKE512" is non-standard;
# we use SHAKE256 with xoflen=64 as the closest legitimate construction and
# label outputs accordingly.
cta_shake256_512() {
    openssl dgst -shake256 -xoflen 64 | awk '{print $NF}'
}

cta_sha3_512() {
    openssl dgst -sha3-512 | awk '{print $NF}'
}

# ---------- Rule 30 cellular automaton (PRNG/salt stream) ----------
# Emits a hex stream derived from a seed integer. Used by the ESL
# "Epoch Rule30 Salt Stream" (Seal of Inherited Provenance).
#
# Usage: cta_rule30 <seed_int> <output_bytes>
# Algorithm: 1D CA, rule 30, width = 257 bits (odd so center column is well-defined),
#            iterate N steps where N = output_bits, emit center column as bit stream,
#            pack bits into bytes, emit hex.
cta_rule30() {
    local seed="$1"
    local nbytes="${2:-32}"
    local nbits=$((nbytes * 8))
    awk -v seed="$seed" -v nbits="$nbits" '
        BEGIN {
            srand(seed)
            width = 257
            # initialize cells: deterministic seed-driven bits
            s = seed
            for (i = 0; i < width; i++) {
                # xorshift32-ish on s
                s = (s * 1103515245 + 12345) % 2147483648
                cells[i] = (s % 2)
            }
            # ensure non-trivial state
            cells[int(width/2)] = 1
            bitbuf = ""
            for (step = 0; step < nbits; step++) {
                bitbuf = bitbuf cells[int(width/2)]
                # rule 30: new = left XOR (center OR right)
                for (i = 0; i < width; i++) {
                    l = cells[(i - 1 + width) % width]
                    c = cells[i]
                    r = cells[(i + 1) % width]
                    new[i] = (l + (c==1 || r==1 ? 1 : 0)) % 2
                }
                for (i = 0; i < width; i++) cells[i] = new[i]
            }
            # pack bits into hex bytes
            for (b = 0; b < nbits; b += 8) {
                byte = 0
                for (k = 0; k < 8; k++) {
                    byte = byte * 2 + substr(bitbuf, b+k+1, 1) + 0
                }
                printf "%02x", byte
            }
            printf "\n"
        }'
}

# ---------- config loader (yaml-light) ----------
# We avoid yq dependency. Only used for simple key: value pairs in our config files.
cta_config_get() {
    local key="$1" file="${2:-$CTA_CONFIG}"
    [[ -f "$file" ]] || { printf ''; return; }
    awk -v k="$key" '
        $0 ~ "^[[:space:]]*"k":" {
            sub(/^[^:]*:[[:space:]]*/, "")
            sub(/[[:space:]]*#.*$/, "")
            print
            exit
        }' "$file"
}
