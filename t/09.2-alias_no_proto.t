use strict;
use warnings;

use Test::More;
BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Data::Printer { alias_p_no_prototypes => 'pp', 'return_value' => 'dump' };

my $scalar = 'test';
is( (pp "Hello"), '"Hello"', 'aliasing p_without_prototypes()' );

done_testing;
