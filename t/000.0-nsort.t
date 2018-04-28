use strict;
use warnings;
use Data::Printer::Common;

use Test::More tests => 1;

my $chosen = Data::Printer::Common::_initialize_nsort();
diag("available sort module: $chosen");

my @unsorted = (
    'DOES (UNIVERSAL)',
    'VERSION (UNIVERSAL)',
    'bar (Bar)',
    'baz',
    'borg',
    'can (UNIVERSAL)',
    'foo',
    'isa (UNIVERSAL)',
    'new'
);
is_deeply( [ Data::Printer::Common::_nsort_pp(@unsorted) ],
    [
        'bar (Bar)',
        'baz',
        'borg',
        'can (UNIVERSAL)',
        'DOES (UNIVERSAL)',
        'foo',
        'isa (UNIVERSAL)',
        'new',
        'VERSION (UNIVERSAL)'
    ], 'pure-perl sorting looks sane'
);
