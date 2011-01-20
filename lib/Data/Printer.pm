package Data::Printer;
use strict;
use warnings;
use Term::ANSIColor;
use Scalar::Util qw(reftype);
use Sort::Naturally;
use Class::MOP;
use Carp qw(croak);
require Object::ID;

use parent 'Exporter';
our @EXPORT = qw(p);
our @EXPORT_OK = qw(d);
our $VERSION = 0.01;

# defaults
my $properties = {
    'name'           => 'var',
    'indent'         => 4,
    'index'          => 1,
    'max_depth'      => 0,
    'multiline'      => 1,
    'deparse'        => 0,
    'hash_separator' => '    ',
    'color_for'      => {
        'array'  => 'bright_white',
        'number' => 'bright_blue',
        'string' => 'bright_yellow',
        'class'  => 'bright_green',
        'undef'  => 'bright_red',
        'hash'   => 'magenta',
        'regex'  => 'yellow',
        'code'   => 'green',
        'repeated' => 'white on_red',
    },
    'class' => {
        show_inherited => 'all',   # also 0, 'none', 'public' or 'private'
        expand         => 'first', # also 1, 'all', 'none', 0
        internals      => 1,
        show_export    => 1,
    },

};


sub p (\[@$%&];%) {
    my ($item, %local_properties) = @_;
    my $p = _init(\%local_properties);

    print STDERR _p( $item, $p ) . $/;
}

sub d (\[@$%&];%) {
    my ($item, %local_properties) = @_;
    my $p = _init(\%local_properties);

    return _p( $item, $p );
}

sub _init {
    return {
        %$properties,            # first we get the global settings

        '_current_indent' => 0,  # used internally
        '_seen'           => {}, # used internally
    };
}

