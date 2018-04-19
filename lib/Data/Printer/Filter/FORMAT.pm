package Data::Printer::Filter::FORMAT;
use strict;
use warnings;
use Data::Printer::Filter;

filter 'FORMAT' => sub {
    my ($format, $ddp) = @_;
    return $ddp->maybe_colorize('FORMAT', 'format');
};

1;
