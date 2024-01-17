package Data::Printer::Theme::Classic;
# classic Data::Printer colors, for nostalgic users :D
use strict;
use warnings;

sub colors {
    return {
        array       => 'bright_white',  # array index numbers
        number      => 'bright_blue',   # numbers
        string      => 'bright_yellow', # strings
        class       => 'bright_green',  # class names
        method      => 'bright_green',  # method names
        undef       => 'bright_red',    # the 'undef' value
        hash        => 'magenta',       # hash keys
        regex       => 'yellow',        # regular expressions
        code        => 'green',         # code references
        glob        => 'bright_cyan',   # globs (usually file handles)
        vstring     => 'bright_blue',   # version strings (v5.16.0, etc)
        lvalue      => '',              # lvalue label
        format      => '',              # format type
        true        => 'bright_cyan',   # boolean type (true)
        false       => 'bright_cyan',   # boolean type (false)
        repeated    => 'white on_red',  # references to seen values
        caller_info => 'bright_cyan',   # details on what's being printed
        weak        => 'cyan',          # weak references
        tainted     => 'red',           # tainted content
        unicode     => '',              # utf8 flag
        escaped     => 'bright_red',    # escaped characters (\t, \n, etc)
        brackets    => '',           # (), {}, []
        separator   => '',           # the "," between hash pairs, array elements, etc
        quotes      => '',
        unknown     => 'bright_yellow on_blue', # any (potential) data type unknown to Data::Printer
    };
}

1;
__END__

=head1 NAME

Data::Printer::Theme::Classic - Classic DDP color theme for nostalgic users

=head1 SYNOPSIS

In your C<.dataprinter> file:

    theme = Classic

Or during runtime:

    use DDP theme => 'Classic';

=head1 DESCRIPTION

This module implements the Classic theme for Data::Printer, which was
the default theme before Data::Printer 1.0.

=for html <a href="https://metacpan.org/pod/Data::Printer::Theme::Classic"><img src="https://raw.githubusercontent.com/garu/Data-Printer/master/examples/theme-classic.png" alt="Classic Theme" /></a>

=head1 SEE ALSO

L<Data::Printer>

L<Data::Printer::Theme>
