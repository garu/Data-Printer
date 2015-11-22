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


my $filepath = _get_path();

my $var = 3;
my @some_array = ( 1.. 3 );
my $str1 = "Printing ";
my $str2 = " in line ";
my $str3 = " of $filepath:\n";
my $expect1 = $str1 . '"$var"' . $str2;
my $expect2 = "${str3}${var}";
my $expect3 = $str1 . '"my $aa = 1; p $var;"' . $str2;
my $expect4 = $str1 . '"@some_array"' . $str2;
stderr_like sub {p $var}, qr/^\Q$expect1\E\d+\Q$expect2\E$/, "no parens capture";
stderr_like sub {p( $var )}, qr/^\Q$expect1\E\d+\Q$expect2\E$/, "parens capture";
stderr_like \&_writer1, qr/^\Q$expect3\E\d+\Q$expect2\E/, "two statements";
stderr_is sub {my $str = np @some_array}, "", "no print";
stderr_like \&_writer2, qr/^\Q$expect4\E\d+\Q$str3\E/, "assignment";
stderr_like sub {p($var, colored => 0)}, qr/^\Q$expect1\E\d+\Q$expect2\E$/, "multiple args";
stderr_like \&_writer3, qr/^\Q$expect1\E\d+\Q$expect2\E$/, "end of line comment";

done_testing;

sub _get_path { my (undef, $filename) =caller; return $filename }

sub _writer1 {
    my $aa = 1; p $var;
}

sub _writer2 {
    my $str = p @some_array;
}

sub _writer3 {
    p $var; # p $b
}
