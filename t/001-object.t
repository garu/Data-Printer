#### this script tests basic object insantiation (arguments validation)
use strict;
use warnings;
use Test::More; # tests => 7;

use Data::Printer::Object;
pass 'Data::Printer::Object loaded successfully';

can_ok 'Data::Printer::Object', qw(new merge_properties);

test_defaults();
test_customization();
test_aliases();
done_testing;
exit;

sub test_defaults {
    ok my $ddp = Data::Printer::Object->new, 'Data::Printer::Object created';
    can_ok($ddp, qw(
        name show_tainted show_unicode show_readonly show_lvalue
        print_escapes scalar_quotes escape_chars caller_info caller_message
        string_max string_preserve string_overflow
    ));
    is $ddp->name, 'var', 'default variable name is "var"';
    is $ddp->show_tainted,  1, 'show_tainted default ON';
    is $ddp->show_unicode,  0, 'show_unicode default OFF';
    is $ddp->show_readonly, 0, 'show_readonly default OFF';
    is $ddp->show_lvalue,   1, 'show_lvalue default ON';
    is $ddp->print_escapes, 0, 'print_escapes default OFF';

    is $ddp->scalar_quotes, '"', 'scalar_quotes defaults to ["]';
    is $ddp->escape_chars, 'none', 'escape_chars defaults to "none"';
    is $ddp->caller_info, 0, 'caller_info default OFF';
    is $ddp->caller_message, 'Printing in line __LINE__ of __FILENAME__:', 'default message';
    is $ddp->string_max, 0, 'string_max defaults to 0 (unlimited)';
    is $ddp->string_preserve, 'begin', 'string_preserve defaults to "begin"';
    is(
        $ddp->string_overflow,
        '(...skipping __SKIPPED__ chars...)',
        'string_overflow'
    );
    is $ddp->unicode_charnames, 0, 'unicode_charnames defaults OFF';
}

sub test_customization {
    TODO: {
        local $TODO = 'test setters';
        fail 'new( %params ) is not tested yet';
    };
}

sub test_aliases {
    my $ddp = Data::Printer::Object->new( as => 'this is a test' );
    is $ddp->caller_info, 1, '"as" will set caller_info';
    is $ddp->caller_message, 'this is a test', '"as" will set caller_message';
}
