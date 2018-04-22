package Data::Printer::Theme::Material;
# inspired by Mattia Astorino's Material theme:
# https://github.com/equinusocio/vsc-material-theme
use strict;
use warnings;

sub colors {
    my %code_for = (
        'very_light_gray' =>  '#EEFFFF',
        'light_gray'      =>  '#B2CCD6',
        'middle_gray'     =>  '#808080',
        'gray'            =>  '#373b41',
        'dark_gray'       =>  '#282a2e',
        'very_dark_gray'  =>  '#263238',
        'green'           =>  '#90B55A', #'#C3E88D',
        'teal'            =>  '#009688',
        'light_teal'      =>  '#73d1c8',
        'cyan'            =>  '#89DDF3',
        'blue'            =>  '#82AAFF',
        'indigo'          =>  '#7986CB',
        'purple'          =>  '#C792EA',
        'pink'            =>  '#FF5370',
        'red'             =>  '#F07178',
        'strong_orange'   =>  '#F78C6A',
        'orange'          =>  '#FFCB6B',
        'light_orange'    =>  '#FFE082',
    );

    return {
        array       => $code_for{light_gray},  # array index numbers
        number      => $code_for{strong_orange}, # numbers
        string      => $code_for{green}, # (or 'very_light_gray'?) # strings
        class       => $code_for{purple},  # class names
        method      => $code_for{blue},  # method names
        undef       => $code_for{pink},  # the 'undef' value
        hash        => $code_for{indigo},  # hash keys
        regex       => $code_for{orange},  # regular expressions
        code        => $code_for{gray},  # code references
        glob        => $code_for{strong_orange},  # globs (usually file handles)
        vstring     => $code_for{strong_orange},  # version strings (v5.16.0, etc)
        lvalue      => $code_for{strong_orange},  # lvalue label
        format      => $code_for{strong_orange},  # format type
        repeated    => $code_for{red},  # references to seen values
        caller_info => $code_for{very_dark_gray},  # details on what's being printed
        weak        => $code_for{green},  # weak references flag
        tainted     => $code_for{light_orange},  # tainted flag
        unicode     => $code_for{light_orange},  # utf8 flag
        escaped     => $code_for{teal},  # escaped characters (\t, \n, etc)
        brackets    => $code_for{cyan},  # (), {}, []
        separator   => $code_for{cyan},  # the "," between hash pairs, array elements, etc
        quotes      => $code_for{cyan},
        unknown     => $code_for{red},  # any (potential) data type unknown to Data::Printer
    };
}

1;
