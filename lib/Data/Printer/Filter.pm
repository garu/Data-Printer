package Data::Printer::Filter;
use strict;
use warnings;
use Data::Printer::Common;
use Scalar::Util;

sub import {
    my $caller = caller;

    my %_filters_for  = ();
    my $filter = sub {
        my ($name, $code) = @_;
        Data::Printer::Common::_die( "syntax: filter 'Class', sub { ... }" )
          unless defined $name
              && defined $code
              && Scalar::Util::reftype($code) eq 'CODE';

        my $target = Data::Printer::Common::_filter_category_for($name);
        unshift @{$_filters_for{$target}{$name}}, sub {
            my ($item, $ddp) = @_;
            $code->($item, $ddp);
        };
    };

    {
        no strict 'refs';
        *{"$caller\::filter"}  = $filter;
        *{"$caller\::_filter_list"} = sub { \%_filters_for };
    }
};

1;
__END__

=head1 NAME

Data::Printer::Filter - Create powerful stand-alone filters for Data::Printer

=head1 SYNOPSIS

Every time you say in your C<.dataprinter> file:

    filters = SomeFilter, OtherFilter

Data::Printer will look for C<Data::Printer::Filter::SomeFilter> and
C<Data::Printer::Filter::OtherFilter> on your C<@INC> and load them.
To load filters without a configuration file:

    use DDP filters => ['SomeFilter', 'OtherFilter'];

Creating your own filter module is super easy:

    package Data::Printer::Filter::MyFilter;
    use Data::Printer::Filter;

    # this filter will run every time DDP runs into a string/number
    filter 'SCALAR' => sub {
        my ($scalar_ref, $ddp) = @_;

        if ($$scalar_ref =~ /password/) {
            return '*******';
        }
        return; # <-- let other SCALAR filters have a go!
    };

    # you can also filter objects of any class!
    filter 'Some::Class' => sub {
        my ($object, $ddp) = @_;

        if (exists $object->{some_data}) {
            return $ddp->parse( $object->{some_data} );
        }
        else {
            return $object->some_method;
        }
    };

Later, in your main code:

    use DDP filters => ['MyFilter'];

Or, in your C<.dataprinter> file:

    filters = MyFilter

=head1 DESCRIPTION

L<Data::Printer> lets you add custom filters to display data structures and
objects as you see fit to better understand and inspect/debug its contents.

While you I<can> put your filters inline in either your C<use> statements
or your inline calls to C<p()>, like so:

    use DDP filters => [{
        SCALAR => sub { 'OMG A SCALAR!!' }
    }];

    p @x, filters => [{ HASH => sub { die 'oh, noes! found a hash in my array' } }];

Most of the time you probably want to create full-featured filters as a
standalone module, to use in many different environments and maybe even
upload and share them on CPAN.

This is where C<Data::Printer::Filter> comes in. Every time you C<use> it
in a package it will export the C<filter> keyword which you can use to
create your own filters.

Note: the loading B<order of filters matter>. They will be called in order
and the first one to return something for the data being analysed will be
used.

=head1 HELPER FUNCTIONS

=head2 filter TYPE, sub { ... };

The C<filter> function creates a new filter for I<TYPE>, using the given
subref. The subref receives two arguments: the item itself - be it an object
or a reference to a standard Perl type - and the current
L<Data::Printer::Object> being used to parse the data.

Inside your filter you are expected to either return a string with whatever
you want to display for that type/object, or an empty "C<return;>" statement
meaning I<"Nothing to do, my mistake, let other filters have a go"> (which
includes core filters from Data::Printer itself).

You may use the current L<Data::Printer::Object> to issue formatting calls
like:

=over 4

=item * C<< $ddp->indent >> - adds to the current indentation level.

=item * C<< $ddp->outdent >> - subtracts from the current indentation level.

=item * C<< $ddp->newline >> - returns a string containing a lineabreak
and the proper number of spaces for the right indentation. It also
accounts for the C<multiline> option so you don't have to worry about it.

=item * C<< $ddp->maybe_colorize( $string, 'label', 'default_color' ) >> -
returns the given string either unmodified (if the output is not colored) or
with the color set for I<'label'> (e.g. "class", "array", "brackets"). You are
encouraged to provide your own custom colors by labelling them C<filter_*>,
which is guaranteed to never collide with a core color label.

=item * C<< $ddp->extra_config >> - all options set by the user either in
calls to DDP or in the C<.dataprinter> file that are not used by
Data::Printer itself will be put here. You are encouraged to provide your
own customization options by labelling them C<filter_*>, which is guaranteed
to never collide with a local setting.

=item * C<< $ddp->parse( $data ) >> - parses and returns the string output of
the given data structure.

=back

=head1 COMPLETE ANNOTATED EXAMPLE

As an example, let's create a custom filter for arrays using
all the options above:

    filter ARRAY => sub {
        my ($array_ref, $ddp) = @_;
        my $output;

        if ($ddp->extra_config->{filter_array}{header}) {
            $output = $ddp->maybe_colorize(
                'got this array:',
                'filter_array_header',
                '#cc7fa2'
            );
        }

        $ddp->indent;
        foreach my $element (@$ref) {
            $output .= $ddp->newline . $ddp->parse($element);
        }
        $ddp->outdent;

        return $output;
    };

Then whenever you pass an array to Data::Printer, it will call this code.
First it checks if the user has our made up custom option
I<'filter_array.header'>. It can be set either with:

    use DDP filter_array => { header => 1 };

Or on C<.dataprinter> as:

    filter_array.header = 1

If it is set, we'll start the output string with I<"got this array">, colored
in whatever color was set by the user under the C<filter_array_header>
color tag - and defaulting to '#cc7fa2' in this case.

Then it updates the indentation, so any call to C<< $ddp->newline >> will add
an extra level of indentation to our output.

After that we walk through the array using C<foreach> and append each element
to our output string as I<newline + content>, where the content is whatever
string was returned from C<< $ddp->parse >>. Note that, if the element or any
of its subelements is an array, our filter will be called again, this time
for the new content.

Check L<Data::Printer::Object> for extra documentation on the methods used
above and many others!

=head1 DECORATING EXISTING FILTERS

It may be the case where you want to call this filter and manipulate the
result. To do so, make sure you make a named subroutine for your filters
instead of using an anonymous one. For instance, all of Data::Printer's
filters for core types have a 'parse' public function you can use:

    my $str = Data::Printer::Filter::HASH::parse($ref, $ddp);

=head1 AVAILABLE FILTERS

Data::Printer comes with filters for all Perl data types and several filters
for popular Perl modules available on CPAN. Take a look at
L<< the Data::Printer::Filter namespace|https://metacpan.org/search?q=Data%3A%3APrinter%3A%3AFilter >> for a complete list!

=head1 SEE ALSO

L<Data::Printer>
