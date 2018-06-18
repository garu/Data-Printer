use strict;
use warnings;
use Test::More tests => 15;
use Data::Printer::Object;

test_json();
exit;

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

        my $ddp = Data::Printer::Object->new(
            colored       => 0,
            multiline     => 0,
            show_readonly => 0,
            filters       => ['Web'],
        );

        my $data = JSON::decode_json($json);
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
