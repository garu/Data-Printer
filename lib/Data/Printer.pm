package Data::Printer;
use strict;
use warnings;
use Data::Printer::Object;
use Data::Printer::Common;
use Data::Printer::Config;

our $VERSION = '0.99_020';

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

    my $use_prototypes = _find_option('use_prototypes', $args, $caller, 1);
    my $exported = ($use_prototypes ? \&p : \&_p_without_prototypes);

    my $imported = _find_option('alias', $args, $caller, 'p');

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
    $args_to_use->{output} = 'handle'; # force color level 0 on 'auto'
    my $printer = Data::Printer::Object->new($args_to_use);
    my $ref = ref $_[0];
    if ($ref eq 'ARRAY' || $ref eq 'HASH' || ($ref eq 'REF' && ref ${$_[0]} eq 'REF')) {
        $printer->{_refcount_base}++;
    }
    my $output = $printer->parse($_[0]);
    if ($printer->caller_message_position eq 'after') {
        $output .= $printer->write_label;
    }
    else {
        $output = $printer->write_label . $output;
    }
    return $output;
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
    my $output = $printer->parse($_[0]);
    if ($printer->caller_message_position eq 'after') {
        $output .= $printer->write_label;
    }
    else {
        $output = $printer->write_label . $output;
    }

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
    my $output = $printer->parse((defined $item ? $item : $_[0]));
    if ($printer->caller_message_position eq 'after') {
        $output .= $printer->write_label;
    }
    else {
        $output = $printer->write_label . $output;
    }

    return _handle_output($printer, $output, !!defined wantarray, $_[0]);
}


