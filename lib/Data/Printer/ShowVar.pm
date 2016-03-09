package Data::Printer::ShowVar;
use strict;
use warnings;

use Term::ANSIColor qw(color colored);
use Test::More;
use Carp qw(croak);
use Cwd ();
use File::Basename ();
use File::Spec;

#
# For background regarding the below $initial_cwd variable, see
# http://www.perlmonks.org/?node_id=1156424
# https://rt.perl.org/Public/Bug/Display.html?id=127646
#
my $initial_cwd;
BEGIN {
    # This code is copied from FindBin::cwd2();
    $initial_cwd = Cwd::getcwd();
    # getcwd might fail if it hasn't access to the current directory.
    # try harder.
    defined $initial_cwd or $initial_cwd = Cwd::cwd();
}

sub handle_filename {
    my ( $line, $filename ) = @_;

    my $line_str = undef;
    my $eval_regex = qr/^\Q(eval\E/;
    my $filename_str = $filename;
    # Note : $filename will not be valid if we were called from "eval $str"..
    #   In that case $filename will be on the form "(eval xx)"..
    #   For example, for "eval 'p $var'", $filename will be "(eval xx)",
    #   in "caller 2", for "xx" equal to an integer representing the
    #   number of the eval statement in the source (as encountered on runtime).
    #
    #   For example, if this were the third "eval" encountered at runtime, xx
    #   would be 3. In this case, element 7 of "caller 3" will contain the
    #   eval-text, i.e. "p $var", and $filename and $line can also be recovered
    #   from "caller 3".  But not all cases allows the source line to be
    #   recovered. For example, for "eval 'sub my_func { p $var }'", and then a
    #   call to "my_func()", will set $filename to "(eval xx)", but now element
    #   7 of "caller 3" will no longer be defined. So in order to determine the
    #   source statement in "caller 2", one would need to parse the whole source
    #   using PPI and search for the xx-th eval statement, and then try to parse
    #   that statement to arrive at 'p $var'.. However, since the xx number
    #   refers to runtime code, it may not be the same number as in the source
    #   code... (Alternatively one could try use "B::Deparse" on "my_func")
    #
    if ( $filename =~ $eval_regex ) {
        #   Still try to determine $filename, by going one stack frame up:
        my @caller = caller 4;
        if ( $caller[1] =~ $eval_regex ) {
            # TODO: we do not currently handle recursive evals
            #   currently: simply bail out on determining the $filename
            $filename = undef;
            $filename_str = '??';
            $line = 0;
        }
        else {
            $filename = $caller[1];
            $filename_str = $caller[1];
            $line = $caller[2];
        }
        $line_str = $caller[6];  # this is the $str in "eval $str" (or may be undef)
        if ( defined $line_str ) {
            # seems like earlier versions of perl (< 5.20) adds a new line and a
            # semicolon to this string.. remove those
            $line_str =~ s/;$//;
            $line_str =~ s/\s+$//;
        }
    }
    return  ( $line, $filename, $line_str, $filename_str) ;
}

# This function reads line number $lineno from file $filename (if $line is undef).
#   If this function is called more than once for a given $filename, it still
#   rereads the file each time. So a possible improvement could be to store each
#   line of a file in private array the first time the file is read. Then
#   subsequent calls for the same $filename could simply lookup the line in the
#   array.
#
sub get_caller_print_var {
    my ( $p, $filename, $lineno, $line ) = @_;
    if ( !defined $line ) {
        if ( !defined $filename ) {
            return _quote('??');
        }
        $line = _get_caller_source_line( $filename, $lineno );
    }
    if ( !defined $line ) {
        return _quote("<Could not read file '$filename'>");
    }
    my $doc = _get_ppi_document( \$line );
    my ($statements, $num_statements) =
      _ppi_get_top_level_items( $doc, 'PPI::Statement' );

    # Default behavior is to use $new_line = $line. This default should still be better
    # than not printing anything! 
    my $new_line = $line;

    # It is not necessary to display a trailing semicolon.
    # (It will only act as "noise" in the output..)
    $new_line =~ s/;$//;
    
    # Next: try to do better than the default behavior
    # Example: if $line is
    #
    #    "p(%some_hash, colored => 1); # print some_hash"
    #
    # we are able to reduce this $line to "%some_hash" using the following:
    #
    if ( $num_statements == 1 ) {
        my $statement = $statements->[0];
        my $is_assignment_statement =
          (ref $statement) eq "PPI::Statement::Variable";
        my $symbols = $statement->find('PPI::Token::Symbol');
        my $num_symbols = ( $symbols ) ? scalar @$symbols : 0;
        my ($words, $num_words) =
          _ppi_get_top_level_items( $statement, 'PPI::Token::Word' );
        # Requiring $num_words == 1, avoids considering cases like
        #   p my_sub( $var );
        # In that case 'p' would be a word, and 'my_sub' would be a word,
        #  and we should *not* extract '$var' in this case.
        #  (This is because it is not the variable
        #  that is printed, rather 'my_sub( $var )' is printed..)
        if ( $num_words == 1 or $is_assignment_statement ) {
            # If the line contains a single top level statement, and
            # that statement contains a single PPI::Token::Symbol,
            # it is likely that that symbol is the name of the sought variable.
            if ( $num_symbols == 1 ) {
                $new_line = $symbols->[0]->content;
            }
            elsif ( $num_symbols == 2 ) {
                # otherwise, if there are two PPI::Token::Symbol's in the
                # statement, and the statement is a PPI::Statement::Variable
                # it is likely that the second symbol is the sought variable..
                # I.e., consider:
                #    my $res = p $var;
                # there are two symbols : '$res' and '$var', but we are interested
                # in the last one.
                if ( $is_assignment_statement ) {
                    $new_line = $symbols->[1]->content;
                }
            }
        }
    }
    return _quote( $new_line );
}

# We use PPI to parse the source line.
# Alternatives to using PPI are
#
#  - Using a source filter (Filter::Util::Call) as in Data::Dumper::Simple and
#    Debug::ShowStuff::ShowVar and let the filter parse the line using a regex
#    and then substitute it with another call to the data dumper function that
#    includes the variable names in the argument list
#
#  - Using PadWalker as in Devel::Caller and Data::Dumper::Names
#
#  - Using B::Deparse as in Data::Dumper::Lazy
#
#  - Using B::CallChecker and B::Deparse as in Debug::Show
#
# See also:
#  - perlmonks: "Displaying a variable's name and value in a sub"
#      http://www.perlmonks.org/?node_id=888088
#
sub _get_ppi_document {
    my ( $line ) = @_;
    
    require PPI;
    my $doc = PPI::Document->new( $line );
    #require PPI::Dumper;
    #my $dumper = PPI::Dumper->new( $doc );
    #$dumper->print;

    return $doc;
}

sub _quote {
    my ( $str ) = @_;

    return '"' . $str . '"';
}

sub _ppi_get_top_level_items {
    my ( $ref, $class_name ) = @_;

    my @items;
    for my $child ( @{ $ref->{children} } ) {
        if ($child->isa( $class_name ) ) {
            push @items, $child;
        }
    }
    return (\@items, scalar @items);
}

sub _get_caller_source_line {
    my ( $filename, $lineno ) = @_;
    
    $filename = _get_abs_filename( $filename );
    my $open_success = open ( my $fh, '<', $filename );
    if ( !$open_success ) {
        ## croak "Could not open file '$filename': $!";
        # We do not want to terminate the program simply
        # because the file cannot be read. Instead return 'undef'
        # to signal that we failed to read the file.
        return undef;
    }
    my $line;
    do { $line = <$fh> } until $. == $lineno || eof;
    close $fh;
    chomp $line;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    return $line;
}

sub _get_abs_filename {
    my ( $filename ) = @_;

    # Note: $filename can be absolute or relative.
    # A difficulty of determining the absolute path of $filename arises
    # if $filename is relative:
    #
    # - If $filename is equal to $0, then $filename is relative
    #   to the initial current directory at the time the main Perl script was run. 
    #   This directory may not be equal to the current directory at this point.
    #   The absolute path of $0 can be recovered using $FindBin::Bin,
    #   but we choose to not use $FindBin::Bin, since $FindBin::Bin does not expose
    #   the initial current directory (it rather exposes the directory of the main
    #   script $0, for example if we run from command line: "perl ./test/prog.pl", then
    #   the initial current directory is what '.' would expand to at the time the script
    #   prog.pl was run, whereas the directory of the main script ($0, here: 'prog.pl')
    #   would be '/test/'),  which we will need if $filename is different
    #   from $0 (that is: a module or a another Perl file loded with "do $filename;").
    #
    # - If $filename is not equal to $0, which would be the case for
    #    * a "require $filename" (implicitly called for any "use ModuleName"
    #      statement) or a "do $filename", and
    #    * ( for a required file) the corresponding entry in @INC
    #      is a relative pathname,
    #   then $filename is relative to the current directory at the time the module
    #   was loaded (which again, might not be equal to the current directory at
    #   this point. Also, for a required file at run time ( not at compile time )
    #   the current directory at the time the module was loaded need not be equal
    #   to the initial current directory ( as used to recover $0, see above )
    #
    if ( !File::Spec->file_name_is_absolute( $filename ) ) {
        # NOTE: variable $initial_cwd below is a lexical variable defined
        #    outside the scope of this subroutine 
        #
        # The following recovery of the absolute $filename should work for most
        #  cases. It may still not work however, in the following cases:
        #
        #  1. This module (i.e. Data::Printer) is loaded at compile time, but later,
        #     at run time, a module M is loaded that also uses Data::Printer. If M is
        #     loaded based on a relative path in @INC, and if the current
        #     directory has changed since Data::Printer was loaded at compile time,
        #     it could be unclear what the absolute path of M would be. If the path
        #     cannot be recoverd with $initial_cwd, we also try the current
        #     directory (see below). However, if the current directory has changed
        #     since module M was loaded, at the time when a Data::Printer::p()
        #     command is executed, that will also fail.
        #
        #  2. This module is loaded at compile time with a "use Data::Printer"
        #     statement, and either
        #    -  the initial current directory is changed *earlier* at compile
        #       time. That is, in a BEGIN {} block which is executed before
        #       $initial_cwd in Data::Printer has been defined. Then $initial_cwd
        #       may be wrong for some of the  modules loaded before Data::Printer, or
        #    -  the initial current directory is changed *after* at compile
        #       time (or run time). That is, the current directory is changed after
        #       $initial_cwd in Data::Printer has been defined. Then $initial_cwd
        #       may be wrong for some of the modules loaded after Data::Printer (and
        #       that also "use"s Data::Printer).
        #
        #       Note: the above point assumes (at least) that the current directory
        #       is changed nonlocally (chdir() is called, and and not reset immediately
        #       after) at compile time. This is considered very unlikely to happen.
        #
        #
        # NOTE: Maybe all these problems could have been avoided if __FILE__
        #   and caller() had avoided using relative path names. A ticket has been
        #   submitted, see: https://rt.perl.org/Public/Bug/Display.html?id=127646
        #
        my $fn_abs = File::Spec->rel2abs( $filename, $initial_cwd );
        if ( ! -e $fn_abs ) {
            # Assume $filename is relative to current directory if it is not relative
            # to $initial_cwd. Note: Cwd::abs_path( $filename ) would fail if a
            # directory component of $filename does not exist. See:
            #   http://stackoverflow.com/q/35876488/2173773
            # we therefore use: File::Spec->rel2abs()
            $fn_abs = File::Spec->rel2abs( $filename, '.' );
        }
        $filename = $fn_abs;
    }
    return $filename;
}

1;
