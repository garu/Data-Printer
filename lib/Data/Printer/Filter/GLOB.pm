package Data::Printer::Filter::GLOB;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;
use Scalar::Util ();
use Fcntl;

filter 'GLOB' => \&parse;


sub parse {
    my ($glob, $ddp) = @_;

    my $string = $ddp->maybe_colorize("$$glob", 'glob');

    # unfortunately, some systems (like Win32) do not
    # implement some of these flags (maybe not even
    # fcntl() itself, so we must wrap it.
    my $extra = '';
    my $flags;
    eval { no warnings qw( unopened closed ); $flags = fcntl($$glob, F_GETFL, 0) };
    if ($flags) {
        $extra .= ($flags & O_WRONLY) ? 'write-only'
                : ($flags & O_RDWR)   ? 'read/write'
                : 'read-only'
                ;

        # How to avoid croaking when the system
        # doesn't implement one of those, without skipping
        # the whole thing? Maybe there's a better way.
        # Solaris, for example, doesn't have O_ASYNC :(
        my %flags = ();
        eval { $flags{'append'}      = O_APPEND   };
        eval { $flags{'async'}       = O_ASYNC    }; # leont says this is the only one I should care for.
        eval { $flags{'create'}      = O_CREAT    };
        eval { $flags{'truncate'}    = O_TRUNC    };
        eval { $flags{'nonblocking'} = O_NONBLOCK };

        if (my @flags = grep { $flags & $flags{$_} } sort keys %flags) {
            $extra .= ", flags: @flags";
        }
        $extra .= ', ';
    }
    my @layers = ();
    # TODO: try PerlIO::Layers::get_layers (leont)
    my $error = Data::Printer::Common::_tryme(sub {
        @layers = PerlIO::get_layers $$glob
    });
    $extra  .= "layers: @layers" unless $error;
    $string .= "  ($extra)" if $extra;

    if ($ddp->show_tied and my $tie = ref tied *$$glob) {
        $string .= " (tied to $tie)"
    }
    return $string;
};

1;