sub _handle_output {
    my ($printer, $output, $wantarray, $data) = @_;

    if ($printer->return_value eq 'pass') {
        print { $printer->output_handle } $output . "\n";
        require Scalar::Util;
        my $ref = Scalar::Util::blessed($data);
        return $data if defined $ref;
        $ref = Scalar::Util::reftype($data);
        if (!$ref) {
            return $data;
        }
        elsif ($ref eq 'ARRAY') {
            return @$data;
        }
        elsif ($ref eq 'HASH') {
            return %$data;
        }
        elsif ( grep { $ref eq $_ } qw(REF SCALAR VSTRING) ) {
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
        $args_to_use = Data::Printer::Common::_merge_options(
            $args_to_use, $rc_arguments->{'_'}
        );
        if (exists $rc_arguments->{$caller}) {
            $args_to_use = Data::Printer::Common::_merge_options(
                $args_to_use, $rc_arguments->{$caller}
            );
        }
    }
    if ($arguments_for{$caller}) {
        $args_to_use = Data::Printer::Common::_merge_options(
            $args_to_use, $arguments_for{$caller}
        );
    }
    if (keys %$run_properties) {
        $args_to_use = Data::Printer::Common::_merge_options(
            $args_to_use, $run_properties
        );
    }
    return $args_to_use;
}

sub _find_option {
    my ($key, $args, $caller, $default) = @_;

    my $value;
    if (exists $args->{$key}) {
        $value =  $args->{$key};
    }
    elsif (
          exists $rc_arguments->{$caller}
       && exists $rc_arguments->{$caller}{$key}
    ) {
        $value = $rc_arguments->{$caller}{$key};
    }
    elsif (exists $rc_arguments->{'_'}{$key}) {
        $value = $rc_arguments->{'_'}{$key};
    }
    else {
        $value = $default;
    }
    return $value;
}


'Marielle, presente.';
__END__

=encoding utf8

=head1 NAME

Data::Printer - colored & full-featured pretty-print of Perl data structures and objects

=head1 SYNOPSIS

Want to see what's inside a variable in a complete, colored and human-friendly way?

    use DDP;  # same as 'use Data::Printer'

    my $var = SomeClass->new;  # or whatever

    p $var;
    p $var, as => "This label will be printed too!";

    # no need to use '\' before arrays or hashes!
    p @array;
    p %hash;

    # for anonymous array/hash references, put '&' in front:
    &p( [ $one, $two, $three ] );
    &p( { foo => $foo, bar => $bar } );

    # use postderef on perl 5.24 or later:
    p [ $one, $two, $three ]->@*;
    p { foo => $foo, bar => $bar }->%*;

The snippets above will print the contents of the chosen variables to STDERR
on your terminal, with colors and a few extra features to help you debug
your code.

If you wish to grab the output and handle it yourself, call C<np()>:

    my $dump = np $var;

    die "this is what happened: " . np(%data);

The C<np()> function is the same as C<p()> but will return the string
containing the dump. By default it has no colors, but you can change that
easily too.

That's it :)

Data::Printer is fully customizable. If you want to change how things are
displayed, or even its standard behavior, just take a look at the
L<available options|/Properties Quick Reference>. Once you figure out your
own preferences, create a
L<< .dataprinter configuration file|/The .dataprinter configuration file >>
for yourself and Data::Printer will automatically use it!

=head1 FEATURES

Here's what Data::Printer offers Perl developers, out of the box:

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

=head2 The .dataprinter configuration file

The most powerful way to customize Data::Printer is to have a C<.dataprinter>
file in your home directory, which is a simple I<key = value> text file. It
lets you set global options to Data::Printer and custom options that will be
active only on C<p()>/C<np()> calls made inside a given module:

    # global settings (note that only full line comments are accepted)
    max_depth       = 1
    theme           = Monokai
    class.stringify = 0
    # use quotes if you want spaces to be significant:
    hash_separator  = " => "

    # You can set rules that apply only to a specific
    # caller module (in this case, MyApp::Some::Module):
    [MyApp::Some::Module]
    max_depth    = 2
    class.expand = 0
    escape_chars = nonlatin1

    [MyApp::Other::Module]
    multiline = 0

Note that on the C<.dataprinter> file you separate suboptions with C<.>, so
"C<< class => { expand => 0, inherited => 'none' } >>" becomes
"C<< class.expand = 0 >>" and "C<< class.inherited = none >>", each on their
own line.

=head2 Properties Quick Reference

For a quick reference, below are all available properties and their
(hopefully sane) default values. See L<Data::Printer::Object> for further
information on each of them:

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
    show_tied      => 1,
    show_dualvar   => 'lax', # strict, off
    show_weak      => 1,
    show_refcount  => 0,
    show_memsize   => 0,
    memsize_unit   => 'auto' # ('b', 'k', m)
    separator      => ',',
    end_separator  => 0,
    caller_info    => 0,
    caller_message => 'Printing in line __LINE__ of __FILENAME__',
    max_depth      => 0,
    deparse        => 0,
    alias          => 'p',  # what to call p() when importing

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

=item * B<fulldump> - when set to 1, disables all max string/hash/array
values. Use this to generate complete (full) dumps of all your content,
which is trimmed by default.

=back

=head2 Colors & Themes

Data::Printer's colorization is set via the C<colorize> output, which can be
set to C<1> (always colorize), C<0> (never colorize) or C<'auto'>.

Data::Printer's default color mode is 'auto', meaning it will colorize
the output only when all conditions below are met:

=over 4

=item * There is no C<ANSI_COLORS_DISABLED> environment variable;

=item * The output is going to the terminal, not just returned;

=item * The output handle (STDERR by default) is not being piped;

=item * Your terminal supports colors (most do nowadays).

=back

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

While you may not put subrefs on your C<.dataprinter> file, you can load any
external filters easily:

    filters = DB, DateTime, Web

=head1 MAKING YOUR CLASSES AWARE OF DDP (WITHOUT ADDING ANY DEPS)

Whenever printing the contents of a class, Data::Printer first
checks to see if that class implements a sub called 'C<_data_printer()>'
(or whatever you set the "class_method" option to in your settings,
see L</Properties Quick Reference>).

If a sub with that exact name is available in the target object,
Data::Printer will use it to get the string to print instead of
making a regular class dump.

This means you could have the following in one of your classes:

  sub _data_printer {
      my ($self, $ddp) = @_;
      return 'Hey, no peeking! But foo contains ' . $self->foo;
  }

Notice that B<< you can do this without adding Data::Printer as a dependency >>
to your project! Just write your sub and it will use that to pretty-print
your objects. The sub will be called with the object to be printed and also
with a C<$ddp> object ready for you. See L<Data::Printer::Object> for
how to use it to pretty-print your data.

Having a filter for that particular class will of course override this setting.

Finally, if your object implements string overload or provides a method called
"to_string", "as_string" or "stringify", Data::Printer will use it. To disable
this behaviour, set C<< class.stringify = 0 >> on your C<.dataprinter>
file, or call p() with C<< class => { stringify => 0 } >>.

=head1 CAVEATS

You can't pass more than one variable at a time.

   p($foo, $bar);  # wrong
   p($foo);        # right
   p($bar);        # right

You can't use it in variable declarations (it will most likely not do what
you want):

    p my @array = qw(a b c d);          # wrong
    my @array = qw(a b c d); p @array;  # right

