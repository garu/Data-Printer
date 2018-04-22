use strict;
use warnings;
use Test::More tests => 3;

use Data::Printer;
pass 'Data::Printer loaded successfully';

ok exists &p , 'p() was imported successfully';
ok exists &np, 'np() was imported successfully';
