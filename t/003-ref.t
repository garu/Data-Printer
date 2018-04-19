use strict;
use warnings;
use Test::More tests => 2;
use Data::Printer::Object;

my $ddp = Data::Printer::Object->new( colored => 0 );
my $data = \"test";
my $ref  = \$data;
my $res = $ddp->parse(\$ref);
is $res, q(\\ "test"), 'reference to reference to scalar';

$ddp = Data::Printer::Object->new( colored => 0 );
$res = $ddp->parse(\\$ref);
is $res, q(\\ \\ "test"), 'ref2ref2ref2scalar';
