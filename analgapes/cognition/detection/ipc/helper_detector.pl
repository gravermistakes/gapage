#!/usr/bin/env perl
# helper_detector.pl — Detect ephemeral helper processes from bpftrace output
# Reads shmget_probe.bt output, correlates execve→shmget→exit chains,
# flags short-lived processes that touch shared memory (doc 5 pattern).
# Also enumerates predictable IPC key derivations from container identity.
# SPDX-License-Identifier: GPL-3.0-or-later
use strict; use warnings;
use Getopt::Long;

my %opt = (max_lifetime_ms => 5000, identity_seeds => '');
GetOptions(\%opt, 'input=s', 'out=s', 'max_lifetime_ms=i', 'identity_seeds=s')
    or die "Usage: $0 --input shmget.log [--max_lifetime_ms 5000] [--identity_seeds 'pod1,node2']\n";

my $in_fh;
if ($opt{input} && $opt{input} ne '-') {
    open $in_fh, '<', $opt{input} or die;
} else { $in_fh = \*STDIN; }

my $out_fh;
if ($opt{out}) { open $out_fh, '>', $opt{out} or die; } else { $out_fh = \*STDOUT; }

# Predictable IPC key space from container identity
# Doc 5: "defender can enumerate plausible environmental constants"
my @seeds = $opt{identity_seeds} ? split(/,/, $opt{identity_seeds}) : ();
my %suspect_keys;
for my $seed (@seeds) {
    # Common derivations: ftok-style, simple hashes, IPC_PRIVATE collisions
    my $simple = 0; $simple += ord($_) for split //, $seed;
    $suspect_keys{$simple} = "ord-sum($seed)";
    $suspect_keys{hex(substr(sprintf("%x", unpack("%32W*", $seed)), 0, 8))} = "checksum($seed)";
    # ftok proj_id range
    for my $proj (0..63) {
        my $k = (($simple & 0xFF) << 24) | $proj;
        $suspect_keys{$k} = "ftok-like($seed,$proj)" if $proj < 4;
    }
}

# Parse events
my %proc;  # pid -> { start, exec, shmget_keys, shmat_ids, comm, ppid }
my @memfd_events;
my @ptrace_events;

while (my $line = <$in_fh>) {
    chomp $line;
    next if $line =~ /^#/ || !$line;
    my @f = split /\s+/, $line, 9;
    next if @f < 8;
    my ($kind, $ts, $pid, $ppid, $uid, $comm, $arg1, $arg2, $arg3) = @f;

    $proc{$pid} //= { ppid => $ppid, uid => $uid, comm => $comm };

    if ($kind eq 'EXECVE') {
        $proc{$pid}{exec_ts} //= $ts;
        $proc{$pid}{exec_path} = $arg1;
    } elsif ($kind eq 'SHMGET') {
        my $key = hex($arg1) // 0;
        push @{$proc{$pid}{shmget}}, { ts => $ts, key => $key, size => $arg2 };
    } elsif ($kind eq 'SHMAT') {
        push @{$proc{$pid}{shmat}}, { ts => $ts, info => $arg1 };
    } elsif ($kind eq 'EXIT') {
        $proc{$pid}{exit_ts} = $ts;
    } elsif ($kind eq 'MEMFD_CREATE') {
        push @memfd_events, { ts => $ts, pid => $pid, comm => $comm, name => $arg1 };
    } elsif ($kind eq 'PTRACE_POKE') {
        push @ptrace_events, { ts => $ts, pid => $pid, comm => $comm, target => $arg2 };
    }
}
close $in_fh;

# Classify
my (@ephemeral_with_shm, @key_collisions, @suspicious_memfd, @suspicious_ptrace);

for my $pid (keys %proc) {
    my $p = $proc{$pid};
    next unless $p->{shmget} || $p->{shmat};

    # Lifetime check
    my $lifetime_ns;
    if ($p->{exec_ts} && $p->{exit_ts}) {
        $lifetime_ns = $p->{exit_ts} - $p->{exec_ts};
        my $lifetime_ms = $lifetime_ns / 1_000_000;

        if ($lifetime_ms < $opt{max_lifetime_ms}) {
            push @ephemeral_with_shm, {
                pid => $pid, comm => $p->{comm}, ppid => $p->{ppid},
                lifetime_ms => $lifetime_ms,
                shmget_count => scalar @{$p->{shmget} // []},
                shmat_count => scalar @{$p->{shmat} // []},
                exec_path => $p->{exec_path} // 'unknown',
            };
        }
    }

    # IPC key collision with predicted keys
    for my $g (@{$p->{shmget} // []}) {
        if (exists $suspect_keys{$g->{key}}) {
            push @key_collisions, {
                pid => $pid, comm => $p->{comm},
                key => sprintf("0x%x", $g->{key}),
                derivation => $suspect_keys{$g->{key}},
            };
        }
    }
}

# memfd from non-container-runtime processes is doc 3's fileless technique
for my $m (@memfd_events) {
    next if $m->{comm} =~ /^(systemd|containerd|runc|dockerd|kubelet)/;
    push @suspicious_memfd, $m;
}

# ptrace POKE is reflective injection
for my $p (@ptrace_events) {
    next if $p->{comm} =~ /^(gdb|strace|ltrace)/;
    push @suspicious_ptrace, $p;
}

# Report
print $out_fh "HELPER_DETECTOR(max_lifetime=$opt{max_lifetime_ms}ms)\n";
print $out_fh "=" x 60 . "\n";

if (@ephemeral_with_shm) {
    print $out_fh "\n*** EPHEMERAL PROCESSES WITH SHARED MEMORY ACCESS ***\n";
    for my $e (sort { $a->{lifetime_ms} <=> $b->{lifetime_ms} } @ephemeral_with_shm) {
        printf $out_fh "  pid=%d (%s) ppid=%d lifetime=%.2fms\n",
            $e->{pid}, $e->{comm}, $e->{ppid}, $e->{lifetime_ms};
        printf $out_fh "    exec: %s\n", $e->{exec_path};
        printf $out_fh "    shmget=%d shmat=%d\n", $e->{shmget_count}, $e->{shmat_count};
    }
}

if (@key_collisions) {
    print $out_fh "\n*** PREDICTABLE IPC KEY COLLISIONS ***\n";
    for my $k (@key_collisions) {
        printf $out_fh "  pid=%d (%s) key=%s matches: %s\n",
            $k->{pid}, $k->{comm}, $k->{key}, $k->{derivation};
    }
}

if (@suspicious_memfd) {
    print $out_fh "\n*** memfd_create FROM UNEXPECTED PROCESSES ***\n";
    for my $m (@suspicious_memfd) {
        printf $out_fh "  pid=%d (%s) name=%s\n", $m->{pid}, $m->{comm}, $m->{name};
    }
}

if (@suspicious_ptrace) {
    print $out_fh "\n*** PTRACE_POKE FROM UNEXPECTED PROCESSES ***\n";
    print $out_fh "  (potential reflective ELF injection)\n";
    for my $p (@suspicious_ptrace) {
        printf $out_fh "  pid=%d (%s) target_pid=%s\n",
            $p->{pid}, $p->{comm}, $p->{target};
    }
}

printf $out_fh "\nSUMMARY: %d ephemeral+shm, %d key-collisions, %d suspicious memfd, %d suspicious ptrace\n",
    scalar @ephemeral_with_shm, scalar @key_collisions,
    scalar @suspicious_memfd, scalar @suspicious_ptrace;
close $out_fh if $opt{out};
