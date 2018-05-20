use strict;
use warnings;
use Test::More tests => 17;
use Data::Printer::Object;

my $ddp = Data::Printer::Object->new( colored => 0 );
my %hash = ();
is($ddp->parse(\%hash), '{}', 'empty hash');
undef %hash;
$ddp = Data::Printer::Object->new( colored => 0 );
is($ddp->parse(\%hash), '{}', 'undefined hash');

# the "%hash = 1" code below is wrong and issues
# an "odd number of elements in hash assignment"
# warning message. But since it's just a warning
# (meaning the code will still run even under strictness)
# we make sure to test everything will be alright.
{
    no warnings 'misc';
    %hash = 1;
}
$ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse(\%hash),
'{
    1   undef
}', 'evil hash of doom');

%hash = ( foo => 33, bar => 99 );
$ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse(\%hash),
'{
    bar   99,
    foo   33
}', 'simple hash');

$ddp = Data::Printer::Object->new( colored => 0, hash_separator => ': ' );
is( $ddp->parse(\%hash),
'{
    bar: 99,
    foo: 33
}', 'simple hash with custom separator');

$ddp = Data::Printer::Object->new( colored => 0 );
my $scalar = 4.2;
$hash{$scalar} = \$scalar;
$hash{hash} = { 1 => 2, 3 => { 4 => 5 }, 10 => 11 };
$hash{something} = [ 3 .. 5 ];
$hash{zelda} = 'moo';

is( $ddp->parse(\%hash),
'{
    4.2         \\ 4.2,
    bar         99,
    foo         33,
    hash        {
        1    2,
        3    {
            4   5
        },
        10   11
    },
    something   [
        [0] 3,
        [1] 4,
        [2] 5
    ],
    zelda       "moo"
}', 'nested hash');

$ddp = Data::Printer::Object->new( colored => 0, align_hash => 0 );
is( $ddp->parse(\%hash),
'{
    4.2   \\ 4.2,
    bar   99,
    foo   33,
    hash   {
        1   2,
        3   {
            4   5
        },
        10   11
    },
    something   [
        [0] 3,
        [1] 4,
        [2] 5
    ],
    zelda   "moo"
}', 'nested hash, unaligned');

$ddp = Data::Printer::Object->new( colored => 0 );
my $hash_ref = { c => 3 };
%hash = ( a => 1, b => \$hash_ref, d => 4 );
is( $ddp->parse(\%hash),
'{
    a   1,
    b   \\ {
        c   3
    },
    d   4
}', 'reference of a hash reference');

$ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse(\\$hash_ref),
'\\ {
    c   3
}', 'simple ref to hash ref' );

%hash = ( 'undef' => undef, foo => { 'meep' => undef }, zed => 26 );
$ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse(\%hash),
'{
    foo     {
        meep   undef
    },
    undef   undef,
    zed     26
}', 'hash with undefs' );

$ddp = Data::Printer::Object->new( colored => 0, ignore_keys => [qw(foo meep)] );
is($ddp->parse({ foo => 1, bar => 2, baz => 3, meep => 4 }),
'{
    bar   2,
    baz   3
}', 'hash with ignored keys');

$ddp = Data::Printer::Object->new( colored => 0, hash_max => 6 );
my $i = 10;
%hash = map { $_ => $i++ } split //, 'abcdefghijklmnopqrstuvwxyz';
is($ddp->parse(\%hash),
'{
    a   10,
    b   11,
    c   12,
    d   13,
    e   14,
    f   15,
    (...skipping 20 keys...)
}', 'hash_max reached');

$ddp = Data::Printer::Object->new( colored => 0, hash_max => 6, hash_preserve => 'begin' );
is($ddp->parse(\%hash),
'{
    a   10,
    b   11,
    c   12,
    d   13,
    e   14,
    f   15,
    (...skipping 20 keys...)
}', 'hash_max reached, preserve begin is the default');

$ddp = Data::Printer::Object->new( colored => 0, hash_max => 6, hash_preserve => 'end' );
is($ddp->parse(\%hash),
'{
    (...skipping 20 keys...)
    u   30,
    v   31,
    w   32,
    x   33,
    y   34,
    z   35
}', 'hash_max reached, preserving end');

$ddp = Data::Printer::Object->new( colored => 0, hash_max => 6, hash_preserve => 'middle' );
is($ddp->parse(\%hash),
'{
    (...skipping 9 keys...)
    j   19,
    k   20,
    l   21,
    m   22,
    n   23,
    o   24,
    (...skipping 11 keys...)
}', 'hash_max reached, preserving middle');

$ddp = Data::Printer::Object->new( colored => 0, hash_max => 6, hash_preserve => 'extremes' );
is($ddp->parse(\%hash),
'{
    a   10,
    b   11,
    c   12,
    (...skipping 20 keys...)
    x   33,
    y   34,
    z   35
}', 'hash_max reached, preserving extremes');

$ddp = Data::Printer::Object->new( colored => 0, hash_max => 6, hash_preserve => 'none' );
is($ddp->parse(\%hash),
'{
    (...skipping 26 keys...)
}', 'hash_max reached, preserving none');
