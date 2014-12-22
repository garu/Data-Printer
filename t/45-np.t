use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Data::Printer;

my $scalar = 'test';

is( np($scalar), '"test"', 'np() returns string' );


is( np($scalar, return_value => 'void'), '"test"', 'np() always returns strings' );


