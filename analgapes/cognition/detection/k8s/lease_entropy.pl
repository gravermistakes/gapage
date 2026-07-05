#!/usr/bin/env perl
# lease_entropy.pl — Detect C2 channels in Kubernetes Lease updates
# Based on doc 4+5 insight: legitimate controllers vary only timestamps;
# C2 channels must vary payload fields, producing detectable per-field entropy.
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Input: JSON stream of Lease objects (e.g., from `kubectl get leases -o json --watch`)
# Output: per-namespace/per-lease entropy report; flags anomalous fields
use strict; use warnings;
use Getopt::Long;
use JSON::PP;

my %opt = (window => 50, threshold => 2.5);
GetOptions(\%opt, 'input=s', 'window=i', 'threshold=f', 'out=s')
    or die "Usage: $0 --input <leases.json> [--window N] [--threshold BITS]\n";

# History per lease: namespace/name -> { field_name -> [values...] }
my %history;
my %field_seen;

sub shannon {
    my @vals = @_;
    return 0 unless @vals;
    my %freq; $freq{$_}++ for @vals;
    my $n = scalar @vals;
    my $h = 0;
    for my $count (values %freq) {
        my $p = $count / $n;
        $h -= $p * log($p) / log(2);
    }
    return $h;
}

sub walk_fields {
    my ($prefix, $obj, $out) = @_;
    if (ref($obj) eq 'HASH') {
        for my $k (sort keys %$obj) {
            walk_fields("$prefix.$k", $obj->{$k}, $out);
        }
    } elsif (ref($obj) eq 'ARRAY') {
        for my $i (0..$#$obj) {
            walk_fields("$prefix\[$i\]", $obj->[$i], $out);
        }
    } else {
        $out->{$prefix} = defined($obj) ? "$obj" : '';
    }
}

# Fields we expect to vary legitimately - exempt from entropy alerting
my %expected_varying = map { $_ => 1 } qw(
    .metadata.resourceVersion
    .metadata.managedFields[0].time
    .spec.renewTime
    .spec.acquireTime
    .spec.holderIdentity
);

my $in_fh;
if ($opt{input} && $opt{input} ne '-') {
    open $in_fh, '<', $opt{input} or die "Cannot open $opt{input}: $!\n";
} else {
    $in_fh = \*STDIN;
}

my $out_fh;
if ($opt{out}) {
    open $out_fh, '>', $opt{out} or die;
} else {
    $out_fh = \*STDOUT;
}

print $out_fh "LEASE_ENTROPY(window=$opt{window},threshold=$opt{threshold} bits)\n";
print $out_fh "=" x 60 . "\n";

# Decode JSON - accept either one object per line or a single array/list
local $/;
my $raw = <$in_fh>;
my $data = eval { decode_json($raw) };
die "JSON parse failed: $@\n" if $@;

# Normalize to array of leases
my @leases;
if (ref($data) eq 'HASH' && $data->{items}) {
    @leases = @{$data->{items}};
} elsif (ref($data) eq 'ARRAY') {
    @leases = @$data;
} else {
    @leases = ($data);
}

# Build per-lease history
for my $lease (@leases) {
    my $ns = $lease->{metadata}{namespace} // 'default';
    my $name = $lease->{metadata}{name} // 'unknown';
    my $key = "$ns/$name";

    my %fields;
    walk_fields('', $lease, \%fields);

    for my $f (keys %fields) {
        push @{$history{$key}{$f}}, $fields{$f};
        $field_seen{$f}++;
    }
}

# Compute entropy per field per lease
my %alerts;
for my $lease_key (sort keys %history) {
    for my $field (sort keys %{$history{$lease_key}}) {
        next if $expected_varying{$field};
        my @vals = @{$history{$lease_key}{$field}};
        next if @vals < 2;  # Need updates to measure variance

        # Truncate to window
        @vals = @vals[-$opt{window} .. -1] if @vals > $opt{window};

        my $h = shannon(@vals);
        my $unique = scalar(keys %{{map { $_ => 1 } @vals}});

        if ($h >= $opt{threshold} && $unique > 1) {
            push @{$alerts{$lease_key}}, {
                field => $field,
                entropy => $h,
                unique_values => $unique,
                sample_count => scalar @vals,
            };
        }
    }
}

# Report
if (%alerts) {
    print $out_fh "\n*** ANOMALOUS LEASES ***\n";
    for my $lease (sort keys %alerts) {
        print $out_fh "\nLEASE: $lease\n";
        for my $a (@{$alerts{$lease}}) {
            printf $out_fh "  %-50s entropy=%.3f bits  unique=%d/%d\n",
                $a->{field}, $a->{entropy}, $a->{unique_values}, $a->{sample_count};
        }
        print $out_fh "  → Investigate: payload field entropy exceeds threshold.\n";
        print $out_fh "    Legitimate controllers vary only resourceVersion and timestamps.\n";
    }
} else {
    print $out_fh "\nNo anomalous lease patterns detected.\n";
}

printf $out_fh "\nSUMMARY: %d leases analyzed, %d flagged, %d distinct fields seen.\n",
    scalar(keys %history), scalar(keys %alerts), scalar(keys %field_seen);
close $out_fh if $opt{out};
