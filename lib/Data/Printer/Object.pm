use strict;
use warnings;
use Data::Printer::Common;

package # hide from pause
    Data::Printer::Object::ClassOptions;
    sub parents            { $_[0]->{'parents'}            }
    sub linear_isa         { $_[0]->{'linear_isa'}         }
    sub universal          { $_[0]->{'universal'}          }
    sub expand             { $_[0]->{'expand'}             }
    sub stringify          { $_[0]->{'stringify'}          }
    sub show_reftype       { $_[0]->{'show_reftype'}       }
    sub show_overloads     { $_[0]->{'show_overloads'}     }
    sub show_methods       { $_[0]->{'show_methods'}       }
    sub sort_methods       { $_[0]->{'sort_methods'}       }
    sub inherited          { $_[0]->{'inherited'}          }
    sub format_inheritance { $_[0]->{'format_inheritance'} }
    sub internals          { $_[0]->{'internals'}          }
    sub new {
        my ($class, $params) = @_;
        my $self = {
            'linear_isa'     => Data::Printer::Common::_fetch_scalar_or_default($params, 'linear_isa', 'auto'),
            'show_reftype'   => Data::Printer::Common::_fetch_scalar_or_default($params, 'show_reftype', 0),
            'show_overloads' => Data::Printer::Common::_fetch_scalar_or_default($params, 'show_overloads', 1),
            'stringify'      => Data::Printer::Common::_fetch_scalar_or_default($params, 'stringify', 1),
            'expand'         => Data::Printer::Common::_fetch_scalar_or_default($params, 'expand', 1),
            'show_methods'   => Data::Printer::Common::_fetch_anyof(
                $params, 'show_methods', 'all', [qw(none all private public)]
            ),
            'inherited' => Data::Printer::Common::_fetch_anyof(
                $params, 'inherited', 'none', [qw(none all private public)]
            ),
            'format_inheritance' => Data::Printer::Common::_fetch_anyof(
                $params, 'format_inheritance', 'string', [qw(string lines)]
            ),
            'universal'    => Data::Printer::Common::_fetch_scalar_or_default($params, 'universal', 1),
            'sort_methods' => Data::Printer::Common::_fetch_scalar_or_default($params, 'sort_methods', 1),
            'internals'    => Data::Printer::Common::_fetch_scalar_or_default($params, 'internals', 1),
            'parents'      => Data::Printer::Common::_fetch_scalar_or_default($params, 'parents', 1),
        };
        return bless $self, $class;
    }
1;

package Data::Printer::Object;
use Scalar::Util ();
use Data::Printer::Theme;
use Data::Printer::Filter::SCALAR; # also implements LVALUE
use Data::Printer::Filter::ARRAY;
use Data::Printer::Filter::HASH;
use Data::Printer::Filter::REF;
use Data::Printer::Filter::VSTRING;
use Data::Printer::Filter::GLOB;
use Data::Printer::Filter::FORMAT;
use Data::Printer::Filter::Regexp;
use Data::Printer::Filter::CODE;
use Data::Printer::Filter::GenericClass;

# create our basic accessors:
foreach my $method_name (qw(
    name show_tainted show_unicode show_readonly show_lvalue show_refcount
    show_memsize memsize_unit print_escapes scalar_quotes escape_chars
    caller_info caller_message string_max string_overflow string_preserve
    array_max array_overflow array_preserve hash_max hash_overflow
    hash_preserve ignore_keys unicode_charnames colored theme show_weak
    max_depth index separator end_separator class_method class hash_separator
    align_hash sort_keys quote_keys deparse return_value
)) {
    no strict 'refs';
    *{__PACKAGE__ . "::$method_name"} = sub {
        $_[0]->{$method_name} = $_[1] if @_ > 1;
        return $_[0]->{$method_name};
    }
}

sub current_depth { $_[0]->{_depth}   }
sub indent        { $_[0]->{_depth}++ }
sub outdent       { $_[0]->{_depth}-- }

sub newline {
    my ($self) = @_;
    return $self->{_linebreak}
         . (' ' x ($self->{_depth} * $self->{_current_indent}))
         . (' ' x $self->{_array_padding})
         ;
}

sub current_name {
    my ($self, $new_value) = @_;
    if (defined $new_value) {
        $self->{_current_name} = $new_value;
    }
    else {
        $self->{_current_name} = $self->name unless defined $self->{_current_name};
    }
    return $self->{_current_name};
}

