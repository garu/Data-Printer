use strict;
use warnings;
use Test::More;

my $success = eval "use Test::Pod::Coverage 1.04; 1";
if ($success) {
    foreach my $m (grep $_ !~ /(?:SCALAR|LVALUE|ARRAY|CODE|VSTRING|REF|GLOB|HASH|FORMAT|GenericClass)$/, all_modules()) {
        pod_coverage_ok($m);
    }
}
else {
    plan skip_all => 'Test::Pod::Coverage not found';
}
