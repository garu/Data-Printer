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
    sub parent_filters     { $_[0]->{'parent_filters'}     }
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
                $params, 'inherited', 'public', [qw(none all private public)]
            ),
            'format_inheritance' => Data::Printer::Common::_fetch_anyof(
                $params, 'format_inheritance', 'lines', [qw(string lines)]
            ),
            'parent_filters' => Data::Printer::Common::_fetch_scalar_or_default($params, 'parent_filters', 1),
            'universal'    => Data::Printer::Common::_fetch_scalar_or_default($params, 'universal', 0),
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
my @method_names =qw(
    name show_tainted show_unicode show_readonly show_lvalue show_refcount
    show_memsize memsize_unit print_escapes scalar_quotes escape_chars
    caller_info caller_message caller_message_newline string_max
    string_overflow string_preserve resolve_scalar_refs
    array_max array_overflow array_preserve hash_max hash_overflow
    hash_preserve ignore_keys unicode_charnames colored theme show_weak
    max_depth index separator end_separator class_method class hash_separator
    align_hash sort_keys quote_keys deparse return_value show_dualvar show_tied
);
foreach my $method_name (@method_names) {
    no strict 'refs';
    *{__PACKAGE__ . "::$method_name"} = sub {
        $_[0]->{$method_name} = $_[1] if @_ > 1;
        return $_[0]->{$method_name};
    }
}
sub extra_config { $_[0]->{extra_config} }

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
    $self->{'show_tied'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'show_tied', 1);
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
    $self->{'caller_message_newline'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'caller_message_newline', 1);
    $self->{'resolve_scalar_refs'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'resolve_scalar_refs', 0);
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
    $self->{'show_dualvar'} = Data::Printer::Common::_fetch_anyof(
        $props,
        'show_dualvar',
        'lax',
        [qw(lax strict off)]
    );

    if (exists $props->{as}) {
        my $msg = Data::Printer::Common::_fetch_scalar_or_default($props, 'as', '');
        $self->{caller_info} = 1;
        $self->{caller_message} = $msg;
    }

    $self->multiline(
        Data::Printer::Common::_fetch_scalar_or_default($props, 'multiline', 1)
    );

    $self->fulldump(
        Data::Printer::Common::_fetch_scalar_or_default($props, 'fulldump', 0)
    );

    $self->_load_colors($props);
    $self->_load_filters($props);
    $self->output($props->{output} || 'stderr');

    my %extra_config;
    my %core_options = map { $_ => 1 }
        (@method_names, qw(as multiline output colors filters));
    foreach my $key (keys %$props) {
        $extra_config{$key} = $props->{$key} unless exists $core_options{$key};
    }
    $self->{extra_config} = \%extra_config;

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
            $self->hash_separator( $self->{_original_separator} )
                if exists $self->{_original_separator};
            $self->array_overflow( $self->{_original_array_overflow} )
                if exists $self->{_original_array_overflow};
            $self->hash_overflow( $self->{_original_hash_overflow} )
                if exists $self->{_original_hash_overflow};
            $self->string_overflow( $self->{_original_string_overflow} )
                if exists $self->{_original_string_overflow};
        }
        else {
            $self->{_original_index} = $self->index;
            $self->index(0);
            $self->{_original_separator} = $self->hash_separator;
            $self->hash_separator(':');
            $self->{_original_array_overflow} = $self->array_overflow;
            $self->array_overflow('(...)');
            $self->{_original_hash_overflow} = $self->hash_overflow;
            $self->hash_overflow('(...)');
            $self->{_original_string_overflow} = $self->string_overflow;
            $self->string_overflow('(...)');
            $self->{_linebreak} = ' ';
            $self->{_current_indent} = 0;
        }
    }
    return $self->{multiline};
}