sub _init {
    my $self = shift;
    my $props = { @_ == 1 ? %{$_[0]} : @_ };

    $self->{'_linebreak'} = "\n";
    $self->{'_depth'} = 0;
    $self->{'_position'} = 0; # depth is for indentation only!
    $self->{'_array_padding'} = 0;
    $self->{'_seen'} = {};
    $self->{_refcount_base} = 3;
    $self->{'indent'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'indent', 4);
    $self->{'index'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'index', 1);
    $self->{'name'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'name', 'var');
    $self->{'show_tainted'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'show_tainted', 1);
    $self->{'show_weak'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'show_weak', 1);
    $self->{'show_unicode'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'show_unicode', 0);
    $self->{'show_readonly'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'show_readonly', 1);
    $self->{'show_lvalue'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'show_lvalue', 1);
    $self->{'show_refcount'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'show_refcount', 0);
    $self->{'show_memsize'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'show_memsize', 0);
    $self->{'memsize_unit'} = Data::Printer::Common::_fetch_anyof(
                                $props,
                                'memsize_unit',
                                'auto',
                                [qw(auto b k m)]
                            );
    $self->{'print_escapes'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'print_escapes', 0);
    $self->{'scalar_quotes'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'scalar_quotes', q("));
    $self->{'escape_chars'} = Data::Printer::Common::_fetch_anyof(
                            $props,
                            'escape_chars',
                            'none',
                            [qw(none nonascii nonlatin1 all)]
                        );
    $self->{'caller_info'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'caller_info', 0);
    $self->{'caller_message'} = Data::Printer::Common::_fetch_scalar_or_default(
                            $props,
                            'caller_message',
                            'Printing in line __LINE__ of __FILENAME__:'
                        );
    $self->{'string_max'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'string_max', 1024);
    $self->{'string_preserve'} = Data::Printer::Common::_fetch_anyof(
                             $props,
                             'string_preserve',
                             'begin',
                             [qw(begin end middle extremes none)]
                         );
    $self->{'string_overflow'} = Data::Printer::Common::_fetch_scalar_or_default(
                                $props,
                                'string_overflow',
                                '(...skipping __SKIPPED__ chars...)'
                            );
    $self->{'array_max'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'array_max', 50);
    $self->{'array_preserve'} = Data::Printer::Common::_fetch_anyof(
                             $props,
                             'array_preserve',
                             'begin',
                             [qw(begin end middle extremes none)]
                         );
    $self->{'array_overflow'} = Data::Printer::Common::_fetch_scalar_or_default(
                                $props,
                                'array_overflow',
                                '(...skipping __SKIPPED__ items...)'
                        );
    $self->{'hash_max'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'hash_max', 50);
    $self->{'hash_preserve'} = Data::Printer::Common::_fetch_anyof(
                             $props,
                             'hash_preserve',
                             'begin',
                             [qw(begin end middle extremes none)]
                       );
    $self->{'hash_overflow'} = Data::Printer::Common::_fetch_scalar_or_default(
                                $props,
                                'hash_overflow',
                                '(...skipping __SKIPPED__ keys...)'
                       );
    $self->{'ignore_keys'} = Data::Printer::Common::_fetch_arrayref_of_scalars($props, 'ignore_keys');
    $self->{'unicode_charnames'} = Data::Printer::Common::_fetch_scalar_or_default(
                               $props,
                               'unicode_charnames',
                               0
                           );
    $self->{'colored'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'colored', 'auto');
    $self->{'max_depth'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'max_depth', 0);
    $self->{'separator'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'separator', ',');
    $self->{'end_separator'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'end_separator', 0);
    $self->{'class_method'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'class_method', '_data_printer');
    $self->{'class'} = Data::Printer::Object::ClassOptions->new($props->{'class'});
    $self->{'hash_separator'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'hash_separator', '   ');
    $self->{'align_hash'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'align_hash', 1);
    $self->{'sort_keys'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'sort_keys', 1);
    $self->{'quote_keys'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'quote_keys', 'auto');
    $self->{'deparse'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'deparse', 0);
    $self->{'return_value'} = Data::Printer::Common::_fetch_anyof(
                             $props,
                             'return_value',
                             'pass',
                             [qw(pass dump void)]
                       );


    if (exists $props->{as}) {
        my $msg = Data::Printer::Common::_fetch_scalar_or_default($props, 'as', '');
        $self->{caller_info} = 1;
        $self->{caller_message} = $msg;
    }

    $self->multiline(
        Data::Printer::Common::_fetch_scalar_or_default($props, 'multiline', 1)
    );

    $self->_load_colors($props);
    $self->_load_filters($props);
    $self->output($props->{output} || 'stderr');

    return $self;
}

sub output {
    my ($self, $new_output) = @_;
    if (@_ > 1) {
        $self->_load_output_handle($new_output);
    }
    return $self->{output};
}

# output_handle() is handle only
sub output_handle { $_[0]->{output_handle} }

sub _load_output_handle {
    my ($self, $output) = @_;
    my %targets = ( stdout => *STDOUT, stderr => *STDERR );
    my $error;
    my $ref = ref $output;
    if (!$ref and exists $targets{ lc $output }) {
        $self->{output} = lc $output;
        $self->{output_handle} = $targets{ $self->{output} };
    }
    elsif ( ( $ref and $ref eq 'GLOB')
         or (!$ref and \$output =~ /GLOB\([^()]+\)$/)
    ) {
        $self->{output} = 'handle';
        $self->{output_handle} = $output;
    }
    elsif (!$ref or $ref eq 'SCALAR') {
        if (open my $fh, '>>', $output) {
            $self->{output} = 'file';
            $self->{output_handle} = $fh;
        }
        else {
            $error = "file '$output': $!";
        }
    }
    else {
        $error = 'unknown output data';
    }
    if ($error) {
        Data::Printer::Common::_warn("error opening custom output handle: $error");
        $self->{output_handle} = $targets{'stderr'}
    }
    return;
}

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self->_init(@_);
}

sub multiline {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{multiline} = !!$value;
        if ($value) {
            $self->{_linebreak} = "\n";
            $self->{_current_indent} = $self->{indent};
            $self->index( $self->{_original_index} )
                if exists $self->{_original_index};
        }
        else {
            $self->{_original_index} = $self->index;
            $self->{_linebreak} = ' ';
            $self->{_current_indent} = 0;
            $self->index(0);
        }
    }
    return $self->{multiline};
}

