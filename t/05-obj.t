use strict;
use warnings;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

package Bar;
sub bar    { }
sub borg   { }
sub _moo   { }

1;

package Foo;
our @ISA = qw(Bar);

sub new    { bless { test => 42 }, shift }
sub foo    { }
sub baz    { }
sub borg   { $_[0]->{borg} = $_[1]; }
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
        test   42
    }
}', 'testing objects' );

is( p($obj, class => { internals => 0 } ), 
'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
}', 'testing objects (no internals)' );

is( p($obj, class => { inherited => 0 }), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
    internals: {
        test   42
    }
}', 'testing objects (inherited => 0)' );


is( p($obj, class => { inherited => 'all' }), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (5) : bar (Bar), baz, borg, foo, new
    private methods (2) : _moo (Bar), _other
    internals: {
        test   42
    }
}', 'testing objects (inherited => "all")' );

is( p($obj, class => { inherited => 'public' }), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (5) : bar (Bar), baz, borg, foo, new
    private methods (1) : _other
    internals: {
        test   42
    }
}', 'testing objects (inherited => "public")' );

is( p($obj, class => { inherited => 'private' }), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (2) : _moo (Bar), _other
    internals: {
        test   42
    }
}', 'testing objects (inherited => "private")' );

is( p($obj, class => { expand => 0 }), 'Foo',
    'testing objects without expansion' );

$obj->borg( Foo->new );

is( p($obj), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
    internals: {
        borg   Foo,
        test   42
    }
}', 'testing nested objects' );

is( p($obj, class => { expand => 'all'} ), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
    internals: {
        borg   Foo  {
            Parents       Bar
            Linear @ISA   Foo, Bar
            public methods (4) : baz, borg, foo, new
            private methods (1) : _other
            internals: {
                test   42
            }
        },
        test   42
    }
}', 'testing nested objects with expansion' );



done_testing;
