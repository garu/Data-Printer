package Data::Printer;
use strict;
use warnings;
use Term::ANSIColor;
use Scalar::Util;
use Sort::Naturally;
use Class::MOP;
use Carp qw(croak);
use Clone qw(clone);
use Hash::FieldHash qw(fieldhash);
use File::Spec;
use File::HomeDir ();
use Fcntl;

our $VERSION = 0.20;

BEGIN {
    if ($^O =~ /Win32/i) {
        require Win32::Console::ANSI;
        Win32::Console::ANSI->import;
    }
}


# defaults
my $BREAK = "\n";
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
    'use_prototypes' => 1,
    'colored'        => 'auto',       # also 0 or 1
    'caller_info'    => 0,
    'caller_message' => 'Printing in line __LINE__ of __FILENAME__:',
    'class_method'   => '_data_printer', # use a specific dump method, if available
    'color'          => {
        'array'       => 'bright_white',
        'number'      => 'bright_blue',
        'string'      => 'bright_yellow',
        'class'       => 'bright_green',
        'undef'       => 'bright_red',
        'hash'        => 'magenta',
        'regex'       => 'yellow',
        'code'        => 'green',
        'glob'        => 'bright_cyan',
        'repeated'    => 'white on_red',
        'caller_info' => 'bright_cyan',
        'weak'        => 'cyan',
    },
    'class' => {
        inherited    => 'none',   # also 'all', 'public' or 'private'
        parents      => 1,
        linear_isa   => 1,
        expand       => 1,        # how many levels to expand. 0 for none, 'all' for all
        internals    => 1,
        export       => 1,
        sort_methods => 1,
        show_methods => 'all',    # also 'none', 'public', 'private'
        _depth       => 0,        # used internally
    },
    'filters' => {
        SCALAR => [ \&SCALAR ],
        ARRAY  => [ \&ARRAY  ],
        HASH   => [ \&HASH   ],
        REF    => [ \&REF    ],
        CODE   => [ \&CODE   ],
        GLOB   => [ \&GLOB   ],
        Regexp => [ \&Regexp ],
        -class => [ \&_class ],
    },

    _current_indent  => 0,           # used internally
    _linebreak       => \$BREAK,     # used internally
    _seen            => {},          # used internally
    _depth           => 0,           # used internally
    _tie             => 0,           # used internally
};


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

    my $exported = ($properties->{use_prototypes} ? \&p : \&np );
    my $imported = $properties->{alias} || 'p';
    my $caller = caller;
    no strict 'refs';
    *{"$caller\::$imported"} = $exported;
}


# get it? get it? :)
sub p (\[@$%&];%) { _data_printer(@_) }
sub np            { _data_printer(@_) }

sub _data_printer {
    croak 'When calling p() without prototypes, please pass arguments as references'
        unless ref $_[0];

    my ($item, %local_properties) = @_;
    local %ENV = %ENV;

    my $p = _merge(\%local_properties);
    unless ($p->{multiline}) {
        $BREAK = ' ';
        $p->{'indent'} = 0;
        $p->{'index'}  = 0;
    }

    # We disable colors if colored is set to false.
    # If set to "auto", we disable colors if the user
    # set ANSI_COLORS_DISABLED or if we're either
    # returning the value (instead of printing) or
    # being piped to another command.
    if ( !$p->{colored}
          or ($p->{colored} eq 'auto'
              and (exists $ENV{ANSI_COLORS_DISABLED}
                   or defined wantarray
                   or not -t *STDERR
                  )
          )
    ) {
        $ENV{ANSI_COLORS_DISABLED} = 1;
    }
    else {
        delete $ENV{ANSI_COLORS_DISABLED};
    }

    my $out = color('reset');

    if ( $p->{caller_info} and $p->{_depth} == 0 ) {
        $out .= _get_info_message($p);
    }

    $out .= _p( $item, $p );
    print STDERR  $out . $/ unless defined wantarray;
    return $out;
}


