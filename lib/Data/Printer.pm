package Data::Printer;
use strict;
use warnings;
use Term::ANSIColor;
use Scalar::Util;
use Sort::Naturally;
use Class::MOP;
use Carp qw(croak);
use Clone qw(clone);
require Object::ID;
use File::Spec;
use File::HomeDir ();
use Fcntl;

our $VERSION = 0.13;

BEGIN {
    if ($^O =~ /Win32/i) {
        require Win32::Console::ANSI;
        Win32::Console::ANSI->import;
    }
}

# defaults
my $properties = {
    'name'           => 'var',
    'indent'         => 4,
    'index'          => 1,
    'max_depth'      => 0,
    'multiline'      => 1,
    'sort_keys'      => 1,
    'deparse'        => 0,
    'hash_separator' => '   ',
    'show_tied'      => 1,
    'class_method'   => undef,        # use a specific dump method, if available
    'color'          => {
        'array'    => 'bright_white',
        'number'   => 'bright_blue',
        'string'   => 'bright_yellow',
        'class'    => 'bright_green',
        'undef'    => 'bright_red',
        'hash'     => 'magenta',
        'regex'    => 'yellow',
        'code'     => 'green',
        'glob'     => 'bright_cyan',
        'repeated' => 'white on_red',
    },
    'class' => {
        inherited    => 'none',   # also 0, 'none', 'public' or 'private'
        expand       => 1,        # how many levels to expand. 0 for none, 'all' for all
        internals    => 1,
        export       => 1,
        sort_methods => 1,
    },
    'filters' => {},
};

my $BREAK = "\n";

sub import {
    my $class = shift;
    my $args;
    if (scalar @_) {
        $args = @_ == 1 ? shift : {@_};
    }

    # the RC file overrides the defaults,
    # (and we load it only once)
    unless( exists $properties->{_initialized} ) {
        my $file = File::Spec->catfile(
            File::HomeDir->my_home,
            '.dataprinter'
        );
        if (-e $file) {
            if ( open my $fh, '<', $file ) {
                my $rc_data;
                { local $/; $rc_data = <$fh> }
                close $fh;

                my $config = eval $rc_data;
                if ( $@ ) {
                    warn "Error loading $file: $@\n";
                }
                elsif (!ref $config or ref $config ne 'HASH') {
                    warn "Error loading $file: config file must return a hash reference\n";
                }
                else {
                    $properties = _merge( $config );
                }
            }
            else {
                warn "error opening '$file': $!\n";
            }
        }
        $properties->{_initialized} = 1;
    }

    # and 'use' arguments override the RC file
    if (ref $args and ref $args eq 'HASH') {
        $properties = _merge( $args );
    }

    my $imported_method = $properties->{alias} || 'p';
    my $caller = caller;
    no strict 'refs';
    *{"$caller\::$imported_method"} = \&p;

    # colors only if we're not being piped
    $ENV{ANSI_COLORS_DISABLED} = 1 if not -t *STDERR;
}

sub p (\[@$%&];%) {
    croak 'When calling p() inside inline filters, please pass arguments as references'
        unless ref $_[0];

    my ($item, %local_properties) = @_;

    my $p = _merge(\%local_properties);
    unless ($p->{multiline}) {
        $BREAK = ' ';
        $p->{'indent'} = 0;
        $p->{'index'}  = 0;
    }

    my $out = color('reset') . _p( $item, $p );
    print STDERR  $out . $/ unless defined wantarray;
    return $out;
}


