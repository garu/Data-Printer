use strict;
use warnings;
use Test::More;

my $success = eval "use Test::Pod::Coverage 1.04; 1";
if ($success) {
    plan tests => 22;
    foreach my $m (grep $_ !~ /(?:SCALAR|LVALUE|ARRAY|CODE|VSTRING|REF|GLOB|HASH|FORMAT|GenericClass|Regexp|Common)\z/, all_modules()) {
        my $params;
        if ($m =~ /\AData::Printer::Theme::/) {
            $params = { also_private => [qr/\Acolors\z/] };
        }
        elsif ($m =~ /\AData::Printer::Profile::/) {
            $params = { also_private => [qr/\Aprofile\z/] };
        }
        pod_coverage_ok($m, $params);
    }
}
else {
    plan skip_all => 'Test::Pod::Coverage not found';
}
