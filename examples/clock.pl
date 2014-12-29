#!/usr/bin/perl 

use strict;
use warnings;

use Device::PiLite;

my $p = Device::PiLite->new();

$p->set_scroll(10);

$p->all_off();

while (1 )
{
	my $text = localtime();
	$p->text($text);
	sleep 1;
}

$p->all_off();
