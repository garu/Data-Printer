use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    use_ok ('Term::ANSIColor', 'colored');
    use_ok ('Data::Printer');
};

my $number = 3.14;
is( p($number), colored($number, 'bright_blue'), 'colored number');

my $string = 'test';
is( p($string), colored('"test"', 'bright_yellow'), 'colored string');

my $undef = undef;
is( p($undef), colored('undef', 'bright_red'), 'colored undef');

my $regex = qr{1};
is( p($regex), '\\ ' . colored('1', 'yellow'), 'colored regex');

my $code = sub {};
is( p($code), '\\ ' . colored('sub { ... }', 'green'), 'colored code');

my @array = (1);
is( p(@array), "[$/    "
               . colored('[0]', 'bright_white')
               . ' '
               . colored(1, 'bright_blue')
               . ",$/]"
, 'colored array');

my %hash = (1=>2);
is( p(%hash), "{$/    "
              . colored(1, 'magenta')
              . '    '
              . colored(2, 'bright_blue')
              . ",$/}"
, 'colored hash');

my $circular = [];
$circular->[0] = $circular;
is( p($circular), "\\ [$/    "
                  . colored('[0]', 'bright_white')
                  . ' '
                  . colored('var', 'white on_red')
                  . ",$/]"
, 'colored circular ref');

done_testing;