sub _load_filters {
    my ($self, $props) = @_;

    my @core_filters = qw(SCALAR ARRAY HASH REF VSTRING GLOB FORMAT Regexp CODE GenericClass);
    foreach my $class (@core_filters) {
        my $module = "Data::Printer::Filter::$class";
        my %from_module = %{$module->_filter_list};
        my %extras      = %{$module->_extra_options};

        foreach my $k (keys %from_module) {
            unshift @{ $self->{filters}{$k} }, @{ $from_module{$k} };
        }
    }
    return;
}


sub _detect_color_level {
    my ($self) = @_;
    my $colored = $self->colored;
    my $color_level;

    # first we honour ANSI_COLORS_DISABLED, colored and tty piping 
    if (   !$colored
        || ($colored eq 'auto' && exists $ENV{ANSI_COLORS_DISABLED})
#        || ! -t $self->{_output} # <-- FIXME TODO
    ) {
        $color_level = 0;
    }
    else {
        # NOTE: we could try `tput colors` but it may not give
        # the proper result, so instead we do what most terminals
        # currently do and rely on environment variables.
        if ($ENV{COLORTERM} && $ENV{COLORTERM} eq 'truecolor') {
            $color_level = 3;
        }
        elsif ($ENV{TERM_PROGRAM} && $ENV{TERM_PROGRAM} eq 'iTerm.app') {
            my $major_version = substr($ENV{TERM_PROGRAM_VERSION} || '0', 0, 1);
            $color_level = $major_version >= 3 ? 3 : 2;
        }
        elsif ($ENV{TERM_PROGRAM} && $ENV{TERM_PROGRAM} eq 'Apple_Terminal') {
            $color_level= 2;
        }
        elsif ($ENV{TERM} && $ENV{TERM} =~ /\-256(?:color)?\z/i) {
            $color_level = 2;
        }
        elsif ($ENV{TERM}
            && ($ENV{TERM} =~ /\A(?:screen|xterm|vt100|rxvt)/i
                || $ENV{TERM} =~ /color|ansi|cygwin|linux/i)
        ) {
            $color_level = 1;
        }
        elsif ($ENV{COLORTERM}) {
            $color_level = 1;
        }
        else {
            $color_level = $colored eq 'auto' ? 0 : 1;
        }
    }
    return $color_level;
}

