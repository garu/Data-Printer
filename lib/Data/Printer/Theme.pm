package Data::Printer::Theme;
use strict;
use warnings;
use Data::Printer::Common;

# the theme name
sub name {
    my ($self) = @_;
    return $self->{name};
}

# true if the theme has at least one color override
sub customized {
    my ($self) = @_;
    return exists $self->{is_custom} ? 1 : 0;
}

# displays the color as-is
sub color_for {
    my ($self, $color_type) = @_;
    return $self->{colors}{$color_type} || '';
}

# prints the SGR (terminal) color modifier
sub sgr_color_for {
    my ($self, $color_type) = @_;
    return unless exists $self->{sgr_colors}{$color_type};
    return $self->{sgr_colors}{$color_type} || ''
}

# prints the SGR (terminal) color reset modifier
sub color_reset { return "\e[m" }

sub new {
    my ($class, %params) = @_;

    my $color_level        = $params{color_level};
    my $colors_to_override = $params{color_overrides};
    my $theme_name         = $params{name};

    # before we put user info on string eval, make sure
    # it's just a module name:
    $theme_name =~ s/[^a-zA-Z0-9:]+//gsm;

    my $theme = bless {
        name        => $theme_name,
        color_level => $color_level,
        colors      => {},
        sgr_colors  => {},
    }, $class;
    $theme->_load_theme($params{ddp}) or delete $theme->{name};
    $theme->_maybe_override_theme_colors($colors_to_override, $params{ddp});
    return $theme;
}

sub _maybe_override_theme_colors {
    my ($self, $colors_to_override, $ddp) = @_;

    return unless $colors_to_override
               && ref $colors_to_override eq 'HASH'
               && keys %$colors_to_override;

    my $error = Data::Printer::Common::_tryme(sub {
        foreach my $kind (keys %$colors_to_override ) {
            my $override = $colors_to_override->{$kind};
            die "invalid color for '$kind': must be scalar not ref" if ref $override;
            my $parsed = $self->_parse_color($override, $ddp);
            if (defined $parsed) {
                $self->{colors}{$kind}     = $override;
                $self->{sgr_colors}{$kind} = $parsed;
                $self->{is_custom}{$kind}  = 1;
            }
        }
    });
    if ($error) {
        Data::Printer::Common::_warn($ddp, "error overriding color: $error. Skipping!");
    }
    return;
}

sub _load_theme {
    my ($self, $ddp) = @_;
    my $theme_name = $self->{name};

    my $class = 'Data::Printer::Theme::' . $theme_name;
    my $error = Data::Printer::Common::_tryme("use $class; 1;");
    if ($error) {
        Data::Printer::Common::_warn($ddp, "error loading theme '$theme_name': $error.");
        return;
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
            my $parsed_color = $self->_parse_color($loaded_color, $ddp);
            if (defined $parsed_color) {
                $loaded_colors->{$kind}     = $loaded_color;
                $loaded_colors_sgr->{$kind} = $parsed_color;
            }
        }
    });
    if ($error) {
        Data::Printer::Common::_warn($ddp, "error loading theme '$theme_name': $error. Output will have no colors");
        return;
    }
    $self->{colors}     = $loaded_colors;
    $self->{sgr_colors} = $loaded_colors_sgr;
    return 1;
}

