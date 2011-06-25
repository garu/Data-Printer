use strict;
use warnings;
use Test::More;

my $file;
BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    use Term::ANSIColor;
    use File::HomeDir::Test;
    use File::HomeDir;
    use File::Spec;

    $file = File::Spec->catfile(
            File::HomeDir->my_home,
            '.dataprinter'
    );

    if (-e $file) {
        plan skip_all => 'File .dataprinter should not be in test homedir';
    }
    open my $fh, '>', $file
        or plan skip_all => "error opening .dataprinter: $!";

    print {$fh} '{ colored => 1, color => { hash => "red" }, hash_separator => "  +  "}'
        or plan skip_all => "error writing to .dataprinter: $!";

    close $fh;

    # file created and in place, let's load up our
    # module and see if it overrides the default conf
    # with our .dataprinter RC file
    use_ok ('Data::Printer');
    unlink $file or fail('error removing test file');
};

my %hash = ( key => 'value' );

is( p(%hash), color('reset') . "{$/    "
              . colored('key', 'red')
              . '  +  '
              . colored('"value"', 'bright_yellow')
              . "$/}"
   , 'hash keys are now red'
);

is( p(%hash, color => { hash => 'blue' }, hash_separator => '  *  ' ), color('reset') . "{$/    "
              . colored('key', 'blue')
              . '  *  '
              . colored('"value"', 'bright_yellow')
              . "$/}"
, 'local configuration overrides our rc file');


done_testing;
