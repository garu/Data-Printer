use strict;
use warnings;
use Test::More;

my $success = eval "use Test::Pod 1.41; 1";
if ($success) {
    all_pod_files_ok();
}
else {
    plan skip_all => 'Test::Pod not found';
}
