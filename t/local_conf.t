use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    use_ok ('Term::ANSIColor');
    use_ok ('Data::Printer');
    use_ok ('File::HomeDir::Test');
    use_ok ('File::HomeDir');
    use_ok ('File::Spec');

    my $file = File::Spec->catfile(
            File::HomeDir->my_home,
            '.dataprinter'
    );

    if (-e $file) {
        unless (unlink $file) {
            diag('error removing temporary rc file: ' . $@);
            plan skip_all => 'File .dataprinter should not be in test homedir';
        }
    }
};

my %hash = ( key => 'value' );
is( p(%hash), color('reset') . "{$/    "
              . colored('key', 'magenta')
              . '   '
              . colored('"value"', 'bright_yellow')
              . "$/}"
, 'default hash');

is( p(%hash, color => { hash => 'red' }, hash_separator => '  +  ' ), color('reset') . "{$/    "
              . colored('key', 'red')
              . '  +  '
              . colored('"value"', 'bright_yellow')
              . "$/}"
, 'hash keys are now red');

is( p(%hash), color('reset') . "{$/    "
              . colored('key', 'magenta')
              . '   '
              . colored('"value"', 'bright_yellow')
              . "$/}"
, 'still default hash');


done_testing;