sub _p {
    my ($item, $p) = @_;
    my $ref = (defined $p->{_reftype} ? $p->{_reftype} : ref $item);
    my $tie;

    my $string = '';

    # Object's unique ID, avoiding circular structures
    my $id = _object_id( $item );
    if ( exists $p->{_seen}->{$id} ) {
        if ( not defined $p->{_reftype} ) {
            return colored($p->{_seen}->{$id}, $p->{color}->{repeated});
        }
    }
    else {
        $p->{_seen}->{$id} = $p->{name};
    }

    delete $p->{_reftype}; # abort override

    # globs don't play nice
    $ref = 'GLOB' if "$item" =~ /=GLOB\([^()]+\)$/;


    # filter item (if user set a filter for it)
    my $found;
    if ( exists $p->{filters}->{$ref} ) {
        foreach my $filter ( @{ $p->{filters}->{$ref} } ) {
            if ( defined (my $result = $filter->($item, $p)) ) {
                $string .= $result;
                $found = 1;
                last;
            }
        }
    }

    if (not $found) {
        # let '-class' filters have a go
        foreach my $filter ( @{ $p->{filters}->{'-class'} } ) {
            if ( defined (my $result = $filter->($item, $p)) ) {
                $string .= $result;
                last;
            }
        }
    }

    if ($p->{show_tied} and $p->{_tie} ) {
        $string .= ' (tied to ' . $p->{_tie} . ')';
    }

    return $string;
}



######################################
## Default filters
######################################

sub SCALAR {
    my ($item, $p) = @_;
    my $string = '';

    if (not defined $$item) {
        $string .= colored('undef', $p->{color}->{'undef'});
    }
    elsif (Scalar::Util::looks_like_number($$item)) {
        $string .= colored($$item, $p->{color}->{'number'});
    }
    else {
        $string .= colored(qq["$$item"], $p->{color}->{'string'});
    }

    $p->{_tie} = ref tied $$item;

    return $string;
}


sub ARRAY {
    my ($item, $p) = @_;
    my $string = '';
    $p->{_depth}++;

    if ( $p->{max_depth} and $p->{_depth} > $p->{max_depth} ) {
        $string .= '[ ... ]';
    }
    elsif (not @$item) {
        $string .= '[]';
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

            my $ref = ref $array_elem;

            # scalar references should be re-referenced
            # to gain a '\' sign in front of them
            if (!$ref or $ref eq 'SCALAR') {
                $string .= _p( \$array_elem, $p );
            }
            else {
                $string .= _p( $array_elem, $p );
            }
            $string .= ' ' . colored('(weak)', $p->{color}->{'weak'})
                if $ref and Scalar::Util::isweak($item->[$i]);

            $string .= ($i == $#{$item} ? '' : ',') . $BREAK;
            my $size = 2 + length($i); # [10], [100], etc
            substr $p->{name}, -$size, $size, '';
        }
        $p->{_current_indent} -= $p->{indent};
        $string .= (' ' x $p->{_current_indent}) . "]";
    }

    $p->{_tie} = ref tied @$item;
    $p->{_depth}--;

    return $string;
}


sub REF {
    my ($item, $p) = @_;
    my $string = '';

    # look-ahead, add a '\' only if it's not an object
    if (my $ref_ahead = ref $$item ) {
        $string .= '\\ ' if grep { $_ eq $ref_ahead }
            qw(SCALAR CODE Regexp ARRAY HASH GLOB REF);
    }
    $string .= _p($$item, $p);
    $string .= ' ' . colored('(weak)', $p->{color}->{'weak'}) if Scalar::Util::isweak($$item);
    return $string;
}


sub CODE {
    my ($item, $p) = @_;
    my $string = '';

    my $code = 'sub { ... }';
    if ($p->{deparse}) {
        $code = _deparse( $item, $p );
    }
    $string .= colored($code, $p->{color}->{'code'});
    return $string;
}


sub HASH {
    my ($item, $p) = @_;
    my $string = '';

    $p->{_depth}++;

    if ( $p->{max_depth} and $p->{_depth} > $p->{max_depth} ) {
        $string .= '{ ... }';
    }
    elsif (not keys %$item) {
        $string .= '{}';
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

            my $ref = ref $element;
            # scalar references should be re-referenced
            # to gain a '\' sign in front of them
            if (!$ref or $ref eq 'SCALAR') {
                $string .= _p( \$element, $p );
            }
            else {
                $string .= _p( $element, $p );
            }
            $string .= ' ' . colored('(weak)', $p->{color}->{'weak'})
                if $ref and Scalar::Util::isweak($item->{$key});

            $string .= (--$total_keys == 0 ? '' : ',') . $BREAK;

            my $size = 2 + length($key); # {foo}, {z}, etc
            substr $p->{name}, -$size, $size, '';
        }
        $p->{_current_indent} -= $p->{indent};
        $string .= (' ' x $p->{_current_indent}) . "}";
    }

    $p->{_tie} = ref tied %$item;
    $p->{_depth}--;

    return $string;
}


