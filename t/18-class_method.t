use strict;
use warnings;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

package Foo;
sub bar  { "I exist with " . scalar @_ . " argument" }
sub _moo { }
sub new  { bless {}, shift }

1;


package main;
use Test::More tests => 1;
use Data::Printer class_method => 'bar';

my $obj = Foo->new;

is p($obj), 'I exist with 1 argument', 'printing object via class_method "bar()"';
