package Data::Printer::Filter::SCALAR;
use strict;
use warnings;
use Data::Printer::Filter;
use Scalar::Util;

filter 'SCALAR' => \&_parse_scalar;
filter 'LVALUE' => sub {
    my ($scalar_ref, $ddp) = @_;
    my $string = _parse_scalar($scalar_ref, $ddp);
    if ($ddp->show_lvalue) {
        $string .= $ddp->maybe_colorize(' (LVALUE)', 'lvalue');
    }
    return $string;
};

sub _parse_scalar {
    my ($scalar_ref, $ddp) = @_;  # TODO: ddp object?

    #my $value =  $$scalar_ref;
    my $ret;

    my $value = ref $scalar_ref ? $$scalar_ref : $scalar_ref;

    if (not defined $value) {
        $ret = $ddp->maybe_colorize('undef', 'undef');
    }
    elsif (_is_number($value)) {
        $ret = $ddp->maybe_colorize($value, 'number');
    }
    else {
        # share code with hash keys:
        $ret = Data::Printer::Common::_process_string($ddp, $value, 'string');
        my $quote = $ddp->maybe_colorize($ddp->scalar_quotes, 'quotes');
        $ret = $quote . $ret . $quote;
#        $ret = Data::Printer::Common::_print_escapes($ddp, $value, 'string');
#        $ret = $ddp->maybe_colorize($value, 'string');
#        $ret = Data::Printer::Common::_escape_chars($ddp, $ret, 'string');
#        $ret = _reduce_string($ddp, $ret);
#        $ret = $ddp->maybe_colorize($ret, 'string')
    }
    $ret .= _check_tainted($ddp, $scalar_ref);
    $ret .= _check_unicode($ddp, $scalar_ref);

    return $ret;
};

#######################################
### Private auxiliary helpers below ###
#######################################


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


1;
