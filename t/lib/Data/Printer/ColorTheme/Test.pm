package Data::Printer::ColorTheme::Test;

sub colors {
    return {
        'array'       => 'bright_white',
        'number'      => 'red on_white',
        'string'      => 'bright_yellow',
        'class'       => 'bright_green',
        'method'      => 'bright_green',
        'undef'       => 'bright_red',
        'hash'        => 'magenta',
        'regex'       => 'yellow',
        'code'        => 'green',
        'glob'        => 'bright_cyan',
        'vstring'     => 'bright_blue',
        'lvalue'      => 'bright_white',
        'format'      => 'bright_cyan',
        'repeated'    => 'white on_red',
        'caller_info' => 'bright_cyan',
        'weak'        => 'cyan',
        'tainted'     => 'red',
        'escaped'     => 'bright_red',
        'unknown'     => 'bright_yellow on_blue',
    };
}

1;
