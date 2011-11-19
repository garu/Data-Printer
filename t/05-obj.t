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

my $old_MOP = 0;
eval 'use Class::MOP 2.0300';
$old_MOP = 1 if $@;

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

is( p($obj, class => { parents => 0 }), 'Foo  {
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
    internals: {
        test   42
    }
}', 'testing objects (parents => 0)' );

is( p($obj, class => { linear_isa => 0 }), 'Foo  {
    Parents       Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
    internals: {
        test   42
    }
}', 'testing objects (linear_isa => 0)' );

is( p($obj, class => { show_methods => 'none' }), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    internals: {
        test   42
    }
}', 'testing objects (no methods)' );

is( p($obj, class => { show_methods => 'public' }), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    internals: {
        test   42
    }
}', 'testing objects (only public methods)' );

is( p($obj, class => { show_methods => 'private' }), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    private methods (1) : _other
    internals: {
        test   42
    }
}', 'testing objects (only private methods)' );

is( p($obj, class => { show_methods => 'all' }), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar
    public methods (4) : baz, borg, foo, new
    private methods (1) : _other
    internals: {
        test   42
    }
}', 'testing objects (explicitly asking for all methods)' );

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

my $public = $old_MOP
           ? 'public methods (5) : bar (Bar), baz, borg, foo, new'
           : 'public methods (9) : bar (Bar), baz, borg, can (UNIVERSAL), DOES (UNIVERSAL), foo, isa (UNIVERSAL), new, VERSION (UNIVERSAL)'
           ;

is( p($obj, class => { inherited => 'all' }), "Foo  {
    Parents       Bar
    Linear \@ISA   Foo, Bar
    $public
    private methods (2) : _moo (Bar), _other
    internals: {
        test   42
    }
}", 'testing objects (inherited => "all")' );


is( p($obj, class => { inherited => 'public' }), "Foo  {
    Parents       Bar
    Linear \@ISA   Foo, Bar
    $public
    private methods (1) : _other
    internals: {
        test   42
    }
}", 'testing objects (inherited => "public")' );

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
