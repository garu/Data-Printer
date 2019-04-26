use strict;
use warnings;
use Test::More tests => 21;
use Data::Printer::Object;

test_json();
test_cookies();
test_http_request();
test_http_response();
exit;

sub test_http_request {
    SKIP: {
        my $error = !eval { require HTTP::Request; 1 };
        skip 'HTTP::Request not available', 1 if $error;
        my $r = HTTP::Request->new(
            'POST',
            'http://www.example.com/ddp',
            [
                'Content-Type'  => 'application/json; charset=UTF-8',
                'Cache-Control' => 'no-cache, must-revalidate',
            ],
            '{"foo":"bar","baz":42}'
        );
        skip 'HTTP::Headers is too old', 1 unless $r->headers->can('flatten');
        my $ddp = Data::Printer::Object->new(
            colored   => 0,
            filters   => ['Web'],
        );
        is(
            $ddp->parse($r),
            'POST http://www.example.com/ddp {
    headers: {
        Cache-Control   "no-cache, must-revalidate",
        Content-Type    "application/json; charset=UTF-8"
    }
    content: {"foo":"bar","baz":42}
}',
            'HTTP::Request'
        );
    };
}

sub test_http_response {
    SKIP: {
        my $error = !eval { require HTTP::Response; 1 };
        skip 'HTTP::Response not available', 1 if $error;
        my $r = HTTP::Response->new(
            '200',
            'OK',
            [
                'Content-Type'  => 'application/json; charset=UTF-8',
                'Cache-Control' => 'no-cache, must-revalidate',
            ],
            '{"foo":"bar","baz":42}'
        );
        skip 'HTTP::Headers is too old', 1 unless $r->headers->can('flatten');
        $r->previous(
            HTTP::Response->new(
                '302', 'Moved Temporarily',[
                    'Location' => 'https://example.com/original'
                ]
            )
        );
        my $ddp = Data::Printer::Object->new(
            colored   => 0,
            filters   => ['Web'],
        );
        is(
            $ddp->parse($r),
            "\x{e2}\x{a4}\x{bf}" . ' 302 Moved Temporarily (https://example.com/original)
200 OK {
    headers: {
        Cache-Control   "no-cache, must-revalidate",
        Content-Type    "application/json; charset=UTF-8"
    }
    content: {"foo":"bar","baz":42}
}',
            'HTTP::Response'
        );
    };
}


sub test_cookies {
    test_mojo_cookie();
    test_dancer_cookie();
    test_dancer2_cookie();
}

sub test_dancer_cookie {
    SKIP: {
        my $error = !eval { require Dancer::Cookie; 1 };
        skip 'Dancer::Cookie not available', 1 if $error;
        my $c = Dancer::Cookie->new(
            name      => 'ddp',
            value     => 'test',
            expires   => time,
            domain    => 'localhost',
            path      => '/test',
            secure    => 1,
            http_only => 1,
        );

        my $ddp = Data::Printer::Object->new(
            colored   => 0,
            filters   => ['Web'],
        );

        like(
            $ddp->parse($c),
            qr{ddp=test; expires=(?:[^;]+); domain=localhost; path=/test; secure; http-only \(Dancer::Cookie\)},
            'Dancer::Cookie parsed correctly'
        );
    };
}

sub test_dancer2_cookie {
    SKIP: {
        my $error = !eval { require Dancer2::Core::Cookie; 1 };
        skip 'Dancer2::Core::Cookie not available', 1 if $error;
        my $c = Dancer2::Core::Cookie->new(
            name      => 'ddp',
            value     => 'test',
            expires   => time,
            domain    => 'localhost',
            path      => '/test',
            secure    => 1,
            http_only => 1,
        );

        my $ddp = Data::Printer::Object->new(
            colored   => 0,
            filters   => ['Web'],
        );

        like(
            $ddp->parse($c),
            qr{ddp=test; expires=(?:[^;]+); domain=localhost; path=/test; secure; http-only \(Dancer2::Core::Cookie\)},
            'Dancer2::Core::Cookie parsed correctly'
        );
    };
}


sub test_mojo_cookie {
    SKIP: {
        my $error = !eval { require Mojo::Cookie::Response; 1 };
        skip 'Mojo::Cookie::Response not available', 1 if $error;
        my $c = Mojo::Cookie::Response->new;
        $c->name('ddp');
        $c->value('test');
        $c->expires( time );
        $c->httponly(1);
        $c->max_age(60);
        $c->path('/test');
        $c->secure(1);
        $c->host_only(0) if $c->can('host_only');
        $c->domain('localhost');

        my $ddp = Data::Printer::Object->new(
            colored   => 0,
            filters   => ['Web'],
        );

        like(
            $ddp->parse($c),
            qr{ddp=test; expires=\d+; domain=localhost; path=/test; secure; http-only; max-age=60 \(Mojo::Cookie\)},
            'Mojo::Cookie parsed correctly'
        );
    };
}

