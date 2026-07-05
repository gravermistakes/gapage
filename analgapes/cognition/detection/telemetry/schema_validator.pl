#!/usr/bin/env perl
# schema_validator.pl — OpenTelemetry schema validator with nonce enforcement
# Doc 5 design: collector injects nonces tied to its own trust domain.
# Validates incoming telemetry preserves nonce integrity; flags covert channels.
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Usage:
#   1. Run as collector preprocessor: inject nonce headers into expected fields
#   2. Run as validator: check incoming telemetry against expected nonce structure
use strict; use warnings;
use Getopt::Long;
use JSON::PP;
use Digest::SHA qw(hmac_sha256_hex);

my %opt = (mode => 'validate', key => '', interval => 60);
GetOptions(\%opt, 'mode=s', 'input=s', 'out=s', 'key=s', 'interval=i',
                  'field=s@', 'epoch=i')
    or die "Usage: $0 --mode inject|validate --key <hexkey> --field <fieldname>\n";

# Generate per-interval nonce from collector-side key
# This is the critical property: nonce never derivable from agent context
sub gen_nonce {
    my ($key, $epoch, $field) = @_;
    return substr(hmac_sha256_hex("$epoch:$field", $key), 0, 16);
}

my @fields = $opt{field} && @{$opt{field}} ? @{$opt{field}}
           : ('attributes.collector.nonce', 'attributes.trust.token');

die "--key required\n" unless $opt{key};

my $epoch = $opt{epoch} // (time() / $opt{interval});  # current interval epoch

my $in_fh;
if ($opt{input} && $opt{input} ne '-') {
    open $in_fh, '<', $opt{input} or die;
} else { $in_fh = \*STDIN; }

my $out_fh;
if ($opt{out}) { open $out_fh, '>', $opt{out} or die; } else { $out_fh = \*STDOUT; }

sub get_nested {
    my ($obj, $path) = @_;
    my @parts = split /\./, $path;
    my $node = $obj;
    for my $p (@parts) {
        return undef unless ref($node) eq 'HASH' && exists $node->{$p};
        $node = $node->{$p};
    }
    return $node;
}

sub set_nested {
    my ($obj, $path, $val) = @_;
    my @parts = split /\./, $path;
    my $last = pop @parts;
    my $node = $obj;
    for my $p (@parts) {
        $node->{$p} //= {};
        $node = $node->{$p};
    }
    $node->{$last} = $val;
}

local $/;
my $raw = <$in_fh>;
my $data = decode_json($raw);
my @items = ref($data) eq 'ARRAY' ? @$data : ($data);

if ($opt{mode} eq 'inject') {
    # Collector preprocessor mode: stamp nonces on outbound spans
    for my $item (@items) {
        for my $field (@fields) {
            my $nonce = gen_nonce($opt{key}, $epoch, $field);
            set_nested($item, $field, $nonce);
        }
    }
    print $out_fh encode_json(\@items);
    exit 0;
}

# Validation mode: check incoming spans
my @violations;
for my $i (0..$#items) {
    my $item = $items[$i];
    for my $field (@fields) {
        my $expected = gen_nonce($opt{key}, $epoch, $field);
        # Allow previous epoch for clock skew
        my $expected_prev = gen_nonce($opt{key}, $epoch - 1, $field);
        my $actual = get_nested($item, $field);

        if (!defined $actual) {
            push @violations, {
                item => $i, field => $field,
                kind => 'missing', expected => $expected, actual => '(none)'
            };
        } elsif ($actual ne $expected && $actual ne $expected_prev) {
            push @violations, {
                item => $i, field => $field,
                kind => 'mismatch', expected => $expected, actual => $actual
            };
        }
    }
}

print $out_fh "OTEL_SCHEMA_VALIDATOR(epoch=$epoch,interval=$opt{interval}s)\n";
print $out_fh "Fields enforced: " . join(", ", @fields) . "\n";
print $out_fh "=" x 60 . "\n";

if (@violations) {
    print $out_fh "\n*** SCHEMA VIOLATIONS ***\n";
    for my $v (@violations) {
        printf $out_fh "  item[%d] %s: %s\n", $v->{item}, $v->{field}, $v->{kind};
        printf $out_fh "    expected: %s\n", $v->{expected};
        printf $out_fh "    actual:   %s\n", $v->{actual};
    }
    print $out_fh "\n→ ALERT: telemetry pipeline shows nonce-integrity failures.\n";
    print $out_fh "  This is either: (a) schema drift, (b) covert channel attempt,\n";
    print $out_fh "  or (c) an agent that bypassed the collector. Investigate source.\n";
    exit 1;
} else {
    printf $out_fh "\nAll %d items pass nonce validation.\n", scalar @items;
    exit 0;
}
