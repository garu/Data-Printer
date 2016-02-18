use strict;
use warnings;

BEGIN {
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use Term::ANSIColor;
};

use Carp;
use File::Temp ();
use Test::More;
use Test::Output;

# Try capture simple variable
_test( 'p $var', 'no parens capture', expect => '$var' ); 

# Try capture variable in parenthesis
_test( 'p( $var )', 'parens capture', expect => '$var' );

# Two statements:  "my $aa = 1; p $var;"
#  -> it would be possible to capture '$var' here, but it is not implemented yet, so
#     we capture the whole line.
_test( 'my $aa = 1; p $var', 'two statements');

# Do not print anything for np command
_test( 'my $str = np @some_array', 'no print', expect => '', exact_match => 1 );

# Assignment statement:  "my $str = p @some_array;"
#  -> captures '@some_array'
_test( 'my $str = p @some_array', 'assignment', expect => '@some_array' );

# Multiple arguments to 'p' command: Capture correct argument '$var'
_test( 'p($var, colored => 0)', 'multiple args', expect => '$var' );

# Statement with a comment at the end of the line:  "p $var; # p $b"
#  -> ignores comment, and capture '$var'
_test( 'p $var; # p $b', 'end of line comment', expect => '$var' );

# Printing return values from function calls
#  -> should *not* capture arguments to the function call, but rather the whole
#     statement
_test( 'p _my_sub( $var )', 'print return value from function call' );

done_testing;

# Note that Test::Output functions like 'stderr_like' takes a subroutine
#  reference as the first argument. Given a Data::Printer command in string form
#  like 'p $var', we would like to generate such a subroutine automatically.
#  That is, we would like avoid having a long list of hardcoded subroutines
#  'writer1()', 'writer2()', ..., and so on.  There seems to be two ways to
#  achieve this:
#
#  1) Use eval. Example:
#
#    sub get_func {
#        my ($str) = @_;
#        return sub {eval "$str"};
#    }
#
#    This has the side-effect of evaluating the Data::Printer command in 'eval'-
#    context.. which means that the filename of the original source cannot be
#    determined from the perl 'caller()' function..
#
#  2) Generate a test module at runtime (in a tempdir) containing a test
#  subroutine with the code. Then require that module. Then call the test
#  subroutine of the module. This procedure avoids using eval.. and the caller
#  environment of the Data::Printer command would be more similar to the one
#  in common use cases.
#
# Here, both methods are used.

{
    my $temp_dir; # state variable for _test() subroutine below
    
    # We will require a different module name for each test.
    # (Alternatively, we could use the same module name for each test
    #  and use Class::Unload to delete the previous module)
    # We use the state variable $counter to keep track of the different modules
    my $counter;
    
    sub _test {
        my ( $statement, $test_name, %opt ) = @_;
        if ( not defined $temp_dir ) { # initialize state variable $temp_dir
            $temp_dir = _get_temp_dir();
        }
        if ( not defined $counter ) { # intitalize state variable $counter
            $counter = 1;
        }
        $opt{expect} //= $statement;
        $opt{exact_match} //= 0;
        my $func = ($opt{exact_match} ? \&stderr_is : \&stderr_like );
        for my $i (1..2) {
            my $module_name = 'DataPrinterTestHelperModule' . $counter++;
            my $fn = _create_test_helper_module(
                $temp_dir, $statement, $module_name, eval => $i - 1,
            );
            my $test_info = ( $i == 1 ? 'eval' : 'module' );
            $func->(
                \&{"$module_name" . "::func"},
                $opt{exact_match}
                    ? $opt{expect}
                    : _get_expect_regex( $opt{expect}, $fn ),
                $test_name . " ($test_info) ",
            );
        }
    }
}

sub _get_temp_dir {
    my $tempdir;
    eval { 
        $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    };
    if ($@) {
        croak "Could not create temp dir: $@";
    }
    return $tempdir;
}

sub _get_expect_regex {
    my ( $str, $fn ) = @_;

    my $expect1 = 'Printing "' . $str . '" in line ';
    my $expect2 = ' of ' . $fn . ":\n";
    return qr/^\Q$expect1\E\d+\Q$expect2\E/;
}


sub _create_test_helper_module {
    my ( $temp_dir, $statement, $module_name, %opt ) = @_;

    $opt{eval} //= 0;
    if ( $opt{eval} ) {
        $statement = "eval '$statement'";
    }

    my $script =  <<"END_SCRIPT";
package $module_name;

use strict;
use warnings;

use Data::Printer 
{
    return_value   => 'pass',
    colored        => 0,
    caller_info    => 1,
    caller_message => 'Printing __VAR__ in line __LINE__ of __FILENAME__:'
};

sub func {
  my \$var = 3;
  my \@some_array = ( 1.. 3 );
  
  $statement
}

sub _my_sub {
    my ( \$var ) = \@_;

    return ++\$var;
}

1;
END_SCRIPT

    my $fn = File::Spec->catfile( $temp_dir, $module_name . '.pm' ); 
    open( my $fh, '>', $fn ) or die "Could not open file '$fn': $!";
    print $fh $script;
    close $fh;
    require $fn;
    return $fn;
}

