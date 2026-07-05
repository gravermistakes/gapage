#!/usr/bin/env perl
# SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
# analgapes :: perception/static/build_graph.pl
# Port of v2.3 build_graph.py. objdump -d <bin> → call graph JSON on stdout.
use strict; use warnings;
my $bin = shift // die "usage: build_graph.pl <binary>\n";
open(my $fh, "-|", "objdump", "-d", $bin) or die "objdump: $!";
my (%graph, $cur);
while (my $l = <$fh>) {
    if ($l =~ /<([^>]+)>:/)            { $cur = $1; $graph{$cur} //= {}; }
    if ($cur && $l =~ /callq?\s+<([^>+]+)/) { $graph{$cur}{$1} = 1; }
}
close $fh;
if (!%graph) { print STDERR "Warning: stripped binary — call graph limited.\n";
               print "{\"stripped\":[\"address_based_graph_not_available\"]}\n"; exit 0; }
my @parts;
for my $f (sort keys %graph) {
    my @callees = map { "\"$_\"" } sort keys %{$graph{$f}};
    push @parts, "\"$f\":[" . join(",", @callees) . "]";
}
print "{" . join(",", @parts) . "}\n";
print STDERR "Call graph built: " . scalar(keys %graph) . " functions\n";
