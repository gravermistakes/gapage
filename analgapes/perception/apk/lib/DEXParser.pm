#!/usr/bin/env perl
# DEXParser.pm - GPL DEX bytecode parser
package DEXParser;
use strict; use warnings;
our $VERSION = '1.0.0';
sub new { bless {data=>$_[1], pos=>0, strings=>[], types=>[], methods=>[], classes=>[]}, $_[0] }
sub parse {
    my $s = shift;
    die "Not DEX" unless substr($s->{data},0,8) =~ /^dex\n\d{3}\0$/;
    $s->{pos} = 8;
    my %h; $h{checksum}=$s->read_u32(); $s->{pos}+=20; # skip sig
    $h{file_size}=$s->read_u32(); $h{header_size}=$s->read_u32();
    $s->{pos}+=4; # endian
    $s->{pos}+=8; # link
    $h{map_off}=$s->read_u32(); 
    my $str_cnt=$s->read_u32(); my $str_off=$s->read_u32();
    my $type_cnt=$s->read_u32(); my $type_off=$s->read_u32();
    my $proto_cnt=$s->read_u32(); my $proto_off=$s->read_u32();
    my $field_cnt=$s->read_u32(); my $field_off=$s->read_u32();
    my $meth_cnt=$s->read_u32(); my $meth_off=$s->read_u32();
    my $class_cnt=$s->read_u32(); my $class_off=$s->read_u32();
    # Parse strings
    $s->{pos} = $str_off;
    for(1..$str_cnt){ my $off=$s->read_u32(); push @{$s->{strings}}, $s->read_str_at($off) }
    # Parse types
    $s->{pos} = $type_off;
    for(1..$type_cnt){ push @{$s->{types}}, $s->get_string($s->read_u32()) }
    # Parse methods
    $s->{pos} = $meth_off;
    for(1..$meth_cnt){
        my $class=$s->read_u16(); my $proto=$s->read_u16();
        my $name=$s->read_u32();
        push @{$s->{methods}}, {class=>$s->{types}[$class], name=>$s->get_string($name)};
    }
    # Parse classes
    $s->{pos} = $class_off;
    for(1..$class_cnt){
        my $type=$s->read_u32(); $s->read_u32(); $s->read_u32(); $s->read_u32();
        $s->read_u32(); $s->read_u32(); $s->read_u32(); $s->read_u32();
        push @{$s->{classes}}, $s->{types}[$type];
    }
    return {header=>\%h, strings=>$s->{strings}, types=>$s->{types}, 
            methods=>$s->{methods}, classes=>$s->{classes},
            stats=>{str_cnt=>$str_cnt, type_cnt=>$type_cnt, meth_cnt=>$meth_cnt, class_cnt=>$class_cnt}};
}
sub read_str_at {
    my($s,$off)=@_; my $p=$s->{pos}; $s->{pos}=$off;
    my $len=$s->read_uleb128(); 
    my $str=substr($s->{data},$s->{pos},$len); $s->{pos}=$p; $str;
}
sub read_uleb128 {
    my $s=shift; my($v,$sh)=(0,0);
    while(1){ my $b=unpack('C',substr($s->{data},$s->{pos}++,1));
        $v|=($b&0x7f)<<$sh; last unless $b&0x80; $sh+=7; }
    $v;
}
sub read_u32 { my $s=shift; my $v=unpack('V',substr($s->{data},$s->{pos},4)); $s->{pos}+=4; $v }
sub read_u16 { my $s=shift; my $v=unpack('v',substr($s->{data},$s->{pos},2)); $s->{pos}+=2; $v }
sub get_string { $_[0]{strings}[$_[1]]||"" }
1;
