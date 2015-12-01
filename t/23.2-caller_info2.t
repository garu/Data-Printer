use strict;
use warnings;

BEGIN {
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use Term::ANSIColor;
};

use Test::More;
use Test::Output;
use Data::Printer
  return_value   => 'pass',
  colored        => 0,
  caller_info    => 1,
  caller_message => 'Printing __VAR__ in line __LINE__ of __FILENAME__:';


my $var = 3;
my @some_array = ( 1.. 3 );

# Try capture simple variable
stderr_like
  sub {eval 'p $var'},
  _get_expect_regex('$var'),
  "no parens capture";

# Try capture variable in parenthesis
stderr_like
  sub{ eval 'p( $var )'},
  _get_expect_regex('$var'),
  "parens capture";

# Two statements:  "my $aa = 1; p $var;"
#  -> it would be possible to capture '$var' here, but it is not implemented yet, so
#     we capture the whole line.
stderr_like
  sub {eval 'my $aa = 1; p $var'},
  _get_expect_regex('my $aa = 1; p $var'),
  "two statements";

# Do not print anything for np command
stderr_is
  sub {eval 'my $str = np @some_array'},
  "",
  "no print";

# Assignment statement:  "my $str = p @some_array;"
#  -> captures '@some_array'
stderr_like
  sub {eval 'my $str = p @some_array'},
  _get_expect_regex('@some_array'),
  "assignment";

# Multiple arguments to 'p' command: Capture correct argument '$var'
stderr_like
  sub {eval 'p($var, colored => 0)'},
  _get_expect_regex('$var'),
  "multiple args";

# Statement with a comment at the end of the line:  "p $var; # p $b"
#  -> ignores comment, and capture '$var'
stderr_like
  sub {eval 'p $var; # p $b'},
  _get_expect_regex('$var'),
  "end of line comment";

# Printing return values from function calls
#  -> should *not* capture arguments to the function call, but rather the whole
#     statement
stderr_like
  sub {eval 'p _my_sub( $var )'},
  _get_expect_regex('p _my_sub( $var )'),
  "print return value from function call";

done_testing;

sub _get_path { my (undef, $filename) =caller; return $filename }

sub _get_expect_regex {
    my ( $str) = @_;

    my $expect1 = 'Printing "' . $str . '" in line ';
    my $expect2 = ' of ' . _get_path() . ":\n";
    return qr/^\Q$expect1\E\d+\Q$expect2\E/;
}

sub _my_sub {
    my ( $var ) = @_;

    return ++$var;
}
