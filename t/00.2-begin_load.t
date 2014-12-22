use strict;
use warnings;

my $res;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
}

BEGIN {
    use Test::More;
    use Data::Printer return_value => 'dump', colored => 0, multiline => 0, index => 0;

    my @data = ( 1 .. 3 );

    $res = p @data;
}

is $res, '[ 1, 2, 3 ]', 'DDP wihtin a BEGIN block';

done_testing;
