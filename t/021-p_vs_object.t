#!perl -T
# ^^ taint mode must be on for taint checking.
use strict;
use warnings;
use Test::More tests => 26;
use Scalar::Util;

BEGIN {
    use Data::Printer::Config;
    no warnings 'redefine';
    *Data::Printer::Config::load_rc_file = sub { {} };
};

use Data::Printer colored       => 0,
                  return_value  => 'dump',
                  show_refcount => 1,
                  show_weak     => 1,
                  show_tainted  => 1,
                  multiline     => 0,
                  class => { expand => 0 }
                  ;

my $has_devel_size = !Data::Printer::Common::_tryme(sub { require Devel::Size; 1; });

test_tainted();
test_weak_ref();
test_refcount();

sub test_tainted {
    SKIP: {
        # only use 1 char substring to avoid leaking
        # user information on test results:
        my $tainted = substr $ENV{'PATH'}, 0, 1;
        skip 'Skipping taint test: sample not found.', 2
            => unless Scalar::Util::tainted($tainted);

        my $pretty = p $tainted;
        is $pretty, qq("$tainted" (TAINTED)), 'found taint flag with p()';

        my $pretty_np = np $tainted;
        is $pretty_np, $pretty, 'found taint flag with np()';
    };
}

sub test_weak_ref {
    my $num = 3.14;
    my $ref = \$num;
    Scalar::Util::weaken($ref);
    my $pretty = p $ref;
    is $pretty, '3.14 (weak)', 'found weak flag with p()';
    my $pretty_np = np $ref;
    is $pretty_np, $pretty, 'found weak flag with np()';
}

sub test_refcount {
    my $array = [42];
    push @$array, $array;
    my $pretty = p $array;
    is $pretty, '[ 42, var ] (refcount: 2)', 'circular array';
    my $pretty_np = np $array;
    is $pretty_np, $pretty, 'circular array (np)';

    my @simple_array = (42);
    push @simple_array, \@simple_array;
    $pretty = p @simple_array;
    is $pretty, '[ 42, var ] (refcount: 2)', 'circular (simple) array';
    $pretty_np = np @simple_array;
    is $pretty_np, $pretty, 'circular (simple) array (np)';

    Scalar::Util::weaken($array->[-1]);
    $pretty = p $array;
    is $pretty, '[ 42, var (weak) ]', 'circular (weak) array';
    $pretty_np = np $array;
    is $pretty_np, $pretty, 'circular (weak) array (np)';

    my %hash = ( foo => 42 );
    $hash{self} = \%hash;
    $pretty = p %hash;
    is $pretty, '{ foo:42, self:var } (refcount: 2)', 'circular (simple) hash';
    $pretty_np = np %hash;
    is $pretty_np, $pretty, 'circular (simple) hash (np)';

    my $hash = { foo => 42 };
    $hash->{self} = $hash;
    $pretty = p $hash;
    is $pretty, '{ foo:42, self:var } (refcount: 2)', 'circular hash';
    $pretty_np = np $hash;
    is $pretty_np, $pretty, 'circular hash (np)';

    my $other_hash = $hash;
    $pretty = p $other_hash;
    is $pretty, '{ foo:42, self:var } (refcount: 3)', 'circular hash with extra ref';
    $pretty_np = np $other_hash;
    is $pretty_np, $pretty, 'circular hash with extra ref (np)';

    Scalar::Util::weaken($hash->{self});
    undef $other_hash;
    $pretty = p $hash;
    is $pretty, '{ foo:42, self:var (weak) }', 'circular (weak) hash';
    $pretty_np = np $hash;
    is $pretty_np, $pretty, 'circular (weak) hash (np)';

    my $scalar;
    $scalar = \$scalar;
    $pretty = p $scalar;
    is $pretty, '\\ var (refcount: 2)', 'circular scalar ref';
    $pretty_np = np $scalar;
    is $pretty_np, $pretty, 'circular scalar ref (np)';

    my $blessed = bless {}, 'Something';
    $pretty = p $blessed;
    is $pretty, 'Something', 'blessed ref';
    $pretty_np = np $blessed;
    is $pretty_np, $pretty, 'blessed ref (np)';

    my $blessed2 = $blessed;
    $pretty = p $blessed2;
    is $pretty, 'Something (refcount: 2)', 'blessed ref (high refcount)';
    $pretty_np = np $blessed2;
    is $pretty_np, $pretty, 'blessed ref (high refcount) (np)';
    Scalar::Util::weaken($blessed2);
    $pretty = p $blessed2;
    is $pretty, 'Something (weak)', 'blessed ref (weak)';
    $pretty_np = np $blessed2;
    is $pretty_np, $pretty, 'blessed ref (weak) (np)';
}
