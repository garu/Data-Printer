use strict;
use warnings;
use Test::More tests => 1;

use Data::Printer alias => 'Dumper', return_value => 'dump', colored => 0;
my $scalar = 'test';
is( Dumper($scalar), '"test"', 'aliasing p()' );
