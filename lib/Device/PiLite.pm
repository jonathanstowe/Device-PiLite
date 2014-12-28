package Device::PiLite;

use strict;
use warnings;

use Moose;

use Carp qw(croak);
use Scalar::Util qw(looks_like_number);


=head1 NAME

Device::PiLite - Interface to Ciseco Pi-Lite for Raspberry Pi

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS



    use Device::PiLite;

    my $pilite = Device::PiLite->new();
    ...



=cut

=head2 DESCRIPTION

=head2 METHODS

=cut

=over 4

=item serial_device

This is the name of the serial device to be used.

The default is "/dev/ttyAMA0".  If it is to be
set to another value this should be provided to the
constructor.

=cut

has serial_device	=>	(
							is	=>	'rw',
							isa	=>	'Str',
							default	=>	'/dev/ttyAMA0',
						);

=item device_serialport

This is the L<Device::SerialPort> that will be used to perform the 
actual communication with the Pi-Lite, configured as appropriate.

This delegates a number of methods and probably doesn't need to be
used directly.

=cut

has device_serialport	=>	(
								is	=>	'rw',
								isa =>	'Device::SerialPort',
								lazy	=>	1,
								builder	=>	'_get_device_serialport',
								handles	=>	{
									serial_write	=>	'write',
									serial_read		=>	'read',
									serial_input	=>	'input',
									serial_look		=>	'lookfor',
									write_done		=>  'write_done',
									lastlook		=>  'lastlook',
								},
							);

sub _get_device_serialport
{
	my ( $self ) = @_;
	
	require Device::SerialPort;

	my $dev = Device::SerialPort->new($self->serial_device());
	$dev->baudrate(9600);
	$dev->databits(8);
	$dev->parity("none");
	$dev->stopbits(1);
	$dev->datatype('raw');
	$dev->write_settings();
	$dev->are_match('-re', "\r\n");

	return $dev;

}

=item all_on

Turns all the LEDs on.

=cut

sub all_on
{
	my ( $self ) = @_;
	return $self->_on_off(1);
}

=item all_off

Turns all the LEDs off.

=cut

sub all_off
{
	my ( $self ) = @_;
	return $self->_on_off(0);
}

=item _on_off

Turns the pixels on or off depending on the boolean supplied.

=cut

sub _on_off
{
	my ( $self, $switch ) = @_;

	my $state = 'OFF';

	if ( $switch )
	{
		$state = 'ON';
	}
	return $self->send_command("ALL,%s", $state);
}

=item set_scroll

This sets the scroll delay in milliseconds per pixel.  The default is
80

=cut

sub set_scroll
{
	my ( $self, $rate ) = @_;
	if ( defined $rate )
	{
		$self->send_command("SPEED%d", $rate );
		$self->_scroll_rate($rate);
	}
}

has _scroll_rate	=>	(
							is	=>	'rw',
							isa	=>	'Int',
							default	=> 80,
						);


=item text

This writes the provided test to the Pi-Lite.  Scrolling as necessary
at the configured rate.

=cut

sub text
{
	my ( $self, $text ) = @_;

	my $rc;

	if ( $text )
	{
		$rc = $self->serial_write( $text . "\r");
	}

	return $rc;
}

=item frame_buffer

This writes every pixel in the Pi-Lite in one go, the argument is a
126 character string where each character is a 1 or 0 that indicates
the state of a pixel.

=cut

sub frame_buffer
{
	my ( $self, $frame ) = @_;

	my $rc;

	if ( defined $frame )
	{
		$rc = $self->send_command("F%s", $frame);
	}
	return $rc;
}

=item bargraph

The bargraph comprises 14 columns with values expressed as 0-100% (the
resolution is only 9 rows however,) The takes the column number (1-14)
and the value as arguments and sets the appropriate column.

=cut

sub bargraph
{
	my ( $self, $column, $value ) = @_;

	my $rc;

	if ( defined $value )
	{
		if ( $self->valid_column($column) )
		{
			$rc = $self->send_command("B%i,%i", $column, $value);
		}
	}

	return $rc;
}

=item vu_meter

This sets one channel of the "vu meter" which is a horizontal two bar
graph, with values expressed 1-100%.  The arguments are the channel number
1 or 2 and the value.

=cut

sub vu_meter
{
	my ( $self, $channel, $value ) = @_;

	my $rc;

	if ( defined $value )
	{
		if ( $self->valid_axis($channel,2))
		{
			$rc = $self->send_command("V%i,%i", $channel, $value);
		}
	}

	return $rc;
}

=item pixel_on

Turns the pixel specified by $column, $row on.

=cut

sub pixel_on
{
	my ( $self, $column, $row ) = @_;

	return $self->pixel_action(1, $column, $row);
}

=item pixel_off

Turns the pixel specified by $column, $row off.

=cut

sub pixel_off
{
	my ( $self, $column, $row ) = @_;

	return $self->pixel_action(0, $column, $row);
}

=item pixel_toggle

Toggles the pixel specified by $column, $row .

=cut

sub pixel_toggle
{
	my ( $self, $column, $row ) = @_;

	return $self->pixel_action(2, $column, $row);
}

=item pixel_action

