use strict;
use warnings;
use Test::More;
use Data::Printer::Common;
use Data::Printer::Object;

plan tests => 8;

test_role_tiny();
test_moo();
test_moose();
exit;

sub test_role_tiny {
    SKIP: {
        my $role_tiny_error = Data::Printer::Common::_tryme(
            'package TestRole; use Role::Tiny; sub role_a {} sub role_b {} 1; package TestClass; use Role::Tiny::With; with q(TestRole); sub new { bless {}, shift } 1;'
        );
        skip 'Role::Tiny not found: ' . $role_tiny_error, 2 if $role_tiny_error;

        my $ddp = Data::Printer::Object->new( colored => 0 );
        my $obj = TestClass->new;
        my $parsed = $ddp->parse($obj);
        like(
            $parsed,
            qr/^\s*roles \(1\): TestRole$/m,
            'Role::Tiny role is listed'
        );
        like(
            $parsed,
            qr/TestRole:\s+role_a, role_b/m,
            'Role::Tiny object parsed properly'
        );
    };
}

sub test_moo {
    SKIP: {
        my $moo_error = Data::Printer::Common::_tryme(
            'package MooTestRole; use Moo::Role; has attr_from_role => (is => "ro", required => 0);sub role_x {} sub role_y {} 1; package MooTestClass; use Moo; with q(MooTestRole); no Moo; 1;'
        );
        skip 'Moo not found: ' . $moo_error, 3 if $moo_error;

        my $ddp = Data::Printer::Object->new( colored => 0 );
        my $obj = MooTestClass->new;
        my $parsed = $ddp->parse($obj);
        like(
            $parsed,
            qr/^\s*roles \(1\): MooTestRole$/m,
            'Moo role is listed'
        );
        like(
            $parsed,
            qr/^\s*attributes \(1\): attr_from_role$/m,
            'role attribute is found in Moo object'
        );
        like(
            $parsed,
            qr/^\s*MooTestRole:\s+role_x, role_y/m,
            'Moo object parsed properly'
        );
    };
}


sub test_moose {
    SKIP: {
        my $moose_error = Data::Printer::Common::_tryme(
            'package MooseTestRole; use Moose::Role; has my_attr => (is => "ro", required => 0);sub role_p {} sub role_q {} 1; package MooseTestClass; use Moose; with q(MooseTestRole); no Moose; __PACKAGE__->meta->make_immutable; 1;'
        );
        skip 'Moose not found: ' . $moose_error, 3 if $moose_error;

        my $ddp = Data::Printer::Object->new( colored => 0 );
        my $obj = MooseTestClass->new;
        my $parsed = $ddp->parse($obj);
        like(
            $parsed,
            qr/^\s*roles \(1\): MooseTestRole$/m,
            'Moose role is listed'
        );
        like(
            $parsed,
            qr/^\s*attributes \(1\): my_attr$/m,
            'role attribute is found in Moose object'
        );
        like(
            $parsed,
            qr/MooseTestRole:\s+role_p, role_q/m,
            'Moose object parsed properly'
        );
    };
}
