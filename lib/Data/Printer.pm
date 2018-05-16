package Data::Printer;
use strict;
use warnings;
use Data::Printer::Object;
use Data::Printer::Common;
use Data::Printer::Config;

our $VERSION = '0.99_005';

my $rc_arguments;
my %arguments_for;

sub import {
    my $class = shift;

    _initialize();

    # export to the caller's namespace:
    my $caller = caller;

    # every time you load it, we override the version from *your* caller
    my $args;
    if (@_ > 0) {
        $args = @_ == 1 ? shift : {@_};
        Data::Printer::Common::_warn(
            'Data::Printer can receive either a hash or a hash reference'
        ) unless ref $args eq 'HASH';
    }
    $arguments_for{$caller} = $args;

    my $use_prototypes = exists $args->{use_prototypes}
            ? $args->{use_prototypes}
        : exists $rc_arguments->{$caller} && exists $rc_arguments->{$caller}{use_prototypes}
            ? $rc_arguments->{$caller}{use_prototypes}
        : exists $rc_arguments->{'_'}{use_prototypes}
            ? $rc_arguments->{'_'}{use_prototypes}
        : 1
        ;
    my $exported = ($use_prototypes ? \&p : \&_p_without_prototypes);

    my $imported = exists $args->{alias}
            ? $args->{alias}
        : exists $rc_arguments->{$caller} && exists $rc_arguments->{$caller}{alias}
            ? $rc_arguments->{$caller}{alias}
        : exists $rc_arguments->{'_'}{alias}
            ? $rc_arguments->{'_'}{alias}
        : 'p'
        ;

    { no strict 'refs';
        *{"$caller\::$imported"} = $exported;
        *{"$caller\::np"}        = \&np;
    }
}

sub _initialize {
    # potential race but worst case is we read it twice :)
    { no warnings 'redefine'; *_initialize = sub {} }
    $rc_arguments = Data::Printer::Config::load_rc_file();
}

sub np (\[@$%&];%) {
    my (undef, %properties) = @_;

    _initialize();

    my $caller = caller;
    my $args_to_use = _fetch_args_with($caller, \%properties);
    my $printer = Data::Printer::Object->new($args_to_use);
    my $ref = ref $_[0];
    if ($ref eq 'ARRAY' || $ref eq 'HASH' || ($ref eq 'REF' && ref ${$_[0]} eq 'REF')) {
        $printer->{_refcount_base}++;
    }
    return $printer->write_label . $printer->parse($_[0]);
}


sub p (\[@$%&];%) {
    my (undef, %properties) = @_;

    _initialize();

    my $caller = caller;
    my $args_to_use = _fetch_args_with($caller, \%properties);
    my $printer = Data::Printer::Object->new($args_to_use);
    my $ref = ref $_[0];
    if ($ref eq 'ARRAY' || $ref eq 'HASH' || ($ref eq 'REF' && ref ${$_[0]} eq 'REF')) {
        $printer->{_refcount_base}++;
    }
    my $output = $printer->write_label . $printer->parse($_[0]);

    return _handle_output($printer, $output, !!defined wantarray, $_[0]);
}

# This is a p() clone without prototypes. Just like regular Data::Dumper,
# this version expects a reference as its first argument. We make a single
# exception for when we only get one argument, in which case we ref it
# for the user and keep going.
sub _p_without_prototypes  {
    my (undef, %properties) = @_;

    my $item;
    if (!ref $_[0] && @_ == 1) {
        my $item_value = $_[0];
        $item = \$item_value;
    }

    _initialize();

    my $caller = caller;
    my $args_to_use = _fetch_args_with($caller, \%properties);
    my $printer = Data::Printer::Object->new($args_to_use);
    my $ref = ref( defined $item ? $item : $_[0] );
    if ($ref eq 'ARRAY' || $ref eq 'HASH' || ($ref eq 'REF'
        && ref(defined $item ? $item : ${$_[0]}) eq 'REF')) {
        $printer->{_refcount_base}++;
    }
    my $output = $printer->write_label . $printer->parse((defined $item ? $item : $_[0]));

    return _handle_output($printer, $output, !!defined wantarray, $_[0]);
}


