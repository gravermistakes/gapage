#!/usr/bin/env perl
# manifest-analyzer.pl - GPL manifest analyzer
use strict; use warnings;
use FindBin; use lib "$FindBin::Bin/../lib";
use BinaryXMLParser;
my $apk = shift or die "Usage: $0 <apk>\n";
system("unzip -p '$apk' AndroidManifest.xml > /tmp/manifest.xml 2>/dev/null");
open my $f, '<:raw', '/tmp/manifest.xml' or die "No manifest\n";
my $data = do{local $/; <$f>}; close $f;
my $p = BinaryXMLParser->new($data);
my $els = $p->parse();
my($pkg,$vn,$vc,@perms,@acts,@svcs);
for my $e (@$els){
    if($e->{name} eq 'manifest'){ 
        $pkg=$e->{attributes}{package}; $vn=$e->{attributes}{'android:versionName'};
        $vc=$e->{attributes}{'android:versionCode'}; 
    }
    push @perms,$e->{attributes}{'android:name'} if $e->{name} eq 'uses-permission';
    push @acts,$e->{attributes}{'android:name'} if $e->{name} eq 'activity';
    push @svcs,$e->{attributes}{'android:name'} if $e->{name} eq 'service';
}
print "Package: $pkg\n"; print "Version: $vn ($vc)\n";
print "Permissions: ",scalar(@perms),"\n";
print "Activities: ",scalar(@acts),"\n"; print "Services: ",scalar(@svcs),"\n";
