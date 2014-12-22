use strict;
use warnings;

use Test::More;
BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Data::Printer return_value => 'dump';

pass('Loaded ok');

my @numbers = (
    -1,
    0,
    1,
    1.23,
    1.23e+38,
    1.23e-38,
    123,
);

foreach my $number (@numbers) {
    ok(
        Data::Printer::_is_number($number),
        "_is_number('$number') return true",
    );
}

my @strings = (
    "",
    "+0123",
    "+1",
    "-0123",
    "0 but true",
    "0123",
    "Inf",
    "Infinity",
    "NaN",
    "abc",
    '1_000',
);

foreach my $not_a_number (@strings) {
    ok(
        not(Data::Printer::_is_number($not_a_number)),
        "_is_number('$not_a_number') return false",
    );
}

done_testing();
