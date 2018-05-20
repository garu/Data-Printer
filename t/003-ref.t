use strict;
use warnings;
use Test::More tests => 3;
use Data::Printer::Object;

my $ddp = Data::Printer::Object->new( colored => 0 );
my $data = "test";
my $ref  = \$data;
my $ref2ref = \$ref;
my $res = $ddp->parse(\$ref2ref);
is $res, q(\\ "test"), 'reference to reference to scalar';

my $doublecheck = $ddp->parse(\$ref2ref);
is $doublecheck, $res, 'checking again gives the same result (previously seen addresses)';

$ddp = Data::Printer::Object->new( colored => 0 );
$res = $ddp->parse(\\$ref2ref);
is $res, q(\\ \\ "test"), 'ref2ref2ref2scalar';
