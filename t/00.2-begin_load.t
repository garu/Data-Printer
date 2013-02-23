my $res;

BEGIN {
    use Test::More;
    use Data::Printer colored => 0, multiline => 0, index => 0;

    my @data = ( 1 .. 3 );

    $res = p @data;
}

is $res, '[ 1, 2, 3 ]', 'DDP wihtin a BEGIN block';

done_testing;
