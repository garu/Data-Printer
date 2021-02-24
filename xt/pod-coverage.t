use strict;
use warnings;
use Test::More;

my $success = eval "use Test::Pod::Coverage 1.04; 1";
if ($success) {
    plan tests => 18;
    foreach my $m (grep $_ !~ /(?:SCALAR|LVALUE|ARRAY|CODE|VSTRING|REF|GLOB|HASH|FORMAT|GenericClass|Regexp|Common)\z/, all_modules()) {
        my $params = {};
        if ($m =~ /\AData::Printer::Theme::/) {
            $params = { also_private => [qr/\Acolors\z/] };
        }
        elsif ($m =~ /\AData::Printer::Profile::/) {
            $params = { also_private => [qr/\Aprofile\z/] };
        }
        elsif ($m eq 'Data::Printer::Theme') {
            $params = { also_private => [qw(new name customized color_for sgr_color_for color_reset)] };
        }
        pod_coverage_ok($m, $params, "$m is covered");
    }
}
else {
    plan skip_all => 'Test::Pod::Coverage not found';
}
