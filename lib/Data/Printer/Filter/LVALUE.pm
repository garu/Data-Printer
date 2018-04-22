package Data::Printer::Filter::LVALUE;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;

filter 'LVALUE' => sub {
    my ($scalar_ref, $ddp) = @_;
    my $string = '';

};

1;