sub test_json {
    my $json = '{"alpha":true,"bravo":false,"charlie":true,"delta":false}';
    my $expected = '{ alpha:true, bravo:false, charlie:true, delta:false }';
    test_json_pp($json, $expected);
    test_json_xs($json, $expected);
    test_json_json($json, $expected);
    test_json_any($json, $expected);
    test_json_maybexs($json, $expected);
    test_json_dwiw($json, $expected);
    test_json_parser($json, $expected);
    test_json_sl($json, $expected);
    test_json_mojo($json, $expected);
    test_json_pegex($json, $expected);
    test_json_cpanel($json, $expected);
    test_json_tiny($json, $expected);
    test_json_typist();
}

sub test_json_typist {
    SKIP: {
        my $error = !eval { require JSON::Typist; require JSON; 1 };
        skip 'JSON::Typist (or JSON, or both) not available', 1 if $error;

        my $ddp = Data::Printer::Object->new(
            colored       => 0,
            multiline     => 0,
            show_readonly => 0,
            filters       => ['Web'],
        );

        my $json = '{ "trueVal": true, "falseVal": false, "strVal": "123", "numVal": 123 }';
        my $obj = JSON->new;
        my $payload;
        if ($obj->can('convert_blessed') && $obj->can('canonical') && $obj->can('decode')) {
            $payload = $obj->convert_blessed->canonical->decode($json);
        }
        else {
            skip 'not sure how to load JSON object for JSON::Typist', 1;
        }
        my $typist =  JSON::Typist->new->apply_types( $payload );
        is(
            $ddp->parse($typist),
            '{ falseVal:false, numVal:123, strVal:"123", trueVal:true }',
            'JSON::Typist properly parsed'
        );
    };
}

sub test_json_pp {
    my ($json, $expected) = @_;
    SKIP: {
        my $error = !eval { require JSON::PP; 1 };
        skip 'JSON::PP not available', 1 if $error;

        my $ddp = Data::Printer::Object->new(
            colored   => 0,
            multiline => 0,
            filters   => ['Web'],
        );

        my $data = JSON::PP::decode_json($json);
        is( $ddp->parse($data), $expected, 'JSON::PP booleans parsed' );
    };
}

sub test_json_xs {
    my ($json, $expected) = @_;
    SKIP: {
        my $error = !eval { require JSON::XS; 1 };
        skip 'JSON::XS not available', 1 if $error;

        my $ddp = Data::Printer::Object->new(
            colored       => 0,
            multiline     => 0,
            show_readonly => 0,
            filters       => ['Web'],
        );

        my $data = JSON::XS::decode_json($json);
        is( $ddp->parse($data), $expected, 'JSON::XS booleans parsed' );
    };
}

sub test_json_json {
    my ($json, $expected) = @_;
    SKIP: {
        my $error = !eval { require JSON; 1 };
        skip 'JSON not available', 1 if $error;
        diag('loaded JSON ' . $JSON::VERSION);

        my $ddp = Data::Printer::Object->new(
            colored       => 0,
            multiline     => 0,
            show_readonly => 0,
            filters       => ['Web'],
        );

        my $data;
        my $obj = JSON->new;
        if ($obj->can('decode')) {
            $data = $obj->decode($json);
        }
        elsif ($obj->can('jsonToObj')) {
            $data = $obj->jsonToObj($json);
        }
        else {
            skip 'not sure how to load JSON object', 1;
        }
        is( $ddp->parse($data), $expected, 'parsed whatever powered JSON' );
    };
}

sub test_json_any {
    my ($json, $expected) = @_;
    SKIP: {
        my $error = !eval { require JSON::Any; JSON::Any->import(); 1 };
        skip 'JSON::Any not available', 1 if $error;

        my $ddp = Data::Printer::Object->new(
            colored       => 0,
            multiline     => 0,
            show_readonly => 0,
            filters       => ['Web'],
        );

        my $data = JSON::Any->new->decode($json);
        is( $ddp->parse($data), $expected, 'parsed whatever powered JSON::Any' );
    };
}

sub test_json_maybexs {
    my ($json, $expected) = @_;
    SKIP: {
        my $error = !eval { require JSON::MaybeXS; 1 };
        skip 'JSON::MaybeXS not available', 1 if $error;

        my $ddp = Data::Printer::Object->new(
            colored       => 0,
            multiline     => 0,
            show_readonly => 0,
            filters       => ['Web'],
        );

        my $data = JSON::MaybeXS::decode_json($json);
        is( $ddp->parse($data), $expected, 'parsed whatever powered JSON::MaybeXS' );
    };
}

