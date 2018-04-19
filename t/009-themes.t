use strict;
use warnings;
use Test::More;
use Data::Printer::Theme;

ok my $theme = Data::Printer::Theme->new('Material'), 'able to load themes';
isa_ok $theme, 'Data::Printer::Theme';
can_ok $theme, qw(name color_reset color_for sgr_color_for);

is $theme->name, 'Material', 'got the right theme';
is $theme->color_for('array'), '#B2CCD6', 'fetched original color';
my $sgr = $theme->sgr_color_for('array');
$sgr =~ s{\e}{\\e};
is $sgr, '\e[0;38;2;178;204;214m', 'fetched SGR variant for color';

done_testing;
