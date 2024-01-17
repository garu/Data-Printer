package Data::Printer::Theme::Monokai;
# inspired by Wimer Hazenberg's Monokai theme: monokai.nl
use strict;
use warnings;

sub colors {
    my %code_for = (
        grey   => '#75715E',
        yellow => '#E6DB74',
        violet => '#AE81FF',
        pink   => '#F92672',
        cyan   => '#66D9EF',
        green  => '#A6E22E',
        orange => '#FD971F',
        empty  => '',
    );
    return {
        array       => $code_for{orange},  # array index numbers
        number      => $code_for{violet}, # numbers
        string      => $code_for{yellow}, # (or 'very_light_gray'?) # strings
        class       => $code_for{green},  # class names
        method      => $code_for{green},  # method names
        undef       => $code_for{pink},  # the 'undef' value
        hash        => $code_for{cyan},  # hash keys
        regex       => $code_for{green},  # regular expressions
        code        => $code_for{orange},  # code references
        glob        => $code_for{violet},  # globs (usually file handles)
        vstring     => $code_for{cyan},  # version strings (v5.16.0, etc)
        lvalue      => $code_for{green},  # lvalue label
        format      => $code_for{violet},  # format type
        true        => $code_for{violet},  # boolean type (true)
        false       => $code_for{violet},  # boolean type (false)
        repeated    => $code_for{pink},  # references to seen values
        caller_info => $code_for{grey},  # details on what's being printed
        weak        => $code_for{green},  # weak references flag
        tainted     => $code_for{green},  # tainted flag
        unicode     => $code_for{green},  # utf8 flag
        escaped     => $code_for{pink},  # escaped characters (\t, \n, etc)
        brackets    => $code_for{empty},  # (), {}, []
        separator   => $code_for{empty},  # the "," between hash pairs, array elements, etc
        quotes      => $code_for{yellow},
        unknown     => $code_for{pink},  # any (potential) data type unknown to Data::Printer
    };
}

1;
__END__

=head1 NAME

Data::Printer::Theme::Monokai - Monokai theme for DDP

=head1 SYNOPSIS

In your C<.dataprinter> file:

    theme = Monokai

Or during runtime:

    use DDP theme => 'Monokai';

=head1 DESCRIPTION

This module implements the Monokai theme for Data::Printer, inspired by
L<Wimer Hazenberg's original work|https://monokai.nl>.

=for html <a href="https://metacpan.org/pod/Data::Printer::Theme::Monokai"><img src="https://raw.githubusercontent.com/garu/Data-Printer/master/examples/theme-monokai.png" alt="Monokai Theme" /></a>


=head1 SEE ALSO

L<Data::Printer>

L<Data::Printer::Theme>
