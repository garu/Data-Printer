use strict;
use warnings;
use Test::More;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Data::Printer {
    filters => {
        'My::Module' => sub { $_[0]->test },
        'SCALAR'     => sub { 'found!!' },
        'ARRAY'      => sub {
           my $ref = shift;
           return join ':', map { p(\$_) } @$ref;
        },
        'HASH' => sub {
            my $ref = shift;
            return 'list => ' . p($ref->{items});
        },
    },
};

package My::Module;

sub new { bless {}, shift }
sub test { return 'this is a test' }

package main;

my $obj = My::Module->new;

is( p($obj), 'this is a test', 'testing filter for object' );

my $scalar = 42;
is( p($scalar), 'found!!', 'testing filter for SCALAR' );

my $scalar_ref = \$scalar;
is( p($scalar_ref), '\\ found!!', 'testing filter for SCALAR (passing a ref instead)' );

my @list = (1 .. 3);
is( p(@list), 'found!!:found!!:found!!', 'testing filters referencing p()' );

my %hash = ( items => \@list );
is( p(%hash), 'list => found!!:found!!:found!!', 'testing filters passing a list into p()' );

done_testing;
