use strict;
use warnings;

BEGIN {
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use Term::ANSIColor;
};

use Carp;
use Cwd ();
use File::Basename ();
use File::Spec;
use File::Temp ();
use Test::More;
use Test::Output;

_update_inc();

# Try capture simple variable
_test( 'p $var', 'no parens capture', expect => '$var' ); 

# Try capture variable in parenthesis
_test( 'p( $var )', 'parens capture', expect => '$var' );

# Two statements:  "my $aa = 1; p $var;"
#  -> it would be possible to capture '$var' here, but it is not implemented yet, so
#     we capture the whole line.
_test( 'my $aa = 1; p $var', 'two statements', expect => '$var');

# Do not print anything for np command
_test( 'my $str = np @a', 'no print', expect => '', exact_match => 1 );

# Assignment statement:  "my $str = p @a;"
#  -> captures '@a'
_test( 'my $str = p @a', 'assignment', expect => '@a' );

# Multiple arguments to 'p' command: Capture correct argument '$var'
_test( 'p($var, colored => 0)', 'multiple args', expect => '$var' );

# Statement with a comment at the end of the line:  "p $var; # p $b"
#  -> ignores comment, and capture '$var'
_test( 'p $var; # p $b', 'end of line comment', expect => '$var' );

# Printing return values from function calls
#  -> should *not* capture arguments to the function call, but rather the whole
#     statement
_test(  'p _my_sub( $var )',  'print return value from function call',
    expect => '_my_sub( $var )'
);

# Incomplete statement. This is the case where a statement straddles multiple
# lines. This is not implemented yet, and we should get back only the part of
# the statement ( the part that is on the line that contains the function call).
#  Note: for "eval", PPI will have access to both lines, so it
#  will work correctly..
_test( 'my $a = 3; pwp [1,2,' . "\n" . '3]', 'Incomplete statement',
       expect => 'my $a = 3; pwp [1,2,',
       expect_eval => '[1,2,' . "\n" . '3]',
);

# No proto type: string
_test( 'pwp "Hello"', 'No proto: string', expect => '"Hello"' );

# No proto type: array
_test( 'pwp [1,2, 6]', 'No proto type: array', expect => '[1,2, 6]' );

# Nested printer call 1
_test( 'my @aa = (2, (p $var), 3)', 'Nested call 1', expect => '$var' );

# Nested printer call 2
_test( 'my @aa = (2, p ($var), 3)', 'Nested call 2', expect => '$var' );

# Reference to hash
_test( 'pwp \%h', 'reference to hash', expect => '\%h' );

# Reference to scalar
_test( 'pwp \my $var2', 'reference to scalar', expect => '\my $var2' );

# Array subscript 1
_test( 'p $a[2]', 'Array subscript 1', expect => '$a[2]' );

# Array subscript 2
_test( 'p $ar->[2]', 'Array subscript 2', expect => '$ar->[2]' );

# Hash subscript 1
_test( 'p $h{b}{c}', 'Hash subscript 1', expect => '$h{b}{c}' );

# Hash and array subscript
_test( 'p $hr->{b}[$var - 2]', 'Hash and array subscript',
       expect => '$hr->{b}[$var - 2]'
);

# Func call through reference
_test( 'p $f->( $var, 4 )', 'Func call through reference',
       expect => '$f->( $var, 4 )'
);

# Package variable
_test( 'p $Data::Printer::VERSION', 'Package variable',
       expect => '$Data::Printer::VERSION'
);

# Array reference
_test( 'p @$ar', 'Array reference', expect => '@$ar' );

# two statements in one
_test( 'print STDERR "var=$var\n" && p @a', 'Two-in-one', expect => '@a' );

# Nested parenthesis
_test( 'pwp (($var + (2  - 5)))', 'Nested parenthesis',
       expect => '($var + (2  - 5))'
);


done_testing;

exit;

# Update %INC with the path to the Data::Printer module..
# we need this for some of the tests..
sub _update_inc {
    require Data::Printer;
}

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
    my $pwp_alias;
    BEGIN { $pwp_alias = 'Data::Printer::p_without_prototypes' };
    sub _test {
        my ( $statement, $test_name, %opt ) = @_;
        $statement =~ s/pwp/$pwp_alias/;
        $statement .= ';';
        if ( exists $opt{expect} ) {
            $opt{expect} =~ s/pwp/$pwp_alias/;
        }
        else {
            $opt{expect} = $statement;
        }
        $opt{exact_match} //= 0;
        if ( not defined $temp_dir ) { # initialize state variable $temp_dir
            $temp_dir = _get_temp_dir();
        }
        my $func = ($opt{exact_match} ? \&stderr_is : \&stderr_like );
        my @args = ( $temp_dir, $statement, $test_name,
                     $opt{expect}, $opt{exact_match}, $func );
        if ( exists $opt{expect_eval} ) {
            $opt{expect_eval} =~ s/pwp/$pwp_alias/;
        }
        else {
            $opt{expect_eval} = $opt{expect};
        }
        _test1( @args, $opt{expect_eval} );
        _test2( @args );
        _test3( @args );
        _test4( @args );
    }
}

