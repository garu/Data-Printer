use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use lib 't/lib', './lib';
    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use Term::ANSIColor;
    use Data::Printer colored => 1, color => 'Test';
};


my $number = 42;
is(
    p($number),
    color('reset') . colored($number, 'cyan'),
    'color theme works!'
);