sub color_level { $_[0]->{_output_color_level} }

sub _load_colors {
    my ($self, $props) = @_;

    $self->{_output_color_level} = $self->_detect_color_level;

    my $theme_object;
    my $default_theme = 'Material';
    my $theme_name    = Data::Printer::Common::_fetch_scalar_or_default($props, 'theme', $default_theme);
    $theme_object     = Data::Printer::Theme->new($theme_name, $props->{colors});
    if (!$theme_object) {
        if ($theme_name ne $default_theme) {
            $theme_object = Data::Printer::Theme->new($default_theme, $props->{colors});
        }
        Data::Printer::Common::_die("Unable to load default theme. This should never happen - please contact the author") unless $theme_object;
    }
    $self->{theme} = $theme_object;
}

sub _filters_for_type {
    my ($self, $type) = @_;
    return exists $self->{filters}{$type} ? @{ $self->{filters}{$type} } : ();
}

sub _filters_for_data {
    my ($self, $data) = @_;

    # we favour reftype() over ref() because you could have
    # a HASH.pm (or ARRAY.pm or whatever) blessing any variable.
    my $ref_kind = Scalar::Util::reftype($data);
    $ref_kind = 'SCALAR' unless $ref_kind;

    # globs don't play nice
    $ref_kind = 'GLOB' if "$ref_kind" =~ /GLOB\([^()]+\)$/;
    # Huh. ref() returns 'Regexp' but reftype() returns 'REGEXP'
    $ref_kind = 'Regexp' if $ref_kind eq 'REGEXP';

    my @potential_filters;

    # first, try class name + full inheritance for a specific name.
    # NOTE: blessed() is returning true for regexes.
    if ($ref_kind ne 'Regexp' and my $class = Scalar::Util::blessed($data)) {
        my $linear_ISA = Data::Printer::Common::_linear_ISA_for($class, $self);
        foreach my $candidate_class (@$linear_ISA) {
            push @potential_filters, $self->_filters_for_type($candidate_class);
        }
        # next, let any '-class' filters have a go:
        push @potential_filters, $self->_filters_for_type('-class');
    }

    # then, try regular data filters
    push @potential_filters, $self->_filters_for_type($ref_kind);

    # finally, if it's neither a class nor a known core type,
    # we must be in a future perl with some type we're unaware of:
    push @potential_filters, $self->_filters_for_type('-unknown');

    return @potential_filters;
}

# _see($data): marks data as seen if it was never seen it before.
# if we are showing refcounts, we return those. Initially we had
# this funcionallity separated, but refcounts increase as we find
# them again and because of that we were seeing weird refcounting.
# So now instead we store the refcount of the variable when we
# first saw it.
# Finally, if we have already seen the data, we return its stringified
# position, like "var", "var{foo}[7]", etc. UNLESS $options{seen_override}
# is set. Why seen_override? Sometimes we want to print the same data
# twice, like the GenericClass filter, which prints the object's metadata
# via parse() and then the internal structure via parse_as(). But if we
# simply do that, we'd get the "seen" version (because we have already
# visited it!) The refcount is still calculated only once though :)
sub _see {
    my ($self, $data, %options) = @_;
    return {} unless ref $data;

    my $id = Data::Printer::Common::_object_id($data);
    if (!exists $self->{_seen}{$id}) {
        $self->{_seen}{$id} = {
            name     => $self->current_name,
            refcount => ($self->show_refcount ? $self->_refcount($data) : 0),
        };
        return { refcount => $self->{_seen}{$id}->{refcount} };
    }
    return { refcount => $self->{_seen}{$id}->{refcount} } if $options{seen_override};
    return $self->{_seen}{$id};
}

sub _refcount {
    my ($self, $data) = @_;

    require B;
    my $count;
    my $rv = B::svref_2object(\$data)->RV;
    if (ref($data) eq 'REF' && ref($$data)) {
        $rv = B::svref_2object($data)->RV;
    }

    # some SV's are special (represented by B::SPECIAL)
    # and don't have a ->REFCNT (e.g. \undef)
    return 0 unless $rv->can( 'REFCNT' );

    # 3 is our magical number: so we return the actual reference count
    # minus the references we added as we were traversing:
    return $rv->REFCNT - $self->{_refcount_base};
}

sub parse_as {
    my ($self, $type, $data) = @_;
    return $self->parse($data, force_type => $type, seen_override => 1);
}

