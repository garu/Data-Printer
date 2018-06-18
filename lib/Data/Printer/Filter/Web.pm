package Data::Printer::Filter::Web;
use strict;
use warnings;
use Data::Printer::Filter;

####################
### JSON parsers
### Heavily inspired by nuba++'s excellent Data::Printer::Filter::JSON
#############################################

sub _parse_json_boolean {
    my ($value, $ddp) = @_;
    return $ddp->maybe_colorize($value, 'filter_web_json_true', '#ccffcc');
}

# JSON::NotString is from JSON::Parser (JSON 1.x)
filter 'JSON::NotString' => sub { _parse_json_boolean($_[0]->{value}, $_[1]) };

# NOTE: boolean is used by Pegex::JSON
foreach my $json (qw(
    JSON::DWIW::Boolean   JSON::PP::Boolean   JSON::SL::Boolean
    JSON::XS::Boolean     boolean             JSON::Tiny::_Bool
)) {
    filter "$json" => sub {
        my ($obj, $ddp) = @_;
        # because JSON boolean objects are just repeated all over
        # the place, we must remove them from our "seen" table:
        $ddp->unsee($obj);

        return _parse_json_boolean(($$obj == 1 ? 'true' : 'false'), $ddp);
    };
}

for my $json (qw( JSON::JOM::Value JSON::JOM::Array JSON::JOM::Object )) {
    filter "$json" => sub {
        my ($obj, $ddp) = @_;
        return $ddp->parse($obj->TO_JSON);
    };
}

1;
__END__

=head1 NAME

Data::Printer::Filter::Web - pretty-printing of HTTP/JSON/LWP/Dancer/Catalyst/Mojo...

=head1 SYNOPSIS

In your C<.dataprinter> file:

    filters = Web

=head1 DESCRIPTION

This is a filter plugin for L<Data::Printer>. It filters through several
web-related objects and display their content in a (hopefully!) more userful
way than a regular dump.

=head1 PARSED MODULES

=head2 JSON

Because Perl has no C<true> or C<false> tokens, many JSON parsers implement
boolean objects to represent those. With this filter, you'll get "true" and
"false" (which is what probably you want to see) instead of an object dump
on those booleans. This module filters through the following modules:

C<JSON::PP>, C<JSON::XS>, C<JSON>, C<JSON::MaybeXS>, C<Cpanel::JSON::XS>,
C<JSON::Parser>, C<JSON::SL>, C<Pegex::JSON>, C<JSON::Tiny>, C<JSON::Any>
and C<JSON::DWIW>.

=head1 SEE ALSO

L<Data::Printer>
