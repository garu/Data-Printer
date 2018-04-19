use strict;
use warnings;
use Test::More tests => 1;
use Data::Printer::Object;

plan skip_all => 'Older perls do not have VSTRING support' if $] < 5.010;
my $version = v1.2.3;
my $ddp = Data::Printer::Object->new( colored => 0 );
my $res = $ddp->parse(\$version);

if ($res eq 'VSTRING object (unable to parse)' || $res eq 'v1.2.3') {
    pass 'VSTRING';
}
else {
    fail "expected v1.2.3, got '$res'!";
}