# parse() must always receive a reference, never a regular copy, because
# that's the only way we are able to figure whether the source data
# is a weak ref or not.
sub parse {
    my $self = shift;
    $self->{_position}++;

    my $str_weak = $self->_check_weak( $_[0] );

    my ($data, %options) = @_;
    my $parsed_string = '';

    # if we've seen this structure before, we return its location
    # instead of going through it again. This avoids infinite loops
    # when parsing circular references:
    my $seen = $self->_see($data, %options);
    if (my $name = $seen->{name}) {
        # on repeated references, the only extra data we put
        # is whether this reference is weak or not:
        $parsed_string .= $self->maybe_colorize($name, 'repeated');
        $parsed_string .= $str_weak;
        $self->{_position}--;
        return $parsed_string;
    }

    # Each filter type provides an array of potential parsers.
    # Once we find the right kind, we go through all of them,
    # from most precise match to most generic.
    # The first filter that returns a defined value "wins"
    # (even if it's an empty string)
    foreach my $filter (
        exists $options{force_type}
          ? $self->_filters_for_type($options{force_type})
          : $self->_filters_for_data($data)
    ) {
        if (defined (my $result = $filter->($data, $self))) {
            $parsed_string .= $result;
            last;
        }
    }

    $parsed_string .= $self->_check_readonly($data);
    $parsed_string .= $str_weak;

    $parsed_string .= $self->_check_memsize($data);
    if ($self->show_refcount && ref($data) ne 'SCALAR' && $seen->{refcount} > 1 ) {
        $parsed_string .= ' (refcount: ' . $seen->{refcount} .')';
    }

    $self->{_position}--;
    return $parsed_string;
}

sub _check_memsize {
    my ($self, $data) = @_;
    return '' unless $self->show_memsize
                  && (   $self->show_memsize eq 'all'
                      || $self->show_memsize >= $self->{_position});
    my $size;
    my $unit;
    my $error = Data::Printer::Common::_tryme(sub {
        require Devel::Size;
        $size = Devel::Size::total_size($data);
        $unit = uc $self->memsize_unit;
        if ($unit eq 'M' || ($unit eq 'AUTO' && $size > 1024*1024)) {
            $size = $size / (1024*1024);
            $unit = 'M';
        }
        elsif ($unit eq 'K' || ($unit eq 'AUTO' && $size > 1024)) {
            $size = $size / 1024;
            $unit = 'K';
        }
        else {
            $unit = 'B';
        }
    });
    if ($error) {
        if ($error =~ m{locate Devel/Size.pm}) {
            Data::Printer::Common::_warn("Devel::Size not found, show_memsize will be ignored")
                if $self->{_position} == 1;
        }
        else {
            Data::Printer::Common::_warn("error fetching memory usage: $error");
        }
        return '';
    }
    return '' unless $size;
    my $string = ' (' . ($size < 0 ? sprintf("%.2f", $size) : int($size)) . $unit . ')';
    return $self->maybe_colorize($string, 'memsize');
}

sub _check_weak {
    my ($self) = shift;
    return '' unless $self->show_weak;

    my $realtype = Scalar::Util::reftype($_[0]);
    my $isweak;
    if ($realtype && ($realtype eq 'REF' || $realtype eq 'SCALAR')) {
        $isweak = Scalar::Util::isweak($_[0] );
    }
    else {
        $isweak = Scalar::Util::isweak($_[0]);
    }
    return '' unless $isweak;
    return ' ' . $self->maybe_colorize('(weak)', 'weak');
}

sub write_label {
    my ($self) = @_;
    return '' unless $self->caller_info;
    my @caller = caller 2;

    my $message = $self->caller_message;

    $message =~ s/\b__PACKAGE__\b/$caller[0]/g;
    $message =~ s/\b__FILENAME__\b/$caller[1]/g;
    $message =~ s/\b__LINE__\b/$caller[2]/g;

    return $message . "\n";
}

sub maybe_colorize {
    my ($self, $output, $color_type, $end_color) = @_;

    if ($self->color_level) {
        $output = $self->theme->sgr_color_for($color_type)
             . $output
             . (defined $end_color
                 ? $self->theme->sgr_color_for($end_color)
                 : $self->theme->color_reset
             );
    }
    return $output;
}


sub _check_readonly {
    my ($self) = @_;
    return ' (read-only)' if $self->show_readonly && &Internals::SvREADONLY($_[1]);
    return '';
}

42;
__END__
