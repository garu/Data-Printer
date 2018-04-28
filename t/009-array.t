use strict;
use warnings;
use Test::More tests => 18;
use Data::Printer::Object;
use Scalar::Util ();

my $ddp = Data::Printer::Object->new( colored => 0 );
my @array;

my $res = $ddp->parse(\@array);
is $res, '[]', 'empty array';
push @array, 3.14, 'test', undef;
$ddp = Data::Printer::Object->new( colored => 0 );
$res = $ddp->parse(\@array);
is $res,
'[
    [0] 3.14,
    [1] "test",
    [2] undef
]',
'array with elements';

push @array, \@array;
$ddp = Data::Printer::Object->new( colored => 0 );
$res = $ddp->parse(\@array);
is $res,
'[
    [0] 3.14,
    [1] "test",
    [2] undef,
    [3] var
]',
'array with elements and circular ref';

$ddp = Data::Printer::Object->new( colored => 0 );
Scalar::Util::weaken($array[3]);
$res = $ddp->parse(\@array);
is $res,
'[
    [0] 3.14,
    [1] "test",
    [2] undef,
    [3] var (weak)
]',
'array with elements and WEAK circular ref';

pop @array;

$ddp = Data::Printer::Object->new( colored => 0, indent => 3 );
$res = $ddp->parse(\@array);
is $res,
'[
   [0] 3.14,
   [1] "test",
   [2] undef
]',
'array with indent => 3';

$ddp = Data::Printer::Object->new( colored => 0, end_separator => 1 );
$res = $ddp->parse(\@array);
is $res,
'[
    [0] 3.14,
    [1] "test",
    [2] undef,
]',
'array with end separator';

$ddp = Data::Printer::Object->new( colored => 0, separator => '!!' );
$res = $ddp->parse(\@array);
is $res,
'[
    [0] 3.14!!
    [1] "test"!!
    [2] undef
]',
'array with !! as separator';

$ddp = Data::Printer::Object->new( colored => 0, separator => '!!', end_separator => 1 );
$res = $ddp->parse(\@array);
is $res,
'[
    [0] 3.14!!
    [1] "test"!!
    [2] undef!!
]',
'array with !! as separator and end separator';

$ddp = Data::Printer::Object->new( colored => 0, index => 0 );
$res = $ddp->parse(\@array);
is $res,
'[
    3.14,
    "test",
    undef
]',
'array with no index';

$ddp = Data::Printer::Object->new( colored => 0, index => 0, indent => 2 );
$res = $ddp->parse(\@array);
is $res,
'[
  3.14,
  "test",
  undef
]',
'array with no index and indent => 2';
push @array, [7,8,9];
$ddp = Data::Printer::Object->new( colored => 0 );
$res = $ddp->parse(\@array);
is $res,
'[
    [0] 3.14,
    [1] "test",
    [2] undef,
    [3] [
            [0] 7,
            [1] 8,
            [2] 9
        ]
]',
'array with nested array';

$ddp = Data::Printer::Object->new( colored => 0, max_depth => 1 );
$res = $ddp->parse(\@array);
is $res,
'[
    [0] 3.14,
    [1] "test",
    [2] undef,
    [3] [...]
]',
'array with nested array over max_depth';

@array = (300 .. 350);
$ddp = Data::Printer::Object->new( colored => 0, array_max => 7 );
is( $ddp->parse(\@array), '[
    [0] 300,
    [1] 301,
    [2] 302,
    [3] 303,
    [4] 304,
    [5] 305,
    [6] 306,
        (...skipping 44 items...)
]', 'max_array');

$ddp = Data::Printer::Object->new( colored => 0, array_max => 7, array_preserve => 'begin', array_overflow => 'AND A LOT MORE!' );
is( $ddp->parse(\@array), '[
    [0] 300,
    [1] 301,
    [2] 302,
    [3] 303,
    [4] 304,
    [5] 305,
    [6] 306,
        AND A LOT MORE!
]', 'max_array (begin is default + overflow message)');


$ddp = Data::Printer::Object->new( colored => 0, array_max => 7, array_preserve => 'end' );
is( $ddp->parse(\@array), '[
         (...skipping 44 items...)
    [44] 344,
    [45] 345,
    [46] 346,
    [47] 347,
    [48] 348,
    [49] 349,
    [50] 350
]', 'max_array preserving end');

$ddp = Data::Printer::Object->new( colored => 0, array_max => 7, array_preserve => 'extremes' );
is( $ddp->parse(\@array), '[
    [0]  300,
    [1]  301,
    [2]  302,
         (...skipping 44 items...)
    [47] 347,
    [48] 348,
    [49] 349,
    [50] 350
]', 'max_array preserving extremes');

$ddp = Data::Printer::Object->new( colored => 0, array_max => 7, array_preserve => 'middle' );
is( $ddp->parse(\@array), '[
         (...skipping 22 items...)
    [22] 322,
    [23] 323,
    [24] 324,
    [25] 325,
    [26] 326,
    [27] 327,
    [28] 328,
         (...skipping 22 items...)
]', 'max_array preserving middle');

$ddp = Data::Printer::Object->new( colored => 0, array_max => 7, array_preserve => 'none' );
is( $ddp->parse(\@array), '[
    (...skipping 51 items...)
]', 'max_array preserving none');
