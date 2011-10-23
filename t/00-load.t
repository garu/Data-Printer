#!perl

use Test::More tests => 2;

BEGIN {
    diag( "Beginning Data::Printer tests in $^O with Perl $], $^X" );
    use_ok( 'Class::MOP' ) || print "Bail out!
";
    diag( "Trying to load Data::Printer with Class::MOP $Class::MOP::VERSION" );
    use_ok( 'Data::Printer' ) || print "Bail out!
";
}

diag( "Testing Data::Printer $Data::Printer::VERSION" );
