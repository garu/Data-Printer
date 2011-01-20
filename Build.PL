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
        'Term::ANSIColor' => 3.00,
        'Scalar::Util'    => 1.23,
        'Sort::Naturally' => 1.02,
        'Class::MOP'      => 1.12,
        'Carp'            => 0,
        'Object::ID'      => 0,
        'parent'          => 0.224,
        'Exporter'        => 5.63,
    },
    add_to_cleanup      => [ 'Data-Printer-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
