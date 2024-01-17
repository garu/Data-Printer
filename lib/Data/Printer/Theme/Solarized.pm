package Data::Printer::Theme::Solarized;
# inspired by Ethan Schoonover's Solarized theme:
# http://ethanschoonover.com/solarized
use strict;
use warnings;

sub colors {
    my %code_for = (
        base03  => '#1c1c1c', # '#002b36'
        base02  => '#262626', # '#073642'
        base01  => '#585858', # '#586e75'
        base00  => '#626262', # '#657b83'
        base0   => '#808080', # '#839496'
        base1   => '#8a8a8a', # '#93a1a1'
        base2   => '#e4e4e4', # '#eee8d5'
        base3   => '#ffffd7', # '#fdf6e3'
        yellow  => '#af8700', # '#b58900'
        orange  => '#d75f00', # '#cb4b16'
        red     => '#d70000', # '#dc322f'
        magenta => '#af005f', # '#d33682'
        violet  => '#5f5faf', # '#6c71c4'
        blue    => '#0087ff', # '#268bd2'
        cyan    => '#00afaf', # '#2aa198'
        green   => '#5f8700', # '#859900'
    );

    return {
        array       => $code_for{violet},  # array index numbers
        number      => $code_for{cyan}, # numbers
        string      => $code_for{cyan}, # strings
        class       => $code_for{yellow},  # class names
        method      => $code_for{orange},  # method names
        undef       => $code_for{red},  # the 'undef' value
        hash        => $code_for{green},  # hash keys
        regex       => $code_for{orange},  # regular expressions
        code        => $code_for{base2},  # code references
        glob        => $code_for{blue},  # globs (usually file handles)
        vstring     => $code_for{base1},  # version strings (v5.16.0, etc)
        lvalue      => $code_for{green},  # lvalue label
        format      => $code_for{green},  # format type
        true        => $code_for{blue},   # boolean type (true)
        false       => $code_for{blue},   # boolean type (false)
        repeated    => $code_for{red},    # references to seen values
        caller_info => $code_for{cyan},   # details on what's being printed
        weak        => $code_for{violet},  # weak references flag
        tainted     => $code_for{violet},  # tainted flag
        unicode     => $code_for{magenta},  # utf8 flag
        escaped     => $code_for{red},  # escaped characters (\t, \n, etc)
        brackets    => $code_for{base0},  # (), {}, []
        separator   => $code_for{base0},  # the "," between hash pairs, array elements, etc
        quotes      => $code_for{'base0'},
        unknown     => $code_for{red},  # any (potential) data type unknown to Data::Printer
    };

}

1;
__END__

=head1 NAME

Data::Printer::Theme::Solarized - Solarized theme for DDP

=head1 SYNOPSIS

In your C<.dataprinter> file:

    theme = Solarized

Or during runtime:

    use DDP theme => 'Solarized';

=head1 DESCRIPTION

This module implements the Solarized theme for Data::Printer, inspired by
L<Ethan Schoonover's original work|http://ethanschoonover.com/solarized>


=for html <a href="https://metacpan.org/pod/Data::Printer::Theme::Solarized"><img src="https://raw.githubusercontent.com/garu/Data-Printer/master/examples/theme-solarized.png" alt="Solarized Theme" /></a>

=head1 SEE ALSO

L<Data::Printer>

L<Data::Printer::Theme>
