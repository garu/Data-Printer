use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use_ok ('Term::ANSIColor');
    use_ok (
        'Data::Printer',
            colored      => 1,
            return_value => 'dump',
            show_unicode => 1,
    );
};

my $uni_str= "\x{2603}";
my $ascii_str= "\x{ff}";

is(
    p($uni_str),
    color('reset') . q["] . colored($uni_str, 'bright_yellow') . q["]
                   . ' ' . colored('(U)', 'bright_yellow'),
    'unicode scalar gets suffix'
);

is(
    p($ascii_str),
    color('reset') . q["] . colored($ascii_str, 'bright_yellow') . q["],
    'ascii scalar without suffix'
);

done_testing;
