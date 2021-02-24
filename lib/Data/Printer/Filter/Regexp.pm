package Data::Printer::Filter::Regexp;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;

filter 'Regexp' => sub {
    my ($regexp, $ddp) = @_;
    my $val = "$regexp";
    my $string;

    # a regex to parse a regex. Talk about full circle :)
    # note: we are not validating anything, just grabbing modifiers
    if ($val =~ m/\(\?\^?([uladxismnpogce]*)(?:\-[uladxismnpogce]+)?:(.*)\)/s) {
        my ($modifiers, $parsed_val) = ($1, $2);
        $string = $ddp->maybe_colorize($parsed_val, 'regex');
        if ($modifiers) {
            $string .= "  (modifiers: $modifiers)";
        }
    }
    else {
        Data::Printer::Common::_warn($ddp, "Unrecognized regex $val. Please submit a bug report for Data::Printer.");
        $string = $ddp->maybe_colorize('Unknown Regexp', 'regex');
    }

    if ($ddp->show_tied and my $tie = ref tied $regexp) {
        $string .= " (tied to $tie)";
    }
    return $string;
};

1;
