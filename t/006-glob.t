use strict;
use warnings;
use Test::More;
use Data::Printer::Object;
use Data::Printer::Common;
use File::Spec;
use Fcntl;

my $ddp = Data::Printer::Object->new( colored => 0 );

my $filename = File::Spec->catfile(
    Data::Printer::Common::_my_home('testing'), 'test_file.dat'
);

if ( open my $var, '>', $filename ) {
    my $str = $ddp->parse(\$var);

    my @layers = ();
    my $error = Data::Printer::Common::_tryme(sub { @layers = PerlIO::get_layers $var });

    close $var;

    if ($error) {
        plan tests => 4;
        diag("error getting handle layers from PerlIO: $error");
    }
    else {
        plan tests => @layers + 4;
        foreach my $l (@layers) {
            like $str, qr/$l/, "layer $l present in info";
        }
    }
}
else {
    diag("error writing to $filename: $!");
}


SKIP: {
    skip "error opening $filename for (write) testing: $!", 4
        unless open my $var, '>', $filename;

    my $flags;
    eval { $flags = fcntl($var, F_GETFL, 0) };
    skip 'fcntl not fully supported', 4 if $@ or !$flags;

    $ddp = Data::Printer::Object->new( colored => 0 );
    like $ddp->parse(\$var), qr{write-only}, 'write-only handle';
    close $var;

    skip "error appending to $filename: $!", 3
        unless open $var, '+>>', $filename;

    $ddp = Data::Printer::Object->new( colored => 0 );
    like $ddp->parse(\$var), qr{read/write}, 'read/write handle';

    $ddp = Data::Printer::Object->new( colored => 0 );
    like $ddp->parse(\$var), qr/flags:[^,]+append/, 'append flag';

    close $var;

    skip "error reading from $filename: $!", 1
        unless open $var, '<', $filename;

    $ddp = Data::Printer::Object->new( colored => 0 );
    like $ddp->parse(\$var), qr{read-only}, 'read-only handle';
    close $var;
};
