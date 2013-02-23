#!perl -T
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

    print {$fh} '{ colored => 0, hash_separator => "-"}'
        or plan skip_all => "error writing to .dataprinter: $!";

    close $fh;

    # file created and in place, let's load up our
    # module and see if it overrides the default conf
    # with our .dataprinter RC file
    use_ok ('Data::Printer');
    unlink $file or fail('error removing test file');
};

my %hash = ( key => 'value' );

isnt( p(%hash), '{
    key-"value"
}',
    'could NOT read rc file in taint mode'
);

done_testing;