sub Regexp {
    my ($item, $p) = @_;
    my $string = '';

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
    return $string;
}


sub GLOB {
    my ($item, $p) = @_;
    my $string = '';

    $string .= colored("$$item", $p->{color}->{'glob'});

    my $extra = '';

    # unfortunately, some systems (like Win32) do not
    # implement some of these flags (maybe not even
    # fcntl() itself, so we must wrap it.
    my $flags;
    eval { $flags = fcntl($$item, F_GETFL, 0) };
    if ($flags) {
        $extra .= ($flags & O_WRONLY) ? 'write-only'
                : ($flags & O_RDWR)   ? 'read/write'
                : 'read-only'
                ;

        # How to avoid croaking when the system
        # doesn't implement one of those, without skipping
        # the whole thing? Maybe there's a better way.
        # Solaris, for example, doesn't have O_ASYNC :(
        my %flags = ();
        eval { $flags{'append'}      = O_APPEND   };
        eval { $flags{'async'}       = O_ASYNC    };
        eval { $flags{'create'}      = O_CREAT    };
        eval { $flags{'truncate'}    = O_TRUNC    };
        eval { $flags{'nonblocking'} = O_NONBLOCK };

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

    $p->{_tie} = ref tied *$$item;
    return $string;
}


sub _class {
    my ($item, $p) = @_;
    my $ref = ref $item;

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
            if ($p->{class}{parents}) {
                $string .= (' ' x $p->{_current_indent})
                        . 'Parents       '
                        . join(', ', map { colored($_, $p->{color}->{'class'}) }
                                     @superclasses
                        ) . $BREAK;
            }

            if ($p->{class}{linear_isa}) {
                $string .= (' ' x $p->{_current_indent})
                        . 'Linear @ISA   '
                        . join(', ', map { colored( $_, $p->{color}->{'class'}) }
                                  $meta->linearized_isa
                        ) . $BREAK;
            }
        }

        $string .= _show_methods($ref, $meta, $p)
            if $p->{class}{show_methods} and $p->{class}{show_methods} ne 'none';

        if ( $p->{'class'}->{'internals'} ) {
            $string .= (' ' x $p->{_current_indent})
                    . 'internals: ';

            local $p->{_reftype} = Scalar::Util::reftype $item;
            $string .= _p($item, $p);
            $string .= $BREAK;
        }

        $p->{_current_indent} -= $p->{indent};
        $string .= (' ' x $p->{_current_indent}) . "}";
    }
    $p->{class}{_depth}--;

    return $string;
}



######################################
## Auxiliary (internal) subs
######################################

