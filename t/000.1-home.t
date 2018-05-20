use strict;
use warnings;
use Test::More tests => 2;

use Data::Printer::Common;
{
    local %ENV = %ENV;
    $ENV{HOME} = '/ddp-home';
    is Data::Printer::Common::_my_home(), '/ddp-home', 'found HOME in env';
    delete $ENV{HOME};

    diag('$^O is ' . $^O);
    ok Data::Printer::Common::_my_home(), 'found home without env';
}
