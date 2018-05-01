use strict;
use warnings;
use Test::More tests => 1;
use Carp;
use Data::Printer::Common;

my $message = 'hello!';
my $got;
my $expected = '[Data::Printer] hello!';

{ no warnings 'redefine';
    *Carp::carp = sub { $got = shift };
}

Data::Printer::Common::_warn($message);
is $got, $expected, 'common warning code';
