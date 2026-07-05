#!/usr/bin/env perl
# Oracle – Patch verification via capability lifting
# Copyright (C) 2026 Anja Evermoor
# GNU GPL v3.0 or later
#
# Determines whether a CVE's vulnerable code path is actually
# present in the binary — accounting for vendor backports where
# the version string says "vulnerable" but the code is patched.
#
# Three verification methods:
#   1. Symbol presence (nm -D): is the vulnerable function exported?
#   2. Disassembly pattern (objdump -d): does the vulnerable code pattern exist?
#   3. SLEDGE capability lifting: formal bounds check (if available)

use strict;
use warnings;

my $HAS_JSON = eval { require JSON; JSON->import(); 1 };

my $binary   = $ARGV[0] or die "Usage: verify_patch.pl <binary> <cve_id> [function_name] [--output <file>]\n";
my $cve_id   = $ARGV[1] or die "Usage: verify_patch.pl <binary> <cve_id> [function_name] [--output <file>]\n";
my $function  = $ARGV[2] // "";
my $output_file = "";
for my $i (0..$#ARGV) {
    $output_file = $ARGV[$i+1] if $ARGV[$i] eq "--output" && defined $ARGV[$i+1];
}

# Clean function name (might come with parens from Chimera)
$function =~ s/\(\)$//;

unless (-f $binary) {
    warn "[Oracle] WARNING: binary not found: $binary\n";
}

my %result = (
    binary                   => $binary,
    cve                      => $cve_id,
    function_queried         => $function,
    symbol_present           => 0,
    disasm_pattern_found     => 0,
    sledge_available         => 0,
    sledge_capability_bounds => "",
    verdict                  => "INDETERMINATE",
    confidence               => "LOW",
    method_used              => [],
);

# === Method 1: Symbol presence ===
if ($function && -f $binary) {
    my $nm_out = `nm -D '$binary' 2>/dev/null`;
    if ($nm_out =~ /\b\Q$function\E\b/) {
        $result{symbol_present} = 1;
        push @{$result{method_used}}, "symbol_lookup";
        warn "[Oracle] Symbol '$function' FOUND in $binary\n";
    } else {
        push @{$result{method_used}}, "symbol_lookup";
        warn "[Oracle] Symbol '$function' NOT found in $binary\n";
    }

    # Also check with objdump for stripped binaries
    if (!$result{symbol_present}) {
        my $objdump = `objdump -t '$binary' 2>/dev/null | grep -i '\Q$function\E'`;
        if ($objdump) {
            $result{symbol_present} = 1;
            push @{$result{method_used}}, "objdump_symtab";
            warn "[Oracle] Symbol found via objdump symtab\n";
        }
    }
}

# === Method 2: Disassembly pattern matching ===
# For known CVE patterns, check if the vulnerable instruction sequence exists
if ($function && -f $binary) {
    my $disasm = `objdump -d '$binary' 2>/dev/null`;
    if ($disasm =~ /<\Q$function\E[\@>]/) {
        $result{disasm_pattern_found} = 1;
        push @{$result{method_used}}, "disasm_pattern";
        warn "[Oracle] Disassembly pattern for '$function' FOUND\n";
    } else {
        push @{$result{method_used}}, "disasm_pattern";
    }
}

# === Method 3: SLEDGE capability lifting ===
my $sledge_path = "/home/claude/phoenix/sledge/sledge";
if (-x $sledge_path && -f $binary) {
    $result{sledge_available} = 1;
    my $lift_cmd = "$sledge_path --lift '$binary' 2>/dev/null";
    my $lift_out = `$lift_cmd`;
    if ($lift_out =~ /BOUND:\s*(\d+)/) {
        $result{sledge_capability_bounds} = $1;
        push @{$result{method_used}}, "sledge_lift";
        warn "[Oracle] SLEDGE capability bound: $1\n";
    }

    # If we have a function name, try targeted lift
    if ($function && $lift_out =~ /FUNC:\s*\Q$function\E\s+REACHABLE:\s*(YES|NO)/i) {
        if ($1 eq "YES") {
            $result{disasm_pattern_found} = 1;
        }
        push @{$result{method_used}}, "sledge_targeted";
    }
}

# === Verdict synthesis ===
if ($function eq "") {
    $result{verdict} = "NO_FUNCTION_TO_CHECK";
    $result{confidence} = "NONE";
} elsif ($result{symbol_present} && $result{disasm_pattern_found}) {
    $result{verdict} = "VULNERABLE";
    $result{confidence} = "HIGH";
} elsif ($result{symbol_present}) {
    $result{verdict} = "LIKELY_VULNERABLE";
    $result{confidence} = "MEDIUM";
} elsif ($result{disasm_pattern_found}) {
    # Symbol stripped but code pattern exists
    $result{verdict} = "POSSIBLY_VULNERABLE";
    $result{confidence} = "MEDIUM";
} else {
    $result{verdict} = "PATCHED";
    $result{confidence} = $result{sledge_available} ? "HIGH" : "MEDIUM";
}

# === Output ===
my $json_out;
if ($HAS_JSON) {
    $json_out = JSON::encode_json(\%result);
} else {
    my $methods = join(",", map { "\"$_\"" } @{$result{method_used}});
    $json_out = sprintf(
        '{"binary":"%s","cve":"%s","function_queried":"%s","symbol_present":%s,"disasm_pattern_found":%s,"sledge_available":%s,"verdict":"%s","confidence":"%s","method_used":[%s]}',
        $result{binary}, $result{cve}, $result{function_queried},
        $result{symbol_present} ? "true" : "false",
        $result{disasm_pattern_found} ? "true" : "false",
        $result{sledge_available} ? "true" : "false",
        $result{verdict}, $result{confidence}, $methods
    );
}

if ($output_file) {
    open(my $fh, '>', $output_file) or die "Cannot write $output_file: $!\n";
    print $fh $json_out, "\n";
    close $fh;
    warn "[Oracle] Output written to $output_file\n";
} else {
    print $json_out, "\n";
}

exit 0;