sub fulldump {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->{fulldump} = !!$value;
        if ($value) {
            $self->{_original_string_max} = $self->string_max;
            $self->string_max(0);
            $self->{_original_array_max} = $self->array_max;
            $self->array_max(0);
            $self->{_original_hash_max} = $self->hash_max;
            $self->hash_max(0);
        }
        else {
            $self->string_max($self->{_original_string_max})
                if exists $self->{_original_string_max};
            $self->array_max($self->{_original_array_max})
                if exists $self->{_original_array_max};
            $self->hash_max($self->{_original_hash_max})
                if exists $self->{_original_hash_max};
        }
    }
}

sub _load_filters {
    my ($self, $props) = @_;

    # load our core filters (LVALUE is under the 'SCALAR' filter module)
    my @core_filters = qw(SCALAR ARRAY HASH REF VSTRING GLOB FORMAT Regexp CODE GenericClass);
    foreach my $class (@core_filters) {
        $self->_load_external_filter($class);
    }
    my @filters;
    # load any custom filters provided by the user
    if (exists $props->{filters}) {
        if (ref $props->{filters} eq 'HASH') {
            Data::Printer::Common::_warn(
                'please update your code: filters => { ... } is now filters => [{ ... }]'
            );
            push @filters, $props->{filters};
        }
        elsif (ref $props->{filters} eq 'ARRAY') {
            @filters = @{ $props->{filters} };
        }
        else {
            Data::Printer::Common::_warn('filters must be an ARRAY reference');
        }
    }
    foreach my $filter (@filters) {
        my $filter_reftype = Scalar::Util::reftype($filter);
        if (!defined $filter_reftype) {
            $self->_load_external_filter($filter);
        }
        elsif ($filter_reftype eq 'HASH') {
            foreach my $k (keys %$filter) {
                if ($k eq '-external') {
                    Data::Printer::Common::_warn(
                        'please update your code: '
                      . 'filters => { -external => [qw(Foo Bar)}'
                      . ' is now filters => [qw(Foo Bar)]'
                    );
                    next;
                }
                if (Scalar::Util::reftype($filter->{$k}) eq 'CODE') {
                    my $type = Data::Printer::Common::_filter_category_for($k);
                    unshift @{ $self->{$type}{$k} }, $filter->{$k};
                }
                else {
                    Data::Printer::Common::_warn(
                        'hash filters must point to a CODE reference'
                    );
                }
            }
        }
        else {
            Data::Printer::Common::_warn('filters must be a name or { type => sub {...} }');
        }
    }
    return;
}

