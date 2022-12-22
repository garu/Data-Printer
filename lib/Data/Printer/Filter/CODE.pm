package Data::Printer::Filter::CODE;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;
use Scalar::Util ();
use Fcntl;

filter 'CODE' => \&parse;


sub parse {
    my ($subref, $ddp) = @_;
    my $string;
    my $color = 'code';
    if ($ddp->deparse) {
        $string = _deparse($subref, $ddp);
        if ($ddp->coderef_undefined && $string =~ /\A\s*sub\s*;\s*\z/) {
            $string = $ddp->coderef_undefined;
            $color = 'undef';
        }
    }
    elsif ($ddp->coderef_undefined && !_subref_is_reachable($subref)) {
        $string = $ddp->coderef_undefined;
        $color = 'undef';
    }
    else {
        $string = $ddp->coderef_stub;
    }
    return $ddp->maybe_colorize($string, $color);
};

#######################################
### Private auxiliary helpers below ###
#######################################

sub _deparse {
    my ($subref, $ddp) = @_;
    require B::Deparse;

    # FIXME: line below breaks encapsulation on Data::Printer::Object
    my $i = $ddp->{indent} + $ddp->{_array_padding};

    my $deparseopts = ["-sCi${i}v'Useless const omitted'"];

    my $sub = 'sub ' . B::Deparse->new($deparseopts)->coderef2text($subref);
    my $pad = $ddp->newline;
    $sub    =~ s/\n/$pad/gse;
    return $sub;
}

sub _subref_is_reachable {
    my ($subref) = @_;
    require B;
    my $cv = B::svref_2object($subref);
    return !(B::class($cv->ROOT) eq 'NULL' && !${ $cv->const_sv });
}

1;
