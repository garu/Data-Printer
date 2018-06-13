package Data::Printer::Filter::Digest;
use strict;
use warnings;
use Data::Printer::Filter;

filter 'Digest::base' => \&_print_digest;

# these modules don't inherit from Digest::base but have the same interface:
filter 'Digest::MD2'  => \&_print_digest;
filter 'Digest::MD4'  => \&_print_digest;

sub _print_digest {
  my ($obj, $ddp) = @_;
  my $digest = $obj->clone->hexdigest;
  my $str = $digest;
  my $ref = ref $obj;

  if ( !exists $ddp->extra_config->{filter_digest}{show_class_name}
      || $ddp->extra_config->{filter_digest}{show_class_name} ) {
      $str .= " ($ref)";
  }

  if( !exists  $ddp->extra_config->{filter_digest}{show_reset}
    || $ddp->extra_config->{filter_digest}{show_reset}
   ) {
     if ($digest eq $ref->new->hexdigest) {
         $str .= ' [reset]';
     }
  }

  return $ddp->maybe_colorize($str, 'datetime', '#ffaaff');
}

1;

__END__

=head1 NAME

Data::Printer::Filter::Digest - pretty-printing MD5, SHA and many other digests

=head1 SYNOPSIS

In your C<.dataprinter> file:

    filters = Digest

You may also setup the look and feel with the following options:

    filter_digest.show_class_name = 0
    filter_digest.show_reset      = 1

    # you can even customize your themes:
    colors.digest = #27ac3c

That's it!

=head1 DESCRIPTION

This is a filter plugin for L<Data::Printer>. It filters through
several message digest objects and displays their current value in
hexadecimal format as a string.

=head2 Parsed Modules

Any module that inherits from L<Digest::base>. The following ones
are actively supported:

=over 4

=item * L<Digest::Adler32>

=item * L<Digest::MD2>

=item * L<Digest::MD4>

=item * L<Digest::MD5>

=item * L<Digest::SHA>

=item * L<Digest::SHA1>

=item * L<Digest::Whirlpool>

=back

If you have any suggestions for more modules or better output,
please let us know.

=head2 Extra Options

Aside from the display color, there are a few other options to
be customized via the C<filter_digest> option key:

=head3 show_class_name

If set to true (the default) the class name will be displayed
right next to the hexadecimal digest.

=head3 show_reset

If set to true (the default), the filter will add a C<[reset]>
tag after dumping an empty digest object. See the rationale below.

=head2 Note on dumping Digest::* objects

The digest operation is effectively a destructive, read-once operation. Once
it has been performed, most Digest::* objects are automatically reset and can
be used to calculate another digest value.

This behaviour - or, rather, forgetting about this behaviour - is
a common source of issues when working with Digests.

This Data::Printer filter will B<not> destroy your object. Instead, we
work on a I<cloned> version to display the hexdigest, leaving your
original object untouched.

As another debugging convenience for developers, since the empty
object will produce a digest even after being used, this filter
adds by default a C<[reset]> tag to indicate that the object is
empty, in a 'reset' state - i.e. its hexdigest is the same as
the hexdigest of a new, empty object of that same class.

=head1 SEE ALSO

L<Data::Printer>
