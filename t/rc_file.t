use strict;
use warnings;
use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    use_ok ('Term::ANSIColor', 'colored');
    use_ok ('File::HomeDir::Test');
    use_ok ('File::HomeDir');
    use_ok ('File::Spec');

    my $file = File::Spec->catfile(
            File::HomeDir->my_home,
            '.dataprinter'
    );

    if (-e $file) {
        plan skip_all => 'File .dataprinter should not be in test homedir';
    }
    open my $fh, '>', $file
        or plan skip_all => "error opening .dataprinter: $!";

    print {$fh} '{ color => { hash => "red" }, hash_separator => "  +  "}'
        or plan skip_all => "error writing to .dataprinter: $!";

    close $fh;

    # file created and in place, let's load up our
    # module and see if it overrides the default conf
    # with our .dataprinter RC file
    use_ok ('Data::Printer');
};

my %hash = ( key => 'value' );

is( p(%hash), "{$/    "
              . colored('key', 'red')
              . '  +  '
              . colored('"value"', 'bright_yellow')
              . ",$/}"
   , 'hash keys are now red'
);

is( p(%hash, color => { hash => 'blue' }, hash_separator => '  *  ' ), "{$/    "
              . colored('key', 'blue')
              . '  *  '
              . colored('"value"', 'bright_yellow')
              . ",$/}"
, 'local configuration overrides our rc file');


done_testing;
