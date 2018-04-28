use strict;
use warnings;

package Bar;
sub bar    { 666 }
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

package Baz;
sub bar { 42 }
1;

package Meep;
our @ISA = qw(Foo Baz);
1;

package ParentLess;
sub new    { bless {}, shift }
1;

package FooArray;
sub new    { bless [], shift }
sub foo    { }
1;

package FooScalar;
sub new    { my $val = 42; bless \$val, shift }
sub foo    { }
1;

package FooCode;
sub new    { my $ref = sub {}; bless $ref, shift }
sub foo    { }
1;

package ICanHazStringOverload;
use overload
  '""' => sub { 'le string of le object' };
sub new { bless {}, shift };
1;

package ICanHazNumberOverload;
use overload
  '0+' => sub { 42 };
sub new { bless {}, shift };
1;

package ChildOfOverload;
our @ISA = ('ICanHazNumberOverload');
sub new { bless {}, shift };
1;

package UnrelatedOverload;
use overload '<' => sub {}, '+' => sub {};
sub new { bless {}, shift };
1;

package ICanHazStringMethodOne;
sub new { bless {}, shift };
sub as_string { 'number one!' }
sub stringify { 'second!' };
1;

package ICanHazStringMethodTwo;
sub new { bless {}, shift };
sub stringify { 'second!' };
1;


package main;
use Test::More tests => 34;
use Data::Printer::Object;

my $ddp = Data::Printer::Object->new( colored => 0 );

my $object = Foo->new;

is(
    $ddp->parse($object),
'Foo  {
    Parents       Bar
    public methods (4): baz, borg, foo, new
    private methods (1): _other
    internals: {
        test   42
    }
}',
    'testing objects'
);

$ddp = Data::Printer::Object->new( colored => 0, class => { linear_isa => 1 } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    Linear @ISA   Foo, Bar, UNIVERSAL
    public methods (4): baz, borg, foo, new
    private methods (1): _other
    internals: {
        test   42
    }
}', 'testing objects, forcing linear @ISA' );

$ddp = Data::Printer::Object->new( colored => 0, class => { parents => 0 } );
is( $ddp->parse($object), 'Foo  {
    public methods (4): baz, borg, foo, new
    private methods (1): _other
    internals: {
        test   42
    }
}', 'testing objects (parents => 0)' );

$ddp = Data::Printer::Object->new( colored => 0, class => { show_methods => 'none' } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    internals: {
        test   42
    }
}', 'testing objects (no methods)' );

$ddp = Data::Printer::Object->new( colored => 0, class => { show_methods => 'public' } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    public methods (4): baz, borg, foo, new
    internals: {
        test   42
    }
}', 'testing objects (only public methods)' );

$ddp = Data::Printer::Object->new( colored => 0, class => { show_methods => 'private' } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    private methods (1): _other
    internals: {
        test   42
    }
}', 'testing objects (only private methods)' );

$ddp = Data::Printer::Object->new( colored => 0, class => { show_methods => 'all' } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    public methods (4): baz, borg, foo, new
    private methods (1): _other
    internals: {
        test   42
    }
}', 'testing objects (explicitly asking for all methods)' );

$ddp = Data::Printer::Object->new( colored => 0, class => { internals => 0 } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    public methods (4): baz, borg, foo, new
    private methods (1): _other
}', 'testing objects (no internals)' );

$ddp = Data::Printer::Object->new( colored => 0, class => { inherited => 'none' } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    public methods (4): baz, borg, foo, new
    private methods (1): _other
    internals: {
        test   42
    }
}', 'testing objects (inherited => "none") (default)' );

my ($n, $extra_field) = $] < 5.010 ? (8, '') : (9, ' DOES (UNIVERSAL),');

$ddp = Data::Printer::Object->new( colored => 0, class => { inherited => 'all' } );
is( $ddp->parse($object), "Foo  {
    Parents       Bar
    public methods ($n): bar (Bar), baz, borg, can (UNIVERSAL),$extra_field foo, isa (UNIVERSAL), new, VERSION (UNIVERSAL)
    private methods (2): _moo (Bar), _other
    internals: {
        test   42
    }
}", 'testing objects (inherited => "all")' );

$ddp = Data::Printer::Object->new( colored => 0, class => { inherited => 'all', format_inheritance => 'lines' } );
my $lines_extra = ($extra_field? ' DOES,' : '');
is( $ddp->parse($object), "Foo  {
    Parents       Bar
    public methods ($n):
        baz, borg, foo, new
        Bar:
            bar
        UNIVERSAL:
            can,$lines_extra isa, VERSION
    private methods (2):
        _other
        Bar:
            _moo
    internals: {
        test   42
    }
}", 'testing objects (inherited => "all", format_inheritance => "lines")' );

$ddp = Data::Printer::Object->new( colored => 0, class => { inherited => 'all', universal => 0 } );
is( $ddp->parse($object), "Foo  {
    Parents       Bar
    public methods (5): bar (Bar), baz, borg, foo, new
    private methods (2): _moo (Bar), _other
    internals: {
        test   42
    }
}", 'testing objects (inherited => "all", universal => 0)' );

$ddp = Data::Printer::Object->new( colored => 0, class => { inherited => 'public' } );
is( $ddp->parse($object), "Foo  {
    Parents       Bar
    public methods ($n): bar (Bar), baz, borg, can (UNIVERSAL),$extra_field foo, isa (UNIVERSAL), new, VERSION (UNIVERSAL)
    private methods (1): _other
    internals: {
        test   42
    }
}", 'testing objects (inherited => "public")' );

