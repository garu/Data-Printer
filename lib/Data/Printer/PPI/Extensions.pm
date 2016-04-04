package Data::Printer::PPI::Extensions;
use feature qw(say);
use strict;
use warnings;

use List::Util qw(any);

sub name {
    my $self = shift;
    
    my $name = $self->class;
    $name =~ s/^PPI:://;
    return $name;
}

sub is_comma_or_semi_colon {
    my $item = shift;
    
    my $name = $item->name;
    if ( $name eq 'Token::Operator') {
        if ( any { $item->content eq $_ } (',', '=>') ) {
            return 1;
        }
    }
    elsif ( $name eq 'Token::Structure' ) {
        if ( $item->content eq ';' ) {
            return 1;
        }
    }
    return 0;
}

1;