sub _p {
    my ($item, $p) = @_;
    my $ref = ref $item;

    my $string = '';

    # Object's unique ID, avoiding circular structures
    my $id = Object::ID::object_id( $item );
    return colored($p->{_seen}->{$id}, $p->{color_for}->{repeated}
    ) if exists $p->{_seen}->{$id};

    $p->{_seen}->{$id} = $p->{name};

    if ($ref eq 'SCALAR') {
        if (not defined $$item) {
            $string .= colored('undef', $p->{color_for}->{'undef'});
        }
        elsif (Scalar::Util::looks_like_number($$item)) {
            $string .= colored($$item, $p->{color_for}->{'number'});
        }
        else {
            $string .= colored(qq["$$item"], $p->{color_for}->{'string'});
        }
    }

    elsif ($ref eq 'REF') {
        $string .= '\\ ' . _p($$item, $p);
    }

    elsif ($ref eq 'CODE') {
        $string .= colored('sub { ... }', $p->{color_for}->{'code'});
    }

    elsif ($ref eq 'Regexp') {
        my $val = "$item";
        # a regex to parse a regex. Talk about full circle :)
        if ($val =~ m/\(\?([xism]*)(?:\-[xism]+)?:(.*)\)/) {
            my ($modifiers, $val) = ($1, $2);
            $string .= colored($val, $p->{color_for}->{'regex'});
            if ($modifiers) {
                $string .= "  (modifiers: $modifiers)";
            }
        }
        else {
            croak "Unrecognized regex $val. Please submit a bug report for Data::Printer.";
        }
    }

    elsif ($ref eq 'ARRAY') {
        $string .= "[\n";
        $p->{_current_indent} += $p->{indent};
        foreach my $i (0 .. $#{$item} ) {
            $p->{name} .= "[$i]";

            my $array_elem = $item->[$i];
            $string .= (' ' x $p->{_current_indent})
                     . colored(
                             sprintf("%-*s", 3 + length($#{$item}), "[$i]"),
                             $p->{color_for}->{'array'}
                       );

            $ref = ref $array_elem;

            # scalar references should be re-referenced
            # to gain a '\' sign in front of them
            if (!$ref or $ref eq 'SCALAR') {
                $string .= _p( \$array_elem, $p );
            }
            else {
                $string .= _p( $array_elem, $p );
            }
            $string .= ",\n";
            my $size = 2 + length($i); # [10], [100], etc
            substr $p->{name}, -$size, $size, '';
        }
        $p->{_current_indent} -= $p->{indent};
        $string .= (' ' x $p->{_current_indent}) . "]";
    }

    elsif ($ref eq 'HASH') {
        $string .= "{\n";
        $p->{_current_indent} += $p->{indent};

        # length of the largest key is used for indenting
        my $len = 0;
        foreach (keys %$item) {
            my $l = length;
            $len = $l if $l > $len;
        }

        foreach my $key (nsort keys %$item) {
            $p->{name} .= "{$key}";
            my $element = $item->{$key};

            $string .= (' ' x $p->{_current_indent})
                     . colored(
                             sprintf("%-*s", $len, $key),
                             $p->{color_for}->{'hash'}
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
            $string .= ",\n";

            my $size = 2 + length($key); # {foo}, {z}, etc
            substr $p->{name}, -$size, $size, '';
        }
        $p->{_current_indent} -= $p->{indent};
        $string .= (' ' x $p->{_current_indent}) . "}";
    }
    else {
        $string .= _class($ref, $item, $p);
    }

    return $string;
}

sub _class {
    my ($ref, $item, $p) = @_;

    my $string = '';

    $string .= colored($ref, $p->{color_for}->{'class'}) . "  {\n";

    $p->{_current_indent} += $p->{indent};

    my $meta = Class::MOP::Class->initialize($ref);

    $string .= (' ' x $p->{_current_indent})
             . 'Parents       ' 
             . join(', ', map { colored($_, $p->{color_for}->{'class'}) }
                          $meta->superclasses
               ) . $/;

    $string .= (' ' x $p->{_current_indent})
             . 'Linear @ISA   '
             . join(', ', map { colored( $_, $p->{color_for}->{'class'}) }
                          $meta->linearized_isa
               ) . $/;


    $string .= _show_methods($ref, $meta, $p);

    my $realtype = reftype $item;
    $string .= (' ' x $p->{_current_indent})
             . 'internals: ';

    # Note: we can't do p($$item) directly
    # or we'd fall in a deep recursion trap
    if ($realtype eq 'SCALAR') {
        my $realvalue = $$item;
        $string .= _p(\$realvalue, $p);
    }
    elsif ($realtype eq 'HASH') {
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
    else {
        croak "Type '$realtype' not identified. Please file a bug report for Data::Printer.";
    }

    $p->{_current_indent} -= $p->{indent};
    $string .= $/ . (' ' x $p->{_current_indent}) . "}";

    return $string;
}

sub _show_methods {
    my ($ref, $meta, $p) = @_;

    my $string = '';
    my $methods = {
        public => [],
        private => [],
    };
    foreach my $method ($meta->get_all_methods) {
        my $method_string = $method->name;

        if ($method->package_name ne $ref) {
            next; #FIXME :)
            $method_string .= ' (' . $method->package_name . ')';
        }

        my $type = substr($method->name, 0, 1) eq '_' ? 'private' : 'public';
            push @{ $methods->{$type} }, $method_string;
    }

    # render our string doing a natural sort by method name
    foreach my $type (qw(public private)) {
        my @list = nsort @{ $methods->{$type} };

        $string .= (' ' x $p->{_current_indent})
                 . "$type methods (" . scalar @list . ')'
                 . (@list ? ' : ' : '')
                 . join(', ', map { colored($_, $p->{color_for}->{class}) }
                              @list
                   ) . $/;
    }

    return $string;
}

1;
__END__

=head1 NAME

Data::Print - colored pretty-print of Perl data structures and objects

=head1 SYNOPSIS

  use Data::Printer;

  my @array = qw(a b);
  $array[3] = 'c';
  
  p(@array);  # no need to pass references!

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
printing it in STDERR, you can export the 'd' function.

  use Data::Printer 'd';

  warn d(%some_hash);


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
this module will NOT help you. Try Storable, Data::Dumper,
JSON, or whatever. CPAN is full of such solutions!

=head1 WARNING - EXTREMELY BETA CODE

Volatile interface and internals. Use at your own risk :)

=head1 CAVEATS

You can't pass more than one variable at a time.

   p($foo, $bar); # wrong
   p($foo);       # right
   p($bar);       # right

You are supposed to pass variables, not anonymous structures:

   p( { foo => 'bar' } ); # wrong

   p( %somehash );        # right
   p( $hash_ref );        # also right


=head1 BUGS

If you find any, please file a bug report.


=head1 SEE ALSO

L<Data::Dumper>

L<Data::Dump>

L<Data::Dumper::Concise>

L<Data::Dump::Streamer>

L<Data::TreeDumper>


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



