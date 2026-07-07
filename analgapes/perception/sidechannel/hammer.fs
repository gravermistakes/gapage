\ HAMMER – BPU State Probe (Spectre Primitive)
\ SPDX-License-Identifier: GPL-3.0-or-later
\ hey wait a second this doesnt do shit does it

code rdtsc ( -- lo hi )
    rdtsc
    mov tos, eax
    push tos
    mov tos, edx
next end-code

: tsc-lo ( -- u ) rdtsc drop ;

: mfence ( -- ) [ $0F c, $AE c, $F0 c, ] ;

: measure-ns ( addr -- ns )
    mfence tsc-lo >r
    @ drop
    mfence tsc-lo r> - ;

: cached? ( addr -- flag )
    measure-ns 80 < ;

: probe-range ( addr len -- )
    cr ." BPU/Cache Probe:" cr
    over + swap
    ?do
        i ." addr=0x" i hex u. ."  "
        i cached? if ." HIT" else ." MISS" then cr
    cache-line-size +loop ;

: cache-line-size 64 ;

: self-test ( -- )
    cr ." HAMMER self-test" cr
    here 256 probe-range ;

self-test
bye
