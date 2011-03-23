use strict;
use warnings;

use Test::More;
BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
};

use Data::Printer { alias => 'Dumper' };

my $scalar = 'test';
is( Dumper($scalar), '"test"', 'aliasing p()' );

eval {
    p( $scalar );
};
ok($@, 'aliased Data::Printer does not export p()');

done_testing;
