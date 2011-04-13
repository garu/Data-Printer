use strict;
use warnings;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
};

package Bar;
sub bar    { }
sub borg   { }

1;

package Foo;
our @ISA = qw(Bar);

sub new    { bless { test => 42 }, shift }
sub foo    { }
sub baz    { }
sub borg   { }
sub _other { }

1;

package main;
use Test::More;
use Data::Printer;

my $obj = Foo->new;

is( p($obj), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
    internals: {
        test    42,
    }
}', 'testing objects' );

is( p($obj, class => { internals => 0 } ), 
'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
}', 'testing objects (no internals)' );


done_testing;
