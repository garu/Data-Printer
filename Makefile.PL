use strict;
use warnings;
use ExtUtils::MakeMaker;

my %options = (
    NAME                => 'Data::Printer',
    AUTHOR              => 'Breno G. de Oliveira <garu@cpan.org>',
    VERSION_FROM        => 'lib/Data/Printer.pm',
    ABSTRACT_FROM       => 'lib/Data/Printer.pm',
    LICENSE             => 'perl',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'      => 0,
        'Scalar::Util'    => 0,
        'version'         => 0.77, # handling VSTRINGS
        'File::Spec'      => 0,
        'File::Temp'      => 0,
        'Fcntl'           => 0,
      ( 'MRO::Compat'    => 0.09 )x!! ($] >= 5.010),
    },
    META_MERGE => {
        resources => {
            license     => 'http://dev.perl.org/licenses/',
            bugtracker  => 'https://github.com/garu/Data-Printer/issues/',
            repository  => 'https://github.com/garu/Data-Printer',
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Data-Printer-*' },
);


if ($^O =~ /Win32/i) {
    $options{PREREQ_PM}{'Win32::Console::ANSI'} = 1.0;
}

WriteMakefile( %options );
