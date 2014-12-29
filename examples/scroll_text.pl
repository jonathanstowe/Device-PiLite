#!/usr/bin/perl 

use strict;
use warnings;

use Device::PiLite;

use Getopt::Long;

my $scroll;

my $o = GetOptions("scroll=i"	=>	\$scroll);

my $p = Device::PiLite->new();

if ( defined $scroll )
{
	$p->set_scroll($scroll);
}

my $text = shift;

$p->all_off();

$p->text($text);

$p->all_off();
