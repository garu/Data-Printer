use strict;
use warnings;
use Test::More tests => 1;
use Data::Printer::Common;

sub warnings(&) {
    my $code = shift;
    my $got;
    local $SIG{__WARN__} = sub {
        $got = shift;
    };
    $code->();
    return $got
}

my $got = warnings { Data::Printer::Common::_warn("HA!") };

is( $got, "[Data::Printer] HA! at t/000.2-warn.t line 16.\n", 'warn with proper caller/line' );