sub _merge {
    my $p = shift;
    my $clone = clone $properties;

    if ($p) {
        foreach my $key (keys %$p) {
            if ($key eq 'color' or $key eq 'colour') {
                my $color = $p->{$key};
                if (defined $color and not $color) {
                    $clone->{color} = {};
                }
                else {
                    foreach my $target ( keys %{$p->{$key}} ) {
                        $clone->{color}->{$target} = $p->{$key}->{$target};
                    }
                }
            }
            elsif ($key eq 'class') {
                foreach my $item ( keys %{$p->{class}} ) {
                    $clone->{class}->{$item} = $p->{class}->{$item};
                }
            }
            elsif ($key eq 'filters') {
                my $val = $p->{$key};

                foreach my $item (keys %$val) {

                    # EXPERIMENTAL: filters in modules
                    if ($item eq '-external') {
                        foreach my $class ( @{$val->{$item}} ) {
                            my $module = "Data::Printer::Filter::$class";
                            eval "use $module";
                            if ($@) {
                                warn "Error loading filter '$module': $@";
                            }
                            else {
                                my %from_module = %{$module->_filter_list};
                                foreach my $k (keys %from_module) {
                                    push @{ $clone->{filters}->{$k} }, @{ $from_module{$k} };
                                }
                            }
                        }
                    }
                    else {
                        push @{ $clone->{filters}->{$item} }, $val->{$item};
                    }
                }
            }
            else {
                $clone->{$key} = $p->{$key};
            }
        }
    }

    $clone->{'_current_indent'} = 0;  # used internally
    $clone->{'_linebreak'} = \$BREAK; # used internally
    $clone->{'_seen'} = {};           # used internally
    $clone->{'_depth'} = 0;           # used internally
    $clone->{'class'}{'_depth'} = 0;  # used internally

    return $clone;
}