On the default mode of C<< use_prototypes => 1 >>, you cannot pass anonymous
data:

    p { foo => 1 };       # wrong!

Try any of the forms below instead, or set C<use_prototypes> to 0:

    p %{ { foo => 1 } };  # right
    p { foo => 1 }->%*;   # also right on perl 5.24+
    &p( { foo => 1 } );   # right, but requires the parenthesis

Also, if you pass a nonexistant key/index to DDP using prototypes, they
will trigger autovivification:

    use DDP;
    my %foo;
    p $foo{bar}; # undef, but will create the 'bar' key (with undef)

    my @x;
    p $x[5]; # undef, but will initialize the array with 5 elements (all undef)

=head1 BACKWARDS INCOMPATIBLE CHANGES

While we make a genuine effort not to break anything on new releases,
sometimes we do. To make things easier for people migrating their
code, we have aggregated here a list of all incompatible changes since ever:

=over 4

=item * 1.00 - some defaults changed!
Because we added a bunch of new features (including color themes), you may
notice some difference on the default output of Data::Printer. Hopefully it's
for the best.

=item * 1.00 - new C<.dataprinter> file format.
I<< This should only affect you if you have a C<.dataprinter> file. >>
The change was required to avoid calling C<eval> on potentially tainted/unknown
code. It also provided a much clearer interface.

=item * 1.00 - new way of creating external filters.
I<< This only affects you if you write or use external filters. >>
Previously, the sub in your C<filters> call would get the reference to be
parsed and a properties hash. The properties hash has been replaced with a
L<Data::Printer::Object> instance, providing much more power and flexibility.
Because of that, the filter call does not export C<p()>/C<np()> anymore,
replaced by methods in Data::Printer::Object.

=item * 1.00 - new way to call filters.
I<< This affects you if you load your own inline filters >>.
The fix is quick and Data::Printer will generate a warning explaining how
to do it. Basically, C<< filters => { ... } >> became
C<< filters => [{ ... }] >> and you must replace C<< -external => [1,2] >>
with C<< filters => [1, 2] >>, or C<< filters => [1, 2, {...}] >> if you
also have inline filters. This allowed us much more power and flexibility
with filters, and hopefully also makes things cleaner.

=item * 0.36 - C<p()>'s default return value changed from 'dump' to 'pass'.
This was a very important change to ensure chained calls and to prevent
weird side-effects when C<p()> is the last statement in a sub.
L<< Read the full discussion|https://github.com/garu/Data-Printer/issues/16 >>.

=back

Any undocumented change was probably unintended. If you bump into one,
please file an issue on Github!

=head1 TIPS & TRICKS

=head2 Circumventing prototypes

The C<p()> function uses prototypes by default, allowing you to say:

    p %var;

instead of always having to pass references, like:

    p \%var;

There are cases, however, where you may want to pass anonymous
structures, like:

    p { foo => $bar };   # this blows up, don't use!

and because of prototypes, you can't. If this is your case, just
set "use_prototypes" option to 0. Note, with this option,
you B<will> have to pass your variables as references:

    use DDP use_prototypes => 0;

    p { foo => 'bar' }; # doesn't blow up anymore, works just fine.

    p %var;  # but now this blows up...
    p \%var; # ...so do this instead!

    p [ $foo, $bar, \@baz ]; # this way you can even pass
                             # several variables at once

