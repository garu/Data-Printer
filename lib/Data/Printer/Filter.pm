package Data::Printer::Filter;
use strict;
use warnings;
use Clone qw(clone);
require Object::ID;

my %_filters_for = ();

sub import {
    my $caller = caller;
    my $id = Object::ID::object_id( \$caller );

    my %properties = ();

    my $filter = sub {
        my ($type, $code) = @_;

        $_filters_for{$id}{$type} = sub {
            my ($item, $p) = @_;

            # send our closured %properties var instead
            # so newline(), indent(), etc can work it
            %properties = %{ clone $p };
            $code->($item, \%properties);
        };
    };

    my $filters = sub {
        return $_filters_for{$id};
    };

    my $newline = sub {
        return ${$properties{_linebreak}} . (' ' x $properties{_current_indent});
    };

    {
        no strict 'refs';
        *{"$caller\::filter"}  = $filter;
        *{"$caller\::newline"} = $newline;

        *{"$caller\::_filter_list"} = $filters;
    }
};


1;
__END__

=head1 SYNOPSIS

Create your filter:

  package Data::Printer::Filter::MyFilter;
  use strict;
  use warnings;
  use Data::Printer::Filter;

  filter 'SCALAR', sub {
      my ($ref, $properties) = @_;
      my $val = $$ref;
      
      if ($val > 100) {
          return 'too big!!';
      }
      else {
          return $val;
      }
  };

  filter 'Some::Class', sub {
      my ($object, $properties) = @_;

      return $ref->some_method;   # or whatever
  }

  1;


Later, in your main code:

  use Data::Printer {
      filters => {
          external => [ 'MyFilter', 'OtherFilter' ],

          # you can still add regular (inline) filters
          SCALAR => sub {
              ...
          }
      },
  };

=head1 WARNING - ALPHA CODE (VERY LOOSE API)

We are still experimenting with the standalone filter syntax, so
B<< filters written like so may break in the future without any warning! >>

B<< If you care, or have any suggestions >>, please drop me a line via RT, email,
or find me ('garu') on irc.perl.org.

You have been warned.

=head1 SEE ALSO

L<Data::Printer>


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Breno G. de Oliveira C<< <garu at cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>.


