use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Data::Printer',
    license             => 'perl',
    dist_author         => q{Breno G. de Oliveira <garu@cpan.org>},
    dist_version_from   => 'lib/Data/Printer.pm',
    build_requires => {
        'Test::More' => 0.88,
    },
    requires => {
        'Term::ANSIColor' => 1.10, # ships with 5.8.8
        'Scalar::Util'    => 0,
        'Sort::Naturally' => 0,
        'Class::MOP'      => 0.65, # introduces get_all_methods()
        'Carp'            => 0,
        'Clone'           => 0,
        'Hash::FieldHash' => 0,
        'File::HomeDir'   => 0.91, # introduces File::HomeDir::Test
        'File::Spec'      => 0,
        'Fcntl'           => 0,
    },
    add_to_cleanup      => [ 'Data-Printer-*' ],
    create_makefile_pl => 'traditional',

    meta_merge     => {
        resources => {
            repository  => 'http://github.com/garu/Data-Printer/'
        },
    },
);

if ($^O =~ /Win32/i) {
    $builder->requires->{'Win32::Console::ANSI'} = 1.0;
}

$builder->create_build_script();