sub _handle_output {
    my ($printer, $output, $wantarray, $data) = @_;

    if ($printer->return_value eq 'pass') {
        print { $printer->output_handle } $output . "\n";
        my $ref = ref $data;
        if (!$ref) {
            return $data;
        }
        elsif ($ref eq 'ARRAY') {
            return @$data;
        }
        elsif ($ref eq 'HASH') {
            return %$data;
        }
        elsif ( grep { $ref eq $_ } qw(REF SCALAR CODE Regexp GLOB VSTRING) ) {
            return $$data;
        }
        else {
            return $data;
        }
    }
    elsif ($printer->return_value eq 'void') {
        print { $printer->output_handle } $output . "\n";
        return;
    }
    else {
        if (!$wantarray) {
            print { $printer->output_handle } $output . "\n";
        }
        return $output;
    }
}

sub _fetch_args_with {
    my ($caller, $run_properties) = @_;

    my $args_to_use = {};
    if (keys %$rc_arguments) {
        $args_to_use = Data::Printer::Common::merge_options(
            $args_to_use, $rc_arguments->{'_'}
        );
        if (exists $rc_arguments->{$caller}) {
            $args_to_use = Data::Printer::Common::merge_options(
                $args_to_use, $rc_arguments->{$caller}
            );
        }
    }
    if ($arguments_for{$caller}) {
        $args_to_use = Data::Printer::Common::merge_options(
            $args_to_use, $arguments_for{$caller}
        );
    }
    if (keys %$run_properties) {
        $args_to_use = Data::Printer::Common::merge_options(
            $args_to_use, $run_properties
        );
    }
    return $args_to_use;
}

'Marielle, presente.';
__END__

=encoding utf8

=head1 NAME

Data::Printer - colored & full-featured pretty-print of Perl data structures and objects

=head1 SYNOPSIS

Want to see what's inside a variable in a complete, colored and human-friendly way?

    use DDP; p $var;
    use DDP; p $var, as => "This label will be printed too!";

    # no need to use '\' before arrays or hashes
    p @array;
    p %hash;

    # add '&' to pass anonymous arrays/hashes of variables:
    &p( [ $one, $two, $three ] );
    &p( { foo => $foo, bar => $bar } );

That's it :)

The snippets above will print the contents of the chosen variables to STDERR
on your terminal, with colors and a few extra features to help you debug
your code.

If you wish to grab the output and handle it yourself, call C<np()>:

    my $dump = np $var;

The C<np()> function is the same as C<p()> but will return the string
containing the dump. By default it has no colors, but you can change that
easily too.

Here are Data::Printer's main features:

=over 4

=item * Variable dumps designed for I<< easy parsing by the human brain >>,
not a machine.

=back

=over 4

=item * B<< Highly customizable >>, from indentation size to depth level.
You can even rename the exported C<p()> function!

=back

=over 4

=item * B<< Beautiful (and customizable) colors >> to highlight variable dumps
and make issues stand-out quickly on your console. Comes bundled with 4
themes for you to pick that work on light and dark terminal backgrounds,
and you can create your own as well.

=back

=over 4

=item * B<< Filters for specific data structures and objects >> to make
debugging much, much easier. Includes filters for several popular classes
from CPAN like JSON::\*, URI, HTTP::\*, LWP, Digest::\*, DBI and DBIx::Class.
Also lets you create your own custom filters easily.

=back

=over 4

=item * Lets you B<< inspect information that's otherwise difficult to find/debug >>
in Perl 5, like circular references, reference counting (refcount),
weak/read-only information, overloaded operators, tainted data, ties,
dual vars, even estimated data size - all to help you spot issues with your
data like leaks without having to know a lot about internal data structures
or install hardcore tools like Devel::Peek and Devel::Gladiator.

=back

=over 4

=item * B<< output to many different targets >> like files, variables or open
handles (defaults to STDERR). You can send your dumps to the screen
or anywhere else.

