use strict;
use warnings;

use Test::More;

use_ok('Device::PiLite');

ok(my $p = Device::PiLite->new(), "new Device::PiLite");

my @tests = (
["ALL,%s", ['ON'], "ALL,ON"],
["SPEED%d",[ 100 ],"SPEED100"],
["F%s",[ '101010'], "F101010"],
["B%i,%i",[ 1, 1], "B1,1"],
["V%i,%i",[ 1, 1], "V1,1"],
["P%i,%i,%s",[ 1, 1, 'ON'],"P1,1,ON"],
["SCROLL%i",[ 14],"SCROLL14"],
["T%i,%i,%s",[ 1, 1, 'X'],"T1,1,X"],
);

foreach my $test ( @tests )
{
	ok(my $val = $p->_build_command($test->[0], @{$test->[1]}),"_build_command");
	like($val, qr/\r$/, "got a carriage return");
	like($val, qr/$test->[2]/, "got the correct text " . $test->[2]);
}

done_testing();
