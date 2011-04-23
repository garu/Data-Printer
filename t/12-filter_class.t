use strict;
use warnings;
use Test::More;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Data::Printer::Filter;

my $filters = _filter_list();
is( $filters, undef, 'no filters set' );

sub test  { 'test' }
sub test2 { 'other test' }

filter 'SCALAR', \&test;

filter HASH => \&test2;

$filters = _filter_list();
is_deeply( $filters, { SCALAR => \&test, HASH => \&test2 }, 'proper filters set' );

done_testing;
