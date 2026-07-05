#!/usr/bin/env perl
# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: perception/dynamic/parse_gdb_mi.pl
# Port of v2.3 parse_gdb_mi.py — extracts crash primitives from GDB/MI logs.
use strict; use warnings;
my $log = do { local $/; <STDIN> };
my %r = (primitive_type=>"unknown", faulting_ip=>undef, registers=>{}, crash_confidence=>0.0);
if ($log =~ /\*stopped,reason="signal-received".*?frame=\{addr="0x([0-9a-f]+)"/s) {
    $r{faulting_ip} = hex($1);
}
while ($log =~ /~"([a-z]+[0-9]*)\s+0x([0-9a-f]+)"/g) {
    $r{registers}{uc $1} = hex($2);
}
# Heuristic: controlled IP (0x41414141 pattern) ⇒ high crash confidence
if (defined $r{faulting_ip} && ($r{faulting_ip} & 0xffffffff) == 0x41414141) {
    $r{primitive_type} = "controlled_eip"; $r{crash_confidence} = 0.9;
}
# Emit compact JSON (no external deps)
my @regs = map { "\"$_\":$r{registers}{$_}" } sort keys %{$r{registers}};
my $ip = defined $r{faulting_ip} ? $r{faulting_ip} : "null";
printf '{"primitive_type":"%s","faulting_ip":%s,"crash_confidence":%.1f,"registers":{%s}}'."\n",
    $r{primitive_type}, $ip, $r{crash_confidence}, join(",",@regs);