{
    # We will require a different module name for each test.
    # (Alternatively, we could use the same module name for each test
    #  and use Class::Unload to delete the previous module)
    # We use the state variable $counter to keep track of the different modules
    my $counter;
    
    # This test creates a module DataPrinterTestHelperModuleX (where X is
    # an integer) in the temp directory. Then it "require" that module
    # and call its "func" sub routine.
    sub _test1 {
        my ( $temp_dir, $statement, $test_name, $expect_noeval,
             $exact_match, $func, $expect_eval ) = @_;
        if ( not defined $counter ) { # intitalize state variable $counter
            $counter = 1;
        }
        for my $i (1..2) {
            my $module_name = 'DataPrinterTestHelperModule' . $counter++;
            my $fn = _create_test_helper_module(
                $temp_dir, $statement, $module_name, eval => $i - 1,
            );
            my $test_info = ( $i == 1 ? 'module' : 'eval' );
            my $expect = ( $i == 1 ? $expect_noeval : $expect_eval );
            $func->(
                \&{"$module_name" . "::func"},
                $exact_match
                    ? $expect
                    : _get_expect_regex( $expect, $fn ),
                $test_name . " ($test_info) ",
            );
        }
    }
}

# Run script in temp dir in two ways:
#  a) Absolute path : system 'perl', '/tmp/script.pl'
#  b) Relative path : system 'perl', 'tmp/script.pl'
sub _test2 {
    my ( $temp_dir, $statement, $test_name, $expect, $exact_match, $func ) = @_;

    my $cmd1 = _create_script1( $temp_dir, $statement  );
    my $dir1 = Cwd::getcwd();
    my ( $cmd2, $dir2 ) = _get_script_start_dir( $cmd1 );
    my @cmds = ( $cmd1, $cmd2 );
    my @dirs = ( $dir1, $dir2 );
    for (0..1) {
        my $cmd = $cmds[$_];
        chdir $dirs[$_];
        $func->(
            sub { system 'perl', $cmd },
            $exact_match ? $expect : _get_expect_regex( $expect, $cmd ),
            $test_name . " (separate script $_) ",
        );
    }
    chdir $dir1;
}

# Run script in temp dir that includes a module "My::Module" relative to the
# temp dir. Only the module loads Data::Printer.
sub _test3 {
    my ( $temp_dir, $statement, $test_name, $expect, $exact_match, $func ) = @_;

    my $curdir = Cwd::getcwd();
    chdir $temp_dir;
    my ( $cmd, $module_name ) = _create_script2( $statement  );
    $func->(
        sub { system 'perl', $cmd },
        $exact_match ? $expect : _get_expect_regex( $expect, $module_name ),
        $test_name . " (separate script 2) ",
    );
    chdir $curdir;
}

# Run script in temp dir that uses Data::Printer, then chdir() to new dir and
# later "require" a module "My::Module" (relative to temp dir) that also uses
# Data::Printer.
sub _test4 {
    my ( $temp_dir, $statement, $test_name, $expect, $exact_match, $func ) = @_;

    my $curdir = Cwd::getcwd();
    chdir $temp_dir;
    my ( $cmd, $module_name ) = _create_script3( $statement  );
    my $expect_regex = qr/\Q<Could not read file '\E$module_name\Q'>\E/;
    $func->(
        sub { system 'perl', $cmd },
        $exact_match ? $expect : $expect_regex,
        $test_name . " (separate script 3) ",
    );
    chdir $curdir;
}

