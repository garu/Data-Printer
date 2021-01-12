use strict;
use warnings;
use Test::More;
use Data::Printer::Common;
use Data::Printer::Object;

plan tests => 4;

test_moo();
test_moose();
exit;

sub test_moo {
    SKIP: {
        my $moo_error = Data::Printer::Common::_tryme(
            'package TestMooClass; use Moo; has bar => (is => "ro", required => 0); no Moo; 1;'
        );
        skip 'Moo not found', 2 if $moo_error;

        my $ddp = Data::Printer::Object->new( colored => 0 );
        my $obj = TestMooClass->new;
        my $parsed = $ddp->parse($obj);
        like(
            $parsed,
            qr/attributes \(1\): bar$/m,
            'Moo object parsed properly'
        );
        unlike(
            $parsed,
            qr/roles/,
            'No role output displayed since no roles were used.'
        );
    };
}

sub test_moose {
    SKIP: {
        my $moose_error = Data::Printer::Common::_tryme(
            'package TestMooseClass; use Moose; has foo => (is => "rw", required => 0); no Moose; 1;'
        );
        skip 'Moose not found', 2 if $moose_error;

        my $ddp = Data::Printer::Object->new( colored => 0 );
        my $obj = TestMooseClass->new;
        my $parsed = $ddp->parse($obj);
        like(
            $parsed,
            qr/attributes \(1\): foo$/m,
            'Moose object parsed properly'
        );
        unlike(
            $parsed,
            qr/roles/,
            'No role output displayed since no roles were used.'
        );
    };
}
