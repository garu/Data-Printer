use strict;
use warnings;
use Test::More tests => 1;
use Data::Printer::Common;
use Data::Printer::Object;

test_object_pad();
exit;

sub test_object_pad {
    SKIP: {
        my $error = Data::Printer::Common::_tryme(
            'use Object::Pad 0.60; class TestClass { has $x :param = 42; method one($dX) { } method two { } }'
        );
        skip 'Object::Pad 0.60+ not found', 1 if $error;

        my $ddp = Data::Printer::Object->new( colored => 0, class => { show_reftype => 1 } );
        my $obj = TestClass->new( x => 666 );
        my $parsed = $ddp->parse($obj);
        is(
            $parsed,
            'TestClass (ARRAY)  {
    parents: Object::Pad::UNIVERSAL
    public methods (6):
        DOES, META, new, one, two
        Object::Pad::UNIVERSAL:
            BUILDARGS
    private methods (0)
    internals: [
        [0] 666
    ]
}',
            'parsed Object::Pad class'
        );
    };
}