If you want to keep using prototypes but still be able to call C<p()> with
anonymous data, you may also try any of these formats:

    &p( { foo => $bar } );        # this is ok, but requires the parentheses
    &p( \"DEBUGGING THIS BIT" );  # this works too

    p %{{ foo => $bar }};    # reref works in all versions of perl 5
    p { foo => $bar }->%*;   # postderef works on 5.24 and newer perls

Or you could just create a very simple wrapper function:

  sub pp { p @_ };

And use it as you use C<p()>.

=head2 Minding the return value of p()

I<< (contributed by Matt S. Trout (mst)) >>

Since Data::Printer 0.36, the default return value changed from 'dump'
to 'pass'. If you are using the 'dump' mode, the return value o p()
is the serialized form of the dump (like np()) unless in void context, in
which case it will print the string. While it's tempting to trust your own
p() calls with that approach, if this is your I<last> statement in a function,
you should keep in mind your debugging code will behave differently depending
on how your function was called!

To prevent that, set the C<return_value> property to either 'void' or 'pass'.
You won't be able to retrieve the dumped string but, hey, who does that anyway
:) Besides, you can use np() for that, too.

Assuming you are using the default pass-through ('pass') property, another
stunningly useful thing you can do with it is change code that says:

   return $obj->foo;

with:

   use DDP;

   return p $obj->foo;

You can even add it to chained calls if you wish to see the dump of
a particular state, changing this:

   $obj->foo->bar->baz;

to:

   $obj->foo->DDP::p->bar->baz

And things will "Just Work".


=head2 Using p() in some/all of your loaded modules

I<< (contributed by Matt S. Trout (mst)) >>

While debugging your software, you may want to use Data::Printer in some or
all loaded modules and not bother having to load it in each and every one of
them. To do this, in any module loaded by C<myapp.pl>, simply write:

  ::p( @myvar );  # note the '::' in front of p()

Then call your program like:

  perl -MDDP myapp.pl

This also has the great advantage that if you leave one p() call
in by accident, it will fail without the -M, making it easier to spot :)

If you really want to have p() imported into your loaded
modules, use the next tip instead.

=head2 Adding p() to all your loaded modules

I<< (contributed by Árpád Szász) >>

If you wish to automatically add Data::Printer's C<p()> function to
every loaded module in you app, you can do something like this to
your main program:

    BEGIN {
        {
            no strict 'refs';
            require Data::Printer;
            my $alias = 'p';
            foreach my $package ( keys %main:: ) {
                if ( $package =~ m/::$/ ) {
                    *{ $package . $alias } = \&Data::Printer::p;
                }
            }
        }
    }

B<WARNING> This will override all locally defined subroutines/methods that
are named C<p>, if they exist, in every loaded module. If you already
have a subroutine named 'C<p()>', be sure to change C<$alias> to
something custom.

If you rather avoid namespace manipulation altogether, use the previous
tip instead.

=head2 Using Data::Printer from the Perl debugger

I<< (contributed by Árpád Szász and Marcel Grünauer (hanekomu)) >>

With L<DB::Pluggable>, you can easily set the perl debugger to use
Data::Printer to print variable information, replacing the debugger's
standard C<p()> function. All you have to do is add these lines to
your C<.perldb> file:

  use DB::Pluggable;
  DB::Pluggable->run_with_config( \'[DataPrinter]' );  # note the '\'

Then call the perl debugger as you normally would:

  perl -d myapp.pl

Now Data::Printer's C<p()> command will be used instead of the debugger's!

See L<perldebug> for more information on how to use the perl debugger, and
L<DB::Pluggable> for extra functionality and other plugins.

