use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use Data::Printer::Config;
    no warnings 'redefine';
    *Data::Printer::Config::load_rc_file = sub { {} };
};

use Data::Printer alias => 'Dumper', return_value => 'dump', colored => 0;
my $scalar = 'test';
is( Dumper($scalar), '"test"', 'aliasing p()' );
