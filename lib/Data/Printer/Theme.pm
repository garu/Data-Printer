package Data::Printer::Theme;
use strict;
use warnings;
use Data::Printer::Common;

sub name {
    my ($self) = @_;
    return $self->{name};
}

sub color_for {
    my ($self, $color_type) = @_;
    return $self->{colors}{$color_type} || '';
}

sub sgr_color_for {
    my ($self, $color_type) = @_;
    return $self->{sgr_colors}{$color_type} || ''
}

sub color_reset { return "\e[0m" }

sub new {
    my ($class, $theme_name, $colors_to_override) = @_;

    my $theme = _load_theme($theme_name) or return;
    _maybe_override_theme_colors($theme, $colors_to_override);
    return bless $theme, $class;
}

sub _maybe_override_theme_colors {
    my ($theme, $colors_to_override) = @_;

    return unless $colors_to_override
               && ref $colors_to_override eq 'HASH'
               && keys %$colors_to_override;

    my $error = Data::Printer::Common::_tryme(sub {
        foreach my $kind (keys %$colors_to_override ) {
            my $override = $colors_to_override->{$kind};
            die "color for '$kind' must be a scalar" if ref $override;
            $theme->{colors}{$kind} = $override;
            $theme->{sgr_colors}{$kind} = _parse_color($override);
            $theme->{is_custom}{$kind} = 1;
        }
    });
    if ($error) {
        Data::Printer::Common::_warn("error overriding color: $error. Skipping!");
    }
    return;
}

sub _load_theme {
    my ($theme_name) = @_;

    my $class = 'Data::Printer::Theme::' . $theme_name;
    my $error = Data::Printer::Common::_tryme("use $class; 1;");
    if ($error) {
        Data::Printer::Common::_warn("error loading theme '$theme_name': $error.");
        return { colors => {}, sgr_colors => {} };
    }
    my $loaded_colors     = {};
    my $loaded_colors_sgr = {};
    $error = Data::Printer::Common::_tryme(sub {
        my $class_colors;
        { no strict 'refs'; $class_colors = &{ $class . '::colors'}(); }
        die "${class}::colors() did not return a hash reference"
            unless ref $class_colors eq 'HASH';

        foreach my $kind (keys %$class_colors) {
            my $loaded_color = $class_colors->{$kind};
            die "color for '$kind' must be a scalar in theme '$theme_name'"
                if ref $loaded_color;
            $loaded_colors->{$kind} = $loaded_color;
            $loaded_colors_sgr->{$kind} = _parse_color($loaded_color);
        }
    });
    if ($error) {
        Data::Printer::Common::_warn("Error loading theme '$theme_name': $error. Output will have no colors");
        return { colors => {}, sgr_colors => {} };
    }
    return {
        name       => $theme_name,
        colors     => $loaded_colors,
        sgr_colors => $loaded_colors_sgr,
    };
}

sub _parse_color {
    my ($color_label) = @_;
    return unless $color_label;

    my $color_code;
    if ($color_label =~ /\Argb\((\d+),(\d+),(\d+)\)\z/) {
        my ($r, $g, $b) = ($1, $2, $3);
        if ($r < 256 && $g < 256 && $b < 256) {
            $color_code = "\e[0;38;2;$r;$g;${b}m";
        }
        else {
            Data::Printer::Common::_warn("invalid color '$color_label': all colors must be between 0 and 255");
        }
    }
    elsif ($color_label =~ /\A#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})\z/i) {
        my ($r, $g, $b) = map hex($_), ($1, $2, $3);
        if ($r < 256 && $g < 256 && $b < 256) {
            $color_code = "\e[0;38;2;$r;$g;${b}m";
        }
        else {
            Data::Printer::Common::_warn("invalid color '$color_label': all colors must be between 00 and FF");
        }
    }
    elsif ($color_label =~ /\A\e\[\d+(:?;\d+)*m\z/) {
        $color_code = $color_label;
    }
    elsif ($color_label =~ /\A
        (?:
         \s*
          (?:on_)?
          (?:bright_)?
          (?:black|red|green|yellow|blue|magenta|cyan|white)
        )+
        \s*\z/x
    ) {
        my %ansi_colors = (
            'black'          => 30,   'on_black'          => 40,
            'red'            => 31,   'on_red'            => 41,
            'green'          => 32,   'on_green'          => 42,
            'yellow'         => 33,   'on_yellow'         => 43,
            'blue'           => 34,   'on_blue'           => 44,
            'magenta'        => 35,   'on_magenta'        => 45,
            'cyan'           => 36,   'on_cyan'           => 46,
            'white'          => 37,   'on_white'          => 47,
            'bright_black'   => 90,   'on_bright_black'   => 100,
            'bright_red'     => 91,   'on_bright_red'     => 101,
            'bright_green'   => 92,   'on_bright_green'   => 102,
            'bright_yellow'  => 93,   'on_bright_yellow'  => 103,
            'bright_blue'    => 94,   'on_bright_blue'    => 104,
            'bright_magenta' => 95,   'on_bright_magenta' => 105,
            'bright_cyan'    => 96,   'on_bright_cyan'    => 106,
            'bright_white'   => 97,   'on_bright_white'   => 107,
        );
        $color_code = "\e["
                    . join ';' => map $ansi_colors{$_}, split(/\s+/, $color_label)
                    . 'm'
                    ;
    }
    else {
        Data::Printer::Common::_warn("unrecognized color '$color_label'");
    }
    return $color_code;
}


1;
