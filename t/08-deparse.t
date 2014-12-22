#use strict;
#use warnings;

use Test::More;
BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use 5.008; # <-- prevents PERL5OPT from kicking in and mangling B::Deparse
use Data::Printer {
    'return_value' => 'dump',
    'deparse'   => 1,
    'deparseopts' => [],
};

my $data = [ 6, sub { print 42 }, 10 ];

is( p($data), '\\ [
    [0] 6,
    [1] sub {
            print 42;
        },
    [2] 10
]', 'deparsing' );

done_testing;
