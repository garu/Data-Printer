#!perl

use Test::More tests => 1;

BEGIN {
    use_ok( 'Data::Printer' ) || print "Bail out!
";
}

diag( "Testing Data::Printer $Data::Printer::VERSION, Perl $], $^X" );
