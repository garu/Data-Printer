use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    use_ok ('Term::ANSIColor', 'colored');
    use_ok ('Data::Printer', 'd');
};

my $number = 3.14;
is( d($number), colored($number, 'bright_blue'), 'colored number');

my $string = 'test';
is( d($string), colored('"test"', 'bright_yellow'), 'colored string');

my $undef = undef;
is( d($undef), colored('undef', 'bright_red'), 'colored undef');

my $regex = qr{1};
is( d($regex), '\\ ' . colored('1', 'yellow'), 'colored regex');

my $code = sub {};
is( d($code), '\\ ' . colored('sub { ... }', 'green'), 'colored code');

my @array = (1);
is( d(@array), "[$/    " 
               . colored('[0]', 'bright_white')
               . ' '
               . colored(1, 'bright_blue')
               . ",$/]"
, 'colored array');

my %hash = (1=>2);
is( d(%hash), "{$/    "
              . colored(1, 'magenta')
              . '    '
              . colored(2, 'bright_blue')
              . ",$/}"
, 'colored hash');

my $circular = [];
$circular->[0] = $circular;
is( d($circular), "\\ [$/    "
                  . colored('[0]', 'bright_white')
                  . ' '
                  . colored('var', 'white on_red')
                  . ",$/]"
, 'colored circular ref');

done_testing;
