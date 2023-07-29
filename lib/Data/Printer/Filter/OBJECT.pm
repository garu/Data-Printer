package Data::Printer::Filter::OBJECT;
use strict;
use warnings;
use Data::Printer::Filter;

filter 'OBJECT' => \&parse;

sub parse {
    return '(opaque object)';
};

1;