$ddp = Data::Printer::Object->new( colored => 0, class => { inherited => 'public', universal => 0 } );
is( $ddp->parse($object), "Foo  {
    Parents       Bar
    public methods (5): bar (Bar), baz, borg, foo, new
    private methods (1): _other
    internals: {
        test   42
    }
}", 'testing objects (inherited => "public", universal => 0)' );

$ddp = Data::Printer::Object->new( colored => 0, class => { inherited => 'private' } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    public methods (4): baz, borg, foo, new
    private methods (2): _moo (Bar), _other
    internals: {
        test   42
    }
}', 'testing objects (inherited => "private")' );

$ddp = Data::Printer::Object->new( colored => 0, class => { expand => 0 } );
is( $ddp->parse($object), 'Foo',
    'testing objects without expansion' );

$object->borg( Foo->new );

$ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    public methods (4): baz, borg, foo, new
    private methods (1): _other
    internals: {
        borg   Foo,
        test   42
    }
}', 'testing nested objects' );

$ddp = Data::Printer::Object->new( colored => 0, class => { expand => 'all' } );
is( $ddp->parse($object), 'Foo  {
    Parents       Bar
    public methods (4): baz, borg, foo, new
    private methods (1): _other
    internals: {
        borg   Foo  {
            Parents       Bar
            public methods (4): baz, borg, foo, new
            private methods (1): _other
            internals: {
                test   42
            }
        },
        test   42
    }
}', 'testing nested objects with expansion' );

my $obj_with_isa = Meep->new;

$ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse($obj_with_isa), 'Meep  {
    Parents       Foo, Baz
    Linear @ISA   Meep, Foo, Bar, Baz, UNIVERSAL
    public methods (0)
    private methods (0)
    internals: {
        test   42
    }
}', 'testing objects with @ISA' );

$ddp = Data::Printer::Object->new( colored => 0, class => { linear_isa => 0 } );
is( $ddp->parse($obj_with_isa), 'Meep  {
    Parents       Foo, Baz
    public methods (0)
    private methods (0)
    internals: {
        test   42
    }
}', 'testing objects with @ISA, opting out the @ISA' );

$ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse($obj_with_isa), 'Meep  {
    Parents       Foo, Baz
    Linear @ISA   Meep, Foo, Bar, Baz, UNIVERSAL
    public methods (0)
    private methods (0)
    internals: {
        test   42
    }
}', 'testing objects with @ISA' );

$ddp = Data::Printer::Object->new( colored => 0 );
my $parentless = ParentLess->new;

is( $ddp->parse($parentless), 'ParentLess  {
    public methods (1): new
    private methods (0)
    internals: {}
}', 'testing parentless object' );


$ddp = Data::Printer::Object->new( colored => 0 );
my $scalar_obj = FooScalar->new;
is( $ddp->parse($scalar_obj), 'FooScalar  {
    public methods (2): foo, new
    private methods (0)
    internals: 42
}', 'testing blessed scalar' );

$ddp = Data::Printer::Object->new( colored => 0, class => { show_reftype => 1 } );
is( $ddp->parse($scalar_obj), 'FooScalar (SCALAR)  {
    public methods (2): foo, new
    private methods (0)
    internals: 42
}', 'testing blessed scalar with reftype' );

$ddp = Data::Printer::Object->new( colored => 0 );
my $array_obj = FooArray->new;
is( $ddp->parse($array_obj), 'FooArray  {
    public methods (2): foo, new
    private methods (0)
    internals: []
}', 'testing blessed array' );

$ddp = Data::Printer::Object->new( colored => 0 );
my $code_obj = FooCode->new;
is( $ddp->parse($code_obj), 'FooCode  {
    public methods (2): foo, new
    private methods (0)
    internals: sub { ... }
}', 'testing blessed code' );

$ddp = Data::Printer::Object->new( colored => 0 );
my $str_overload = ICanHazStringOverload->new;
is( $ddp->parse($str_overload),
    'le string of le object (ICanHazStringOverload)',
    'object with string overload'
);
my $num_overload = ICanHazNumberOverload->new;
is( $ddp->parse($num_overload),
    '42 (ICanHazNumberOverload)',
    'object with number overload'
);

my $child_overload = ChildOfOverload->new;
is( $ddp->parse($child_overload),
    '42 (ChildOfOverload)',
    'object with inherited overload'
);

my $unrelated = UnrelatedOverload->new;
is( $ddp->parse($unrelated), 'UnrelatedOverload  {
    public methods (1): new
    private methods (0)
    overloads: +, <
    internals: {}
}',
    'object with different overload (should not stringify)'
);

$ddp = Data::Printer::Object->new( colored => 0, class => { show_overloads => 0 } );
is( $ddp->parse($unrelated), 'UnrelatedOverload  {
    public methods (1): new
    private methods (0)
    internals: {}
}',
    'object with different overload (not showing overloads)'
);

$ddp = Data::Printer::Object->new( colored => 0 );
is( $ddp->parse( ICanHazStringMethodOne->new ),
    'number one! (ICanHazStringMethodOne)',
    'object with as_string and stringify (prefer as_string)'
);

is( $ddp->parse( ICanHazStringMethodTwo->new ),
    'second! (ICanHazStringMethodTwo)',
    'object with stringify'
);

$ddp = Data::Printer::Object->new( colored => 0, class => { stringify => 0 } );
is( $ddp->parse( ICanHazStringMethodTwo->new ),
'ICanHazStringMethodTwo  {
    public methods (2): new, stringify
    private methods (0)
    internals: {}
}',
'object with stringify => 0 expands normally'
);



done_testing;