If you can't or don't wish to use DB::Pluggable, or simply want to keep
the debugger's C<p()> function and add an extended version using
Data::Printer (let's call it C<px()> for instance), you can add these
lines to your C<.perldb> file instead:

    $DB::alias{px} = 's/px/DB::px/';
    sub px {
        my $expr = shift;
        require Data::Printer;
        print Data::Printer::p($expr);
    }

Now, inside the Perl debugger, you can pass as reference to C<px> expressions
to be dumped using Data::Printer.

=head2 Using Data::Printer in a perl shell (REPL)

Some people really enjoy using a REPL shell to quickly try Perl code. One
of the most famous ones out there is L<Devel::REPL>. If you use it, now
you can also see its output with Data::Printer!

Just install L<Devel::REPL::Plugin::DataPrinter> and add the following
line to your re.pl configuration file (usually ".re.pl/repl.rc" in your
home dir):

  load_plugin('DataPrinter');

The next time you run C<re.pl>, it should dump all your REPL using
Data::Printer!

=head2 Easily rendering Data::Printer's output as HTML

To turn Data::Printer's output into HTML, you can do something like:

  use HTML::FromANSI;
  use Data::Printer;

  my $html_output = ansi2html( p($object, colored => 1) );

In the example above, the C<$html_output> variable contains the
HTML escaped output of C<p($object)>, so you can print it for
later inspection or render it (if it's a web app).

=head2 Using Data::Printer with Template Toolkit

I<< (contributed by Stephen Thirlwall (sdt)) >>

If you use Template Toolkit and want to dump your variables using Data::Printer,
install the L<Template::Plugin::DataPrinter> module and load it in your template:

   [% USE DataPrinter %]

The provided methods match those of C<Template::Plugin::Dumper>:

   ansi-colored dump of the data structure in "myvar":
   [% DataPrinter.dump( myvar ) %]

   html-formatted, colored dump of the same data structure:
   [% DataPrinter.dump_html( myvar ) %]

The module allows several customization options, even letting you load it as a
complete drop-in replacement for Template::Plugin::Dumper so you don't even have
to change your previous templates!

=head2 Unified interface for Data::Printer and other debug formatters

I<< (contributed by Kevin McGrath (catlgrep)) >>

If you are porting your code to use Data::Printer instead of
Data::Dumper or similar, you can just replace:

  use Data::Dumper;

with:

  use Data::Printer alias => 'Dumper';
  # use Data::Dumper;

making sure to provide Data::Printer with the proper alias for the
previous dumping function.

If, however, you want a really unified approach where you can easily
flip between debugging outputs, use L<Any::Renderer> and its plugins,
like L<Any::Renderer::Data::Printer>.

=head2 Printing stack traces with arguments expanded using Data::Printer

I<< (contributed by Sergey Aleynikov (randir)) >>

There are times where viewing the current state of a variable is not
enough, and you want/need to see a full stack trace of a function call.

The L<Devel::PrettyTrace> module uses Data::Printer to provide you just
that. It exports a C<bt()> function that pretty-prints detailed information
on each function in your stack, making it easier to spot any issues!

=head2 Troubleshooting apps in real time without changing a single line of your code

I<< (contributed by Marcel Grünauer (hanekomu)) >>

L<dip> is a dynamic instrumentation framework for troubleshooting Perl
programs, similar to L<DTrace|http://opensolaris.org/os/community/dtrace/>.
In a nutshell, C<dip> lets you create probes for certain conditions
in your application that, once met, will perform a specific action. Since
it uses Aspect-oriented programming, it's very lightweight and you only
pay for what you use.

C<dip> can be very useful since it allows you to debug your software
without changing a single line of your original code. And Data::Printer
comes bundled with it, so you can use the C<p()> function to view your
data structures too!

   # Print a stack trace every time the name is changed,
   # except when reading from the database.
   dip -e 'before { print longmess(p $_->{args}[1]) if $_->{args}[1] }
     call "MyObj::name" & !cflow("MyObj::read")' myapp.pl

You can check you L<dip>'s own documentation for more information and options.

=head2 Sample output for color fine-tuning

I<< (contributed by Yanick Champoux (yanick)) >>

The "examples/try_me.pl" file included in this distribution has a sample
dump with a complex data structure to let you quickly test color schemes.

=head2 creating fiddling filters

I<< (contributed by dirk) >>

Sometimes, you may want to take advantage of Data::Printer's original dump,
but add/change some of the original data to enhance your debugging ability.
Say, for example, you have an C<HTTP::Response> object you want to print
but the content is encoded. The basic approach, of course, would be to
just dump the decoded content:

  use DDP filter {
    'HTTP::Response' => sub { p( \shift->decoded_content, %{shift} );
  };

But what if you want to see the rest of the original object? Dumping it
would be a no-go, because you would just recurse forever in your own filter.

Never fear! When you create a filter in Data::Printer, you're not replacing
the original one, you're just stacking yours on top of it. To forward your data
to the original filter, all you have to do is return an undefined value. This
means you can rewrite your C<HTTP::Response> filter like so, if you want:

  use DDP filters => {
    'HTTP::Response' => sub {
      my ($res, $p) = @_;

      # been here before? Switch to original handler
      return if exists $res->{decoded_content};

      # first timer? Come on in!
      my $clone = $res->clone;
      $clone->{decoded_content} = $clone->decoded_content;
      return p($clone, %$p);
    }
  };

And voilà! Your fiddling filter now works like a charm :)

=head1 CONTRIBUTORS

Many thanks to everyone who helped design and develop this module with
patches, bug reports, wishlists, comments and tests. They are (alphabetically):

Adam Rosenstein, Alexandr Ciornii (chorny), Allan Whiteford,
Anatoly (Snelius30), Andreas König (andk), Andy Bach, Anthony DeRobertis,
Árpád Szász, Athanasios Douitsis (aduitsis), Baldur Kristinsson,
Benct Philip Jonsson (bpj), brian d foy, Chad Granum (exodist),
Chris Prather (perigrin), Curtis Poe (Ovid), David D Lowe (Flimm),
David Golden (xdg), David Precious (bigpresh), David Raab,
David E. Wheeler (theory), Damien Krotkine (dams), Denis Howe, dirk,
Dotan Dimet, Eden Cardim (edenc), Elliot Shank (elliotjs), Eugen Konkov (KES777),
Fernando Corrêa (SmokeMachine), Fitz Elliott, Florian (fschlich),
Frew Schmidt (frew), GianniGi, Graham Knop (haarg), Graham Todd,
Gregory J. Oschwald, grr, Håkon Hægland, Nigel Metheringham (nigelm),
Ivan Bessarabov (bessarabv), J Mash, James E. Keenan (jkeenan),
Jarrod Funnell (Timbus), Jay Allen (jayallen), Jay Hannah (jhannah),
jcop, Jesse Luehrs (doy), Joel Berger (jberger),
John S. Anderson (genehack), Karen Etheridge (ether),
Kartik Thakore (kthakore), Kevin Dawson (bowtie), Kevin McGrath (catlgrep),
Kip Hampton (ubu), Londran, Marcel Grünauer (hanekomu),
Marco Masetti (grubert65), Mark Fowler (Trelane), Martin J. Evans,
Matt S. Trout (mst), Maxim Vuets, Michael Conrad, Mike Doherty (doherty),
Nicolas R (atoomic), Nuba Princigalli (nuba), Olaf Alders (oalders),
Paul Evans (LeoNerd), Pedro Melo (melo), Philippe Bruhat (BooK),
Przemysław Wesołek (jest), Rebecca Turner (iarna), Renato Cron (renatoCRON),
Ricardo Signes (rjbs), Rob Hoelz (hoelzro), sawyer, Sebastian Willing (Sewi),
Sergey Aleynikov (randir), Slaven Rezić, Stanislaw Pusep (syp),
Stephen Thirlwall (sdt), sugyan, Tai Paul, Tatsuhiko Miyagawa (miyagawa),
Thomas Sibley (tsibley), Tim Heaney (oylenshpeegul), Torsten Raudssus (Getty),
Tokuhiro Matsuno (tokuhirom), trapd00r, Tsai Chung-Kuan, vividsnow,
Wesley Dal`Col (blabos), y, Yanick Champoux (yanick).

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
