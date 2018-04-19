use strict;
use warnings;
use Test::More tests => 3;
use Data::Printer::Object;

my $ddp = Data::Printer::Object->new( colored => 0 );

my $regex_with_modifiers = qr{(?:moo(\d|\s)*[a-z]+(.?))}i;
is(
    $ddp->parse(\$regex_with_modifiers),
    '(?:moo(\d|\s)*[a-z]+(.?))  (modifiers: i)',
    'regex with modifiers'
);

my $plain_regex = qr{(?:moo(\d|\s)*[a-z]+(.?))};
is(
    $ddp->parse(\$plain_regex),
    '(?:moo(\d|\s)*[a-z]+(.?))',
    'plain regex'
);

my $creepy_regex = qr{
      |
    ^ \s* go \s
}x;
is(
    $ddp->parse(\$creepy_regex),
    "\n      |\n    ^ \\s* go \\s\n  (modifiers: x)",
    'creepy regex'
);
