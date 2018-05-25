#### this script tests basic object instantiation (arguments validation)
use strict;
use warnings;
use Test::More tests => 127;

use Data::Printer::Object;
pass 'Data::Printer::Object loaded successfully';

test_defaults();
test_customization();
test_aliases();
test_colorization();
exit;

sub test_defaults {
    ok my $ddp = Data::Printer::Object->new, 'Data::Printer::Object created';
    is $ddp->name, 'var', 'default variable name is "var"';
    is $ddp->show_tainted,  1, 'show_tainted default ON';
    is $ddp->show_unicode,  0, 'show_unicode default OFF';
    is $ddp->show_readonly, 1, 'show_readonly default OFF';
    is $ddp->show_lvalue,   1, 'show_lvalue default ON';
    is $ddp->show_refcount, 0, 'show_refcount default OFF';
    is $ddp->show_memsize, 0, 'show_memsize default OFF';
    is $ddp->memsize_unit, 'auto', 'memsize_unit default "auto"';
    is $ddp->print_escapes, 0, 'print_escapes default OFF';
    is $ddp->scalar_quotes, '"', 'scalar_quotes defaults to ["]';
    is $ddp->escape_chars, 'none', 'escape_chars defaults to "none"';
    is $ddp->caller_info, 0, 'caller_info default OFF';
    is $ddp->caller_message, 'Printing in line __LINE__ of __FILENAME__:', 'default message';
    is $ddp->string_max, 1024, 'string_max defaults to 1024';
    is $ddp->string_preserve, 'begin', 'string_preserve defaults to "begin"';
    is(
        $ddp->string_overflow,
        '(...skipping __SKIPPED__ chars...)',
        'string_overflow'
    );
    is $ddp->array_max, 50, 'array_max default to 50';
    is $ddp->array_preserve, 'begin', 'array_preserve defaults to "begin"';
    is $ddp->array_overflow, '(...skipping __SKIPPED__ items...)', 'array_overflow';
    is $ddp->hash_max, 50, 'hash_max default 50';
    is $ddp->hash_preserve, 'begin', 'hash_preserve defaults to "begin"';
    is $ddp->hash_overflow, '(...skipping __SKIPPED__ keys...)', 'hash_overflow';
    is_deeply $ddp->ignore_keys, [], 'ignore_keys';
    is $ddp->unicode_charnames, 0, 'unicode_charnames defaults OFF';
    is $ddp->colored, 'auto', 'colored defaults to "auto"';
    my $theme = $ddp->theme;
    is $theme->name, 'Material', 'default theme';
    is $ddp->show_weak, 1, 'show_weak default ON';
    is $ddp->max_depth, 0, 'max_depth defaults to infinite depth';
    is $ddp->index, 1, 'index default ON';
    is $ddp->separator, ',', 'separator is ","';
    is $ddp->end_separator, 0, 'end_separator default OFF';
    is $ddp->class_method, '_data_printer', 'class_method';
    my $class_opts = $ddp->class;
    isa_ok $class_opts, 'Data::Printer::Object::ClassOptions';
    is $ddp->hash_separator, '   ', 'hash_separator is 3 spaces';
    is $ddp->align_hash, 1, 'align_hash default ON';
    is $ddp->sort_keys, 1, 'sort_keys default ON';
    is $ddp->quote_keys, 'auto', 'quote_keys defaults to "auto"';
    is $ddp->deparse, 0, 'deparse default OFF';
    is $ddp->show_dualvar, 'lax', 'dualvar default LAX';
}

