use Test::More tests => 4;
use Data::Printer::Object;

# use strict;   # <-- messes with B::Deparse
# use warnings; # <-- messes with B::Deparse
use 5.008;      # <-- prevents PERL5OPT from kicking in and mangling B::Deparse

my $sub = sub { 0 };
my $ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse(\$sub), 'sub { ... }', 'subref test' );

$sub = sub { print 42 };
$ddp = Data::Printer::Object->new( colored => 0, deparse => 1 );
is( $ddp->parse(\$sub), 'sub {
    print 42;
}', 'subref with deparse');

$ddp = Data::Printer::Object->new( colored => 0 );
my $data = [ 6, sub { print 42 }, 10 ];
is( $ddp->parse(\$data), '[
    [0] 6,
    [1] sub { ... },
    [2] 10
]', 'subref in array');

$ddp = Data::Printer::Object->new( colored => 0, deparse => 1 );
is( $ddp->parse(\$data), '[
    [0] 6,
    [1] sub {
            print 42;
        },
    [2] 10
]', 'subref in array');
