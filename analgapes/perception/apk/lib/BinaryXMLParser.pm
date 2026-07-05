#!/usr/bin/env perl
# BinaryXMLParser.pm - GPL Android binary XML parser
package BinaryXMLParser;
use strict; use warnings;
our $VERSION = '1.0.0';
use constant {
    CHUNK_AXML_FILE => 0x00080003, CHUNK_STRING_POOL => 0x001C0001,
    CHUNK_XML_RESOURCE => 0x00080180, CHUNK_XML_START_TAG => 0x00100102,
    CHUNK_XML_END_TAG => 0x00100103,
};
sub new { bless {data=>$_[1], pos=>0, strings=>[], elements=>[]}, $_[0] }
sub parse {
    my $s = shift;
    die "Invalid AXML" unless $s->read_u32() == CHUNK_AXML_FILE;
    $s->read_u32(); # file_size
    while ($s->{pos} < length($s->{data})) {
        my $t = $s->peek_u32() || last;
        if ($t == CHUNK_STRING_POOL) { $s->parse_string_pool() }
        elsif ($t == CHUNK_XML_RESOURCE) { $s->skip_chunk() }
        elsif ($t == CHUNK_XML_START_TAG) { $s->parse_start_element() }
        elsif ($t == CHUNK_XML_END_TAG) { $s->skip_chunk() }
        else { $s->skip_chunk() }
    }
    return $s->{elements};
}
sub parse_string_pool {
    my $s = shift; my $start = $s->{pos};
    $s->read_u32(); my $size = $s->read_u32();
    my $cnt = $s->read_u32(); $s->read_u32(); # style_count
    my $flags = $s->read_u32(); my $str_off = $s->read_u32(); $s->read_u32();
    my $utf8 = $flags & 0x100;
    my @off = map { $s->read_u32() } 1..$cnt;
    for (@off) { push @{$s->{strings}}, $s->read_string_at($start+$str_off+$_, $utf8) }
    $s->{pos} = $start + $size;
}
sub parse_start_element {
    my $s = shift; my $start = $s->{pos};
    $s->read_u32(); my $size = $s->read_u32();
    $s->read_u32(); $s->read_u32(); $s->read_u32(); # line, comment, ns
    my $name = $s->read_u32();
    $s->read_u16(); $s->read_u16(); my $acnt = $s->read_u16();
    $s->read_u16(); $s->read_u16(); $s->read_u16();
    my %e = (name => $s->get_string($name), attributes => {});
    for (1..$acnt) {
        $s->read_u32(); my $an = $s->read_u32(); my $av = $s->read_u32();
        $s->read_u16(); $s->read_u8(); $s->read_u8(); my $data = $s->read_u32();
        $e{attributes}{$s->get_string($an)} = $s->get_string($av) || $data;
    }
    push @{$s->{elements}}, \%e;
    $s->{pos} = $start + $size;
}
sub skip_chunk { my $s=shift; my $p=$s->{pos}; $s->read_u32(); $s->{pos}=$p+$s->read_u32() }
sub read_u32 { my $s=shift; my $v=unpack('V',substr($s->{data},$s->{pos},4)); $s->{pos}+=4; $v }
sub read_u16 { my $s=shift; my $v=unpack('v',substr($s->{data},$s->{pos},2)); $s->{pos}+=2; $v }
sub read_u8 { my $s=shift; my $v=unpack('C',substr($s->{data},$s->{pos},1)); $s->{pos}++; $v }
sub peek_u32 { unpack('V',substr($_[0]{data},$_[0]{pos},4)||"\0\0\0\0") }
sub read_string_at {
    my($s,$p,$u8)=@_; return "" if $p>=length($s->{data});
    my $l = $u8 ? do{my $x=unpack('C',substr($s->{data},$p++,1)); $x&0x80?((($x&0x7F)<<8)|unpack('C',substr($s->{data},$p++,1))):$x}
                : do{my $x=unpack('v',substr($s->{data},$p,2));$p+=2; $x&0x8000?((($x&0x7FFF)<<16)|unpack('v',substr($s->{data},$p,2))):$x};
    return "" unless $l;
    $u8 ? substr($s->{data},$p,$l) : join('',map{chr}unpack('v*',substr($s->{data},$p,$l*2)));
}
sub get_string { my($s,$i)=@_; !defined($i)||$i==0xFFFFFFFF?undef:$s->{strings}[$i]//"" }
1;
