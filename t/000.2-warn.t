use strict;
use warnings;
use Test::More tests => 1;
use Data::Printer::Common;
use File::Spec;
my $dir_sep_char = File::Spec->catfile('', '');

sub warnings(&) {
    my $code = shift;
    my $got;
    local $SIG{__WARN__} = sub {
        $got = shift;
    };
    $code->();
    return $got
}

my $got = warnings { Data::Printer::Common::_warn(undef, "HA!") };

is( $got, "[Data::Printer] HA! at t${dir_sep_char}000.2-warn.t line 18.\n", 'warn with proper caller/line' );
