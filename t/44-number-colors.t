use strict;
use warnings;
use Test::More tests => 4;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use_ok ('Term::ANSIColor');
    use_ok ('Data::Printer', return_value => 'dump', colored => 1);
};

pass('Loaded ok');

my $data = {
    not_a_number_1 => "0123",
    not_a_number_2 => "Inf",
    not_a_number_3 => "Infinity",
    not_a_number_4 => "NaN",
    not_a_number_5 => "0 but true",
    not_a_number_6 => "-0123",
    not_a_number_7 => "+0123",
    not_a_number_8 => "",
    not_a_number_9 => "abc",
    not_a_number_10 => "+1",
    not_a_number_11 => '1_000',

    number_1 => 123,
    number_2 => 0,
    number_3 => 1,
    number_4 => -1,
    number_7 => 1.23,
    number_8 => 1.23e+38,
    number_9 => 1.23e-38,
};

my $space = ' 'x4;

my $expected_output = color('reset') . "\\ {\n"
    . ' 'x4 . colored('not_a_number_1', 'magenta') . ' 'x4 . '"' . colored('0123', 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_2', 'magenta') . ' 'x4 . '"' . colored("Inf", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_3', 'magenta') . ' 'x4 . '"' . colored("Infinity", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_4', 'magenta') . ' 'x4 . '"' . colored("NaN", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_5', 'magenta') . ' 'x4 . '"' . colored("0 but true", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_6', 'magenta') . ' 'x4 . '"' . colored("-0123", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_7', 'magenta') . ' 'x4 . '"' . colored("+0123", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_8', 'magenta') . ' 'x4 . '"' . colored("", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_9', 'magenta') . ' 'x4 . '"' . colored("abc", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_10', 'magenta') . ' 'x3 . '"' . colored("+1", 'bright_yellow') . '",' . "\n"
    . ' 'x4 . colored('not_a_number_11', 'magenta') . ' 'x3 . '"' . colored('1_000', 'bright_yellow') . '",' . "\n"

    . ' 'x4 . colored('number_1', 'magenta') . ' 'x10 . colored(123, 'bright_blue') . ",\n"
    . ' 'x4 . colored('number_2', 'magenta') . ' 'x10 . colored(0, 'bright_blue') . ",\n"
    . ' 'x4 . colored('number_3', 'magenta') . ' 'x10 . colored(1, 'bright_blue') . ",\n"
    . ' 'x4 . colored('number_4', 'magenta') . ' 'x10 . colored(-1, 'bright_blue') . ",\n"
    . ' 'x4 . colored('number_7', 'magenta') . ' 'x10 . colored(1.23, 'bright_blue') . ",\n"
    . ' 'x4 . colored('number_8', 'magenta') . ' 'x10 . colored(1.23e+38, 'bright_blue') . ",\n"
    . ' 'x4 . colored('number_9', 'magenta') . ' 'x10 . colored(1.23e-38, 'bright_blue') . "\n"
    . "}"
    ;

is(
    p($data),
    $expected_output,
    "Numbers and strings are written as expected",
);
