use strict;
use warnings;
use Test::More;


##############################
### DEPRECATED!!!!!!!!!!!! ###
##############################

###########################################
### PLEASE USE 'print_escapes' instead! ###
###########################################
BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
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

my %hash_with_escaped_keys = (
     '  '   => 1,
);

is(
    p( %hash_with_escaped_keys ),
       color('reset') . "{$/    "
     . q[']
     . colored('  ', 'magenta')
     . q[']
     . '   '
     . colored(1, 'bright_blue')
     . "$/}",
     'testing hash key with spaces'
);

%hash_with_escaped_keys = (
    "\n" => 1,
);

is(
    p( %hash_with_escaped_keys ),
       color('reset') . "{$/    "
     . q[']
     . color('magenta')
     . color('bright_red')
     . '\n'
     . color('magenta')
     . color('reset')
     . q[']
     . '   '
     . colored(1, 'bright_blue')
     . "$/}",
     'testing escaped hash keys'
);

%hash_with_escaped_keys = (
    '' => 1,
);

is(
    p( %hash_with_escaped_keys ),
       color('reset') . "{$/    "
     . q[']
     . colored('', 'magenta')
     . q[']
     . '   '
     . colored(1, 'bright_blue')
     . "$/}",
     'quoting empty hash key'
);

done_testing;
