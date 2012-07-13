use strict;
use warnings;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter

    use Test::More;
    use Data::Printer;

}

my $scalar = \substr( "abc", 2);
my $test_name = "LVALUE refs";
eval {
    is( p($scalar), 'LVALUE  "c"', $test_name );
};
if ($@) {
    fail( $test_name );
    diag( $@ );
}

done_testing();
