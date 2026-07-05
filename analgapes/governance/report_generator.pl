#!/usr/bin/env perl
# REPORT GENERATOR – Final human-readable VRP report
# SPDX-License-Identifier: GPL-3.0-or-later
use strict;
use warnings;
use POSIX qw(strftime);

my $workspace = $ARGV[0] // '/home/user/A51/avrs-cybernetic';
my $report    = "$workspace/results/final_report.txt";

open my $fh, '>', $report or die "write report: $!";

my $ts = strftime('%Y-%m-%dT%H:%M:%S%z', localtime);

print $fh <<"HDR";
══════════════════════════════════════════════════
  AVRS v3.0 Cybernetic – Vulnerability Report
  Authorization: Google Bug Hunters VRP
══════════════════════════════════════════════════

Timestamp : $ts
Workspace : $workspace

HDR

# Fusion scores
my $fusion = "$workspace/data/fusion/report.txt";
if (-f $fusion) {
    print $fh "── Anomaly Fusion Scores ─────────────────────\n";
    open my $ff, '<', $fusion or die;
    print $fh $_ while <$ff>;
    close $ff;
    print $fh "\n";
}

# Primitive
my $prim = "$workspace/data/memory/primitive.json";
if (-f $prim) {
    print $fh "── Identified Primitive ──────────────────────\n";
    open my $pf, '<', $prim or die;
    print $fh $_ while <$pf>;
    close $pf;
    print $fh "\n";
}

# Validation evidence
my $val = "$workspace/results/validation.log";
if (-f $val) {
    print $fh "── Sandbox Validation ────────────────────────\n";
    open my $vf, '<', $val or die;
    my ($crashes, $canary) = (0, 0);
    while (<$vf>) {
        $crashes++ if /SIGSEGV|SIGABRT/;
        $canary++  if /CANARY/;
    }
    close $vf;
    print $fh "  Crashes observed : $crashes\n";
    print $fh "  Write confirmed  : $canary\n\n";
}

# Canary evidence
my $can = "$workspace/results/canary_evidence.txt";
if (-f $can) {
    print $fh "── Canary Evidence ───────────────────────────\n";
    open my $cf, '<', $can or die;
    print $fh $_ while <$cf>;
    close $cf;
    print $fh "\n";
}

# the operator after-action
my $aa = "$workspace/kerebral/after_action_report.txt";
if (-f $aa) {
    print $fh "── Strategic Executive Assessment ───────────\n";
    open my $af, '<', $aa or die;
    print $fh $_ while <$af>;
    close $af;
    print $fh "\n";
}

# Provenance
my $prov = "$workspace/results/provenance_chain.txt";
if (-f $prov) {
    print $fh "── Provenance Chain ──────────────────────────\n";
    open my $rf, '<', $prov or die;
    print $fh $_ while <$rf>;
    close $rf;
}

print $fh <<"FTR";

══════════════════════════════════════════════════
  License: GNU GPL v3.0 or later
══════════════════════════════════════════════════
FTR

close $fh;
print "[Report] Written: $report\n";
