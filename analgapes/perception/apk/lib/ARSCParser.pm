#!/usr/bin/env perl
# ARSCParser.pm - GPL ARSC resource parser
package ARSCParser;
use strict; use warnings;
our $VERSION = '1.0.0';
use constant { RES_TABLE => 0x0001, RES_STRING_POOL => 0x0001, RES_TABLE_PACKAGE => 0x0200 };
sub new { bless {data=>$_[1], pos=>0, strings=>[], packages=>[]}, $_[0] }
sub parse {
    my $s = shift;
    my $type = $s->read_u16(); $s->read_u16(); my $size=$s->read_u32();
    my $pkg_cnt = $s->read_u32();
    # Parse string pool
    my $pool_type = $s->read_u16(); $s->read_u16();
    my $pool_size = $s->read_u32(); my $str_cnt = $s->read_u32();
    $s->read_u32(); my $flags = $s->read_u32();
    my $str_off = $s->read_u32(); $s->read_u32();
    my $pool_start = $s->{pos} - 20;
    my @offs = map { $s->read_u32() } 1..$str_cnt;
    for(@offs){ push @{$s->{strings}}, $s->read_str_at($pool_start+$str_off+$_, $flags&0x100) }
    # Skip to packages
    while($s->{pos} < length($s->{data})){
        last if $s->{pos}+8 > length($s->{data});
        my $t=$s->read_u16(); $s->read_u16(); my $sz=$s->read_u32();
        last if $sz==0; $s->{pos}+=$sz-8;
    }
    return {strings=>$s->{strings}, package_count=>$pkg_cnt};
}
sub read_str_at {
    my($s,$p,$u8)=@_; return "" if $p>=length($s->{data});
    my $l=$u8?unpack('C',substr($s->{data},$p++,1)):unpack('v',substr($s->{data},$p,2));
    $p+=2 unless $u8; return "" unless $l;
    $u8?substr($s->{data},$p,$l):join('',map{chr}unpack('v*',substr($s->{data},$p,$l*2)));
}
sub read_u32 { my $s=shift; my $v=unpack('V',substr($s->{data},$s->{pos},4)); $s->{pos}+=4; $v }
sub read_u16 { my $s=shift; my $v=unpack('v',substr($s->{data},$s->{pos},2)); $s->{pos}+=2; $v }
1;
