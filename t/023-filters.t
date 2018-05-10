use strict;
use warnings;
use Test::More tests => 11;

package
    My::Module;
sub new { bless {}, shift }
sub test { return 'this is a test' }

package
    Other::Module;
sub new { bless {}, shift }

package
    Inherited::Module;
our @ISA = qw(My::Module);
sub whatever {}

package main;

BEGIN {
    use Data::Printer::Config;
    no warnings 'redefine';
    *Data::Printer::Config::load_rc_file = sub { {} };
};

use DDP
    colored => 0,
    return_value => 'dump',
    filters => [{
        'My::Module' => sub { shift->test },
        -class       => sub { '1, 2, 3' },
        SCALAR       => sub { 'scalar here!' },
    }];

my $obj = My::Module->new;
my $string = 'oi?';

is p($obj), 'this is a test', 'basic object filter';
is p($string), 'scalar here!', 'scalar filter';

is(
    p($obj, filters => [{ 'My::Module' => sub { return 'mo' } }]),
    'mo',
    'overriding My::Module filter'
);
# NOTE: a custom 'filters' key *REPLACES ALL* global/local filters,
#       not add to the existing ones. See for yourself:
is(
    p($string, filters => [{ 'My::Module' => sub { return 'mo' } }]),
    '"oi?"',
    'custom filter list destroys previous one'
);

is p($obj), 'this is a test', 'basic object filter restored';
is p($string), 'scalar here!', 'scalar filter restored';

is(
    p($string, filters => [{ 'SCALAR' => sub { return } }]),
    '"oi?"',
    'move to next filter if current filter returns'
);

is(
    p($string, filters => [
        { 'SCALAR' => sub { return } },
        { 'SCALAR' => sub { return 222 } }
    ]),
    '222',
    'move to next (custom) filter if current filter returns'
);

my $obj2 = Other::Module->new;
is p($obj2), '1, 2, 3', '-class filter works';

my $inherited = Inherited::Module->new;
is p($inherited), 'this is a test', 'inherited filter';
is p($inherited, class => { parent_filters => 0 }), '1, 2, 3', 'disabling parent filters';
