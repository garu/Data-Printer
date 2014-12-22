use strict;
use warnings;
use Test::More;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use DDP return_value => 'dump';

eval 'use YAML::Syck';
if ($@) {
    plan skip_all => 'YAML::Syck not found.';
}
else {
    plan tests => 1;
}

my $yaml = qq{---
sample:
-  !!some.method
    name: 'foo'
    value: 'bar'
};

my $data = YAML::Syck::Load($yaml);

is p($data), '\ {
    sample   [
        [0] some.method  {
            public methods (0)
            private methods (0)
            internals: {
                name    "foo",
                value   "bar"
            }
        }
    ]
}',
  'testing odd objects (YAML::Syck)';