=back

=over 4

=item * keep your customized settings on a `.dataprinter` file that allows
B<< different options per module >> being analyzed!

=back

=over 4

=item * B<< Easy to learn, easy to master >>. Seriously, the synopsis above
and the customization section below cover about 90% of all use cases.

=back

=over 4

=item * Works on B<< Perl 5.8 and later >>. Because you can't control where
you debug, we try our best to be compatible with all versions of Perl 5.

=back

=over 4

=item * Best of all? All that with B<< No non-core dependencies >>,
Zero. Nada. So don't worry about adding extra weight to your project, as
Data::Printer can be easily added/removed.

=back

=head1 DESCRIPTION

The ever-popular Data::Dumper is a fantastic tool, meant to stringify
data structures in a way they are suitable for being "eval"'ed back in.
The thing is, a lot of people keep using it (and similar ones, like
Data::Dump) to print data structures and objects on screen for inspection
and debugging, and while you I<can> use those modules for that, it doesn't
mean you I<should>.

This is where Data::Printer comes in. It is meant to do one thing and one
thing only:

I<< format Perl variables and objects to be inspected by a human >>

If you want to serialize/store/restore Perl data structures, this module
will NOT help you. Try Storable, Data::Dumper, JSON, or whatever. CPAN is
full of such solutions!

Whenever you type C<use Data::Printer> or C<use DDP>, we export two functions
to your namespace:

=head2 p()

This function pretty-prints the contents of whatever variable to STDERR
(by default), and will use colors by default if your terminal supports it.

    p @some_array;
    p %some_hash;
    p $scalar_or_ref;

Note that anonymous structures will only work if you prefix C<p()> with C<&>.
Parenthesis also becomes mandatory:

    &p( [ $foo, $bar, $baz ] );
    &p( { foo => $foo, bar => $bar } );

You can pass custom options that will work only on that particular call:

    p @var, as => "some label", colorized => 0;
    p %var, show_memsize => 1;

By default C<p()> will print to STDERR and return the same variable being
dumped. This lets you quickly wrap variables with C<p()> without worrying
about changing return values. It means that if you change this:

    sub foo { my $x = shift + 13; $x }

to this:

    sub foo { my $x = shift + 13; p($x) }

The function will still return C<$x>. This form of handling data even allows
method chaining, so if you want to inspect what's going on in the middle of
this:

    $object->foo->bar->baz;

You can just add C<DDP::p> anywhere:

    $object->foo->DDP::p->bar->baz; # what happens to $object after ->foo?

Check out the L<customization|/CUSTOMIZATION> section below for all available
options so Data::Printer can show you exactly what you want, and output not
just to STDERR but to files and much more.

=head2 np()

The C<np()> function behaves exactly like C<p()> except it always returns
the string containing the dump (thus ignoring any setting regarding dump
mode or destination), and contains no colors by default. It is meant to
provide an easy way to fetch the dump and send it to some unsupported
target, or appended to some other text (like part of a bigger message):


=head1 CUSTOMIZATION

Passing arguments to C<p()> or C<np()> after the variable you are dumping
lets you quickly override any global/local settings. The options are only
used on that particular dump:

    p @var, colored => 0, show_refcount => 1;
    p $var, as => 'this is my dump', show_memsize => 1;

Passing arguments to your Data::Printer/DDP call provides local settings to
your current package. It lets you have different custom options that will be
active on all calls to C<p()> and C<np()> on that package (unless they are
overriden by passing arguments like shown above):

    package Foo;
        use DDP max_depth => 2, deparse => 1;

    package main;
        use DDP max_depth => 1, deparse => 0;

=head2 The .dataprinter file

The most powerful way to customize Data::Printer is to have a C<.dataprinter>
file in your home directory, which is a simple I<key = value> text file. It
lets you set global options to Data::Printer and custom options that will be
active only on C<p()>/C<np()> calls made inside a given module:

    # global settings
    max_depth       = 1
    theme           = Monokai
    class.stringify = 0

    # only active inside MyApp::Some::Module:
    [MyApp::Some::Module]
    max_depth    = 2
    class.expand = 0
    escape_chars = nonlatin1

