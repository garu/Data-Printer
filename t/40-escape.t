use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

use Test::More;

BEGIN {
    delete $ENV{ANSI_COLORS_DISABLED};
    delete $ENV{DATAPRINTERRC};
    use File::HomeDir::Test;  # avoid user's .dataprinter
    use_ok ('Term::ANSIColor');
    use_ok (
        'Data::Printer',
            return_value  => 'dump',
            colored       => 1,
    );
};

my $ec = color('bright_red');
my $oc = color('bright_yellow');

my @stuff = (

    # C0 Controls
    {   original => "\0",
        c0controls => {
            hex      => $ec . '\x{00}' . $oc,
            char     => $ec . '\0'     . $oc,
            picture  => $ec . '␀'      . $oc,
        },
        basiclatin => {
            hex      => $ec . '\0' . $oc,
            char     => $ec . '\0' . $oc,
            picture  => $ec . '\0' . $oc,
        },
        c1controls => {
            hex      => $ec . '\0' . $oc,
            char     => $ec . '\0' . $oc,
            picture  => $ec . '\0' . $oc,
        },
        latin1 => {
            hex      => $ec . '\0' . $oc,
            char     => $ec . '\0' . $oc,
            picture  => $ec . '\0' . $oc,
        },
        multibyte => {
            hex      => $ec . '\0' . $oc,
            char     => $ec . '\0' . $oc,
            picture  => $ec . '\0' . $oc,
        }
    },
    {   original => "\a",
        c0controls => {
            hex      => $ec . '\x{07}' . $oc,
            char     => $ec . '\a'     . $oc,
            picture  => $ec . '␇'      . $oc,
        }
    },
    {   original => "\b",
        c0controls => {
            hex      => $ec . '\x{08}' . $oc,
            char     => $ec . '\b'     . $oc,
            picture  => $ec . '␈'      . $oc,
        }
    },
    {   original => "\e",
        c0controls => {
            hex      => $ec . '\x{1b}' . $oc,
            char     => $ec . '\e'     . $oc,
            picture  => $ec . '␛'      . $oc,
        }
    },
    {   original => "\f",
        c0controls => {
            hex      => $ec . '\x{0c}' . $oc,
            char     => $ec . '\f'     . $oc,
            picture  => $ec . '␌'      . $oc,
        }
    },
    {   original => "\n",
        c0controls => {
            hex      => $ec . '\x{0a}' . $oc,
            char     => $ec . '\n'     . $oc,
            picture  => $ec . '␊'      . $oc,
        }
    },
    {   original => "\r",
        c0controls => {
            hex      => $ec . '\x{0d}' . $oc,
            char     => $ec . '\r'     . $oc,
            picture  => $ec . '␍'      . $oc,
        }
    },
    {   original => "\t",
        c0controls => {
            hex      => $ec . '\x{09}' . $oc,
            char     => $ec . '\t'     . $oc,
            picture  => $ec . '␉'      . $oc,
        }
    },
    {   original => "\x{1E}",
        c0controls => {
            hex      => $ec . '\x{1e}' . $oc,
            picture  => $ec . '␞'      . $oc,
        }
    },
    {   original => "\x{7F}",
        c0controls => {
            hex      => $ec . '\x{7f}' . $oc,
            picture  => $ec . '␡'      . $oc,
        }
    },

    # Basic Latin
    {   original => " ",
        basiclatin => {
            hex      => $ec . '\x{20}' . $oc,
            picture  => $ec . '␠'      . $oc,
        }
    },
    {   original => "~",
        basiclatin => {
            hex      => $ec . '\x{7e}' . $oc,
        }
    },

    # C1 Controls
    {   original => "\x{80}", # PAD
        c1controls => {
            hex      => $ec . '\x{80}' . $oc,
        }
    },
    {   original => "\x{9F}", # APC
        c1controls => {
            hex      => $ec . '\x{9f}' . $oc,
        }
    },

    # Latin-1 Supplement
    {   original => "\x{A0}", # NBSP
        latin1 => {
            hex      => $ec . '\x{a0}' . $oc,
            picture  => $ec . '␣'      . $oc,
        }
    },
    {   original => "ÿ",
        latin1 => {
            hex      => $ec . '\x{ff}' . $oc,
        }
    },

    # Multibyte
    {   original => "ё",
        multibyte => {
            hex      => $ec . '\x{451}' . $oc,
        }
    },
    {   original => "￭",
        multibyte => {
            hex      => $ec . '\x{ffed}' . $oc,
        }
    },
    {   original => "😀",
        multibyte => {
            hex      => $ec . '\x{1f600}' . $oc,
        }
    },

    # Mix                   
    {   original =>   "string"              # basiclatin
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
        c0controls => {
            hex      => "string${ec}\\x{00}${oc}with\x{A0}vertical${ec}\\x{0b}${oc}tabulation,\x{88}record${ec}\\x{1e}${oc}separator, new${ec}\\x{0a}${oc}line and ${ec}\\x{7f}${oc}юникод",
            char     => "string${ec}\\0${oc}with\x{A0}vertical\x{0b}tabulation,\x{88}record\x{1e}separator, new${ec}\\n${oc}line and \x{7f}юникод",
            picture  => "string${ec}␀${oc}with\x{A0}vertical${ec}␋${oc}tabulation,\x{88}record${ec}␞${oc}separator, new${ec}␊${oc}line and ${ec}␡${oc}юникод",
        },
        basiclatin => {
            hex      =>   ${ec} . '\x{73}\x{74}\x{72}\x{69}\x{6e}\x{67}' . '\0' . '\x{77}\x{69}\x{74}\x{68}'
                        . ${oc} . "\x{A0}"
                        . ${ec} . '\x{76}\x{65}\x{72}\x{74}\x{69}\x{63}\x{61}\x{6c}'
                        . ${oc} . "\x{0B}"
                        . ${ec} . '\x{74}\x{61}\x{62}\x{75}\x{6c}\x{61}\x{74}\x{69}\x{6f}\x{6e}\x{2c}'
                        . ${oc} . "\x{88}"
                        . ${ec} . '\x{72}\x{65}\x{63}\x{6f}\x{72}\x{64}'
                        . ${oc} . "\x{1E}"
                        . ${ec} . '\x{73}\x{65}\x{70}\x{61}\x{72}\x{61}\x{74}\x{6f}\x{72}\x{2c}\x{20}\x{6e}\x{65}\x{77}'
                        . ${oc} . "\n"
                        . ${ec} . '\x{6c}\x{69}\x{6e}\x{65}\x{20}\x{61}\x{6e}\x{64}\x{20}'
                        . ${oc} . "\x{7f}" . 'юникод',
            char     => "string${ec}\\0${oc}with\x{A0}vertical\x{0B}tabulation,\x{88}record\x{1E}separator, new\nline and \x{7f}юникод",
            picture  => "string${ec}\\0${oc}with\x{A0}vertical\x{0B}tabulation,\x{88}record\x{1E}separator,${ec}␠${oc}new\nline${ec}␠${oc}and${ec}␠${oc}\x{7f}юникод",
        },
        c1controls => {
            hex      => "string${ec}\\0${oc}with\x{A0}vertical\x{0B}tabulation,${ec}\\x{88}${oc}record\x{1E}separator, new\nline and \x{7f}юникод",
            char     => "string${ec}\\0${oc}with\x{A0}vertical\x{0b}tabulation,\x{88}record\x{1e}separator, new\nline and \x{7f}юникод",
            picture  => "string${ec}\\0${oc}with\x{A0}vertical\x{0b}tabulation,\x{88}record\x{1e}separator, new\nline and \x{7f}юникод",
        },
        latin1 => {
            hex      =>   "string${ec}\\0${oc}with"
                        . ${ec} . '\x{a0}'
                        . ${oc} . "vertical\x{0B}tabulation,\x{88}record\x{1E}separator, new\nline and \x{7f}юникод",
            char     => "string${ec}\\0${oc}with\x{A0}vertical\x{0b}tabulation,\x{88}record\x{1e}separator, new\nline and \x{7f}юникод",
            picture  => "string${ec}\\0${oc}with${ec}␣${oc}vertical\x{0b}tabulation,\x{88}record\x{1e}separator, new\nline and \x{7f}юникод",
        },
        multibyte => {
            hex      =>   "string${ec}\\0${oc}with\x{A0}vertical\x{0B}tabulation,\x{88}record\x{1E}separator, new\nline and \x{7f}"
                        . ${ec} . '\x{44e}\x{43d}\x{438}\x{43a}\x{43e}\x{434}'
                        . ${oc},
            char     => "string${ec}\\0${oc}with\x{A0}vertical\x{0b}tabulation,\x{88}record\x{1e}separator, new\nline and \x{7f}юникод",
            picture  => "string${ec}\\0${oc}with\x{A0}vertical\x{0b}tabulation,\x{88}record\x{1e}separator, new\nline and \x{7f}юникод",
        },
    },
);

for my $range ( qw(c0controls basiclatin c1controls latin1 multibyte) ) {
    for my $esc ( qw(hex char picture) ) {

        foreach my $item (@stuff) {

            my $printed = join('', map { sprintf( '\x{%02x}', ord $_) } split //, $item->{original} );
            my $colored = $item->{$range}->{$esc} || $item->{original};

            is(
                p( $item->{original}, escape => {$range => $esc} ),
                  color('reset')
                . '"'
                . color('bright_yellow')
                . $colored
                . color('reset')
                . '"',
                qq{$range to $esc for "$printed"}
            );
        }
    }
}

done_testing;