# Convert path name like /tmp/test/p.pl to test/p.pl
sub _get_script_start_dir {
    my ( $cmd ) = @_;

    my $cmd1 = File::Basename::basename( $cmd );
    my $dir1 = File::Basename::dirname( $cmd );
    my $dir2 = File::Basename::dirname( $dir1 );
    my $cmd2 = File::Spec->catfile( $dir1, $cmd1 );
    return ( $cmd2, $dir2 );
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


{
    my $decl_str;
    BEGIN {
        $decl_str = <<"END_STR";
my \$var = 3;
my \@a = ( 1.. 3 );
my \%h = ( a=>1, b=>{c=>1} );
my \$ar = [1,2,3];
my \$hr = { a=>1, b=>[4,5] };
my \$f = \\&_my_sub
END_STR
    };

    sub _get_script_var_decl {
        return $decl_str;
    }
}

{
    my $sub_def;
    BEGIN {
        $sub_def = <<"END_STR";
sub _my_sub {
    my ( \$var ) = \@_;

    return ++\$var;
}

END_STR
    };

    sub _get_script_sub_def {
        return $sub_def;
    }
}

{
    my $use_str;
    BEGIN {
        $use_str = <<"END_STR";
use Data::Printer 
{
    return_value   => 'pass',
    colored        => 0,
    caller_info    => 1,
    caller_message => 'Printing __VAR__ in line __LINE__ of __FILENAME__:'
}

END_STR
    };

    sub _get_script_use_str {
        return $use_str;
    }
}

sub _create_script1 {
    my ( $temp_dir, $statement  ) = @_;

    my $mod_path = File::Basename::dirname( $INC{'Data/Printer.pm'} );
    $mod_path = File::Basename::dirname( $mod_path );
    my $var_decl = _get_script_var_decl();
    my $sub_def = _get_script_sub_def();
    my $use_dataprinter = _get_script_use_str();
    my $script =  <<"END_SCRIPT";
use strict;
use warnings;

use lib '$mod_path';

BEGIN {
    delete \$ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use Term::ANSIColor;
};

$use_dataprinter;

$var_decl;

$statement;

$sub_def

END_SCRIPT

    my $fn = File::Spec->catfile( $temp_dir, 'test_script1.pl' ); 
    #if ( -e $fn ) {
    #    unlink $fn;
    #}
    open ( my $fh, '>', $fn ) or die "Could not open file '$fn': $!";
    print $fh $script;
    close $fh;
    return $fn;
}


sub _create_script2 {
    my ( $statement  ) = @_;

    my $module_dir = 'My';
    my $module_base_name = 'Module';
    my ( $module_name, $module_name_perl ) 
         = _write_test_module( $statement, $module_base_name, $module_dir );
    
    my $script =  <<"END_SCRIPT";
use strict;
use warnings;

# Note: the current directory '.' is usually included in \@INC, but it could be
#   at the end of \@INC.. The following command ensures that the current
#   directory is at the beginning of \@INC
use lib '.';  
use $module_name_perl;

${module_name_perl}::func();

END_SCRIPT

    my $fn = 'test_script2.pl';
    #if ( -e $fn ) {
    #    unlink $fn;
    #}
    open ( my $fh, '>', $fn ) or die "Could not open file '$fn': $!";
    print $fh $script;
    close $fh;
    return ( $fn, $module_name );
}

sub _create_script3 {
    my ( $statement  ) = @_;

    my $dummy_dir = 'dummy_folder';
    if ( ! -e $dummy_dir ) {
        mkdir $dummy_dir or croak "Could not create directory: $!";
    }
    my $test_dir = 'test';
    if ( ! -e $test_dir ) {
         mkdir $test_dir or croak "Could not create directory: $!";
    }
    chdir $test_dir;
    my $module_dir = 'My';
    my $module_base_name = 'Module2';
    my ( $module_name, $module_name_perl ) 
        = _write_test_module( $statement, $module_base_name, $module_dir );
    chdir '..';
    my $use_dataprinter = _get_script_use_str();
    my $script =  <<"END_SCRIPT";
use strict;
use warnings;

# Note: the current directory '.' is usually included in \@INC, but it could be
#   at the end of \@INC.. The following command ensures that the current
#   directory is at the beginning of \@INC
use lib '.';  

BEGIN {
    delete \$ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use Term::ANSIColor;
};

$use_dataprinter;

chdir '$test_dir';

eval 'use $module_name_perl';

chdir '..';
chdir '$dummy_dir';

${module_name_perl}::func();

END_SCRIPT

    my $fn = 'test_script3.pl';
    open ( my $fh, '>', $fn ) or die "Could not open file '$fn': $!";
    print $fh $script;
    close $fh;
    return ( $fn, $module_name );
}

sub _write_test_module {
    my ( $statement, $base_name, $dir  ) = @_;

    my $name = $dir . '::' . $base_name;
    my $mod_path = File::Basename::dirname( $INC{'Data/Printer.pm'} );
    $mod_path = File::Basename::dirname( $mod_path );
    my $var_decl = _get_script_var_decl();
    my $sub_def = _get_script_sub_def();
    my $use_dataprinter = _get_script_use_str();

    my $script =  <<"END_SCRIPT";
package $name;

use strict;
use warnings;
use lib '$mod_path';

$use_dataprinter;

sub func {
  $var_decl;
  
  $statement
}

$sub_def

1;
END_SCRIPT

    my $fn = $name;
    $fn =~ s/::/\//g;
    $fn .= '.pm';
    if ( ! -e $dir ) {
         mkdir $dir or croak "Could not create directory: $!";
    }
    open ( my $fh, '>', $fn ) or die "Could not open file '$fn': $!";
    print $fh $script;
    close $fh;
    return ( $fn, $name );
}


sub _create_test_helper_module {
    my ( $temp_dir, $statement, $module_name, %opt ) = @_;

    $opt{eval} //= 0;
    if ( $opt{eval} ) {
        $statement = "eval '$statement'";
    }
    my $var_decl = _get_script_var_decl();
    my $sub_def = _get_script_sub_def();
    my $use_dataprinter = _get_script_use_str();

    my $script =  <<"END_SCRIPT";
package $module_name;

use strict;
use warnings;

$use_dataprinter;

sub func {
  $var_decl;
  $statement
}

$sub_def

1;
END_SCRIPT
    my $fn = File::Spec->catfile( $temp_dir, $module_name . '.pm' ); 
    open ( my $fh, '>', $fn ) or die "Could not open file '$fn': $!";
    print $fh $script;
    close $fh;
    require $fn;
    return $fn;
}

