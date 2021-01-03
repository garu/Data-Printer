package Data::Printer::Filter::VSTRING;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;

filter 'VSTRING' => \&parse;

sub parse {
    my ($vstring, $ddp) = @_;
    my $string = '';

    # The reason we don't simply do:
    #   use version 0.77 ();
    # is because it was causing some issues with UNIVERSAL on Perl 5.8 and
    # some versions of version.pm. So now we do it on runtime on the filter.
    # ->parse() will raise an error unless version.pm >= 0.77.
    my $error = Data::Printer::Common::_tryme(sub {
        require version;
        $string = version->parse($$vstring)->normal;
    });
    $string = 'VSTRING object (unable to parse)' if $error;

    if ($ddp->show_tied and my $tie = ref tied $$vstring) {
        $string .= " (tied to $tie)";
    }
    return $ddp->maybe_colorize($string, 'vstring');
};

1;
