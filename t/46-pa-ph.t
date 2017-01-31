use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Data::Printer qw'return_value dump use_shortcut 1';

my $dh = ph my %hsh = qw'a b c d';
my $da = pa my @arr = 1..4;

isnt( $dh, 4, 'hash declaration dump' );
isnt( $da, 4, 'array declaration dump' );
