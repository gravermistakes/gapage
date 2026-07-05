#!/usr/bin/perl
# DEXDUMP – Dalvik Executable class/method/string extractor
# Reads DEX header, string table, type IDs, class defs
# SPDX-License-Identifier: GPL-3.0-or-later
use strict; use warnings;
use JSON::PP;

my $file = $ARGV[0] or die "Usage: dexdump.pl <classes.dex> [--json|--classes|--strings|--methods]\n";
my $mode = $ARGV[1] // '--classes';

open(my $fh, '<:raw', $file) or die "Cannot open $file: $!\n";
my $data; { local $/; $data = <$fh>; } close $fh;

# DEX header (40 bytes minimum)
my $magic = substr($data, 0, 4);
die "Not DEX (magic=$magic)\n" unless $magic eq "dex\n";
my $version = substr($data, 4, 4);

my $checksum      = unpack('V', substr($data, 8, 4));
my $file_size     = unpack('V', substr($data, 32, 4));
my $string_ids_sz = unpack('V', substr($data, 56, 4));
my $string_ids_off= unpack('V', substr($data, 60, 4));
my $type_ids_sz   = unpack('V', substr($data, 64, 4));
my $type_ids_off  = unpack('V', substr($data, 68, 4));
my $proto_ids_sz  = unpack('V', substr($data, 72, 4));
my $proto_ids_off = unpack('V', substr($data, 76, 4));
my $method_ids_sz = unpack('V', substr($data, 88, 4));
my $method_ids_off= unpack('V', substr($data, 92, 4));
my $class_defs_sz = unpack('V', substr($data, 96, 4));
my $class_defs_off= unpack('V', substr($data, 100, 4));

# Read string table
sub read_uleb128 {
    my ($data, $pos) = @_;
    my $result = 0; my $shift = 0;
    while (1) {
        my $byte = ord(substr($data, $$pos, 1)); $$pos++;
        $result |= ($byte & 0x7F) << $shift;
        last unless $byte & 0x80;
        $shift += 7;
    }
    return $result;
}

my @strings;
for my $i (0..$string_ids_sz-1) {
    my $str_data_off = unpack('V', substr($data, $string_ids_off + $i * 4, 4));
    my $p = $str_data_off;
    my $len = read_uleb128($data, \$p);
    my $str = substr($data, $p, $len);
    $str =~ s/[^\x20-\x7E]/?/g;  # sanitize non-printable
    push @strings, $str;
}

# Read type IDs (each is a string index)
my @types;
for my $i (0..$type_ids_sz-1) {
    my $str_idx = unpack('V', substr($data, $type_ids_off + $i * 4, 4));
    push @types, ($str_idx < @strings) ? $strings[$str_idx] : "?$str_idx";
}

# Read class defs
my @classes;
for my $i (0..$class_defs_sz-1) {
    my $off = $class_defs_off + $i * 32;
    my $class_idx = unpack('V', substr($data, $off, 4));
    my $access = unpack('V', substr($data, $off + 4, 4));
    my $super_idx = unpack('V', substr($data, $off + 8, 4));
    
    my $name = ($class_idx < @types) ? $types[$class_idx] : "?$class_idx";
    my $super = ($super_idx != 0xFFFFFFFF && $super_idx < @types) ? $types[$super_idx] : "";
    
    my $flags = [];
    push @$flags, 'public'    if $access & 0x0001;
    push @$flags, 'final'     if $access & 0x0010;
    push @$flags, 'interface' if $access & 0x0200;
    push @$flags, 'abstract'  if $access & 0x0400;
    push @$flags, 'synthetic' if $access & 0x1000;
    push @$flags, 'annotation' if $access & 0x2000;
    push @$flags, 'enum'      if $access & 0x4000;
    
    push @classes, { name => $name, super => $super, flags => $flags };
}

# Read method IDs
my @methods;
for my $i (0..$method_ids_sz-1) {
    my $off = $method_ids_off + $i * 8;
    my $class_idx = unpack('v', substr($data, $off, 2));
    my $proto_idx = unpack('v', substr($data, $off + 2, 2));
    my $name_idx  = unpack('V', substr($data, $off + 4, 4));
    
    my $class = ($class_idx < @types) ? $types[$class_idx] : "?";
    my $name = ($name_idx < @strings) ? $strings[$name_idx] : "?";
    push @methods, { class => $class, name => $name };
}

if ($mode eq '--json') {
    print encode_json({
        version => $version,
        strings_count => scalar @strings,
        types_count => scalar @types,
        classes_count => scalar @classes,
        methods_count => scalar @methods,
        classes => \@classes,
    });
} elsif ($mode eq '--strings') {
    print "$_\n" for @strings;
} elsif ($mode eq '--methods') {
    for my $m (@methods) {
        printf "%s->%s\n", $m->{class}, $m->{name};
    }
} else {
    # --classes (default)
    for my $c (@classes) {
        my $flags = join(' ', @{$c->{flags}});
        printf "%s %s", $flags, $c->{name};
        printf " extends %s", $c->{super} if $c->{super};
        print "\n";
    }
}
