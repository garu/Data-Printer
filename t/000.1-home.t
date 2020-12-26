use strict;
use warnings;
use Test::More tests => 4;

use Data::Printer::Config;
{
    local %ENV = %ENV;
    $ENV{HOME} = '/ddp-home';
    is Data::Printer::Config::_my_home(), '/ddp-home', 'found HOME in env';
    delete $ENV{HOME};

    diag('$^O is ' . $^O);
    ok Data::Printer::Config::_my_home(), 'found home without env';

    ok Data::Printer::Config::_project_home(), 'found project home';
    {
        local $0;
        eval { $0 = '-e'; };
        SKIP: {
            skip 'unable to change $0', 1 unless $0 eq '-e';
            ok Data::Printer::Config::_project_home(), 'found project home';
        };
    }
}
