use strict;
use warnings;
use Test::More tests => 2;
use Data::Printer::Object;

my $scalar_lvalue = \substr( "abc", 2);
my $ddp = Data::Printer::Object->new( colored => 0 );
is $ddp->parse(\$scalar_lvalue), q("c" (LVALUE)), 'LVALUE ref with show_lvalue';
$ddp = Data::Printer::Object->new( colored => 0, show_lvalue => 0 );
is $ddp->parse(\$scalar_lvalue), q("c"), 'LVALUE ref without show_lvalue';
