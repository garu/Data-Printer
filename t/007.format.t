use strict;
use warnings;
use Test::More tests => 1;
use Data::Printer::Object;


format TEST =
.

my $form = *TEST{FORMAT};

my $ddp = Data::Printer::Object->new( colored => 0 );

is( $ddp->parse(\$form), 'FORMAT',  'FORMAT reference' );
