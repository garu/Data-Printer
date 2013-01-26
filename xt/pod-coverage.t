use strict;
use warnings;
use Test::More;
use Test::Pod::Coverage 1.04;

all_pod_coverage_ok({
  also_private => [ qr/^(?:SCALAR|ARRAY|CODE|GLOB|HASH|REF|VSTRING|Regexp|FORMAT|LVALUE)$/, qr/^np$/ ],
});
