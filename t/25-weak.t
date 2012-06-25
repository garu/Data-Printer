use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use_ok ('Term::ANSIColor');
    use_ok ('Scalar::Util', qw(weaken));
    use_ok ('Data::Printer', colored => 1);
};

my $number = 3.14;
my $n_ref = \$number;
weaken($n_ref);
is( p($n_ref), color('reset') . '\\ '
                  . colored($number, 'bright_blue')
                  . ' ' . colored('(weak)', 'cyan')
, 'weakened ref');


my $circular = [];
$circular->[0] = $circular;
weaken($circular->[0]);
is( p($circular), color('reset') . "\\ [$/    "
                  . colored('[0] ', 'bright_white')
                  . colored('var', 'white on_red')
                  . ' ' . colored('(weak)', 'cyan')
                  . "$/]"
, 'weakened circular array ref');



my %hash = ();
$hash{key} = \%hash;
weaken($hash{key});
is( p(%hash), color('reset') . "{$/    "
              . colored('key', 'magenta')
              . '   '
              . colored('var', 'white on_red')
              . ' ' . colored('(weak)', 'cyan')
              . "$/}"
, 'weakened circular hash ref');

package Foo;
sub new {my $s = bless [], shift; $s->[0] = $s; Scalar::Util::weaken($s->[0]); return $s }

package main;

my $obj = Foo->new;

is( p($obj), color('reset') . colored('Foo', 'bright_green') . '  {
    public methods (1) : ' . colored('new', 'bright_green') . '
    private methods (0)
    internals: [
        '
    . colored('[0] ', 'bright_white')
    . colored('var', 'white on_red')
    . ' ' . colored('(weak)', 'cyan').'
    ]
}', 'circular weak ref to object' );



done_testing;