This performs the specified action 'ON' (1), 'OFF' (0), 'TOGGLE' (2)
on the pixel specified by column and row.  This is used by C<pixel_on>,
C<pixel_off> and C<pixel_toggle> internally but may be useful if the
state is to be computed.

=cut

sub pixel_action
{
	my ( $self, $action, $column, $row ) = @_;

	my $rc;
	if (defined(my $verb = $self->_get_action($action)))
	{
		if ( $self->valid_column($column) && $self->valid_row($row) )
		{
			$rc = $self->send_command("P%i,%i,%s", $column, $row, $verb);
		}
	}
	return $rc;
}


sub _get_action
{
	my ( $self, $action ) = @_;

	my $rc;
	if ( defined $action )
	{
		$rc = $self->_actions()->[$action];
	}
	return $rc;

	
}

has _actions	=>	(
						is	=> 'ro',
						isa	=> 'ArrayRef',
						default	=> sub { [qw(OFF ON TOGGLE)] },
					);


=item scroll

This scrolls by the number of  columns left or right, a negative
value will shift to the right, positive shift to the left.

Once a pixel is off the display it won't come back when you scroll
it back as there is no buffer.


=cut

sub scroll
{
	my ( $self, $cols ) = @_;

	my $rc;
	if (looks_like_number($cols) && $self->valid_column(abs($cols)))
	{
		$rc = $self->send_command("SCROLL%i", $cols);
	}
	return $rc;
}

=item character

This displays the specified single character at $column, $row.

If the character would be partially off the screen it won't be displayed.

=cut

sub character
{
	my ( $self, $column, $row, $char ) = @_;

	my $rc;
	if (defined $char && length $char )
	{
		if ( $self->valid_column($column) && $self->valid_row($row))
		{
			$rc = $self->send_command("T%i,%i,%s", $column, $row, $char);
		}
	}
	return $rc;
}


=item columns

This is the number of columns on the Pi-Lite.  This is almost
certainly 14.

=cut 

has columns	=> (
					is	=>	'rw',
					isa	=>	'Int',
					default	=>	14,
				);

=item valid_column

Returns a boolean to indicate whether it is an integer between 1 and
C<columns>.

=cut

sub valid_column
{
	my ( $self, $column ) = @_;

	my $rc = $self->valid_axis($column, $self->columns());
	return $rc ;
}

=item rows

This is the number of rows on the Pi-Lite.  This is almost
certainly 9.

=cut 

has rows	=> (
					is	=>	'rw',
					isa	=>	'Int',
					default	=>	9,
				);

=item valid_row

Returns a boolean to indicate whether it is an integer between 1 and
C<rows>.

=cut

sub valid_row
{
	my ( $self, $row ) = @_;

	my $rc = $self->valid_axis($row, $self->rows());
	return $rc ;
}

=item valid_axis

Return a boolean to indicate $value is greater ot equal to 1
and smaller or equal to $bound.

=cut

sub valid_axis
{
	my ( $self, $value, $bound ) = @_;

	my $rc = 0;
	if ( looks_like_number($value) && looks_like_number($bound))
	{
		if ($value >= 1 && $value <= $bound)
		{
			$rc = 1;
		}
	}
	return $rc ;
}

=item cmd_prefix

A Pi-Lite serial command sequenced is introduced by sending '$$$'.

=cut

has cmd_prefix	=>	(
						is	=>	'rw',
						isa	=>	'Str',
						default	=>	'$$$',
					);

=item send_prefix

Write the prefix to the device. And wait for the response 'OK'.

It will return a boolean value to indicate the success or
otherwise of the write.

=cut

sub send_prefix
{
	my ( $self ) = @_;

	my $rc = 0;
	my $count = $self->serial_write($self->cmd_prefix());
	$self->write_done(1);

	if ( $count == length($self->cmd_prefix()))
	{
		my  $string  = "";
		while ( !$string )
		{
			if (!defined($string = $self->serial_look() ))
			{
				croak "Read abort without input\n";
			}
		}
		$rc = 1;
	}

	return $rc;
}

=item send_command

This sends a command to the Pi-Lite, sending the command prefix and the
command constructed by $format and @arguments which are dealt with by
C<_build_command>.

=cut

sub send_command
{
	my ( $self, $format, @arguments ) = @_;

	my $rc;
	if ( my $cmd_str = $self->_build_command($format, @arguments ))
	{
		if ( $self->send_prefix() )
		{
			$rc = $self->serial_write($cmd_str);
		}
	}
	return $rc;
}


=item _build_command

This returns the command string constructed from the sprintf format
specified by $format and the set of replacements in @arguments.

=cut

sub _build_command
{
	my ( $self, $format, @arguments ) = @_;

	my $command;
	if ( $format && @arguments )
	{
			$format .= "\r";
		$command = sprintf $format, @arguments;
	}
	return $command;
}

=back

=head1 AUTHOR

Jonathan Stowe, C<< <jns at gellyfish.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-device-pilite at rt.cpan.org>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Device::PiLite


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Device-PiLite>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Device-PiLite>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Device-PiLite>

=item * Search CPAN

L<http://search.cpan.org/dist/Device-PiLite/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Jonathan Stowe.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.


=cut

1; 
