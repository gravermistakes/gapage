#!/usr/bin/env perl
# security-auditor.pl - GPL security auditor
use strict; use warnings;
my $apk = shift or die "Usage: $0 <apk>\n";
my @crit; my @warn;
# Extract and scan
system("unzip -q '$apk' -d /tmp/apk_scan 2>/dev/null");
# Check manifest for debuggable
open my $mf, '-|', "unzip -p '$apk' AndroidManifest.xml 2>/dev/null" or die;
my $manifest = do{local $/; <$mf>}; close $mf;
push @crit, "Debuggable flag enabled" if $manifest =~ /debuggable.*true/;
push @warn, "Backup allowed" if $manifest =~ /allowBackup.*true/ || $manifest !~ /allowBackup/;
# Scan DEX for secrets
for my $dex (glob("/tmp/apk_scan/*.dex")){
    open my $d, '<:raw', $dex or next;
    my $data = do{local $/; <$d>}; close $d;
    push @crit, "Google API key found" if $data =~ /AIza[0-9A-Za-z\-_]{35}/;
    push @crit, "AWS key found" if $data =~ /AKIA[0-9A-Z]{16}/;
    push @warn, "Hardcoded password pattern" if $data =~ /password.*[=:].*["'][^"']{8,}["']/i;
    push @warn, "HTTP endpoint (not HTTPS)" if $data =~ /http:\/\/[a-z0-9\.\-]+/i;
}
system("rm -rf /tmp/apk_scan");
print "=== Security Audit ===\n";
print "CRITICAL (",scalar(@crit),"):\n"; print "  - $_\n" for @crit;
print "WARNINGS (",scalar(@warn),"):\n"; print "  - $_\n" for @warn;
print scalar(@crit)==0 && scalar(@warn)==0 ? "No issues found.\n" : "";
