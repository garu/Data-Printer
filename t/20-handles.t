use strict;
use warnings;

BEGIN {
    $ENV{ANSI_COLORS_DISABLED} = 1;
    use File::HomeDir::Test;  # avoid user's .dataprinter
};

use Test::More;
use Fcntl;
use Data::Printer;

open my $var, '+>>', 't/test_file.dat' or plan skip_all => 'error opening file for testing';

my $str = p $var;

my @layers = ();
eval { @layers = PerlIO::get_layers $var };
unless ($@) {
    foreach my $l (@layers) {
        like $str, qr/$l/, "layer $l present in info";
    }
}

my $flags = fcntl($var, F_GETFL, 0) or plan skip_all => 'fcntl not present?';

like $str, qr{read/write}, 'read/write handle';
like $str, qr/flags: append/, 'append flag';

close $var;

open $var, '>', 't/test_file.dat' or plan skip_all => 'error opening file for (write) testing';
like p($var), qr{write-only}, 'write-only handle';
close $var;

open $var, '<', 't/test_file.dat' or plan skip_all => 'error opening file for (read) testing';
like p($var), qr{read-only}, 'read-only handle';
close $var;


done_testing;

