use strict;
use warnings;
use Test::More tests => 1;
use Data::Printer::Object;

my $data = [ 1, 2, { foo => 3, bar => 4 } ];
push @$data, $data->[2];

my $ddp = Data::Printer::Object->new( colored => 0, multiline => 0 );
is( $ddp->parse($data), '[ 1, 2, { bar:4, foo:3 }, var[2] ]', 'single line dump');
