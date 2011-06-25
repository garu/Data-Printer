use inc::Module::Install;

name 'Data-Printer';
all_from 'lib/Data/Printer.pm';

test_requires 'Test::More' => 0.88;

requires 'Term::ANSIColor' => 1.10;  # ships with 5.8.8
requires 'Scalar::Util'    => 0;
requires 'Sort::Naturally' => 0;
requires 'Class::MOP'      => 0.65; # introduces get_all_methods()
requires 'Carp'            => 0;
requires 'Clone'           => 0;
requires 'Hash::FieldHash' => 0;
requires 'File::HomeDir'   => 0.91; # introduces File::HomeDir::Test
requires 'File::Spec'      => 0;
requires 'Fcntl'           => 0;

if ($^O =~ /Win32/i) {
    requires 'Win32::Console::ANSI' => 1.0;
}

resources(
    'license'    => 'http://dev.perl.org/licenses/',
    'repository' => 'http://github.com/garu/Data-Printer/',
);

WriteAll;
