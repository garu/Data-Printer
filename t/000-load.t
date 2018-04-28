use strict;
use warnings;
use Test::More tests => 3;

BEGIN {
    use Data::Printer::Config;
    no warnings 'redefine';
    *Data::Printer::Config::load_rc_file = sub { {} };
};

use Data::Printer;
pass 'Data::Printer loaded successfully';

ok exists &p , 'p() was imported successfully';
ok exists &np, 'np() was imported successfully';
