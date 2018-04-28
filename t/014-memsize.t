use strict;
use warnings;
use Test::More tests => 6;
use Data::Printer::Object;
use Data::Printer::Common;

my $error = Data::Printer::Common::_tryme(sub { require Devel::Size; 1; });
SKIP: {
    skip 'Devel::Size not found - cannot test show_memsize', 6 if $error;

    my $ddp = Data::Printer::Object->new( colored => 0, show_memsize => 1 );
    my @x = (1, 'two');
    my $res = $ddp->parse(\@x);
    my @count = $res =~ /B|K|M/g;
    is (scalar @count, 1, 'show_memsize == 1 only goes 1 level deep') or diag($res);
    like $res, qr/\] \(\d+(?:B|K|M)\)\z/, 'show_memsize looks ok when set to 1';
    $ddp = Data::Printer::Object->new( colored => 0, show_memsize => 2 );
    $res = $ddp->parse(\@x);
    @count = $res =~ /B|K|M/g;
    is (scalar @count, 3, 'show_memsize == 2 goes 2 levels deep.');
    like $res, qr/ \(\d+(?:B|K|M)\)\z/, 'show_memsize looks ok when set to 2';
    $ddp = Data::Printer::Object->new( colored => 0, show_memsize => 'all' );
    $res = $ddp->parse(\@x);
    @count = $res =~ /B|K|M/g;
    is (scalar @count, 3, 'show_memsize == all show everything.');
    like $res, qr/ \(\d+(?:B|K|M)\)\z/, 'show_memsize looks ok when set to "all"';
};
