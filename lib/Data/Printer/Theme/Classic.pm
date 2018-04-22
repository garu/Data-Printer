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
        repeated    => 'white on_red',  # references to seen values
        caller_info => 'bright_cyan',   # details on what's being printed
        weak        => 'cyan',          # weak references
        tainted     => 'red',           # tainted content
        escaped     => 'bright_red',    # escaped characters (\t, \n, etc)
        brackets    => undef,           # (), {}, []
        hash_arrow  => undef,           # =>
        punctuation => undef,           # everything else: , ; \

        # potential new Perl datatypes, unknown to Data::Printer
        unknown     => 'bright_yellow on_blue',
    };
}

1;
