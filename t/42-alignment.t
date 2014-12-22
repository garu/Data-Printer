use strict;
use warnings;

use Test::More tests => 2;
BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Data::Printer return_value => 'dump';

my $structure = {
    a          => 1,
    bb         => 2,
    long_line  => 3,
};

my $output_with_alignment = '\ {
    a           1,
    bb          2,
    long_line   3
}';

is(
    p($structure),
    $output_with_alignment,
    "Got correct structure with default settings",
);

my $output_without_alignment = '\ {
    a   1,
    bb   2,
    long_line   3
}';

is(
    p($structure, align_hash => 0),
    $output_without_alignment,
    "Got correct structure with disabled alignment",
);
