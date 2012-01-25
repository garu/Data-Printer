use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use_ok ('Term::ANSIColor');
    use_ok (
        'Data::Printer',
            colored      => 1,
            escape_chars => 0,
    );
};

my @stuff = (
     {
        original  => "\0",
        unescaped => '\0',
     },
     {
        original  => "\n",
        unescaped => '\n',
     },
     {
        original  => "\t",
        unescaped => '\t',
     },
     {
        original  => "\b",
        unescaped => '\b',
     },
     {
        original  => "\e",
        unescaped => '\e',
        },
     {
        original  => "\r",
        unescaped => '\r',
     },
     {
        original  => "\f",
        unescaped => '\f',
     },
     {
        original  => "\a",
        unescaped => '\a',
     },
);

my $mixed = ();

foreach my $item (@stuff) {
    my $colored = color('bright_red')
                . $item->{unescaped}
                . color('bright_yellow')
                ;

    $mixed->{original}  .= $item->{original};
    $mixed->{unescaped} .= $item->{unescaped};
    $mixed->{colored}   .= $colored;

    is(
        p( $item->{original} ),
          color('reset')
        . color('bright_yellow')
        . '"'
        . $colored
        . '"'
        . color('reset'),
        'testing escape sequence for ' . $item->{unescaped}
    );
}

is(
    p( $mixed->{original} ),
       color('reset')
     . color('bright_yellow')
     . '"'
     . $mixed->{colored}
     . '"'
     . color('reset'),
     'testing escape sequence for ' . $mixed->{unescaped}
);

done_testing;
