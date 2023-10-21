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
    my @colors = ($value eq 'true'
        ? ('filter_web_json_true', '#ccffcc')
        : ('filter_web_json_false', '#ffcccc')
    );
    return $ddp->maybe_colorize($value, @colors);
}

# JSON::NotString is from JSON::Parser (JSON 1.x)
filter 'JSON::NotString' => sub { _parse_json_boolean($_[0]->{value}, $_[1]) };

# JSON::Typist
filter 'JSON::Typist::String' => sub {
    my ($obj, $ddp) = @_;
    require Data::Printer::Common;
    my $ret = Data::Printer::Common::_process_string($ddp, "$obj", 'string');
    my $quote = $ddp->maybe_colorize($ddp->scalar_quotes, 'quotes');
    return $quote . $ret . $quote;
};

filter 'JSON::Typist::Number' => sub {
    return $_[1]->maybe_colorize($_[0], 'number');
};

# NOTE: boolean is used by Pegex::JSON
foreach my $json (qw(
    JSON::DWIW::Boolean   JSON::PP::Boolean   JSON::SL::Boolean
    JSON::XS::Boolean     boolean             JSON::Tiny::_Bool
    Mojo::JSON::_Bool     Cpanel::JSON::XS::Boolean
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

####################
### Cookie parsers
#############################################

filter 'Mojo::Cookie' => sub {
    my ($obj, $ddp) = @_;
    return _format_cookie({
        expires   => scalar $obj->expires,
        max_age   => $obj->max_age,
        domain    => $obj->domain,
        path      => $obj->path,
        secure    => $obj->secure,
        http_only => $obj->httponly,
        host_only => ($obj->can('host_only') ? $obj->host_only : 0),
        name      => $obj->name,
        value     => $obj->value,
        class     => 'Mojo::Cookie',
    }, $ddp);
};

filter 'Dancer::Cookie' => sub {
    my ($obj, $ddp) = @_;
    return _format_cookie({
        expires   => scalar $obj->expires,
        domain    => $obj->domain,
        path      => $obj->path,
        secure    => $obj->secure,
        http_only => $obj->http_only,
        name      => $obj->name,
        value     => $obj->value,
        class     => 'Dancer::Cookie',
    }, $ddp);
};

filter 'Dancer2::Core::Cookie' => sub {
    my ($obj, $ddp) = @_;
    return _format_cookie({
        expires   => scalar $obj->expires,
        domain    => $obj->domain,
        path      => $obj->path,
        secure    => $obj->secure,
        http_only => $obj->http_only,
        name      => $obj->name,
        value     => $obj->value,
        class     => 'Dancer2::Core::Cookie',
    }, $ddp);
};

sub _format_cookie {
    my ($data, $ddp) = @_;
    return $ddp->maybe_colorize(
          $data->{name} . '='
        . Data::Printer::Common::_process_string($ddp, $data->{value})
        . '; expires=' . $data->{expires}
        . '; domain=' . $data->{domain}
        . '; path=' . $data->{path}
        . ('; secure'x!!$data->{secure})
        . ('; http-only'x!!$data->{http_only})
        . ('; host-only'x!!$data->{host_only})
        . (defined $data->{max_age} ? '; max-age=' . $data->{max_age} : '')
        , 'filter_web_cookie', '#0b3e21'
    ) . ' (' . $ddp->maybe_colorize($data->{class}, 'class') . ')';
}

####################
### HTTP parsers
#############################################

filter 'HTTP::Request' => sub {
    my ($obj, $ddp) = @_;
    my $output = $ddp->maybe_colorize($obj->method, 'filter_web_method', '#fefe33')
               . ' '
               . $ddp->maybe_colorize($obj->uri, 'filter_web_uri', '#fefe88')
               ;

    if ($ddp->extra_config->{filter_web}{show_class_name}) {
        $output .= ' (' . $ddp->maybe_colorize(ref $obj, 'class') . ')';
    }

    my $expand_headers = !exists $ddp->extra_config->{filter_web}{expand_headers}
                      || $ddp->extra_config->{filter_web}{expand_headers};

    my $content = $obj->decoded_content;
    if ($expand_headers || $content) {
        $output .= ' {';
        $ddp->indent;
        if ($expand_headers) {
            if ($obj->headers->can('flatten')) {
                my %headers = $obj->headers->flatten;
                $output .= $ddp->newline . 'headers: ' . $ddp->parse(\%headers);
            }
        }
        if ($content) {
            $output .= $ddp->newline . 'content: '
                    . Data::Printer::Common::_process_string($ddp, $content, 'string');
        }
        $ddp->outdent;
        $output .= $ddp->newline . '}';
    }
    return $output;
};

filter 'HTTP::Response' => sub {
    my ($obj, $ddp) = @_;
    my $output = _maybe_show_request($obj, $ddp);

    if (!exists $ddp->extra_config->{filter_web}{show_redirect}
        || $ddp->extra_config->{filter_web}{show_redirect}
    ) {
        foreach my $redir ($obj->redirects) {
            $output .= "\x{e2}\x{a4}\x{bf} "
                    . $redir->code . ' ' . $redir->message
                    . ' (' . $redir->header('location') . ')'
                    . $ddp->newline;
        }
    }

    my %colors = (
        1 => ['filter_web_response_info'    , '#3333fe'],
        2 => ['filter_web_response_success' , '#33fe33'],
        3 => ['filter_web_response_redirect', '#fefe33'],
        4 => ['filter_web_response_error'   , '#fe3333'],
        5 => ['filter_web_response_error'   , '#fe3333'],
    );
    my $status_key = substr($obj->code, 0, 1);
    $output .= $ddp->maybe_colorize(
        $obj->status_line,
        (exists $colors{$status_key} ? @{$colors{$status_key}} : @{$colors{1}})
    );

    if ($ddp->extra_config->{filter_web}{show_class_name}) {
        $output .= ' (' . $ddp->maybe_colorize(ref $obj, 'class') . ')';
    }

    my $expand_headers = !exists $ddp->extra_config->{filter_web}{expand_headers}
                      || $ddp->extra_config->{filter_web}{expand_headers};

    my $content = $obj->decoded_content;
    if ($expand_headers || $content) {
        $output .= ' {';
        $ddp->indent;
        if ($expand_headers) {
            if ($obj->headers->can('flatten')) {
                my %headers = $obj->headers->flatten;
                $output .= $ddp->newline . 'headers: ' . $ddp->parse(\%headers);
            }
        }
        if ($content) {
            $output .= $ddp->newline . 'content: '
                    . Data::Printer::Common::_process_string($ddp, $content, 'string');
        }
        $ddp->outdent;
        $output .= $ddp->newline . '}';
    }
    return $output;
};

sub _maybe_show_request {
    my ($obj, $ddp) = @_;
    return '' unless $ddp->extra_config->{filter_web}{show_request_in_response};

    my ($redir) = $obj->redirects;
    my $output = 'Request: ';
    my $request;
    if ($redir) {
        $request = $redir->request;
    }
    else {
        $request = $obj->request;
    }
    return $output . ($request ? $ddp->parse($request) : '-');
}


1;
__END__

=head1 NAME

Data::Printer::Filter::Web - pretty-printing of HTTP/JSON/LWP/Plack/Dancer/Catalyst/Mojo...

=head1 SYNOPSIS

In your C<.dataprinter> file:

    filters = Web

You may also customize the look and feel with the following options (defaults shown):

    filter_web.show_class_name          = 0
    filter_web.expand_headers           = 1
    filter_web.show_redirect            = 1
    filter_web.show_request_in_response = 0

    # you can even customize your themes:
    colors.filter_web_json_true         = #ccffcc
    colors.filter_web_json_false        = #ffcccc
    colors.filter_web_cookie            = #0b3e21
    colors.filter_web_method            = #fefe33
    colors.filter_web_uri               = $fefe88
    colors.filter_web_response_success  = #fefe33
    colors.filter_web_response_info     = #fefe33
    colors.filter_web_response_redirect = #fefe33
    colors.filter_web_response_error    = #fefe33

=head1 DESCRIPTION

This is a filter plugin for L<Data::Printer>. It filters through several
web-related objects and display their content in a (hopefully!) more useful
way than a regular dump.

=head1 PARSED MODULES

=head2 JSON

Because Perl has no C<true> or C<false> tokens, many JSON parsers implement
boolean objects to represent those. With this filter, you'll get "true" and
"false" (which is what probably you want to see) instead of an object dump
on those booleans. This module filters through the following modules:

C<JSON::PP>, C<JSON::XS>, C<JSON>, C<JSON::MaybeXS>, C<Cpanel::JSON::XS>,
C<JSON>, C<JSON::SL>, C<Pegex::JSON>, C<JSON::Tiny>, C<JSON::Any>,
C<JSON::DWIW> and C<Mojo::JSON>.

Also, if you use C<JSON::Typist> to parse your JSON strings, a Data::Printer
dump using this filter will always properly print numbers as numbers and
strings as strings.

=head2 COOKIES

This filter is able to handle cookies from C<Dancer>/C<Dancer2> and
C<Mojolicious> frameworks. Other frameworks like C<Catalyst> rely on
C<HTTP::CookieJar> and C<HTTP::Cookies>, which simply store them in a
hash, not an object.

=head2 HTTP REQUEST/RESPONSE

C<HTTP::Request> and C<HTTP::Response> objects are filtered to display
headers and content. These are returned by L<LWP::UserAgent>,
L<WWW::Mechanize> and many others.

If the response comes from chained redirects (that the source HTTP::Response
object knows about), this filter will show you the entire redirect chain
above the actual object. You may disable this by changing the
C<filter_web.show_redirect> option.


=head1 SEE ALSO

L<Data::Printer>
