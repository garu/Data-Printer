#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 10;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Data::Printer multiline => 1, return_value => 'dump';

my $x = {a=>1,b=>2};

like   p($x)             , qr/\n/, 'Default with linebreaks';
unlike p($x,multiline=>0), qr/\n/, 'Override no linebreaks';
like   p($x)             , qr/\n/, 'Back to default with linebreaks';
unlike p($x,multiline=>0), qr/\n/, 'Override no linebreaks';
like   p($x,multiline=>1), qr/\n/, 'Override with linebreaks';

############################
$SIG{__WARN__} = sub {};
require ( delete $INC{'Data/Printer.pm'} );
Data::Printer->import( multiline => 0, return_value => 'dump' );
$SIG{__WARN__} = undef;
############################

unlike p($x)             , qr/\n/, 'Default without linebreaks';
like   p($x,multiline=>1), qr/\n/, 'Override with linebreaks';
unlike p($x)             , qr/\n/, 'Back to default without linebreaks';
like   p($x,multiline=>1), qr/\n/, 'Override with linebreaks';
unlike p($x,multiline=>0), qr/\n/, 'Override without linebreaks';
