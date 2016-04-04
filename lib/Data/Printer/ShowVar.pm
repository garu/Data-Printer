package Data::Printer::ShowVar;
use strict;
use warnings;

use Term::ANSIColor qw(color colored);
use Carp qw(croak);
use Cwd ();
use File::Basename ();
use File::Spec;
use List::Util qw(any first);

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
    #   in "caller 3", for "xx" equal to an integer representing the
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
    my ( $p, $filename, $lineno, $line, $caller ) = @_;

    # Determine if we were called as "Data::Printer::p", or as
    # "Data::Printer::p_without_prototypes"
    my $called_as = $caller->[3]; 

    if ( !defined $line ) {
        if ( !defined $filename ) {
            return _quote('??');
        }
        $line = _get_caller_source_line( $filename, $lineno );
        if ( !defined $line ) {
            return _quote("<Could not read file '$filename'>");
        }
    }
    my ( $valid_callers, $proto ) = _get_valid_callers( $p, $called_as );
    if (defined $valid_callers ) {
        my $doc = _get_ppi_document( \$line );
        if ( defined $doc ) {
            $line = _parse_line( $doc, $line, $called_as, $valid_callers, $proto );
        }
    }
    return _quote( $line );
}

sub _get_valid_callers {
    my ( $p, $called_as ) = @_;

    my @pp; my @pnp;
    if ( defined (my $alias = $p->{alias} ) ) {
        push @pp, $alias;
    }
    push @pp, 'Data::Printer::p', 'p';
    push @pnp, 'Data::Printer::p_without_prototypes', 'p_without_prototypes';

    my $proto;
    my $valid_callers;
    if ( any { $_ eq $called_as } @pp ) {
        $valid_callers = \@pp;
        $proto = 1;
    }
    elsif ( any { $_ eq $called_as } @pnp ) {
        $valid_callers = \@pnp;
        $proto = 0;
    }
    return ($valid_callers, $proto );
}

# Parse line, and extract variable name to be printed.
# Default behavior if we cannot determine a variable name is to use $line.
# This default should still be better than not printing anything! 
#
# Example: if $line is
#
#    "p(%some_hash, colored => 1); # print some_hash"
#
# we should be able to reduce this to "%some_hash":
#
# Note: currently the input variable "$proto" is not used.
sub _parse_line {
    my ( $doc, $orig_line, $called_as, $valid_callers, $proto ) = @_;

    # If line contains multiple statements, determine which one to use:
    ( my $line, my $statement, my $node, $called_as ) 
      = _extract_statement_from_line( $doc, $orig_line, $called_as, $valid_callers );

    my $children = $node->schildren;
    my $elem = $node->find_first(
        sub { ($_[1]->name eq 'Token::Word') and ($_[1]->content eq $called_as) }
    );
    if ( $elem ) {
        $elem = $elem->snext_sibling;
        if ( $elem ) {
            $line = _parse_var( $elem, $line );
        }
    }

    # It is not necessary to display a trailing semicolon.
    # (It will only act as "noise" in the output..)
    $line =~ s/\s*;?\s*$//;

    return $line;
}

# Determine the the first argument (usually a variable, but could also be an
# expression) of the original caller, i.e. p() or p_without_prototypes(). 
# Currently we are able to parse the sought variable name the same way regardless
# of whether the caller was p() or p_without_prototypes(). This is due to the way
# PPI parses the line.
sub _parse_var {
    my ( $elem, $orig_line ) = @_;

    if ( $elem->name eq 'Structure::List' ) {
        $elem = _enter_list_structure( $elem );
        return $orig_line if !$elem; 
    }
    my $line = "";
    while ( $elem ) {
        ($elem, $line) = _skip_to_next_token( $elem, $line );
    }
    return $line;
}

sub _enter_list_structure {
    my ( $elem ) = @_;
    $elem = ( $elem->schildren )[0];
    return undef if !$elem;
    if ( any { $elem->name eq $_ } qw(Statement Statement::Expression) ) {
        $elem = ( $elem->schildren )[0];
    }
    return $elem;
}

sub _skip_to_next_token {
    my ( $elem, $line ) = @_;
    while (1) {
        $line .= $elem->content;
        $elem = $elem->next_sibling;
        last if !$elem;
        if ( $elem->is_comma_or_semi_colon ) {
            $elem = undef;
            last;
        }
        last if $elem->significant;
    }
    return ($elem, $line);
}


