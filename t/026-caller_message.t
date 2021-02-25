use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    use Data::Printer::Config;
    no warnings 'redefine';
    *Data::Printer::Config::load_rc_file = sub { {} };
};

use Data::Printer
    colored                 => 0,
    caller_info             => 1,
    return_value            => 'dump',
    caller_message_newline  => 0,
    caller_message_position => 'before';

my $x;
my $got = p $x;
is(
    $got,
    'Printing in line 19 of t/026-caller_message.t: undef',
    'caller_info shows the proper caller message (after)'
);

$got = p $x, caller_message_position => 'after';
is(
    $got,
    'undef Printing in line 26 of t/026-caller_message.t:',
    'caller_info shows the proper caller message (before)'
);
