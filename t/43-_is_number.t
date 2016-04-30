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
    '123\n',
    "123\n",
    '-',
);

foreach my $not_a_number (@strings) {

    # If we don't change new line symbol then the test output will be messy:
    #
    #   ok 20 - _is_number('1_000') return false
    #   ok 21 - _is_number('123
    #   # ') return false
    #   1..21

    my $number_for_test_name = $not_a_number;
    $number_for_test_name =~ s/\n/\\n/g;

    ok(
        not(Data::Printer::_is_number($not_a_number)),
        "_is_number('$number_for_test_name') return false",
    );
}

done_testing();
