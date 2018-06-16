package Data::Printer::Filter::REF;
use strict;
use warnings;
use Data::Printer::Filter;
use Scalar::Util ();

filter 'REF' => sub {
    my ($ref, $ddp) = @_;

    my $string = '';
    # we only add the '\' if it's not an object
    if (!Scalar::Util::blessed($$ref) && ref $$ref eq 'REF') {
        $string .= '\\ ';
    }
    $string .= $ddp->parse($$ref);

    if ($ddp->show_tied and my $tie = ref tied $ref) {
        $string .= " (tied to $tie)";
    }

    return $string;
};

1;