sub _parse_color {
    my ($self, $color_label, $ddp) = @_;
    return unless defined $color_label;
    return '' unless $color_label;

    my $color_code;
    if ($color_label =~ /\Argb\((\d+),(\d+),(\d+)\)\z/) {
        my ($r, $g, $b) = ($1, $2, $3);
        if ($r < 256 && $g < 256 && $b < 256) {
            if ($self->{color_level} == 3) {
                $color_code = "\e[0;38;2;$r;$g;${b}m";
            }
            else {
                my $reduced = _rgb2short($r,$g,$b);
                $color_code = "\e[0;38;5;${reduced}m";
            }
        }
        else {
            Data::Printer::Common::_warn($ddp, "invalid color '$color_label': all colors must be between 0 and 255");
        }
    }
    elsif ($color_label =~ /\A#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})\z/i) {
        my ($r, $g, $b) = map hex($_), ($1, $2, $3);
        if ($self->{color_level} == 3) {
            $color_code = "\e[0;38;2;$r;$g;${b}m";
        }
        else {
            my $reduced = _rgb2short($r,$g,$b);
            $color_code = "\e[0;38;5;${reduced}m";
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
                    . join(';' => map $ansi_colors{$_}, split(/\s+/, $color_label))
                    . 'm'
                    ;
    }
    else {
        Data::Printer::Common::_warn($ddp, "invalid color '$color_label'");
    }
    return $color_code;
}

sub _rgb2short {
    my ($r,$g,$b) = @_;
    my @snaps = (47, 115, 155, 195, 235);
    my @new;
    foreach my $color ($r,$g,$b) {
        my $big = 0;
        foreach my $s (@snaps) {
            $big++ if $s < $color;
        }
        push @new, $big
    }
    return $new[0]*36 + $new[1]*6 + $new[2] + 16
}

1;
__END__

=head1 NAME

Data::Printer::Theme - create your own color themes for DDP!

=head1 SYNOPSIS

    package Data::Printer::Theme::MyCustomTheme;

    sub colors {
        return {
            array       => '#aabbcc', # array index numbers
            number      => '#aabbcc', # numbers
            string      => '#aabbcc', # strings
            class       => '#aabbcc', # class names
            method      => '#aabbcc', # method names
            undef       => '#aabbcc', # the 'undef' value
            hash        => '#aabbcc', # hash keys
            regex       => '#aabbcc', # regular expressions
            code        => '#aabbcc', # code references
            glob        => '#aabbcc', # globs (usually file handles)
            vstring     => '#aabbcc', # version strings (v5.30.1, etc)
            lvalue      => '#aabbcc', # lvalue label
            format      => '#aabbcc', # format type
            true        => '#aabbcc', # boolean type (true)
            false       => '#aabbcc', # boolean type (false)
            repeated    => '#aabbcc', # references to seen values
            caller_info => '#aabbcc', # details on what's being printed
            weak        => '#aabbcc', # weak references flag
            tainted     => '#aabbcc', # tainted flag
            unicode     => '#aabbcc', # utf8 flag
            escaped     => '#aabbcc', # escaped characters (\t, \n, etc)
            brackets    => '#aabbcc', # (), {}, []
            separator   => '#aabbcc', # the "," between hash pairs, array elements, etc
            quotes      => '#aabbcc', # q(")
            unknown     => '#aabbcc', # any (potential) data type unknown to Data::Printer
        };
    }
    1;

Then in your C<.dataprinter> file:

    theme = MyCustomTheme

That's it! Alternatively, you can load it at runtime:

    use DDP theme => 'MyCustomTheme';


=head1 DESCRIPTION

Data::Printer colorizes your output by default. Originally, the only way to
customize colors was to override the default ones. Data::Printer 1.0 introduced
themes, and now you can pick a theme or create your own.

Data::Printer comes with several themes for you to choose from:

=over 4

=item * L<Material|Data::Printer::Theme::Material> I<(the default)>

=for html <a href="https://metacpan.org/pod/Data::Printer::Theme::Material"><img style="height:50%" src="https://raw.githubusercontent.com/garu/Data-Printer/master/examples/theme-material.png" alt="Material Theme" /></a>

=item * L<Monokai|Data::Printer::Theme::Monokai>

=for html <a href="https://metacpan.org/pod/Data::Printer::Theme::Monokai"><img style="height:50%" src="https://raw.githubusercontent.com/garu/Data-Printer/master/examples/theme-monokai.png" alt="Monokai Theme" /></a>

=item * L<Solarized|Data::Printer::Theme::Solarized>

=for html <a href="https://metacpan.org/pod/Data::Printer::Theme::Solarized"><img style="height:50%" src="https://raw.githubusercontent.com/garu/Data-Printer/master/examples/theme-solarized.png" alt="Solarized Theme" /></a>

=item * L<Classic|Data::Printer::Theme::Classic> I<(original pre-1.0 colors)>

=for html <a href="https://metacpan.org/pod/Data::Printer::Theme::Classic"><img style="height:50%" src="https://raw.githubusercontent.com/garu/Data-Printer/master/examples/theme-classic.png" alt="Classic Theme" /></a>

=back

Run C<< examples/try_me.pl >> to see them in action on your own terminal!


=head1 CREATING YOUR THEMES

A theme is a module in the C<Data::Printer::Theme> namespace. It doesn't have
to inherit or load any module. All you have to do is implement a single
function, C<colors>, that returns a hash reference where keys are the
expected color labels, and values are the colors you want to use.

Feel free to copy & paste the code from the SYNOPSIS and customize at will :)

=head2 Customizing Colors

Setting any color to C<undef> means I<< "Don't colorize this" >>.
Otherwise, the color is a string which can be one of the following:

=head3 Named colors, Term::ANSIColor style (discouraged)

Only 8 named colors are supported:

black, red, green, yellow, blue, magenta, cyan, white

and their C<bright_XXX>, C<on_XXX> and C<on_bright_XXX> variants.

Those are provided only as backards compatibility with older versions
of Data::Printer and, because of their limitation, we encourage you
to try and use one of the other representations.

=head3 SGR Escape code (Terminal style)

You may provide any SGR escape sequence, and they will be honored
as long as you use double quotes (e.g. C<"\e[38;5;196m">). You may
use this to achieve extra control like blinking, etc. Note, however,
that some terminals may not support them.

=head3 An RGB value in one of those formats (Recommended)

    'rgb(0,255,30)'
    '#00FF3B'

B<NOTE:> There may not be a real 1:1 conversion between RGB and
terminal colors. In those cases we use approximation to achieve the
closest option.

=head1 SEE ALSO

L<Data::Printer>