# All glory to Vincent Pit for coming up with this implementation,
# to Goro Fuji for Hash::FieldHash, and of course to Michael Schwern
# and his "Object::ID", whose code is copied almost verbatim below.
{
    fieldhash my %IDs;

    my $Last_ID = "a";
    sub _object_id {
        my $self = shift;

        # This is 15% faster than ||=
        return $IDs{$self} if exists $IDs{$self};
        return $IDs{$self} = ++$Last_ID;
    }
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
    my $show_methods = $p->{class}{show_methods};
    foreach my $type (qw(public private)) {
        next unless $show_methods eq 'all'
                 or $show_methods eq $type;

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

sub _get_info_message {
    my $p = shift;
    my @caller = caller 2;

    my $message = $p->{caller_message};

    $message =~ s/\b__PACKAGE__\b/$caller[0]/g;
    $message =~ s/\b__FILENAME__\b/$caller[1]/g;
    $message =~ s/\b__LINE__\b/$caller[2]/g;

    return colored($message, $p->{color}{caller_info}) . $BREAK;
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
                    my $filters = $val->{$item};

                    # EXPERIMENTAL: filters in modules
                    if ($item eq '-external') {
                        my @external = ( ref($filters) ? @$filters : ($filters) );

                        foreach my $class ( @external ) {
                            my $module = "Data::Printer::Filter::$class";
                            eval "use $module";
                            if ($@) {
                                warn "Error loading filter '$module': $@";
                            }
                            else {
                                my %from_module = %{$module->_filter_list};
                                foreach my $k (keys %from_module) {
                                    unshift @{ $clone->{filters}->{$k} }, @{ $from_module{$k} };
                                }
                            }
                        }
                    }
                    else {
                        my @filter_list = ( ref $filters eq 'CODE' ? ( $filters ) : @$filters );
                        unshift @{ $clone->{filters}->{$item} }, @filter_list;
                    }
                }
            }
            else {
                $clone->{$key} = $p->{$key};
            }
        }
    }

    return $clone;
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
a 'C<.dataprinter>' file in your home dir and don't repeat yourself
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
        array       => 'bright_white',  # array index numbers
        number      => 'bright_blue',   # numbers
        string      => 'bright_yellow', # strings
        class       => 'bright_green',  # class names
        undef       => 'bright_red',    # the 'undef' value
        hash        => 'magenta',       # hash keys
        regex       => 'yellow',        # regular expressions
        code        => 'green',         # code references
        glob        => 'bright_cyan',   # globs (usually file handles)
        repeated    => 'white on_red',  # references to seen values
        caller_info => 'bright_cyan',   # details on what's being printed
        weak        => 'cyan'           # weak references
     },
   };

Don't fancy colors? Disable them with:

  use Data::Printer colored => 0;

Remember to put your preferred settings in the C<.dataprinter> file
so you never have to type them at all!


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
      caller_info    => 0,       # include information on what's being printed
      use_prototypes => 1,       # allow p(%foo), but prevent anonymous data

      class_method   => '_data_printer', # make classes aware of Data::Printer
                                         # and able to dump themselves.

      class => {
          internals  => 1,       # show internal data structures of classes

          inherited  => 'none',  # show inherited methods,
                                 # can also be 'all', 'private', or 'public'.

          parents    => 1,       # show parents?
          linear_isa => 1,       # show the entire @ISA, linearized

          expand     => 1,       # how deep to traverse the object (in case
                                 # it contains other objects). Defaults to
                                 # 1, meaning expand only itself. Can be any
                                 # number, 0 for no class expansion, and 'all'
                                 # to expand everything.

          sort_methods => 1,     # sort public and private methods

          show_methods => 'all'  # method list. Also 'none', 'public', 'private'
      },
  };

Note: setting C<multiline> to C<0> will also set C<index> and C<indent> to C<0>.


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

Your filters are supposed to return a defined value (usually, the
string you want to print). If you don't, Data::Printer will
let the next filter of that same type have a go, or just fallback
to the defaults. You can also use an array reference to pass more
than one filter for the same type or class.

B<Note>: If you plan on calling C<p()> from I<within> an inline
filter, please make sure you are passing only REFERENCES as
arguments. See L</CAVEATS> below.

You may also like to specify standalone filter modules. Please
see L<Data::Printer::Filter> for further information on a more
powerful filter interface for Data::Printer, including useful
filters that are shipped as part of this distribution.

=head1 MAKING YOUR CLASSES DDP-AWARE (WITHOUT ADDING ANY DEPS)

Whenever printing the contents of a class, Data::Printer first
checks to see if that class implements a sub called '_data_printer'
(or whatever you set the "class_method" option to in your settings,
see L</CUSTOMIZATION> below).

If a sub with that exact name is available in the target object,
Data::Printer will use it to get the string to print instead of
making a regular class dump.

This means you could have the following in one of your classes:

  sub _data_printer {
      my ($self, $properties) = @_;
      return 'Hey, no peeking! But foo contains ' . $self->foo;
  }

Notice you don't have to depend on Data::Printer at all, just
write your sub and it will use that to pretty-print your objects.

If you want to use colors and filter helpers, and still not
add Data::Printer to your dependencies, remember you can import
them during runtime:

  sub _data_printer {
      require Data::Printer::Filter;
      Data::Printer::Filter->import;

      # now we have 'indent', outdent', 'linebreak', 'p' and 'colored'
      my ($self, $properties) = @_;
      ...
  }

