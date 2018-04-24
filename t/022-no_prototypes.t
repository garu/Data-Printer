use strict;
use warnings;
use Test::More tests => 4;
use Scalar::Util;

BEGIN {
    use Data::Printer::Config;
    no warnings 'redefine';
    *Data::Printer::Config::load_rc_file = sub { {} };
};

use Data::Printer colored        => 0,
                  return_value   => 'dump',
                  use_prototypes => 0;

is p(\"test"), '"test" (read-only)', 'scalar without prototype check';
is p(my $undef), 'undef', 'undef scalar (no ref exception) without prototype check';

is p( { foo => 42 } ),
'{
    foo   42
}', 'hash without prototype check';

is p( [ 1, 2 ] ),
'[
    [0] 1,
    [1] 2
]', 'array without prototype check';