sub test_json_dwiw {
    my ($json, $expected) = @_;

    my $ddp = Data::Printer::Object->new(
        colored       => 0,
        multiline     => 0,
        filters       => ['Web'],
    );

    SKIP: {
        my $error = !eval { require JSON::DWIW; 1 };
        skip 'JSON::DWIW not available', 1 if $error;

        my $data = JSON::DWIW::from_json($json, { convert_bool => 1 });
        is( $ddp->parse($data), $expected, 'JSON::DWIW live booleans' );
    };
    my $emulated = {
        alpha   => bless( do { \( my $v = 1 ) }, 'JSON::DWIW::Boolean' ),
        bravo   => bless( do { \( my $v = 0 ) }, 'JSON::DWIW::Boolean' ),
        charlie => bless( do { \( my $v = 1 ) }, 'JSON::DWIW::Boolean' ),
        delta   => bless( do { \( my $v = 0 ) }, 'JSON::DWIW::Boolean' ),
    };
    is($ddp->parse($emulated), $expected, 'JSON::DWIW, emulated');
}

sub test_json_parser {
    my ($json, $expected) = @_;

    my $ddp = Data::Printer::Object->new(
        colored       => 0,
        multiline     => 0,
        filters       => ['Web'],
    );

    SKIP: {
        my $error = !eval { require JSON::Parser; 1 };
        skip 'JSON::Parser not available', 1 if $error;

        my $data = JSON::Parser->new->jsonToObj($json);
        is( $ddp->parse($data), $expected, 'JSON::Parser live booleans' );
    };
    my $emulated = {
        alpha   => bless({value => 'true' }, 'JSON::NotString' ),
        bravo   => bless({value => 'false'}, 'JSON::NotString' ),
        charlie => bless({value => 'true' }, 'JSON::NotString' ),
        delta   => bless({value => 'false'}, 'JSON::NotString' ),
    };
    is($ddp->parse($emulated), $expected, 'JSON::Parser, emulated');
}

sub test_json_sl {
    my ($json, $expected) = @_;

    my $ddp = Data::Printer::Object->new(
        colored       => 0,
        multiline     => 0,
        filters       => ['Web'],
    );

    SKIP: {
        my $error = !eval { require JSON::SL; 1 };
        skip 'JSON::SL not available', 1 if $error;

        my $data = JSON::SL::decode_json($json);
        is( $ddp->parse($data), $expected, 'JSON::SL live booleans' );
    };
    my $emulated = {
        alpha   => bless(do { \(my $o = 1) }, 'JSON::SL::Boolean' ),
        bravo   => bless(do { \(my $o = 0) }, 'JSON::SL::Boolean' ),
        charlie => bless(do { \(my $o = 1) }, 'JSON::SL::Boolean' ),
        delta   => bless(do { \(my $o = 0) }, 'JSON::SL::Boolean' ),
    };
    is($ddp->parse($emulated), $expected, 'JSON::SL, emulated');
}

sub test_json_mojo {
    my ($json, $expected) = @_;

    my $ddp = Data::Printer::Object->new(
        colored       => 0,
        show_readonly => 0,
        multiline     => 0,
        filters       => ['Web'],
    );

    SKIP: {
        my $error = !eval { require Mojo::JSON; 1 };
        skip 'Mojo::JSON not available', 1 if $error;

        my $data = Mojo::JSON->can('new')
                 ? Mojo::JSON->new->decode($json)
                 : Mojo::JSON::decode_json($json)
                 ;
        is( $ddp->parse($data), $expected, 'Mojo::JSON live booleans' );
    };
}

sub test_json_pegex {
    my ($json, $expected) = @_;

    my $ddp = Data::Printer::Object->new(
        colored       => 0,
        multiline     => 0,
        filters       => ['Web'],
    );

    SKIP: {
        my $error = !eval { require Pegex::JSON; 1 };
        skip 'Pegex::JSON not available', 1 if $error;

        my $data = Pegex::JSON->can('parse')
                 ? Pegex::JSON->parse($json)
                 : Pegex::JSON->new->load($json)
                 ;
        is( $ddp->parse($data), $expected, 'Pegex::JSON live booleans' );
    };
}

sub test_json_cpanel {
    my ($json, $expected) = @_;

    my $ddp = Data::Printer::Object->new(
        colored       => 0,
        multiline     => 0,
        show_readonly => 0,
        filters       => ['Web'],
    );

    SKIP: {
        my $error = !eval { require Cpanel::JSON::XS; 1 };
        skip 'Cpanel::JSON::XS not available', 1 if $error;

        my $data = Cpanel::JSON::XS::decode_json($json);
        is( $ddp->parse($data), $expected, 'Cpanel::JSON::XS live booleans' );
    };
}

sub test_json_tiny {
    my ($json, $expected) = @_;

    my $ddp = Data::Printer::Object->new(
        colored       => 0,
        multiline     => 0,
        filters       => ['Web'],
    );

    SKIP: {
        my $error = !eval { require JSON::Tiny; 1 };
        skip 'JSON::Tiny not available', 1 if $error;

        my $data = JSON::Tiny::decode_json($json);
        is( $ddp->parse($data), $expected, 'JSON::Tiny live booleans' );
    };
}