Having a filter for that particular class will of course override
this setting.


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

=head1 CALLER INFORMATION

If you set caller_info to a true value, Data::Printer will prepend
every call with an informational message. For example:

  use Data::Printer caller_info => 1;

  my $var = 42;
  p $var;

will output something like:

  Printing in line 4 of myapp.pl:
  42

The default message is C<< 'Printing in line __LINE__ of __FILENAME__:' >>.
The special strings C<__LINE__>, C<__FILENAME__> and C<__PACKAGE__> will
be interpolated into their according value so you can customize them at will:

  use Data::Printer
    caller_info => 1,
    caller_message => "Okay, __PACKAGE__, let's dance!"
    color => {
        caller_info => 'bright_red',
    };

As shown above, you may also set a color for "caller_info" in your color
hash. Default is cyan.


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

The default mode is to use prototypes, in which you are supposed to pass
variables, not anonymous structures:

   p( { foo => 'bar' } ); # wrong

   p %somehash;        # right
   p $hash_ref;        # also right

To pass anonymous structures, set "use_prototypes" option to 0. But
remember you'll have to pass your variables as references:

   use Data::Printer use_prototypes => 0;

   p( { foo => 'bar' } ); # was wrong, now is right.

   p( %foo  ); # was right, but fails without prototypes
   p( \%foo ); # do this instead

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

=head1 EXTRA TIPS

=head2 Adding p() to all your loaded modules

I<< (contributed by Árpád Szász) >>

For even faster debugging you can automatically add Data::Printer's C<p()>
function to every loaded module using this in your main program:

    BEGIN {
        {
            use Data::Printer;
            no strict 'refs';
            foreach my $package ( keys %main:: ) {
                my $alias = 'p';
                *{ $package . $alias } = \&Data::Printer::p;
            }
        }
    }

B<WARNING> This will override all locally defined subroutines/methods that
are named C<p>, if they exist, in every loaded module, so be sure to change
C<$alias> to something custom.

=head2 Circumventing prototypes

The C<p()> function uses prototypes by default, allowing you to say:

  p %var;

instead of always having to pass references, like:

  p \%var;

There are cases, however, where you may want to pass anonymous
structures, like:

  p { foo => $bar };   # this blows up, don't use

and because of prototypes, you can't. If this is your case, just
set "use_prototypes" option to 0. Note, with this option,
you B<will> have to pass your variables as references:

  use Data::Printer use_prototypes => 0;

   p { foo => 'bar' }; # doesn't blow up anymore, works just fine.

   p %var;  # but now this blows up...
   p \%var; # ...so do this instead

In versions prior to 0.17, you could use C<&p()> instead of C<p()>
to circumvent prototypes and pass elements (including anonymous variables)
as B<REFERENCES>. This notation, however, requires enclosing parentheses:

  &p( { foo => $bar } );        # this is ok, use at will
  &p( \"DEBUGGING THIS BIT" );  # this works too

Or you could just create a very simple wrapper function:

  sub pp { p @_ };

And use it just as you use C<p()>.

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

=head2 Unified interface for Data::Printer and other debug formatters

I<< (contributed by Kevin McGrath) >>

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
like L<< Any::Renderer::Data::Printer|https://github.com/kmcgrath/Any-Renderer-Data-Printer >>.


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

Many thanks to everyone that helped design and develop this module
with patches, bug reports, wishlists, comments and tests. They are
(alphabetically):

=over 4

=item * Árpád Szász

=item * brian d foy

=item * Chris Prather (perigrin)

=item * Damien Krotkine (dams)

=item * Dotan Dimet

=item * Eden Cardim (edenc)

=item * Elliot Shank (elliotjs)

=item * Fernando Corrêa (SmokeMachine)

=item * Kartik Thakore (kthakore)

=item * Kevin McGrath (catlgrep)

=item * Kip Hampton (ubu)

=item * Mike Doherty (doherty)

=item * Paul Evans (LeoNerd)

=item * Sebastian Willing (Sewi)

=item * Sergey Aleynikov (randir)

=item * sugyan

=item * Tatsuhiko Miyagawa (miyagawa)

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



