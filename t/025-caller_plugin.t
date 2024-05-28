use strict;
use warnings;
use Test::More;

BEGIN {
    use Data::Printer::Config;
    no warnings 'redefine';
    *Data::Printer::Config::load_rc_file = sub { {} };
};

use Data::Printer colored        => 0,
                  use_prototypes => 0,
                  caller_info    => 1,
                  caller_plugin  => 'Foo';

if (!eval { require Capture::Tiny; 1; }) {
    plan skip_all => 'Capture::Tiny not found';
}
else {
    plan tests => 1;
}

{
    # Try to force require(..) for a caller plugin to fail..

    # In the case the user by chance should have installed a module with
    # the same name as the caller plugin, make sure it will not be found
    # by erasing @INC :
    local @INC = ('./lib');

    # NOTE: local $INC{'Data/Printer/Plugin/Caller/Foo.pm'} does not work
    #  it just sets $INC{'Data/Printer/Plugin/Caller/Foo.pm'} to undef
    #  but that is enough for require "Data/Printer/Plugin/Caller/Foo.pm" not
    #  to fail, so we have to delete the key (and the value):
    my $save = delete $INC{'Data/Printer/Plugin/Caller/Foo.pm'};
    my $var = 1;
    my ($stdout, $stderr) = Capture::Tiny::capture(
        sub {
            p \$var, output => *STDOUT;
        }
    );
    like $stderr, qr/Failed to load caller plugin/, 'missing plugin';
    $INC{'Data/Printer/Plugin/Caller/Foo.pm'} = $save if defined $save;
}
