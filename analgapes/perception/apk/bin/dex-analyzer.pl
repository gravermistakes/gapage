#!/usr/bin/env perl
# dex-analyzer.pl - GPL DEX analyzer
use strict; use warnings;
use FindBin; use lib "$FindBin::Bin/../lib";
use DEXParser;
my $apk = shift or die "Usage: $0 <apk>\n";
system("unzip -p '$apk' classes.dex > /tmp/classes.dex 2>/dev/null");
open my $f, '<:raw', '/tmp/classes.dex' or die "No DEX\n";
my $data = do{local $/; <$f>}; close $f;
my $p = DEXParser->new($data);
my $r = $p->parse();
print "DEX Analysis:\n";
print "  Strings: $r->{stats}{str_cnt}\n";
print "  Types: $r->{stats}{type_cnt}\n";
print "  Methods: $r->{stats}{meth_cnt}\n";
print "  Classes: $r->{stats}{class_cnt}\n";
print "\nTop classes:\n";
for(0..9){ last unless $r->{classes}[$_]; print "  $r->{classes}[$_]\n"; }
