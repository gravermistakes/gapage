# cta-v1 :: scripts/lib/transforms.sh
# Pluggable transformation engine for state vectors.
# Sourced by invariant_detect.sh and gonzo_check.sh.
#
# DSL (one op per call):
#   identity                  no-op
#   negate:i / mirror:i       flip sign of dimension i (0-indexed)
#   scale:i:k                 multiply dim i by k
#   shift:i:k                 add k to dim i
#   swap:i:j                  swap dims i and j
#   permute:p0,p1,...         reorder dims to specified permutation
#   rotate:i:j:theta          rotate dims i,j by theta radians
#   noise:sigma               add Gaussian noise (sigma) to every dim
#   scale_all:k               multiply every dim by k
#   shift_all:k               add k to every dim
#
# License: ESL-ANCSA-MRA-IndiModSHA v1.0

[[ -n "${__CTA_TRANSFORMS_LOADED:-}" ]] && return 0
__CTA_TRANSFORMS_LOADED=1

# Apply a single transform op to a comma-separated vector.
# Echoes the transformed vector.
cta_apply_transform() {
    local op="$1" vec="$2" seed="${CTA_SEED:-1}"
    local kind="${op%%:*}"
    local args=""
    [[ "$op" == *":"* ]] && args="${op#*:}"
    case "$kind" in
        identity)
            printf '%s' "$vec"
            ;;
        negate|mirror)
            awk -v vec="$vec" -v i="$args" '
                BEGIN {
                    n = split(vec, a, /,/)
                    for (k=1;k<=n;k++) printf "%s%g", (k>1?",":""), ((k-1)==i ? -a[k] : a[k])
                }'
            ;;
        scale)
            local i="${args%%:*}"; local k="${args#*:}"
            awk -v vec="$vec" -v idx="$i" -v factor="$k" '
                BEGIN {
                    n = split(vec, a, /,/)
                    for (kk=1;kk<=n;kk++) printf "%s%g", (kk>1?",":""), ((kk-1)==idx ? a[kk]*factor : a[kk])
                }'
            ;;
        shift)
            local i="${args%%:*}"; local k="${args#*:}"
            awk -v vec="$vec" -v idx="$i" -v inc="$k" '
                BEGIN {
                    n = split(vec, a, /,/)
                    for (kk=1;kk<=n;kk++) printf "%s%g", (kk>1?",":""), ((kk-1)==idx ? a[kk]+inc : a[kk])
                }'
            ;;
        swap)
            local i="${args%%:*}"; local j="${args#*:}"
            awk -v vec="$vec" -v ii="$i" -v jj="$j" '
                BEGIN {
                    n = split(vec, a, /,/)
                    ii++; jj++
                    tmp = a[ii]; a[ii] = a[jj]; a[jj] = tmp
                    for (kk=1;kk<=n;kk++) printf "%s%s", (kk>1?",":""), a[kk]
                }'
            ;;
        permute)
            awk -v vec="$vec" -v perm="$args" '
                BEGIN {
                    n = split(vec, a, /,/)
                    np = split(perm, p, /,/)
                    if (np != n) { print vec; exit }
                    for (kk=1;kk<=np;kk++) printf "%s%s", (kk>1?",":""), a[p[kk]+1]
                }'
            ;;
        rotate)
            local i="${args%%:*}"; local rest="${args#*:}"
            local j="${rest%%:*}"; local theta="${rest#*:}"
            awk -v vec="$vec" -v ii="$i" -v jj="$j" -v th="$theta" '
                BEGIN {
                    n = split(vec, a, /,/)
                    ii++; jj++
                    c = cos(th); s = sin(th)
                    xi = a[ii]; xj = a[jj]
                    a[ii] = xi*c - xj*s
                    a[jj] = xi*s + xj*c
                    for (kk=1;kk<=n;kk++) printf "%s%g", (kk>1?",":""), a[kk]
                }'
            ;;
        noise)
            awk -v vec="$vec" -v sig="$args" -v seed="$seed" '
                BEGIN {
                    srand(seed)
                    n = split(vec, a, /,/)
                    for (kk=1;kk<=n;kk++) {
                        u1 = rand(); u2 = rand()
                        if (u1 < 1e-10) u1 = 1e-10
                        z = sqrt(-2*log(u1)) * cos(6.2831853*u2)
                        printf "%s%g", (kk>1?",":""), a[kk] + sig*z
                    }
                }'
            ;;
        scale_all)
            awk -v vec="$vec" -v factor="$args" '
                BEGIN {
                    n = split(vec, a, /,/)
                    for (kk=1;kk<=n;kk++) printf "%s%g", (kk>1?",":""), a[kk]*factor
                }'
            ;;
        shift_all)
            awk -v vec="$vec" -v inc="$args" '
                BEGIN {
                    n = split(vec, a, /,/)
                    for (kk=1;kk<=n;kk++) printf "%s%g", (kk>1?",":""), a[kk]+inc
                }'
            ;;
        *)
            # Unknown transform: warn to stderr, return unchanged
            printf '[cta:warn] unknown transform: %s\n' "$kind" >&2
            printf '%s' "$vec"
            ;;
    esac
}