sub test_customization {
    my %custom = (
        name => 'something',
        show_tainted => 0,
        show_unicode => 1,
        show_readonly => 0,
        show_lvalue   => 0,
        show_refcount => 1,
        show_dualvar => 'strict',
        show_memsize => 1,
        memsize_unit => 'k',
        print_escapes => 1,
        scalar_quotes => q('),
        escape_chars => 'all',
        caller_info  => 1,
        caller_message => 'meep!',
        string_max => 3,
        string_preserve => 'end',
        string_overflow => 'oh, noes! __SKIPPED__',
        array_max => 5,
        array_preserve => 'middle',
        array_overflow => 'hey!',
        hash_max => 7,
        hash_preserve => 'extremes',
        hash_overflow => 'YAY!',
        ignore_keys => [3,2,1],
        unicode_charnames => 1,
        colored => 0,
        theme => 'Monokai',
        show_weak => 0,
        max_depth => 4,
        index => 0,
        separator => '::',
        end_separator => 1,
        class_method => '_foo',
        class => {
        },
        hash_separator => 'oo',
        align_hash => 0,
        sort_keys => 0,
        quote_keys => 0,
        deparse => 1,
    );
    run_customization_tests(1, %custom);  # as hash
    run_customization_tests(2, \%custom); # as hashref
}

sub run_customization_tests {
    my $pass = shift;
    ok my $ddp = Data::Printer::Object->new(@_);
    is $ddp->name, 'something', "custom variable name (pass: $pass)";
    is $ddp->show_tainted,  0, "custom show_tainted (pass: $pass)";
    is $ddp->show_unicode,  1, "custom show_unicode (pass: $pass)";
    is $ddp->show_readonly, 0, "custom show_readonly (pass: $pass)";
    is $ddp->show_lvalue,   0, "custom show_lvalue (pass: $pass)";
    is $ddp->show_refcount, 1, "custom show_refcount (pass: $pass)";
    is $ddp->show_dualvar, 'strict', "custom show_dualvar (pass: $pass)";
    is $ddp->show_memsize, 1, "custom show_memsize (pass: $pass)";
    is $ddp->memsize_unit, 'k', "custom memsize_unit (pass: $pass)";
    is $ddp->print_escapes, 1, "custom print_escapes (pass: $pass)";
    is $ddp->scalar_quotes, q('), "custom scalar_quotes (pass: $pass)";
    is $ddp->escape_chars, 'all', "custom escape_chars (pass: $pass)";
    is $ddp->caller_info, 1, "custom caller_info (pass: $pass)";
    is $ddp->caller_message, 'meep!', "custom message (pass: $pass)";
    is $ddp->string_max, 3, "custom string_max (pass: $pass)";
    is $ddp->string_preserve, 'end', "custom string_preserve (pass: $pass)";
    is( $ddp->string_overflow, 'oh, noes! __SKIPPED__', "custom string_overflow");
    is $ddp->array_max, 5, "custom array_max (pass: $pass)";
    is $ddp->array_preserve, 'middle', "custom array_preserve (pass: $pass)";
    is $ddp->array_overflow, 'hey!', "custom array_overflow (pass: $pass)";
    is $ddp->hash_max, 7, "custom hash_max (pass: $pass)";
    is $ddp->hash_preserve, 'extremes', "custom hash_preserve (pass: $pass)";
    is $ddp->hash_overflow, 'YAY!', "custom hash_overflow (pass: $pass)";
    is_deeply $ddp->ignore_keys, [3,2,1], "custom ignore_keys (pass: $pass)";
    is $ddp->unicode_charnames, 1, "custom unicode_charnames (pass: $pass)";
    is $ddp->colored, 0, "custom colored (pass: $pass)";
    my $theme = $ddp->theme;
    is $theme->name, 'Monokai', "custom theme (pass: $pass)";
    is $ddp->show_weak, 0, "custom show_weak (pass: $pass)";
    is $ddp->max_depth, 4, "custom max_depth (pass: $pass)";
    is $ddp->index, 0, "custom index (pass: $pass)";
    is $ddp->separator, '::', "custom separator (pass: $pass)";
    is $ddp->end_separator, 1, "custom end_separator (pass: $pass)";
    is $ddp->class_method, '_foo', "custom class_method (pass: $pass)";
    my $class_opts = $ddp->class;
    isa_ok $class_opts, 'Data::Printer::Object::ClassOptions';
    is $ddp->hash_separator, 'oo', "custom hash_separator (pass: $pass)";
    is $ddp->align_hash, 0, "custom align_hash (pass: $pass)";
    is $ddp->sort_keys, 0, "custom sort_keys (pass: $pass)";
    is $ddp->quote_keys, 0, "custom quote_keys (pass: $pass)";
    is $ddp->deparse, 1, "custom deparse (pass: $pass)";
}

sub test_aliases {
    my $ddp = Data::Printer::Object->new( as => 'this is a test' );
    is $ddp->caller_info, 1, '"as" will set caller_info';
    is $ddp->caller_message, 'this is a test', '"as" will set caller_message';
}

sub test_colorization {
    my $ddp = Data::Printer::Object->new( colored => 1 );
    is $ddp->maybe_colorize('x'), 'x', 'no color unless tag is provided';
    is $ddp->maybe_colorize('x', 'invalid tag'), 'x', 'no color unless valid tag';
    my $colored = $ddp->maybe_colorize('x', 'invalid tag', "\e[0;38;2m");
    if ($colored eq "\e[0;38;2mx\e[0m") {
        pass 'fallback to default color';
    }
    else {
        $colored =~ s{\e}{\\e}gsm;
        my $sgr = $ddp->theme->sgr_color_for('invalid tag');
        my $parsed = $ddp->theme->_parse_color("\e[0;38;2m");
        $parsed =~ s{\e}{\\e}gsm if defined $parsed;
        fail 'fallback to default color:'
           . ' got "' . $colored . '" expected "\e[0;38;2mx\e[0m"'
           . ' theme name: ' . $ddp->theme->name
           . ' color level: ' . $ddp->color_level
           . ' sgr_color_for "invalid tag": '
           . (defined $sgr ? $sgr : 'undef')
           . ' parsed default: ' . (defined $parsed ? $parsed : 'undef')
           ;
        ;
    }

    $ddp = Data::Printer::Object->new(
        colored => 1,
        colors    => { 'invalid tag' => '' }
    );
    $colored = $ddp->maybe_colorize('x', 'invalid tag', "\e[0;38;2m");
    if ($colored eq 'x') {
        pass 'color has fallback but user declined';
    }
    else {
        $colored =~ s{\e}{\\e}gsm;
        my $sgr = $ddp->theme->sgr_color_for('invalid tag');
        my $parsed = $ddp->theme->_parse_color("\e[0;38;2m");
        $parsed =~ s{\e}{\\e}gsm if defined $parsed;
        fail 'fallback to default color:'
           . ' got "' . $colored . '" expected "\e[0;38;2mx\e[0m"'
           . ' theme name: ' . $ddp->theme->name
           . ' color level: ' . $ddp->color_level
           . ' sgr_color_for "invalid tag": '
           . (defined $sgr ? $sgr : 'undef')
           . ' parsed default: ' . (defined $parsed ? $parsed : 'undef')
           ;
        ;
    }
}
