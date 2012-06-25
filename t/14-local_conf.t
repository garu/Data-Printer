use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test; # avoid user's .dataprinter
    use_ok 'Term::ANSIColor';
    use_ok 'Data::Printer', colored => 1;
};

my %hash = ( key => 'value' );
is( p(%hash), color('reset') . "{$/    "
              . colored('key', 'magenta')
              . '   '
              . colored('"value"', 'bright_yellow')
              . "$/}"
, 'default hash');

is( p(%hash, color => { hash => 'red' }, hash_separator => '  +  ' ), color('reset') . "{$/    "
              . colored('key', 'red')
              . '  +  '
              . colored('"value"', 'bright_yellow')
              . "$/}"
, 'hash keys are now red');

is( p(%hash), color('reset') . "{$/    "
              . colored('key', 'magenta')
              . '   '
              . colored('"value"', 'bright_yellow')
              . "$/}"
, 'still default hash');


done_testing;
