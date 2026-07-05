#!/usr/bin/env perl
# apkre.pl - GPL APK reverse engineering master CLI
use strict; use warnings;
use FindBin; use lib "$FindBin::Bin/../lib";
my($cmd,$apk)=@ARGV; 
die "Usage: $0 {analyze|audit|unpack} <apk>\n" unless $cmd && $apk;
my $bin = "$FindBin::Bin";
if($cmd eq 'analyze'){
    print "=== APKre Analysis ===\n\n";
    print "--- Manifest ---\n"; system("$bin/manifest-analyzer.pl '$apk'");
    print "\n--- DEX ---\n"; system("$bin/dex-analyzer.pl '$apk'");
    print "\n--- Security ---\n"; system("$bin/security-auditor.pl '$apk'");
} elsif($cmd eq 'audit'){
    system("$bin/security-auditor.pl '$apk'");
} elsif($cmd eq 'unpack'){
    my $out = $ARGV[2] || 'apk_unpacked';
    system("$bin/apk-unpack.sh '$apk' '$out'");
} else { die "Unknown command: $cmd\n" }
