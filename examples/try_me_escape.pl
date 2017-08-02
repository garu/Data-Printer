#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

# This sample code is available to you so you
# can see Data::Printer working out of the box.
# It can be used as a quick way to test your
# color palette scheme!

use DDP {
    show_unicode  => 1,
    color         => { escaped => 'white', },
};

my $string =  "string"              # basiclatin
            . "\0"                  #  c0controls
            . "with"                # basiclatin
            . "\x{A0}"              #  latin1
            . "vertical"            # basiclatin
            . "\x{0B}"              #  c0controls
            . "tabulation,"         # basiclatin
            . "\x{88}"              #  c1controls (HTS)
            . "record"              # basiclatin
            . "\x{1E}"              #  c0controls
            . "separator, new"      # basiclatin
            . "\n"                  #  c0controls
            . "line and "           # basiclatin
            . "\x{7F}"              #  c0controls (DEL)
            . "юникод",             #  multibyte
           ;

print STDERR qq{as is:          "$string"\n};


print STDERR "as hex:         ";
p $string, 
    print_escapes => 0,
    escape        => { c0controls => 'hex', c1controls => 'hex', latin1 => 'hex', multibyte => 'hex' },
;

print STDERR "as char:        ";
p $string, 
    print_escapes => 0,
    escape        => { c0controls => 'char', c1controls => 'char', latin1 => 'char', multibyte => 'char', },
;

print STDERR "as picture:     ";
p $string, 
    print_escapes => 0,
    escape        => { c0controls => 'picture', c1controls => 'picture', latin1 => 'picture', multibyte => 'picture', },
;

print STDERR "as picture/hex: ";
p $string, 
    print_escapes => 0,
    escape        => { c0controls => 'picture', c1controls => 'hex', latin1 => 'picture', multibyte => 'picture', },
;