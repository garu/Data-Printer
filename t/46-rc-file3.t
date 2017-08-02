use strict;
use warnings;
use Test::More;

my $plainfile;
my $symlink;
BEGIN {
    eval { symlink("", ""); 1; } or plan skip_all => "Symlinks not supported on this platform";

    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
    use Term::ANSIColor;
    use File::HomeDir::Test;
    use File::HomeDir;
    use File::Spec;

    $plainfile = File::Spec->catfile(
            File::HomeDir->my_home,
            'plainfile'
    );
    $symlink = File::Spec->catfile(
            File::HomeDir->my_home,
            '.dataprinter'
    );

    if (-e $plainfile || -l $symlink || -e $symlink) {
        plan skip_all => 'Files plainfile and .dataprinter should not be in test homedir';
    }
    umask 0022;
    symlink $plainfile, $symlink or plan skip_all => "Symlink could not be created";
    open my $fh, '>', $plainfile
        or plan skip_all => "error opening plainfile $!";

    print {$fh} '{ colored => 1, color => { hash => "red" }, hash_separator => "  +  "}'
        or plan skip_all => "error writing to plainfile: $!";

    close $fh;

    # file created and in place, let's load up our
    # module and see if it overrides the default conf
    # with our .dataprinter RC file
    use_ok ('Data::Printer', return_value => 'dump');
    unlink $plainfile or fail('error removing test file');

    # let's see if we can call p() from within the BEGIN block itself.
    # prototypes aren't available in here :(
    my $h = { a => 42 };
    is( p($h), color('reset') . "{$/    "
                . colored('a', 'red')
                . '  +  '
                . colored('42', 'bright_blue')
                . "$/}"
    , 'hash keys are now red'
    );
};

my %hash = ( key => 'value' );

is( p(%hash), color('reset') . "{$/    "
              . colored('key', 'red')
              . '  +  '
              . q["] . colored('value', 'bright_yellow') . q["]
              . "$/}"
   , 'hash keys are now red'
);

is( p(%hash, color => { hash => 'blue' }, hash_separator => '  *  ' ), color('reset') . "{$/    "
              . colored('key', 'blue')
              . '  *  '
              . q["] . colored('value', 'bright_yellow') . q["]
              . "$/}"
, 'local configuration overrides our rc file');


done_testing;

