use strict;
use warnings;

my $success = eval { require Test::Whitespaces; };

if ($success) {
    Test::Whitespaces->import({
        dirs => [
            qw(
                examples
                lib
                t
            )
        ],
    });
    1;
}
else {
    require Test::More;
    Test::More->import;
    Test::More::plan(skip_all => 'Test::Whitespaces not found');
}
