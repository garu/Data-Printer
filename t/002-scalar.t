#!perl -T
# ^^ taint mode must be on for taint checking.
use strict;
use warnings;
use Test::More tests => 67;
use Data::Printer::Object;
use Scalar::Util;

test_basic_values();
test_tainted_values();
test_unicode_string();
test_escape_chars();
test_print_escapes();
test_max_string();
test_weak_ref();
test_readonly();
test_dualvar_lax();
test_dualvar_strict();
test_dualvar_off();

sub test_weak_ref {
    my $num = 3.14;
    my $ref = \$num;
    Scalar::Util::weaken($ref);
    my $ddp = Data::Printer::Object->new( colored => 0 );
    is $ddp->parse(\$ref), '3.14 (weak)', 'parse() after weaken';
}

sub test_basic_values {
    my $object = Data::Printer::Object->new( colored => 0 );

    # hardcoded values:
    is $object->parse(\undef)  , 'undef (read-only)'  , 'hardcoded undef value';
    is $object->parse(\123)    , '123 (read-only)'    , 'hardcoded integer value';
    is $object->parse(\0)      , '0 (read-only)'      , 'hardcoded integer value';
    is $object->parse(\123.456), '123.456 (read-only)', 'hardcoded floating point value';
    is $object->parse(\'meep!'), '"meep!" (read-only)', 'hardcoded string value';

    # variable values:
    my $var;
    is $object->parse(\$var), 'undef', 'undefined variable';

    $var = undef;
    $object = Data::Printer::Object->new( colored => 0 );
    is $object->parse(\$var), 'undef', 'explicitly undefined variable';

    $object = Data::Printer::Object->new( colored => 0 );
    $var = 0;
    is $object->parse(\$var), '0', 'integer 0 in variable';

    $object = Data::Printer::Object->new( colored => 0 );
    $var = -1;
    is $object->parse(\$var), '-1', 'integer -1 in variable';

    $object = Data::Printer::Object->new( colored => 0 );
    $var = 123;
    is $object->parse(\$var), '123', 'integer 123 in variable';
}

sub test_tainted_values {
    SKIP: {
        # only use 1 char substring to avoid leaking
        # user information on test results:
        my $tainted = substr $ENV{'PATH'}, 0, 1;
        skip 'Skipping taint test: sample not found.', 2
            => unless Scalar::Util::tainted($tainted);

        my $object = Data::Printer::Object->new( colored => 0 );
        is $object->parse(\$tainted), qq("$tainted" (TAINTED)), 'show tainted scalar';
        $object = Data::Printer::Object->new( colored => 0, show_tainted => 0 );
        is $object->parse(\$tainted), qq("$tainted"), 'no tainted flag without show_tainted';
    }
}

sub test_unicode_string {
    my $object = Data::Printer::Object->new( colored => 0 );
    my $unicode_str = "\x{2603}";
    my $ascii_str   = "\x{ff}";
    is $object->parse(\$unicode_str), qq("$unicode_str"), 'no suffix on unicode by default';
    is $object->parse(\$ascii_str), qq("$ascii_str"), 'ascii scalar never has suffix (1)';

    $object = Data::Printer::Object->new( colored => 0, show_unicode => 1 );
    is $object->parse(\$unicode_str), qq("$unicode_str" (U)), 'unicode scalar gets suffix';
    is $object->parse(\$ascii_str), qq("$ascii_str"), 'ascii scalar never has suffix (2)';
}

