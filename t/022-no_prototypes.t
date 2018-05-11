use strict;
use warnings;
use Test::More tests => 7;
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
my $undef;
is p($undef), 'undef', 'undef scalar (no ref exception) without prototype check';

is p( { foo => 42 } ),
'{
    foo   42
}', 'hash without prototype check';

is p( [ 1, 2 ] ),
'[
    [0] 1,
    [1] 2
]', 'array without prototype check';

DDPTestOther::test_no_prototypes_on_pass();
exit;

package # hide from pause
    DDPTestOther;

    use Data::Printer colored => 0, return_value => 'pass';
    use Test::More;

    sub test_no_prototypes_on_pass {
        SKIP: {
            my $has_capture_tiny = eval { require Capture::Tiny; 1; };
            skip 'Capture::Tiny not found', 3 unless $has_capture_tiny;
            my $val = 123;
            my $ret;
            my ($stdout, $stderr) = Capture::Tiny::capture( sub {
                $ret = p($val, return_value => 'pass');
                1;
            });
            is $ret, $val, 'pass works without prototypes';
            is $stdout, '', 'pass STDOUT works without prototypes';
            is $stderr, "123\n", 'pass STDERR works without prototypes';
        };
    }
