use strict;
use warnings;
use Test::More;

my $file;
BEGIN {
    use_ok ('File::Temp');

    $file = File::Temp->new()
        or plan skip_all => "error creating temporary rc file: $!";
    $file->print('{colored => 0, hash_separator => " ><(((o> "}')
        or plan skip_all => "error writing to temporary rc file: $!";
    $file->close();

    use_ok ('Data::Printer', $file->filename());
};

my %hash = ( key => 'value' );

is( p(%hash), qq[{$/    key ><(((o> "value"$/}], 'custom rc file works');

done_testing;
