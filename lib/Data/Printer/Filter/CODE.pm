package Data::Printer::Filter::CODE;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;
use Scalar::Util ();
use Fcntl;

filter 'CODE' => sub {
    my ($subref, $ddp) = @_;
    my $string = $ddp->deparse ? _deparse($subref, $ddp) : 'sub { ... }';
    return $ddp->maybe_colorize($string, 'code');
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

1;
