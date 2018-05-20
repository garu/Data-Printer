use strict;
use warnings;
use Test::More tests => 17;
use Data::Printer::Object;
use Scalar::Util qw(weaken isweak);
use B;

test_scalar_refcount();
test_hash_refcount();
test_array_refcount();

exit;

sub test_array_refcount {
    my $var = [42];
    my $count; eval { $count = B::svref_2object($var)->REFCNT };
    push @$var, $var;

    my $count2; eval { $count2 = B::svref_2object($var)->REFCNT };
    ok $count2 > $count, "array: $count2 > $count";
    my $ddp = Data::Printer::Object->new( colored => 0, show_refcount => 1 );
    is $ddp->parse($var), '[
    [0] 42,
    [1] var
] (refcount: 2)', 'circular array ref';
    weaken($var->[-1]);
    my $count3; eval { $count3 = B::svref_2object($var)->REFCNT };
    ok $count3 == $count, "array: $count3 == $count";
    is_deeply($ddp->{_seen}, {}, 'ensure proper internal structure (array)');

    is $ddp->parse($var), '[
    [0] 42,
    [1] var (weak)
]', 'circular array ref (weakened)';


    my $data2 = [[10]];
    push @{$data2}, $data2->[0];
    my $out = $ddp->parse( \$data2 );
    my @times_matched = $out =~ /refcount:/g;
    is(@times_matched, 1, 'found (refcount: 2) only once') or diag $out;
}

sub test_hash_refcount {
    my $var = { foo => 42 };
    my $count; eval { $count = B::svref_2object($var)->REFCNT };
    $var->{self} = $var;
    my $count2; eval { $count2 = B::svref_2object($var)->REFCNT };
    ok $count2 > $count, "hash: $count2 > $count";

    my $ddp = Data::Printer::Object->new( colored => 0, show_refcount => 1 );
    is ($ddp->parse($var), '{
    foo    42,
    self   var
} (refcount: 2)', 'circular hash ref');

    weaken($var->{self});
    my $count3; eval { $count3 = B::svref_2object($var)->REFCNT };
    ok $count3 == $count, "hash: $count3 == $count";
    is_deeply($ddp->{_seen}, {}, 'ensure proper internal structure (hash)');
    is ($ddp->parse($var), '{
    foo    42,
    self   var (weak)
}', 'circular hash ref (weakened)');
}

sub test_scalar_refcount {
    my $ddp = Data::Printer::Object->new( colored => 0, show_refcount => 1 );
    my $var;
    my $count; eval { $count = B::svref_2object(\$var)->REFCNT };
    $var = \$var;

    my $count2; eval { $count2 = B::svref_2object(\$var)->REFCNT };
    ok $count2 > $count, "scalar: $count2 > $count";
    is $ddp->parse($var), '\\ var (refcount: 2)', 'circular scalar ref';
    is $ddp->parse($var), '\\ var (refcount: 2)', 'circular scalar ref (retest)';
    weaken($var);
    my $count3; eval { $count3 = B::svref_2object(\$var)->REFCNT };
    ok $count3 == $count, "scalar: $count3 == $count";
    is $ddp->parse($var), '\\ var (weak)', 'circular scalar ref (weakened)';
    my $ref = \$var;
    $ddp = Data::Printer::Object->new( colored => 0, show_refcount => 1 );
    is $ddp->parse($ref), '\\ var (weak) (refcount: 2)', 'circular scalar ref (weakened)';
}
