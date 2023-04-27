package Data::Printer::Filter::SCALAR;
use strict;
use warnings;
use Data::Printer::Filter;
use Scalar::Util;
use B;

filter 'SCALAR' => \&parse;
filter 'LVALUE' => sub {
    my ($scalar_ref, $ddp) = @_;
    my $string = parse($scalar_ref, $ddp);
    if ($ddp->show_lvalue) {
        $string .= $ddp->maybe_colorize(' (LVALUE)', 'lvalue');
    }
    return $string;
};

sub parse {
    my ($scalar_ref, $ddp) = @_;

    my $ret;
    my $value = ref $scalar_ref ? $$scalar_ref : $scalar_ref;

    if (not defined $value) {
        $ret = $ddp->maybe_colorize('undef', 'undef');
    }
    elsif ( $ddp->show_dualvar ne 'off' ) {
        my $numified;
        $numified = do { no warnings 'numeric'; 0+ $value } if defined $value;
        if ( ( $numified || $numified == 0 ) && $ddp->show_numbers_strict eq 'on' && ! _is_number_strict( $value ) ) {
            $ret = Data::Printer::Common::_process_string( $ddp, "$value", 'string' );
            $ret = _quoteme($ddp, $ret);
            $ret .= ' (dualvar: ' . $ddp->maybe_colorize( $numified, 'number' ) . ')';
        }
        elsif ( $numified ) {
            if ( "$numified" eq $value
                || (
                    # lax mode allows decimal zeroes
                    $ddp->show_dualvar eq 'lax'
                    && ((index("$numified",'.') != -1 && $value =~ /\A\s*${numified}[0]*\s*\z/)
                        || (index("$numified",'.') == -1 && $value =~ /\A\s*$numified(?:\.[0]*)?\s*\z/))
                )
            ) {
                $value =~ s/\A\s+//;
                $value =~ s/\s+\z//;
                $ret = $ddp->maybe_colorize($value, 'number');
            }
            else {
                $ret = Data::Printer::Common::_process_string( $ddp, "$value", 'string' );
                $ret = _quoteme($ddp, $ret);
                $ret .= ' (dualvar: ' . $ddp->maybe_colorize( $numified, 'number' ) . ')';
            }
        }
        elsif ( !$numified && _is_number($value) ) {
            $ret = $ddp->maybe_colorize($value, 'number');
        }
        else {
            $ret = Data::Printer::Common::_process_string($ddp, $value, 'string');
            $ret = _quoteme($ddp, $ret);
        }
    }
    elsif (_is_number($value)) {
        $ret = $ddp->maybe_colorize($value, 'number');
    }
    else {
        $ret = Data::Printer::Common::_process_string($ddp, $value, 'string');
        $ret = _quoteme($ddp, $ret);
    }
    $ret .= _check_tainted($ddp, $scalar_ref);
    $ret .= _check_unicode($ddp, $scalar_ref);

    if ($ddp->show_tied and my $tie = ref tied $$scalar_ref) {
        $ret .= " (tied to $tie)";
    }

    return $ret;
};

#######################################
### Private auxiliary helpers below ###
#######################################
sub _quoteme {
    my ($ddp, $text) = @_;

    my $scalar_quotes = $ddp->scalar_quotes;
    if (defined $scalar_quotes) {
        # foo'bar ==> 'foo\'bar'
        $text =~ s{$scalar_quotes}{\\$scalar_quotes}g if index($text, $scalar_quotes) >= 0;
        my $quote = $ddp->maybe_colorize( $scalar_quotes, 'quotes' );
        $text = $quote . $text . $quote;
    }
    return $text;
}

sub _check_tainted {
    my ($self, $var) = @_;
    return ' (TAINTED)' if $self->show_tainted && Scalar::Util::tainted($$var);
    return '';
}

sub _check_unicode {
    my ($self, $var) = @_;
    return ' (U)' if $self->show_unicode && utf8::is_utf8($$var);
    return '';
}

sub _is_number {
    my ($maybe_a_number) = @_;

    # Scalar values that start with a zero are strings, NOT numbers.
    # You can write `my $foo = 0123`, but then `$foo` will be 83,
    # (numbers starting with zero are octal integers)
    return if $maybe_a_number =~ /^-?0[0-9]/;

    my $is_number = $maybe_a_number =~ m/
        ^
        -?          # numbers may begin with a '-' sign, but can't with a '+'.
                    # If they do they are not numbers, but strings.

        [0-9]+      # then there should be some numbers

        ( \. [0-9]+ )?      # there can be decimal part, which is optional

        ( e [+-] [0-9]+ )?  # and an also optional exponential notation part
        \z
    /x;

    return $is_number;
}

sub _is_number_strict {
    my ($maybe_a_number) = @_;
    return (0 != (B::svref_2object(\$maybe_a_number)->FLAGS & B::SVf_POK)) ? 0 : 1;
}

1;