Note that on the C<.dataprinter> file you separate suboptions with C<.>, so
"C<< class => { expand => 0, inherited => 'none' } >>" becomes
"C<< class.expand = 0 >>" and "C<< class.inherited = none >>", each on their
own line.

=head2 Properties Quick Reference

For a quick reference, below are all available properties and their
(hopefully sane) default values:

    # scalar options
    show_tainted      => 1,
    show_unicode      => 1,
    show_lvalue       => 1,
    print_escapes     => 0,
    scalar_quotes     => q("),
    escape_chars      => 'none', # (nonascii, nonlatin1 all)
    string_max        => 1024,
    string_preserve   => 'begin', # (end, middle, extremes, none)
    string_overflow   => '(...skipping __SKIPPED__ chars...)',
    unicode_charnames => 0,

    # array options
    array_max      => 50,
    array_preserve => 'begin', # end, middle, extremes, none
    array_overflow => '(...skipping __SKIPPED__ items...)',
    index          => 1,

    # hash options
    hash_max       => 50,
    hash_preserve  => 'begin', # end, middle, extremes, none
    hash_overflow  => '(...skipping __SKIPPED__ keys...)',
    ignore_keys    => [],
    hash_separator => '   ',
    align_hash     => 1,
    sort_keys      => 1,
    quote_keys     => 'auto', # 0, 1

    # general options
    name           => 'var', # the name to use for circular references
    return_value   => 'pass', # dump, void
    output         => 'stderr', # stdout, \$string, $filehandle
    use_prototypes => 1,
    indent         => 4,
    show_readonly  => 1,
    show_tied      => ???
    show_dualvar   => ???
    show_weak      => 1,
    show_refcount  => 0,
    show_memsize   => 0,
    memsize_unit   => 'auto' ('b', 'k', m)
    separator      => ',',
    end_separator  => 0,
    caller_info    => 0,
    caller_message => 'Printing in line __LINE__ of __FILENAME__',
    max_depth      => 0,
    deparse        => 0,

    # colorization (see Colors & Themes below)
    colored => 'auto', # 0, 1
    theme   => 'Material',
    colors  => { ... },  # override theme colors

    # object output
    class_method => '_data_printer',
    class => {
        parents            => 1,
        linear_isa         => 'auto',
        universal          => 1,
        expand             => 1,
        stringify          => 1,
        show_reftype       => 0,
        show_overloads     => 1,
        show_methods       => 'all', # none, public, private
        sort_methods       => 1,
        inherited          => 'none',   # all, public, private
        format_inheritance => 'string', # lines
        parent_filters     => 1,
        internals          => 1,
    },

    # filters (see Filters below)
    filters => [
        {
            SCALAR    => sub { ... }, # <-- inline filter for SCALARs
            SomeClass => sub { ... }, # <-- inline filter for class 'SomeClass'
            -class    => sub { ... }. # <-- inline filter for all classes
        },
        'DB',  # <-- loads Data::Printer::Filter::DB
        'Web', # <-- loads Data::Printer::Filter::Web
    ],

=head3 Settings shortcuts

=over 4

=item * B<as> - prints a string before the dump. So:

    p $some_var, as => 'here!';

is a shortcut to:

    p $some_var, caller_info => 1, caller_message => 'here!';

=item * B<multiline> - lets you create shorter dumps. By setting it to 0,
we use a single space as linebreak and disable the array index. Setting it
to 1 (the default) goes back to using "\n" as linebreak and restore whatever
array index you had originally.

=back

=head2 Colors & Themes

Data::Printer's colored output is handled by the C<colors> option. You may
set each color individually, using ANSIColors naming, hex color tags or RGB:

    use DDP colors => {
        array  => 'blue',
        number => '#2e4f0a',
        undef  => 'rgb(255,80,103)',
        # and many more!
    },

You may also use any of Data::Printer's available themes:

    use DDP theme => 'Monokai';

This will load Data::Printer::Theme::Monokai, that contains all color
settings. You are encouraged to create your own themes and upload them
to CPAN for others to use as well!

See L<Data::Printer::Theme> for information on how to create your own custom
theme, and for a complete list of all natively used color labels.

=head2 Profiles

TBD.

=head2 Filters

Data::Printer works by passing your variable to a different set of filters,
depending on whether it's a scalar, a hash, an array, an object, etc. It
comes bundled with filters for all native data types and several others for
the most common objects on CPAN. To set your own filter, simply add it to the
C<filters>. The list may receive named filters:

    use DDP filters => [ 'DB', 'Web' ];

Which will load C<< <Data::Printer::Filter::DB >> and C<< ::Web >>,
respectively. It may also get a hashref of inline filters:

    use DDP filters => [{
        SCALAR       => sub { ... },
        'My::Module' => sub { ... },
    }];

Or any combination of those. Creating your custom filters is very easy, and
you're encouraged to upload them to CPAN. There are many options available
under the C<< Data::Printer::Filter::* >> namespace. Check
L<Data::Printer::Filter> for extra information!

=head1 TIPS & TRICKS

TBD.

=head1 CONTRIBUTORS

Many thanks to everyone who helped design and develop this module with
patches, bug reports, wishlists, comments and tests. They are (alphabetically):

Adam Rosenstein, Alexandr Ciornii (chorny), Allan Whiteford,
Anatoly (Snelius30), Andreas König (andk), Andy Bach, Anthony DeRobertis,
Árpád Szász, Athanasios Douitsis (aduitsis), Baldur Kristinsson,
Benct Philip Jonsson (bpj), brian d foy, Chad Granum (exodist),
Chris Prather (perigrin), Curtis Poe (Ovid), David D Lowe (Flimm),
David Golden (xdg), David Precious (bigpresh), David Raab,
David E. Wheeler (theory), Damien Krotkine (dams), Denis Howe, Dotan Dimet,
Eden Cardim (edenc), Elliot Shank (elliotjs), Eugen Konkov (KES777),
Fernando Corrêa (SmokeMachine), Fitz Elliott, Frew Schmidt (frew), GianniGi,
Graham Knop (haarg), Graham Todd, grr, Håkon Hægland,
Nigel Metheringham (nigelm), Ivan Bessarabov (bessarabv), J Mash,
James E. Keenan (jkeenan), Jarrod Funnell (Timbus), Jay Allen (jayallen),
Jay Hannah (jhannah), jcop, Jesse Luehrs (doy), Joel Berger (jberger),
John S. Anderson (genehack), Karen Etheridge (ether),
Kartik Thakore (kthakore), Kevin Dawson (bowtie), Kevin McGrath (catlgrep),
Kip Hampton (ubu), Londran, Marcel Grünauer (hanekomu),
Marco Masetti (grubert65), Mark Fowler (Trelane), Martin J. Evans,
Matt S. Trout (mst), Maxim Vuets, Michael Conrad, Mike Doherty (doherty),
Nuba Princigalli (nuba), Olaf Alders (oalders), Paul Evans (LeoNerd),
Pedro Melo (melo), Przemysław Wesołek (jest), Rebecca Turner (iarna),
Renato Cron (renatoCRON), Ricardo Signes (rjbs), Rob Hoelz (hoelzro),
sawyer, Sebastian Willing (Sewi), Sergey Aleynikov (randir), Slaven Rezić,
Stanislaw Pusep (syp), Stephen Thirlwall (sdt), sugyan,
Tatsuhiko Miyagawa (miyagawa), Thomas Sibley (tsibley),
Tim Heaney (oylenshpeegul), Torsten Raudssus (Getty),
Tokuhiro Matsuno (tokuhirom), trapd00r, vividsnow, Wesley Dal`Col (blabos),
y, Yanick Champoux (yanick).

If I missed your name, please drop me a line!

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011-2018 Breno G. de Oliveira

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR
THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU.
SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY
SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL
ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO
YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED
INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE
SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER
PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
