#!/usr/bin/perl
# AXML – Android Binary XML Decoder
# Parses APK AndroidManifest.xml (binary AXML format) to readable XML/JSON
# SPDX-License-Identifier: GPL-3.0-or-later
use strict; use warnings;
use JSON::PP;

my $file = $ARGV[0] or die "Usage: axml.pl <AndroidManifest.xml> [--json]\n";
my $json_mode = grep { $_ eq '--json' } @ARGV;

open(my $fh, '<:raw', $file) or die "Cannot open $file: $!\n";
my $data; { local $/; $data = <$fh>; } close $fh;

my $pos = 0;
sub u16 { my $v = unpack('v', substr($data, $pos, 2)); $pos += 2; $v }
sub u32 { my $v = unpack('V', substr($data, $pos, 4)); $pos += 4; $v }

# AXML magic
my $magic = u32();
die "Not AXML (magic=$magic)\n" unless $magic == 0x00080003;
my $file_size = u32();

# String pool
my $sp_type = u32(); # 0x001c0001
my $sp_size = u32();
my $str_count = u32();
my $style_count = u32();
my $sp_flags = u32();
my $str_start = u32();
my $style_start = u32();

# String offsets
my @str_offsets;
for (1..$str_count) { push @str_offsets, u32(); }
# Style offsets (skip)
for (1..$style_count) { u32(); }

# Read strings
my $str_data_start = $pos;
my @strings;
for my $i (0..$str_count-1) {
    my $spos = $str_data_start + $str_offsets[$i];
    if ($sp_flags & (1 << 8)) {
        # UTF-8
        my $len = ord(substr($data, $spos, 1)); $spos++;
        $len = ord(substr($data, $spos, 1)) if $len & 0x80; $spos++;
        push @strings, substr($data, $spos, $len);
    } else {
        # UTF-16LE
        my $charlen = unpack('v', substr($data, $spos, 2)); $spos += 2;
        if ($charlen & 0x8000) {
            $charlen = (($charlen & 0x7FFF) << 16) | unpack('v', substr($data, $spos, 2));
            $spos += 2;
        }
        my $raw = substr($data, $spos, $charlen * 2);
        my $str = '';
        for (my $j = 0; $j < length($raw); $j += 2) {
            my $c = unpack('v', substr($raw, $j, 2));
            $str .= ($c < 128) ? chr($c) : sprintf("\\u%04x", $c);
        }
        push @strings, $str;
    }
}

$pos = 8 + $sp_size;  # skip to after string pool

# Parse XML chunks
my @elements;
my @stack;
my $depth = 0;

while ($pos < length($data) - 8) {
    my $chunk_type = u16();
    my $header_size = u16();
    my $chunk_size = u32();
    
    if ($chunk_type == 0x0102) {
        # START_TAG
        my $line = u32(); my $comment = u32();
        my $ns = u32(); my $name_idx = u32();
        my $attr_start = u16(); my $attr_size = u16(); my $attr_count = u16();
        my $id_idx = u16(); my $class_idx = u16(); my $style_idx = u16();
        
        my $tag_name = ($name_idx < @strings) ? $strings[$name_idx] : "?$name_idx";
        
        my @attrs;
        for (1..$attr_count) {
            my $a_ns = u32(); my $a_name = u32(); my $a_raw = u32();
            my $a_type = u16(); u16(); # size, res0
            my $a_data = u32();
            
            my $attr_name = ($a_name < @strings) ? $strings[$a_name] : "?$a_name";
            my $attr_val;
            if ($a_raw != 0xFFFFFFFF && $a_raw < @strings) {
                $attr_val = $strings[$a_raw];
            } elsif (($a_type >> 8) == 0x10) {
                $attr_val = "$a_data";
            } elsif (($a_type >> 8) == 0x12) {
                $attr_val = $a_data ? "true" : "false";
            } elsif (($a_type >> 8) == 0x01 && $a_data < @strings) {
                $attr_val = '@' . $strings[$a_data];
            } else {
                $attr_val = sprintf("0x%08x", $a_data);
            }
            push @attrs, { name => $attr_name, value => $attr_val };
        }
        
        push @elements, { type => 'start', tag => $tag_name, attrs => \@attrs, depth => $depth };
        $depth++;
    }
    elsif ($chunk_type == 0x0103) {
        # END_TAG
        my $line = u32(); my $comment = u32();
        my $ns = u32(); my $name_idx = u32();
        $depth-- if $depth > 0;
        my $tag_name = ($name_idx < @strings) ? $strings[$name_idx] : "?$name_idx";
        push @elements, { type => 'end', tag => $tag_name, depth => $depth };
    }
    elsif ($chunk_type == 0x0100 || $chunk_type == 0x0101) {
        # NS_START or NS_END — skip body
        $pos += $chunk_size - 8 if $chunk_size > 8;
    }
    else {
        $pos += $chunk_size - 8 if $chunk_size > 8;
    }
}

if ($json_mode) {
    print encode_json({ strings => \@strings, elements => \@elements });
} else {
    for my $el (@elements) {
        my $indent = "  " x $el->{depth};
        if ($el->{type} eq 'start') {
            my $attrs = join(' ', map { "$_->{name}=\"$_->{value}\"" } @{$el->{attrs}});
            print "${indent}<$el->{tag}" . ($attrs ? " $attrs" : "") . ">\n";
        } elsif ($el->{type} eq 'end') {
            print "${indent}</$el->{tag}>\n";
        }
    }
}
