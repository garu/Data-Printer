use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use_ok ('Term::ANSIColor');
    use_ok (
        'Data::Printer',
            return_value => 'dump',
            colored      => 1,
            print_escapes => 1,
    );
};

my $string = "L\x{e9}on likes to build a m\x{f8}\x{f8}se \x{2603} with \x{2744}\x{2746}";
my $ctl_string = "\n\x{14}\x{7f}\x{9b}"; # "common" control character, C0, DEL, C1
my %hash   = ( $string => $string );

sub col(@) {
    my $return = color('bright_red');
    $return .= '\\x{' . shift() . '}' while @_;
    $return .= color('bright_yellow');
    return $return;
}

sub col_sp(@) {
    my $return = color('bright_red');
    $return .= '\\' . shift() while @_;
    $return .= color('bright_yellow');
    return $return;
}

sub str($) {
    return color('reset')
           . '"'
           . color('bright_yellow')
           . shift()
           . color('reset')
           . '"';
}

### none ###

is(
    p( $string ),
    str($string),
    "Testing 'none'"
);

### nonascii ###

use_ok (
    'Data::Printer',
        colored      => 1,
        print_escapes => 1,
        escape_chars => "nonascii",
);


is(
    p( $string ),
    str "L@{[col 'e9']}on likes to build a m@{[col 'f8','f8']}se @{[col '2603']} with @{[col '2744','2746']}",
    "Testing 'nonascii'"
);

is(
    p( $ctl_string ),
    str( col_sp('n','x{14}','x{7f}','x{9b}') ),
    "Testing 'nonascii' control characters"
);

### nonlatin1 ###

use_ok (
    'Data::Printer',
        colored      => 1,
        print_escapes => 1,
        escape_chars => "nonlatin1",
);

is(
    p( $string ),
    str "L\x{e9}on likes to build a m\x{f8}\x{f8}se @{[col '2603']} with @{[col '2744','2746']}",
    "Testing 'nonlatin1'"
);

is(
    p( $ctl_string ),
    str( col_sp('n','x{14}','x{7f}','x{9b}') ),
    "Testing 'nonlatin1' control characters"
);

### all ###

use_ok (
    'Data::Printer',
        colored      => 1,
        print_escapes => 1,
        escape_chars => "all",
);

is(
    p( $string ),
    str(
        color('bright_red')
        . join('',map { (sprintf '\x{%02x}', ord($_)) } split //, $string)
        . color('bright_yellow')
    ),
    "Testing 'all'"
);

done_testing;