sub test_escape_chars {
    my $string = "L\x{e9}on likes to build a m\x{f8}\x{f8}se \x{2603} with \x{2744}\x{2746}";
    my $object = Data::Printer::Object->new( colored => 0 );
    is $object->parse(\$string), qq("$string"), 'escape_chars => "none"';

    $object = Data::Printer::Object->new( colored => 0, escape_chars => 'nonascii' );
    is(
        $object->parse(\$string),
        qq("L\\x{e9}on likes to build a m\\x{f8}\\x{f8}se \\x{2603} with \\x{2744}\\x{2746}"),
        'escaping nonascii'
    );

    $object = Data::Printer::Object->new( colored => 0, escape_chars => 'nonascii', unicode_charnames => 1 );
    is(
        $object->parse(\$string),
        qq("L\\N{LATIN SMALL LETTER E WITH ACUTE}on likes to build a m\\N{LATIN SMALL LETTER O WITH STROKE}\\N{LATIN SMALL LETTER O WITH STROKE}se \\N{SNOWMAN} with \\N{SNOWFLAKE}\\N{HEAVY CHEVRON SNOWFLAKE}"),
        'escaping nonascii (with unicode_charnames)'
    );
    $object = Data::Printer::Object->new( colored => 0, escape_chars => 'nonlatin1' );
    is(
        $object->parse(\$string),
        qq("L\x{e9}on likes to build a m\x{f8}\x{f8}se \\x{2603} with \\x{2744}\\x{2746}"),
        'escaping nonlatin1'
    );
    $object = Data::Printer::Object->new( colored => 0, escape_chars => 'nonlatin1', unicode_charnames => 1 );
    is(
        $object->parse(\$string),
        qq("L\x{e9}on likes to build a m\x{f8}\x{f8}se \\N{SNOWMAN} with \\N{SNOWFLAKE}\\N{HEAVY CHEVRON SNOWFLAKE}"),
        'escaping nonlatin1 (with unicode_charnames)'
    );

    $object = Data::Printer::Object->new( colored => 0, escape_chars => 'all' );
    is(
        $object->parse(\$string),
        '"' . join('', map {(sprintf '\x{%02x}', ord($_)) } split //, $string) . '"',
        'escaping all'
    );
    $object = Data::Printer::Object->new( colored => 0, escape_chars => 'all', unicode_charnames => 1 );
    $string = "L\x{e9}on";
    is(
        $object->parse(\$string),
        '"\N{LATIN CAPITAL LETTER L}\N{LATIN SMALL LETTER E WITH ACUTE}\N{LATIN SMALL LETTER O}\N{LATIN SMALL LETTER N}"',
        'escaping all (with unicode_charnames)'
    );
}

sub test_print_escapes {
    my $object = Data::Printer::Object->new( colored => 0 );
    my $string = "\n\r\t\0\f\b\a\e";
    is $object->parse(\$string), qq("\n\r\t\\0\f\b\a\e"), 'only \0 is always escaped';
    $object = Data::Printer::Object->new( colored => 0, print_escapes => 1 );
    is $object->parse(\$string), q("\n\r\t\0\f\b\a\e"), 'print_escapes works';
}

sub test_max_string {
    my $ddp = Data::Printer::Object->new(
        colored         => 0,
        string_max      => 10,
        string_preserve => 'begin',
        string_overflow => '[...__SKIPPED__...]',
    );
    my $string = "I'll tell you, I think\nparsing strings is N-E-A-T";
    is $ddp->parse(\$string), q("I'll tell [...39...]"), 'string_max begin';

    $ddp = Data::Printer::Object->new(
        colored         => 0,
        string_max      => 10,
        string_preserve => 'end',
        string_overflow => '[...__SKIPPED__...]',
    );
    is $ddp->parse(\$string), q("[...39...]is N-E-A-T"), 'string_max end';
    $ddp = Data::Printer::Object->new(
        colored         => 0,
        string_max      => 10,
        string_preserve => 'extremes',
        string_overflow => '[...__SKIPPED__...]',
    );
    is $ddp->parse(\$string), q("I'll [...39...]E-A-T"), 'string_max extremes';
    $ddp = Data::Printer::Object->new(
        colored         => 0,
        string_max      => 10,
        string_preserve => 'middle',
        string_overflow => '[...__SKIPPED__...]',
    );

    is $ddp->parse(\$string), qq("[...19...]ink\nparsin[...20...]"), 'string_max middle';

    $ddp = Data::Printer::Object->new(
        colored         => 0,
        string_max      => 10,
        string_preserve => 'none',
        string_overflow => '[...__SKIPPED__...]',
    );
    is $ddp->parse(\$string), q("[...49...]"), 'string_max none';
}

sub test_readonly {
    my $ddp = Data::Printer::Object->new( colored => 0, show_readonly => 1 );
    my $foo = 42;
    &Internals::SvREADONLY( \$foo, 1 );
    is $ddp->parse(\$foo), '42 (read-only)', 'readonly variables';
}

sub test_dualvar_lax {
    # if you are adding tests here, please repeat them in test_dualvar_strict
    for my $t (
        [ 0,     'number' ],
        [ 0.0,   'number' ],
        [ '0.0', 'number' ],
        [ '3',   'number' ],
        [ '1.0', 'number'],
        [ '1.10', 'number'],
        [ 1.100, 'number'],
        [ 1.000, 'number'],
        [ '123   ', 'number', 123],
        [ '123.040   ', 'number', '123.040'],
        [ '   123', 'number', 123],
        [ '   123.040', 'number', '123.040'],
        [
            Scalar::Util::dualvar( 42, "The Answer" ),
            'dualvar',
            '"The Answer" (dualvar: 42)'
        ],
        [ "Nil",  'string',  '"Nil"' ],
        [ 0123,   'number' ],
        [ "0199", 'dualvar', '"0199" (dualvar: 199)' ],
      )
    {
        my ( $var, $type, $expected ) = @$t;
        my $ddp = Data::Printer::Object->new( colored => 0 );
        is(
            $ddp->parse( \$var ),
            defined $expected ? $expected : "$var",
            "$var in lax mode is a $type"
        );
    }

    # one very specific Perl dualvar
    $! = 2;
    like(
        Data::Printer::Object->new( colored => 0 )->parse( \$! ),
        qr/".+" \(dualvar: 2\)/,
        '$! is a dualvar'
    );
}

sub test_dualvar_strict {
    # if you are adding tests here, please repeat them in test_dualvar_lax
    for my $t (
        [ 0,     'number' ],
        [ 0.0,   'number' ],
        [ '0.0', 'number' ],
        [ '3',   'number' ],
        [ '1.0', 'dualvar', '"1.0" (dualvar: 1)'],
        [ '1.10', 'dualvar', '"1.10" (dualvar: 1.1)'],
        [ 1.10, 'number'],
        [ 1.000, 'number'],
        [ '123   ', 'dualvar', '"123   " (dualvar: 123)' ],
        [ '123.040   ', 'dualvar', '"123.040   " (dualvar: 123.04)' ],
        [ '   123', 'dualvar', '"   123" (dualvar: 123)' ],
        [ '   123.040', 'dualvar', '"   123.040" (dualvar: 123.04)' ],
        [
            Scalar::Util::dualvar( 42, "The Answer" ),
            'dualvar',
            '"The Answer" (dualvar: 42)'
        ],
        [ "Nil",  'string',  '"Nil"' ],
        [ 0123,   'number' ],
        [ "0199", 'dualvar', '"0199" (dualvar: 199)' ],
      )
    {
        my ( $var, $type, $expected ) = @$t;
        my $ddp = Data::Printer::Object->new( colored => 0, show_dualvar => 'strict' );
        is(
            $ddp->parse( \$var ),
            defined $expected ? $expected : "$var",
            "$var in strict mode is a $type"
        );
    }

    # one very specific Perl dualvar
    $! = 2;
    like(
        Data::Printer::Object->new( colored => 0, show_dualvar => 'strict' )->parse( \$! ),
        qr/".+" \(dualvar: 2\)/,
        '$! is a dualvar'
    );
}

sub test_dualvar_off {
    # one very specific Perl dualvar
    $! = 2;
    is(
        index(
            Data::Printer::Object->new( colored => 0, show_dualvar => 'off' )->parse( \$! ),
            'dualvar'
        ),
        -1,
        'dualvar $! shown only as string when show_dualvar is off'
    );
}