#
sub _extract_statement_from_line {
    my ( $doc, $orig_line, $called_as, $valid_callers ) = @_;

    my ($statements, $num_statements) = _get_top_level_statements( $doc );

    my $statement;
    my $node;
    my $line = $orig_line;
    
    if ( $num_statements >= 1 ) {
        ($statement, $node, $called_as) 
          = _select_statement( $statements, $called_as, $valid_callers );
        if ( defined $statement ) {
            $line = $statement->content;
        }
    }
    return ( $line, $statement, $node, $called_as );
}

sub _select_statement {
    my ( $statements, $called_as, $valid_callers ) = @_;

    my $found_statement;
    my $node;
    for my $statement (@$statements) {
        my $words = $statement->find('PPI::Token::Word');
        my $found_word = first {
            my $word = $_->content; any { $_ eq $word } @$valid_callers
        } @$words;
        if ( defined $found_word ) {
            $node = $found_word->parent;
            $found_statement = $statement;
            $called_as = $found_word->content;
            last;
        }
    }
    return ($found_statement, $node, $called_as);
}

# We choose to only focus on simple statements with p() and p_without_prototypes()
# Two classes of PPI statements are supported:
#
# PPI::Statement :
#
#  - p $var, p @var, p %h, ...
#  - p ( $var ), p ( $var, colored => 0 ), ...
#  - p_without_prototypes "Hello", p_without_prototypes [ 1, 3, 5 ], ..
#
# PPI::Statement::Variable : these are relevant when option "return_value" is 'dump' or
#   'pass' . Examples:
#
#  my $var = p $var, ...
#
#
sub _get_top_level_statements {
    my ( $ref ) = @_;

    my @items;
    for my $child ( @{ $ref->{children} } ) {
        if ( ((ref $child) eq 'PPI::Statement')
             or ((ref $child) eq 'PPI::Statement::Variable') ) {
            push @items, $child;
        }
    }
    return (\@items, scalar @items);
}

# Use PPI to parse the source line.
#
# This approach (using PPI) is admittedly somewhat heavy, but no good
# alternative has yet to be found, though many interesting approaches was found on CPAN,
# but as far as I can see, none of those seems perfect either:
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
{
    my $is_initialized; 
    sub _get_ppi_document {
        my ( $line ) = @_;
    
        if ( !$is_initialized ) {
            require PPI;
            _setup_ppi_extensions();
            $is_initialized = 1;
        }
        my $temp_line = $$line;
        _add_trailing_semicolon( \$temp_line );
        my $doc = PPI::Document->new( \$temp_line );
        return _check_doc_complete( $doc );
    }
}

sub _add_trailing_semicolon {
    my ( $line ) = @_;

    if ( $$line !~ /;\s*$/ ) {
        $$line .= ';';
    }
}

sub _setup_ppi_extensions {
    require Data::Printer::PPI::Extensions;
    no strict "refs";
    for (qw( is_comma_or_semi_colon name)) {
        *{"PPI::Element::$_"} = \&{"Data::Printer::PPI::Extensions::$_"};
    }
}

# Checks if the line we read from the source file is complete. That is, if
# it consists of one or more valid Perl statements. Examples of invalid lines:
#
#   p $a; my %h = (
#
# This line is not valid since the second statement (my %h = ... ) is not complete.
# (It is completed on the following lines (not shown)); another example:
#
#   };  p $var;
#
# In this case, the preceding source lines (not shown) defines a hash or a sub,
# which is completed on this line ( '};' ).
#
#    p { a=> 1, 
#
# In this example (assuming use_protypes = 0 ), the hash is not completed on the
# given source line..
#
# These cases can be handled by reading additional lines before or after the
# given source line until the complete() function of PPI::Document returns true.
# 
# However, currently only source lines with one (or more) complete statement are
# handled. ( Support for statements extending
# over multiple lines should be straightforward to implement though, if needed. )
#
# If the line contains a single Perl statement, it is known that that statement
# is the correct one ( the one that caused the call to Data::Printer::p() )
#
# If the line contains multiple Perl statements, we must determine which of
# the statements is the correct one. In this case, a currently crude method is
# is used to determine the correct statement: The statements in the
# PPI::Document are traversed one by one and the first one that
# matches (caller())[3] is selected.
#
#
sub _check_doc_complete {
    my ( $doc ) = @_;

    if ( $doc->complete ) {
        return $doc;
    }
    else {
        return undef;
    }
}

sub _quote {
    my ( $str ) = @_;

    return '"' . $str . '"';
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
