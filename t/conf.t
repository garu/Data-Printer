use strict;
use warnings;

use Test::More;
BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
};

use Data::Printer {
    'name'   => 'TEST',
    'indent' => 2,
    'index'  => 0,
    'hash_separator' => ' => ',
};

my $data = [ 1, 2, { foo => 3 } ];
push @$data, $data->[2];

is( p($data), '\\ [
  1,
  2,
  {
    foo => 3,
  },
  TEST[2],
]', 'customization' );

done_testing;