sub _p {
    my ($item, $p) = @_;
    my $ref = ref $item;
    my $tie;

    my $string = '';

    # Object's unique ID, avoiding circular structures
    my $id = Object::ID::object_id( $item );
    return colored($p->{_seen}->{$id}, $p->{color}->{repeated}
    ) if exists $p->{_seen}->{$id};

    $p->{_seen}->{$id} = $p->{name};

    # filter item (if user set a filter for it)
    if ( exists $p->{filters}->{$ref} ) {
        foreach my $filter ( @{ $p->{filters}->{$ref} } ) {
            if ( my $result = $filter->($item, $p) ) {
                $string .= $result;
                last;
            }
        }
    }

    # TODO: Might be a good idea to set the rest of this sub
    # inside the filter dispatch table.
    elsif ($ref eq 'SCALAR') {
        if (not defined $$item) {
            $string .= colored('undef', $p->{color}->{'undef'});
        }
        elsif (Scalar::Util::looks_like_number($$item)) {
            $string .= colored($$item, $p->{color}->{'number'});
        }
        else {
            $string .= colored(qq["$$item"], $p->{color}->{'string'});
        }

        $tie = ref tied $$item;
    }

    elsif ($ref eq 'REF') {
        # look-ahead, add a '\' only if it's not an object
        if (my $ref_ahead = ref $$item ) {
            $string .= '\\ ' if grep { $_ eq $ref_ahead }
                qw(SCALAR CODE Regexp ARRAY HASH GLOB REF);
        }
        $string .= _p($$item, $p);
    }

    elsif ($ref eq 'CODE') {
        my $code = 'sub { ... }';
        if ($p->{deparse}) {
            $code = _deparse( $item, $p );
        }
        $string .= colored($code, $p->{color}->{'code'});
    }

    elsif ($ref eq 'GLOB' or "$item" =~ /=GLOB\([^()]+\)$/ ) {
        $string .= colored("$$item", $p->{color}->{'glob'});

        my $extra = '';
        if (my $flags = fcntl($$item, F_GETFL, 0) ) {

            $extra .= $flags & O_WRONLY ? 'write-only'
                    : $flags & O_RDWR   ? 'read/write'
                    : 'read-only'
                    ;

            my %flags = (
                    'append'      => O_APPEND,
                    'async'       => O_ASYNC,
                    'create'      => O_CREAT,
                    'truncate'    => O_TRUNC,
                    'nonblocking' => O_NONBLOCK,
            );

            if (my @flags = grep { $flags & $flags{$_} } keys %flags) {
                $extra .= ", flags: @flags";
            }
            $extra .= ', ';
        }
        my @layers = ();
        eval { @layers = PerlIO::get_layers $$item };
        unless ($@) {
            $extra .= "layers: @layers";
        }
        $string .= "  ($extra)" if $extra;

        $tie = ref tied *$$item;
    }

    elsif ($ref eq 'Regexp') {
        my $val = "$item";
        # a regex to parse a regex. Talk about full circle :)
        # note: we are not validating anything, just grabbing modifiers
        if ($val =~ m/\(\?\^?([uladxismpogce]*)(?:\-[uladxismpogce]+)?:(.*)\)/s) {
            my ($modifiers, $val) = ($1, $2);
            $string .= colored($val, $p->{color}->{'regex'});
            if ($modifiers) {
                $string .= "  (modifiers: $modifiers)";
            }
        }
        else {
            croak "Unrecognized regex $val. Please submit a bug report for Data::Printer.";
        }
    }

    elsif ($ref eq 'ARRAY') {
        $p->{_depth}++;

        if ( $p->{max_depth} and $p->{_depth} > $p->{max_depth} ) {
            $string .= '[ ... ]';
        }
        else {
            $string .= "[$BREAK";
            $p->{_current_indent} += $p->{indent};

            foreach my $i (0 .. $#{$item} ) {
                $p->{name} .= "[$i]";

                my $array_elem = $item->[$i];
                $string .= (' ' x $p->{_current_indent});
                if ($p->{'index'}) {
                    $string .= colored(
                                 sprintf("%-*s", 3 + length($#{$item}), "[$i]"),
                                 $p->{color}->{'array'}
                           );
                }

                $ref = ref $array_elem;

                # scalar references should be re-referenced
                # to gain a '\' sign in front of them
                if (!$ref or $ref eq 'SCALAR') {
                    $string .= _p( \$array_elem, $p );
                }
                else {
                    $string .= _p( $array_elem, $p );
                }
                $string .= ($i == $#{$item} ? '' : ',') . $BREAK;
                my $size = 2 + length($i); # [10], [100], etc
                substr $p->{name}, -$size, $size, '';
            }
            $p->{_current_indent} -= $p->{indent};
            $string .= (' ' x $p->{_current_indent}) . "]";
        }

        $tie = ref tied @$item;
        $p->{_depth}--;
    }

    elsif ($ref eq 'HASH') {
        $p->{_depth}++;

        if ( $p->{max_depth} and $p->{_depth} > $p->{max_depth} ) {
            $string .= '{ ... }';
        }
        else {
            $string .= "{$BREAK";
            $p->{_current_indent} += $p->{indent};

            # length of the largest key is used for indenting
            my $len = 0;
            if ($p->{multiline}) {
                foreach (keys %$item) {
                    my $l = length;
                    $len = $l if $l > $len;
                }
            }

            my $total_keys = scalar keys %$item;
            my @keys = ($p->{sort_keys} ? nsort keys %$item : keys %$item );
            foreach my $key (@keys) {
                $p->{name} .= "{$key}";
                my $element = $item->{$key};

                $string .= (' ' x $p->{_current_indent})
                         . colored(
                                 sprintf("%-*s", $len, $key),
                                 $p->{color}->{'hash'}
                           )
                         . $p->{hash_separator}
                         ;

                $ref = ref $element;
                # scalar references should be re-referenced
                # to gain a '\' sign in front of them
                if (!$ref or $ref eq 'SCALAR') {
                    $string .= _p( \$element, $p );
                }
                else {
                    $string .= _p( $element, $p );
                }
                $string .= (--$total_keys == 0 ? '' : ',') . $BREAK;

                my $size = 2 + length($key); # {foo}, {z}, etc
                substr $p->{name}, -$size, $size, '';
            }
            $p->{_current_indent} -= $p->{indent};
            $string .= (' ' x $p->{_current_indent}) . "}";
        }

        $tie = ref tied %$item;
        $p->{_depth}--;
    }
    else {
        # let '-class' filters have a go
        my $visited = 0;
        if ( exists $p->{filters}->{'-class'} ) {
            foreach my $filter ( @{ $p->{filters}->{'-class'} } ) {
                if ( my $result = $filter->($item, $p) ) {
                    $string .= $result;
                    $visited = 1;
                    last;
                }
            }
        }
        $string .= _class($ref, $item, $p) unless $visited;
    }

    if ($p->{show_tied} and $tie) {
        $string .= " (tied to $tie)";
    }

    return $string;
}

sub _deparse {
    my ($item, $p) = @_;
    require B::Deparse;
    my $i = $p->{indent};
    my $deparseopts = ["-sCi${i}v'Useless const omitted'"];

    my $sub = 'sub ' . B::Deparse->new($deparseopts)->coderef2text($item);
    my $pad = "\n" . (' ' x ($p->{_current_indent} + $i));
    $sub    =~ s/\n/$pad/gse;
    return $sub;
}

sub _class {
    my ($ref, $item, $p) = @_;

    # if the user specified a method to use instead, we do that
    if ( $p->{class_method} and $item->can($p->{class_method}) ) {
        my $method = $p->{class_method};
        return $item->$method;
    }

    my $string = '';
    $p->{class}{_depth}++;

    $string .= colored($ref, $p->{color}->{'class'});

    if ($p->{class}{expand} eq 'all'
        or $p->{class}{expand} >= $p->{class}{_depth}
    ) {
        $string .= "  {$BREAK";

        $p->{_current_indent} += $p->{indent};

        my $meta = Class::MOP::Class->initialize($ref);

        if ( my @superclasses = $meta->superclasses ) {
            $string .= (' ' x $p->{_current_indent})
                    . 'Parents       '
                    . join(', ', map { colored($_, $p->{color}->{'class'}) }
                                 @superclasses
                    ) . $BREAK;

            $string .= (' ' x $p->{_current_indent})
                    . 'Linear @ISA   '
                    . join(', ', map { colored( $_, $p->{color}->{'class'}) }
                              $meta->linearized_isa
                    ) . $BREAK;
        }

        $string .= _show_methods($ref, $meta, $p);

        if ( $p->{'class'}->{'internals'} ) {
            my $realtype = Scalar::Util::reftype $item;
            $string .= (' ' x $p->{_current_indent})
                    . 'internals: ';

            # Note: we can't do p($$item) directly
            # or we'd fall in a deep recursion trap
            if ($realtype eq 'HASH') {
                my %realvalue = %$item;
                $string .= _p(\%realvalue, $p);
            }
            elsif ($realtype eq 'ARRAY') {
                my @realvalue = @$item;
                $string .= _p(\@realvalue, $p);
            }
            elsif ($realtype eq 'CODE') {
                my $realvalue = &$item;
                $string .= _p(\$realvalue, $p);
            }
            # SCALAR and friends
            else {
                my $realvalue = $$item;
                $string .= _p(\$realvalue, $p);
            }
            $string .= $BREAK;
        }

        $p->{_current_indent} -= $p->{indent};
        $string .= (' ' x $p->{_current_indent}) . "}";
    }
    $p->{class}{_depth}--;

    return $string;
}

sub _show_methods {
    my ($ref, $meta, $p) = @_;

    my $string = '';
    my $methods = {
        public => [],
        private => [],
    };
    my $inherited = $p->{class}{inherited} || 'none';

METHOD:
    foreach my $method ($meta->get_all_methods) {
        my $method_string = $method->name;
        my $type = substr($method_string, 0, 1) eq '_' ? 'private' : 'public';

        if ($method->package_name ne $ref) {
            next METHOD unless $inherited ne 'none'
                           and ($inherited eq 'all' or $type eq $inherited);
            $method_string .= ' (' . $method->package_name . ')';
        }

        push @{ $methods->{$type} }, $method_string;
    }

    # render our string doing a natural sort by method name
    foreach my $type (qw(public private)) {
        my @list = ($p->{class}{sort_methods} ? nsort @{$methods->{$type}} : @{$methods->{$type}});

        $string .= (' ' x $p->{_current_indent})
                 . "$type methods (" . scalar @list . ')'
                 . (@list ? ' : ' : '')
                 . join(', ', map { colored($_, $p->{color}->{class}) }
                              @list
                   ) . $BREAK;
    }

    return $string;
}

1;
__END__

=head1 NAME

Data::Printer - colored pretty-print of Perl data structures and objects

=head1 SYNOPSIS

  use Data::Printer;   # or just "use DDP" for short

  my @array = qw(a b);
  $array[3] = 'c';
  
  p @array;  # no need to pass references!

Code above will show this (with colored output):

   [
       [0] "a",
       [1] "b",
       [2] undef,
       [3] "c",
   ]

You can also inspect Objects:

    my $obj = SomeClass->new;

    p($obj);

Which might give you something like:

  \ SomeClass  {
      Parents       Moose::Object
      Linear @ISA   SomeClass, Moose::Object
      public methods (3) : bar, foo, meta
      private methods (0)
      internals: {
         _something => 42,
      }
  }
 

If for some reason you want to mangle with the output string instead of
printing it to STDERR, you can simply ask for a return value:

  # move to a string
  my $string = p(@some_array);

  # output to STDOUT instead of STDERR
  print p(%some_hash);

  # or even render as HTML
  use HTML::FromANSI;
  ansi2html( p($object) );

Finally, you can set all options during initialization, including
coloring, identation and filters!

  use Data::Printer {
      color => {
         'regex' => 'blue',
         'hash'  => 'yellow',
      },
      filters => {
         'DateTime' => sub { $_[0]->ymd },
         'SCALAR'   => sub { "oh noes, I found a scalar! $_[0]" },
      },
  };

You can ommit the first {} block and just initialize it with a
regular hash, if it makes things easier to read:

  use Data::Printer  deparse => 1, sort_keys => 0;

And if you like your setup better than the defaults, just put them in
a '.dataprinter' file in your home dir and don't repeat yourself
ever again :)


=head1 RATIONALE

Data::Dumper is a fantastic tool, meant to stringify data structures
in a way they are suitable for being C<eval>'ed back in.

The thing is, a lot of people keep using it (and similar ones,
like Data::Dump) to print data structures and objects on screen
for inspection and debugging, and while you B<can> use those
modules for that, it doesn't mean mean you B<should>.

This is where Data::Printer comes in. It is meant to do one thing
and one thing only:

I<< display Perl variables and objects on screen, properly
formatted >> (to be inspected by a human)

If you want to serialize/store/restore Perl data structures,
this module will NOT help you. Try L<Storable>, L<Data::Dumper>,
L<JSON>, or whatever. CPAN is full of such solutions!

=head1 COLORS

Below are all the available colorizations and their default values.
Note that both spellings ('color' and 'colour') will work.

   use Data::Printer {
     color => {
        array    => 'bright_white',  # array index numbers
        number   => 'bright_blue',   # numbers
        string   => 'bright_yellow', # strings
        class    => 'bright_green',  # class names
        undef    => 'bright_red',    # the 'undef' value
        hash     => 'magenta',       # hash keys
        regex    => 'yellow',        # regular expressions
        code     => 'green',         # code references
        glob     => 'bright_cyan',   # globs (usually file handles)
        repeated => 'white on_red',  # references to seen values
     },
   };

=head1 FILTERS

Data::Printer offers you the ability to use filters to override
any kind of data display. The filters are placed on a hash,
where keys are the types - or class names - and values
are anonymous subs that receive two arguments: the item itself
as first parameter, and the properties hashref (in case your
filter wants to read from it). This lets you quickly override
the way Data::Printer handles and displays data types and, in
particular, objects.

  use Data::Printer filters => {
            'DateTime'      => sub { $_[0]->ymd },
            'HTTP::Request' => sub { $_[0]->uri },
  };

Perl types are named as C<ref> calls them: I<SCALAR>, I<ARRAY>,
I<HASH>, I<REF>, I<CODE>, I<Regexp> and I<GLOB>. As for objects,
just use the class' name, as shown above.

As of version 0.13, you may also use the '-class' filter, which
will be called for all non-perl types (objects).

B<Note>: If you plan on calling C<p()> from I<within> an inline
filter, please make sure you are passing only REFERENCES as
arguments. See L</CAVEATS> below.

You may also like to specify standalone filter modules. Please
see L<Data::Printer::Filter> for further information on a more
powerful filter interface for Data::Printer, including useful
filters that are shipped as part of this distribution.


=head1 ALIASING

Data::Printer provides the nice, short, C<p()> function to dump your
data structures and objects. In case you rather use a more explicit
name, already have a C<p()> function (why?) in your code and want
to avoid clashing, or are just used to other function names for that
purpose, you can easily rename it:

  use Data::Printer alias => 'Dumper';

  Dumper( %foo );


=head1 CUSTOMIZATION

I tried to provide sane defaults for Data::Printer, so you'll never have
to worry about anything other than typing C<< "p( $var )" >> in your code.
That said, and besides coloring and filtering, there are several other
customization options available, as shown below (with default values):

  use Data::Printer {
      name           => 'var',   # name to display on cyclic references
      indent         => 4,       # how many spaces in each indent
      hash_separator => '   ',   # what separates keys from values
      index          => 1,       # display array indices
      multiline      => 1,       # display in multiple lines (see note below)
      max_depth      => 0,       # how deep to traverse the data (0 for all)
      sort_keys      => 1,       # sort hash keys
      deparse        => 0,       # use B::Deparse to expand subrefs
      show_tied      => 1,       # expose tied() variables
      class_method   => undef,   # if available in the target object, use
                                 # this method instead to dump it

      class => {
          internals => 1,        # show internal data structures of classes

          inherited => 'none',   # show inherited methods,
                                 # can also be 'all', 'private', or 'public'.

          expand    => 1,        # how deep to traverse the object (in case
                                 # it contains other objects). Defaults to
                                 # 1, meaning expand only itself. Can be any
                                 # number, 0 for no class expansion, and 'all'
                                 # to expand everything.

          sort_methods => 1      # sort public and private methods
      },
  };

Note: setting C<multiline> to C<0> will also set C<index> and C<indent> to C<0>.

=head1 CONFIGURATION FILE (RUN CONTROL)

Data::Printer tries to let you easily customize as much as possible
regarding the visualization of your data structures and objects.
But we don't want you to keep repeating yourself every time you
want to use it!

To avoid this, you can simply create a file called C<.dataprinter> in
your home directory (usually C</home/username> in Linux), and put
your configuration hash reference in there.

This way, instead of doing something like:

   use Data::Printer {
     colour => {
        array => 'bright_blue',
     },
     filters => {
         'Catalyst::Request' => sub {
             my $req = shift;
             return "Cookies: " . p($req->cookies)
         },
     },
   };

You can create a .dataprinter file like this:

   {
     colour => {
        array => 'bright_blue',
     },
     filters => {
         'Catalyst::Request' => sub {
             my $req = shift;
             return "Cookies: " . p($req->cookies)
         },
     },
   };

and from then on all you have to do while debugging scripts is:

  use Data::Printer;

and it will load your custom settings every time :)


=head1 THE "DDP" PACKAGE ALIAS

You're likely to add/remove Data::Printer from source code being
developed and debugged all the time, and typing it might feel too
long. Because of this the 'DDP' package is provided as a shorter
alias to Data::Printer:

   use DDP;
   p %some_var;


=head1 EXPERIMENTAL FEATURES

The following are volatile parts of the API which are subject to
change at any given version. Use them at your own risk.

=head2 Local Configuration (experimental!)

You can override global configurations by writing them as the second
parameter for p(). For example:

  p( %var, color => { hash => 'green' } );


=head2 Filter classes

As of Data::Printer 0.11, you can create complex filters as a separate
module. Those can even be uploaded to CPAN and used by other people!
See L<Data::Printer::Filter> for further information.

=head1 CAVEATS

You can't pass more than one variable at a time.

   p($foo, $bar); # wrong
   p($foo);       # right
   p($bar);       # right

You are supposed to pass variables, not anonymous structures:

   p( { foo => 'bar' } ); # wrong

   p %somehash;        # right
   p $hash_ref;        # also right


If you are using inline filters, and calling p() (or whatever name you
aliased it to) from inside those filters, you B<must> pass the arguments
to C<p()> as a reference:

  use Data::Printer {
      filters => {
          ARRAY => sub {
              my $listref = shift;
              my $string = '';
              foreach my $item (@$listref) {
                  $string .= p( \$item );      # p( $item ) will not work!
              }
              return $string;
          },
      },
  };

This happens because your filter function is compiled I<before> Data::Printer
itself loads, so the filter does not see the function prototype. As a way
to avoid unpleasant surprises, if you forget to pass a reference, Data::Printer
will generate an exception for you with the following message:

    'If you call p() inside a filter, please pass arguments as references'

Another way to avoid this is to use the much more complete L<Data::Printer::Filter>
interface for standalone filters.

=head1 BUGS

If you find any, please file a bug report.


=head1 SEE ALSO

L<Data::Dumper>

L<Data::Dump>

L<Data::Dumper::Concise>

L<Data::Dump::Streamer>

L<Data::PrettyPrintObjects>

L<Data::TreeDumper>


=head1 AUTHOR

Breno G. de Oliveira C<< <garu at cpan.org> >>

=head1 CONTRIBUTORS

Many thanks to everyone that helped design and develop this module, in
one way or the other. They are (alphabetically):

=over 4

=item * brian d foy

=item * Chris Prather (perigrin)

=item * Eden Cardim (edenc)

=item * Kartik Thakore (kthakore)

=item * Kip Hampton (ubu)

=item * Torsten Raudssus (Getty)

=back

If I missed your name, please drop me a line!


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Breno G. de Oliveira C<< <garu at cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>.



=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.



