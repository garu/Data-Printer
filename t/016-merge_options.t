use strict;
use warnings;
use Test::More tests => 12;
use Data::Printer::Common;

is_deeply(
    Data::Printer::Common::_merge_options(undef, { foo => 42, bar => 27 }),
    { foo => 42, bar => 27 },
    'merge undef and hash'
);
is_deeply(
    Data::Printer::Common::_merge_options(undef,[ foo => 42, bar => 27 ]),
    [ 'foo', 42, 'bar',27 ],
    'merge undef and array'
);
is_deeply(
    Data::Printer::Common::_merge_options({}, { foo => 42, bar => 27 }),
    { foo => 42, bar => 27 },
    'merge hash and hash'
);
is_deeply(
    Data::Printer::Common::_merge_options([],[ foo => 42, bar => 27 ]),
    [ 'foo', 42, 'bar',27 ],
    'merge array and array'
);
is_deeply(
    Data::Printer::Common::_merge_options([], { foo => 42, bar => 27 }),
    { foo => 42, bar => 27 },
    'merge array and hash'
);
is_deeply(
    Data::Printer::Common::_merge_options({},[ foo => 42, bar => 27 ]),
    [ 'foo', 42, 'bar',27 ],
    'merge hash and array'
);

is_deeply(
    Data::Printer::Common::_merge_options(
        { foo => 42, bar => 27 },
        { foo => 666 },
    ),
    { foo => 666, bar => 27 },
    'merge two hashes'
);

is_deeply(
    Data::Printer::Common::_merge_options(
        { foo => { bar => 42, baz => 27 } },
        { foo => { bar => 666 } },
    ),
    { foo => { bar => 666, baz => 27 } },
    'merge two hashes with recursion'
);

my $old = { x => [1], foo => { bar => 42, baz => { a => 1, b => 2 } } };
my $new = { x => [9,8], bar => 10, foo => { meep => 1, baz => { b => 4, c => q(a) } } };
my $merged = Data::Printer::Common::_merge_options($old, $new);

is_deeply(
    $merged,
    { x => [9,8], bar => 10, foo => { bar => 42, meep => 1, baz => { a => 1, b => 4, c => q(a) } } },
    'merge two deep hash variables'
);

$merged->{foo}{baz} = undef; # <-- are we really a new value or a ref? let's check!

is_deeply(
    $old,
    { x => [1], foo => { bar => 42, baz => { a => 1, b => 2 } } },
    'old variable was not changed'
);

is_deeply(
    $new,
    { x => [9,8], bar => 10, foo => { meep => 1, baz => { b => 4, c => q(a) } } },
    'new variable was not changed'
);


is_deeply(
    Data::Printer::Common::_merge_options(
        { foo => 1, bar => 2, baz => { meep => 666, moop => [444], bla => [3,2,1] } },
        { foo => 42, baz => { otherkey => 42, moop => [44,3] } }
    ),
    {
        foo => 42,
        bar => 2,
        baz => {
            meep => 666,
            moop => [44,3],
            otherkey => 42,
            bla => [3,2,1]
        }
    },
    'merged complex data structures'
);
