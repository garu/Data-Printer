use strict;
use warnings;
use Test::More tests => 7;
use Data::Printer::Object;

my $ddp = Data::Printer::Object->new( colored => 0, show_readonly => 0 );
my $data = "test";
my $ref  = \$data;
my $ref2ref = \$ref;
my $res = $ddp->parse(\$ref2ref);
is $res, q(\\ \\ "test"), 'reference to reference to scalar';

my $doublecheck = $ddp->parse(\$ref2ref);
is $doublecheck, $res, 'checking again gives the same result (previously seen addresses)';

$ddp = Data::Printer::Object->new( colored => 0, show_readonly => 0 );
$res = $ddp->parse(\\$ref2ref);
is $res, q(\\ \\ \\ "test"), 'ref2ref2ref2scalar';

my $x = [];
my $y = $x;
Scalar::Util::weaken($y);
is $ddp->parse($x), '[]', 'regular array ref';
is $ddp->parse($y), '[] (weak)', 'weak array ref';
$x->[0] = $x;
Scalar::Util::weaken($x->[0]);
is $ddp->parse($x), '[
    [0] var (weak)
]', 'circular array';

my $array_of_refs = [\1, \2];
$res = $ddp->parse($array_of_refs);
is $res, '[
    [0] \ 1,
    [1] \ 2
]', 'proper results when 2 references present on the same array (regression)';