sub _load_external_filter {
    my ($self, $class) = @_;
    my $module = "Data::Printer::Filter::$class";
    my $error = Data::Printer::Common::_tryme("use $module; 1;");
    if ($error) {
        Data::Printer::Common::_warn("error loading filter '$class': $error");
        return;
    }
    my $from_module = $module->_filter_list;
    foreach my $kind (keys %$from_module) {
        foreach my $name (keys %{$from_module->{$kind}}) {
            unshift @{ $self->{$kind}{$name} }, @{ $from_module->{$kind}{$name} };
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
    $theme_object = Data::Printer::Theme->new(
        name            => $theme_name,
        color_overrides => $props->{colors},
        color_level     => $self->color_level,
    );
    if (!$theme_object) {
        if ($theme_name ne $default_theme) {
            $theme_object = Data::Printer::Theme->new(
                name            => $default_theme,
                color_overrides => $props->{colors},
                color_level     => $self->color_level,
            );
        }
        Data::Printer::Common::_die("Unable to load default theme. This should never happen - please contact the author") unless $theme_object;
    }
    $self->{theme} = $theme_object;
}

sub _filters_for_type {
    my ($self, $type) = @_;
    return exists $self->{type_filters}{$type} ? @{ $self->{type_filters}{$type} } : ();
}

sub _filters_for_class {
    my ($self, $type) = @_;
    return exists $self->{class_filters}{$type} ? @{ $self->{class_filters}{$type} } : ();
}

sub _filters_for_data {
    my ($self, $data) = @_;

    # we favour reftype() over ref() because you could have
    # a HASH.pm (or ARRAY.pm or whatever) blessing any variable.
    my $ref_kind = Scalar::Util::reftype($data);
    $ref_kind = 'SCALAR' unless $ref_kind;

    # Huh. ref() returns 'Regexp' but reftype() returns 'REGEXP'
    $ref_kind = 'Regexp' if $ref_kind eq 'REGEXP';

    my @potential_filters;

    # first, try class name + full inheritance for a specific name.
    # NOTE: blessed() is returning true for regexes.
    my $class = $ref_kind eq 'Regexp' ? () : Scalar::Util::blessed($data);
    # before 5.11 regexes are blessed SCALARs:
    if ($] < 5.011 && $ref_kind eq 'SCALAR' && defined $class && $class eq 'Regexp') {
        $ref_kind = 'Regexp';
        undef $class;
    }
    if (defined $class) {
        if ($self->class->parent_filters) {
            my $linear_ISA = Data::Printer::Common::_linear_ISA_for($class, $self);
            foreach my $candidate_class (@$linear_ISA) {
                push @potential_filters, $self->_filters_for_class($candidate_class);
            }
        }
        else {
            push @potential_filters, $self->_filters_for_class($class);
        }
        # next, let any '-class' filters have a go:
        push @potential_filters, $self->_filters_for_class('-class');
    }

    # then, try regular data filters
    push @potential_filters, $self->_filters_for_type($ref_kind);

    # finally, if it's neither a class nor a known core type,
    # we must be in a future perl with some type we're unaware of:
    push @potential_filters, $self->_filters_for_class('-unknown');

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

sub unsee {
    my ($self, $data) = @_;
    return unless ref $data && keys %{$self->{_seen}};

    my $id = Data::Printer::Common::_object_id($data);
    delete $self->{_seen}{$id};
    return;
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
    my $str_weak = $self->_check_weak( $_[0] );

    my ($data, %options) = @_;
    my $parsed_string = '';

    # if we've seen this structure before, we return its location
    # instead of going through it again. This avoids infinite loops
    # when parsing circular references:
    my $seen = $self->_see($data, %options);
    if (my $name = $seen->{name}) {
        $parsed_string .= $self->maybe_colorize(
            ((ref $data eq 'SCALAR' && $self->resolve_scalar_refs)
                ? $$data
                : $name
            ),
            'repeated'
        );
        # on repeated references, the only extra data we put
        # is whether this reference is weak or not.
        $parsed_string .= $str_weak;
        return $parsed_string;
    }
    $self->{_position}++;

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
    $parsed_string .= $str_weak if ref($data) ne 'REF';

    $parsed_string .= $self->_check_memsize($data);
    if ($self->show_refcount && ref($data) ne 'SCALAR' && $seen->{refcount} > 1 ) {
        $parsed_string .= ' (refcount: ' . $seen->{refcount} .')';
    }

    if (--$self->{'_position'} == 0) {
        $self->{'_seen'} = {};
        $self->{'_refcount_base'} = 3;
        $self->{'_position'} = 0;
    }

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

    return $message . ($self->caller_message_newline ? "\n" : '');
}

sub maybe_colorize {
    my ($self, $output, $color_type, $default_color, $end_color) = @_;

    if ($self->color_level && defined $color_type) {
        my $theme = $self->theme;
        my $sgr_color = $theme->sgr_color_for($color_type);
        if (!defined $sgr_color && defined $default_color) {
            $sgr_color = $theme->_parse_color($default_color);
        }
        if ($sgr_color) {
            $output = $sgr_color
                . $output
                . (defined $end_color
                    ? $theme->sgr_color_for($end_color)
                    : $theme->color_reset
                );
        }
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

=head1 NAME

Data::Printer::Object - underlying object for Data::Printer

=head1 SYNOPSIS

Unless you're writing a plugin, you're probably looking for L<Data::Printer>.
Seriously!

    use Data::Printer::Object;

    my $ddp = Data::Printer::Object->new(
        colorized     => 1,
        show_refcount => 0,
        ...
    );

    my $data = 123;

    say $ddp->parse( \$data );


=head1 DESCRIPTION

This module implements the underlying object used by Data::Printer to parse,
format and print Perl data structures.

It is passed to plugins so they can rely on contextual information from the
caller like colors, spacing and other options.

=head1 INSTANTIATION

=head2 new( %options )

Creates a new Data::Printer::Object instance. It may (optionally) receive a
hash or hash reference with custom settings for any of its properties.

=head1 PARSING

=head2 parse( $data_ref )

=head2 parse( $data_ref, %options )

This method receives a reference to a data structure to parse, and returns the
parsed string. It will call each filter and colorize the output accordingly.

Use this inside filters whenever you want to use the result of a parsed data
strucure.

    my $ddp = Data::Printer::Object->new;

    my $output = $ddp->parse( [3,2,1] );

An optional set of parameters may be passed:

=over 4

=item * C<< force_type => $type >> - forces data to be treated as that type,
where $type is the name of the Perl data strucuture as returned by
Scalar::Util::reftype (e.g. 'HASH', 'ARRAY' etc). This is used when a filter
wants to show the internals of blessed data. Otherwise parse would just call
the same filter over and over again.

=item * C<< seen_override => 1 >> - Data::Printer::Object tries to remember
if it has already seen a data structure before, so it can show the circular
reference instead of entenring an infinite loop. However, there are cases
when you wanto to print the same data structure twice, like when you're doing
a second pass on a blessed object to print its internals, or if you're using
the same object over and over again. This setting overrides the internal
counter and prints the same data again. Check L<unsee|/unsee( $data )> below
for another way to achieve this.

=back

=head2 parse_as( $type, $data_ref )

This is a convenience method to force some data to be interpreted as a
particular type. It is the same as:

    $ddp->parse( $data, force_type => $type, seen_override => 1 );

=head2 indent

=head2 outdent

=head2 newline

These methods are used to control the indentation level of the string being
created to represent your data. While C<indent> and C<outdent> respectively
increase and decrease the indentation level, C<newline> will add a linebreak
and position the "cursor" where you are expected to continue your dump string:

    my $output = $ddp->newline . 'this is a new line';
    $ddp->indent;
    $output .= $ddp->newline . 'this is indented';
    $ddp->outdent;
    $output .= $ddp->newline . 'back to our previous indentation!';

Unless multiline was set to 0, the code above should print something like:

    this is a new line
        this is indented
    back to our previous indentation

=head2 maybe_colorize( $string, $label )

=head2 maybe_colorize( $string, $label, $default_color )

    my $output = $ddp->maybe_colorize( 12.3, 'number');

Instead of simply adding raw content to your dump string, you should wrap it
with this method, as it will look up colors on the current theme and print
them (or not, depending on whether the terminal supports color or the user
has explicitly turned them off).

If you are writing a custom filter and don't want to use the core labels to
colorize your content, you may want to set your own label and pass a default
color. For example:

    my $output = $ddp->maybe_colorize( $data, 'filter_myclass', '#ffccb3' );

In the code above, if the user has C<colors.filter_myclass> set either on the
C<.dataprinter> file or the runtime hashref, that one will be used. Otherwise,
Data::Printer will use C<'#ffccb3'>.

=head2 unsee( $data )

Sometimes you are writing a filter for data that you know will be repeated
several times, like JSON Boolean objects. To prevent Data::Printer from
showing this content as repeated, you can use the C<unsee> method to make
the current object forget about having ever visited this data.

=head1 OTHER METHODS / PROPERTIES

Most of them are described in L<Data::Printer>.

=over 4

=item * align_hash - vertically align hash keys (default: 1)

=item * array_max - maximum array elements to show. Set to 0 to show all (default: 50)

=item * array_overflow - message to display once array_max is reached

=item * array_preserve - which part of the array to preserve after array_max (default: 'begin')

=item * caller_info - whether the user wants to prepend dump with caller information or not (default: 0)

=item * caller_message - what to print when caller_info is true.

=item * caller_message_newline - skip line after printing caller_message (default: 1)

=item * class - class properties to override.

=item * class_method - function name to look for custom dump of external classes (default: '_dataprinter')

=item * color_level - what the current color level is. Used by themes to approximate (or disable) colors.

=item * colored - whether to colorize the output or not (default: 'auto')

=item * current_depth - shows the current depth level.

=item * current_name - gets/sets the name for the current posistion, to be printed when the parser visits that data again. E.g. C<var[0]{abc}[2]>.

=item * deparse - whether the user wants to see deparsed content or not (default: 0)

=item * end_separator - should we print the trailing comma? (default: 0)

=item * escape_chars - which characters to escape when parsing strings ('nonascii', 'nonlatin1', 'all' or 'none' (the default))

=item * extra_config - all given options that were not recognized by Data::Printer::Object are kept here. Useful to create custom options in filters. See L<Data::Printer::Filter>.

=item * hash_max - maximum hash pairs to show. Set to 0 to show all (default: 50)

=item * hash_overflow - message to display once hash_max is reached

=item * hash_preserve - which part of the (sorted) hash to preserve after hash_max (default: 'begin')

=item * hash_separator - what to use to separate keys from values (default: '   ')

=item * ignore_keys - arrayref of keys to ignore (default: [])

=item * index - whether to show array index numbers or not (default: 1)

=item * max_depth - how far inside the data strucuture should we go (default: 0 for infinite)

=item * memsize_unit - show memory size as bytes (b), kbytes (k) or megabytes (m). Default is 'auto'

=item * multiline - defaults to 1. When set to 0, disables array index and linebreaks, uses ':' as hash separator and '(...)' as overflow for hashes, arrays and strings.

=item * fulldump - set to 1 to disable string_max, array_max and hash_max at the same time.

=item * output - where the user wants the output to be printed. Defaults to 'stderr', could be 'stdout', \$string or $filehandle.

=item * output_handle - stores the proper handle for the given output so you can print to it.

=item * print_escapes - whether to print invisible characters in strings, like \b, \n and \t (default: 0)

=item * quote_keys - whether to quote hash keys or not (default: 'auto')

=item * return_value - whether the user wants the return value to be a pass-through of the source data ('pass'), the dump content itself ('dump') or nothing at all ('void'). Defaults to 'pass'.

=item * scalar_quotes - which quotation character to use when printing strings (default: ")

=item * separator - what separator character to use for arrays/hashes (default: ,)

=item * show_dualvar - whether to label dual-variables (default: 1)

=item * show_lvalue - whether to label lvalues (default: 1)

=item * show_memsize - whether to show memory size of data structure. Requires Devel::Size (default: 0)

=item * show_readonly - whether to label readonly data (default: 1)

=item * show_refcount - whether to show data refcount it's above 1 (default: 0)

=item * show_tainted - whether to label tainted data (default: 1)

=item * show_unicode - whether to label data with the unicode flag set (default: 1)

=item * show_weak - whether to label weak references (default: 1)

=item * show_tied - whether to label tied variables (default: 1)

=item * sort_keys - whether to sort hash keys (default: 1)

=item * string_max - maximum number of characters in a string. Set to 0 to show all (default: 1024)

=item * string_overflow - message to display once string_max is reached

=item * string_preserve - which part of the string to preserve after string_max (default: 'begin')

=item * theme - points to the current theme object

=item * unicode_charnames - whether to use the character's names when escaping unicode (e.g. SNOWMAN instead of \x{2603}) (default: 0)

=item * write_label - returns the proper label string, as parsed from caller_message.

=back

=head1 SEE ALSO

L<Data::Printer>
