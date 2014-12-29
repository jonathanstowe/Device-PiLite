
use strict;
use warnings;

use Test::More;

use_ok("Device::PiLite");

ok(my $p = Device::PiLite->new(), "get new object");

is($p->columns(), 14, "default columns ok");
is($p->rows(), 9, "default rows ok");
is($p->_scroll_rate(), 80, "default scroll rate");
is($p->serial_device(), '/dev/ttyAMA0', "default serial device");
isa_ok($p->device_serialport(), 'Device::SerialPort', 'device_serialport');
is($p->device_serialport()->baudrate(), 9600, "baud rate");
is($p->cmd_prefix(), '$$$', "command prefix");

foreach my $col ( 1 .. $p->columns() )
{
	ok($p->valid_column($col), "$col is a valid column");
	ok(!$p->valid_column($col * -1), ($col * -1) . " isn't a valid column"); 
}

foreach my $row ( 1 .. $p->rows() )
{
	ok($p->valid_row($row), "$row is a valid row");
	ok(!$p->valid_row($row * -1), ($row * -1) . " isn't a valid row"); 
}

foreach my $val ( 1 .. 10 )
{
	ok($p->valid_axis($val, $val + 1 ), "$val is valid with bound of " . ($val + 1 ));
	ok(!$p->valid_axis($val + 1, $val), ($val + 1 ) . " isn't valid with $val");
	ok(!$p->valid_axis(0, $val), "0 is never valid");
}

done_testing();
