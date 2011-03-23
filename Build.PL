use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Data::Printer',
    license             => 'perl',
    dist_author         => q{Breno G. de Oliveira <garu@cpan.org>},
    dist_version_from   => 'lib/Data/Printer.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Term::ANSIColor' => 3.00,
        'Scalar::Util'    => 1.23,
        'Sort::Naturally' => 1.02,
        'Class::MOP'      => 1.12,
        'Carp'            => 0,
        'Clone'           => 0.31,
        'Object::ID'      => 0,
        'File::HomeDir'   => 0,
        'File::Spec'      => 0,
    },
    add_to_cleanup      => [ 'Data-Printer-*' ],
    create_makefile_pl => 'traditional',
);

if ($^O =~ /Win32/i) {
    $builder->requires->{'Win32::Console::ANSI'} = 1.0;
}

$builder->create_build_script();
