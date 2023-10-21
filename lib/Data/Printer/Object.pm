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
    sub show_wrapped       { $_[0]->{'show_wrapped'}       }
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
            'show_wrapped' => Data::Printer::Common::_fetch_scalar_or_default($params, 'show_wrapped', 1),
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
use Data::Printer::Filter::OBJECT;
use Data::Printer::Filter::GenericClass;

# create our basic accessors:
my @method_names =qw(
    name show_tainted show_unicode show_readonly show_lvalue show_refcount
    show_memsize memsize_unit print_escapes scalar_quotes escape_chars
    caller_info caller_message caller_message_newline caller_message_position
    string_max string_overflow string_preserve resolve_scalar_refs
    array_max array_overflow array_preserve hash_max hash_overflow
    hash_preserve unicode_charnames colored theme show_weak
    max_depth index separator end_separator class_method class hash_separator
    align_hash sort_keys quote_keys deparse return_value show_dualvar show_tied
    warnings arrows coderef_stub coderef_undefined
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
    $self->{'warnings'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'warning', 1);
    $self->{'indent'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'indent', 4);
    $self->{'index'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'index', 1);
    $self->{'name'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'name', 'var');
    $self->{'arrows'} = Data::Printer::Common::_fetch_anyof(
        $props,
        'arrows',
        'none',
        [qw(none first all)]
    );

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
    $self->{'caller_message_position'} = Data::Printer::Common::_fetch_anyof($props, 'caller_message_position', 'before', [qw(before after)]);
    $self->{'resolve_scalar_refs'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'resolve_scalar_refs', 0);
    $self->{'string_max'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'string_max', 4096);
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
    $self->{'array_max'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'array_max', 100);
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
    $self->{'hash_max'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'hash_max', 100);
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
    $self->{'coderef_stub'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'coderef_stub', 'sub { ... }');
    $self->{'coderef_undefined'} = Data::Printer::Common::_fetch_scalar_or_default($props, 'coderef_undefined', '<undefined coderef>');
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

    $self->output(defined $props->{output} ? $props->{output} : 'stderr');
    $self->_load_colors($props);
    $self->_load_filters($props);

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
        Data::Printer::Common::_warn($self, "error opening custom output handle: $error");
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
    my @core_filters = qw(SCALAR ARRAY HASH REF VSTRING GLOB FORMAT Regexp CODE OBJECT GenericClass);
    foreach my $class (@core_filters) {
        $self->_load_external_filter($class);
    }
    my @filters;
    # load any custom filters provided by the user
    if (exists $props->{filters}) {
        if (ref $props->{filters} eq 'HASH') {
            Data::Printer::Common::_warn(
                $self,
                'please update your code: filters => { ... } is now filters => [{ ... }]'
            );
            push @filters, $props->{filters};
        }
        elsif (ref $props->{filters} eq 'ARRAY') {
            @filters = @{ $props->{filters} };
        }
        else {
            Data::Printer::Common::_warn($self, 'filters must be an ARRAY reference');
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
                        $self,
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
                        $self,
                        'hash filters must point to a CODE reference'
                    );
                }
            }
        }
        else {
            Data::Printer::Common::_warn($self, 'filters must be a name or { type => sub {...} }');
        }
    }
    return;
}

sub _load_external_filter {
    my ($self, $class) = @_;
    my $module = "Data::Printer::Filter::$class";
    my $error = Data::Printer::Common::_tryme("use $module; 1;");
    if ($error) {
        Data::Printer::Common::_warn($self, "error loading filter '$class': $error");
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

    # first we honour ANSI_COLORS_DISABLED, colored and writing to files
    if (   !$colored
        || ($colored eq 'auto'
            && (exists $ENV{ANSI_COLORS_DISABLED}
                || $self->output eq 'handle'
                || $self->output eq 'file'
            )
        )
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

sub _load_colors {
    my ($self, $props) = @_;

    $self->{_output_color_level} = $self->_detect_color_level;

    my $theme_object;
    my $default_theme = 'Material';
    my $theme_name    = Data::Printer::Common::_fetch_scalar_or_default($props, 'theme', $default_theme);
    $theme_object = Data::Printer::Theme->new(
        name            => $theme_name,
        color_overrides => $props->{colors},
        color_level     => $self->{_output_color_level},
        ddp             => $self,
    );
    if (!$theme_object) {
        if ($theme_name ne $default_theme) {
            $theme_object = Data::Printer::Theme->new(
                name            => $default_theme,
                color_overrides => $props->{colors},
                color_level     => $self->{_output_color_level},
                ddp             => $self,
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

    # ref() returns 'Regexp' but reftype() returns 'REGEXP', so we picked one:
    $ref_kind = 'Regexp' if $ref_kind eq 'REGEXP';

    my @potential_filters;

    # first, try class name + full inheritance for a specific name.
    my $class = Scalar::Util::blessed($data);

    # a regular regexp is blessed, but in that case we want a
    # regexp filter, not a class filter.
    if (defined $class && $class eq 'Regexp') {
        if ($ref_kind eq 'Regexp' || ($] < 5.011 && $ref_kind eq 'SCALAR')) {
            $ref_kind = 'Regexp';
            undef $class;
        }
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

# _see($data): marks data as seen if it was never seen before.
# if we are showing refcounts, we return those. Initially we had
# this funcionallity separated, but refcounts increase as we find
# them again and because of that we were seeing weird refcounting.
# So now instead we store the refcount of the variable when we
# first see it.
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
    my $id = pack 'J', Scalar::Util::refaddr($data);
    if (!exists $self->{_seen}{$id}) {
        my $entry = {
            name     => $self->current_name,
            refcount => ($self->show_refcount ? $self->_refcount($data) : 0),
        };
        # the values returned by tied hashes are temporaries, so we can't
        # mark them as 'seen'. Ideally, we'd use something like
        # Hash::Util::Fieldhash::register() (see PR#179) and remove entries
        # from $self->{_seen} when $data is destroyed. The problem is this
        # adds a lot of internal magic to the data we're inspecting (we tried,
        # see Issue#75), effectively changing it. So we just ignore them, at
        # the risk of missing some circular reference.
        $self->{_seen}{$id} = $entry unless $options{tied_parent};
        return { refcount => $entry->{refcount} };
    }
    return { refcount => $self->{_seen}{$id}->{refcount} } if $options{seen_override};
    return $self->{_seen}{$id};
}

sub seen {
    my ($self, $data) = @_;
    my $id = pack 'J', Scalar::Util::refaddr($data);
    return exists $self->{_seen}{$id};
}

sub unsee {
    my ($self, $data) = @_;
    return unless ref $data && keys %{$self->{_seen}};

    my $id = pack 'J', Scalar::Util::refaddr($data);
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

    # FIXME: because of prototypes, p(@data) becomes a ref (that we don't care about)
    # to the data (that we do care about). So we should not show refcounts, memsize
    # or readonly status for something guaranteed to be ephemeral.
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
            Data::Printer::Common::_warn($self, "Devel::Size not found, show_memsize will be ignored")
                if $self->{_position} == 1;
        }
        else {
            Data::Printer::Common::_warn($self, "error fetching memory usage: $error");
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
        $isweak = Scalar::Util::isweak($_[0]);
    }
    else {
        $isweak = Scalar::Util::isweak($_[0]);
    }
    return '' unless $isweak;
    return ' ' . $self->maybe_colorize('(weak)', 'weak');
}

sub _write_label {
    my ($self) = @_;
    return '' unless $self->caller_info;
    my @caller = caller 1;

    my $message = $self->caller_message;

    $message =~ s/\b__PACKAGE__\b/$caller[0]/g;
    $message =~ s/\b__FILENAME__\b/$caller[1]/g;
    $message =~ s/\b__LINE__\b/$caller[2]/g;

    my $separator = $self->caller_message_newline ? "\n" : ' ';
    $message = $self->maybe_colorize($message, 'caller_info');
    $message = $self->caller_message_position eq 'before'
        ? $message . $separator
        : $separator . $message
        ;
    return $message;
}

sub maybe_colorize {
    my ($self, $output, $color_type, $default_color, $end_color) = @_;

    if ($self->{_output_color_level} && defined $color_type) {
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

Unless you're writing a plugin, or looking for some
L<< configuration property details|/Attributes >>
the documentation you want is probably on L<Data::Printer>. Seriously!


=head1 DESCRIPTION

This module implements the underlying object used by Data::Printer to parse,
format and print Perl data structures.

It is passed to plugins so they can rely on contextual information from the
caller like colors, spacing and other options.

=head1 COMMON PROPERTIES / ATTRIBUTES

=head2 Scalar Options

=head3 show_tainted

When set, will detect and let you know of any tainted data (default: 1)
Note that this is a no-op unless your script is in taint mode, meaning
it's running with different real and effective user/group IDs, or with the
-T flag. See L<perlsec> for extra information.

=head3 show_unicode

Whether to label data that has the L<unicode flag|perlunifaq> set. (default: 1)

=head3 show_dualvar

Perl can interpret strings as numbers and vice-versa, but that doesn't mean
it always gets it right. When this option is set to "lax", Data::Printer will
show both values if they differ. If set to "strict", it will always show both
values, and when set to "off" it will never show the second value. (default: lax)

=head3 show_lvalue

Lets you know whenever a value is an lvalue (default: 1)

=head3 string_max

The maximum number of characters to display in a string. If the string is
bigger than that, Data::Printer will trim a part of the string (set by
L<string_preserve|/string_preserve>) and replace it with the message set on
L<string_overflow|/string_overflow>. Set C<string_max> to 0 to show all
characters (default: 4096)

=head3 string_overflow

Message to display once L<string_max|/string_max> is reached. Defaults to
I<< "(...skipping __SKIPPED__ chars...)" >>.

=head3 string_preserve

When the string has more characters than L<string_max|/string_max>, this
option defines which part of the string to preserve. Can be set to 'begin',
'middle' or 'end'. (default: 'begin')

=head3 scalar_quotes

Which quotation character to use when printing strings (default: ")

=head3 escape_chars

Use this to escape certain characters from strings, which could be useful if
your terminal is in a different encoding than the data being printed. Can be
set to 'nonascii', 'nonlatin1', 'all' or 'none' (default: none).

=head3 unicode_charnames

whether to use the character's names when escaping unicode (e.g. SNOWMAN instead of \x{2603}) (default: 0)

=head3 print_escapes

Whether to print invisible characters in strings, like \b, \n and \t (default: 0)

=head3 resolve_scalar_refs

If a reference to a scalar value is found more than once, print the resolved
value. For example, you may have an object that you reuse to represent 'true'
or 'false'. If you have more than one of those in your data, Data::Printer
will by default print the second one as a circular reference. When this option
is set to true, it will instead resolve the scalar value and keep going. (default: false)

=head2 Array Options

=head3 array_max

The maximum number of array elements to show. If the array is bigger than
that, Data::Printer will trim the offending slice (set by
L<array_preserve|/array_preserve>) and replace it with the message set on
L<array_overflow|/array_overflow>. Set C<array_max> to 0 to show all elements
in the array, regardless of array size (default: 100)

=head3 array_overflow

Message to display once L<array_max|/array_max> is reached. Defaults to
C<< "(...skipping __SKIPPED__ items...)" >>.

=head3 array_preserve

When an array has more elements than L<array_max|/array_max>, this option
defines which part of the array to preserve. Can be set to 'begin', 'middle'
or 'end'. (default: 'begin')

=head3 index

When set, shows the index number before each array element. (default: 1)

=head2 Hash Options

=head3 align_hash

If this option is set, hash keys  will be vertically aligned by the length
of the longest key.

This is better explained with an example, so consider the hash
C<< my %h = ( a => 123, aaaaaa => 456 ) >>. This would be an unaligned output:

    a => 123,
    aaaaaa => 456

and this is what it looks like with C<< align_hash = 1 >>:

    a      => 123,
    aaaaaa => 456

(default: 1)

=head3 hash_max

The maximum number of hash key/value pairs to show. If the hash is bigger than
that, Data::Printer will trim the offending slice (set by
L<hash_preserve|/hash_preserve>) and replace it with the message set on
L<hash_overflow|/hash_overflow>. Set C<hash_max> to 0 to show all elements
in the hash, regardless of the total keys. (default: 100)

=head3 hash_overflow

Message to display once L<hash_max|/hash_max> is reached. Defaults to
C<< "(...skipping __SKIPPED__ keys...)" >>.

=head3 hash_preserve

When a hash has more elements than L<hash_max|/hash_max>, this option
defines which part of the hash to preserve. Can be set to 'begin', 'middle'
or 'end'. Note that Perl makes no promises regarding key order, so this
option only makes sense if keys are sorted. In other words, if
you have disabled L<sort_keys|/sort_keys>, expect random keys to be
shown regardless of which part was preserved. (default: 'begin')

=head3 hash_separator

What to use to separate keys from values. Default is '   ' (three spaces)

=head3 sort_keys

Whether to sort keys when printing the contents of a hash (default: 1)

=head3 quote_keys

Whether to quote hash keys or not. Can be set to 1 (always quote), 0
(never quote) or 'auto' to quote only when a key contains spaces or
linebreaks. (default: 'auto')


=head2 Caller Information

Data::Printer can add an informational message to every call to C<p()> or
C<np()> if you enable C<caller_info>. So for example if you write:

    my $var = "meep!";
    p $var, caller_info => 1;

this will output something like:

    Printing in line 2 of myapp.pl:
    "meep!"

The following options let you customize the message and how it is displayed.

=head3 caller_info

Set this option to a true value to display a L<message|/caller_message> next
to the data being printed. (default: 0)

=head3 caller_message

What message to print when L<caller_info|/caller_info> is true.

Defaults to
"C<< Printing in line __LINE__ of __FILENAME__ >>".

If the special strings C<__LINE__>, C<__FILENAME__> or C<__PACKAGE__> are
present in the message, they'll be interpolated into their according value
so you can customize the message at will:

    caller_message = "[__PACKAGE__:__LINE__]"

=head3 caller_message_newline

When true, skips a line when printing L<caller_message|/caller_message>.
When false, only a single space is added between the message and the data.
(default: 1)

=head3 caller_message_position

This option controls where the L<caller_message|/caller_message> will appear
in relation to the code being printed. Can be set to 'before' or 'after'. A
line is always skipped between the message and the data (either before or
after), unless you set L<caller_message_newline|/caller_message_newline> to 0.
(default: 'before')


=head2 General Options

=head3 arrows

Data::Printer shows circular references as a data path, indicating where in
the data that reference points to. You may use this option to control if/when
should it print reference arrows. Possible values are 'all' (e.g
C<< var->{x}->[y]->[z] >>), 'first' (C<< var->{x}[y][z] >>) or 'none'
(C<< var{x}[y][z] >>). Default is 'none'.

=head3 colored

Whether to colorize the output or not. Can be set to 1 (always colorize), 0
(never colorize) or 'auto'. Default is 'auto', meaning it will colorize only
when printing to STDOUT or STDERR, never to a file or to a variable. The 'auto'
setting also respects the C<ANSI_COLORS_DISABLED> environment variable.

=head3 deparse

If the data structure contains a subroutine reference (coderef), this option
can be set to deparse it and print the underlying code, which hopefully
resembles the original source code. (default: 0)

=head3 coderef_stub

If the data structure contains a subroutine reference (coderef) and the
'L<deparse|/deparse>' option above is set to false, Data::Printer will print this
instead. (default: 'C<< sub { ... } >>')

=head3 coderef_undefined

If the data structure contains a subroutine reference (coderef) that has
not actually been defined at the time of inspection, Data::Printer will
print this instead. Set it to '0' to disable this check, in which case
Data::Printer will use whatever value you set on
L<coderef_stub|/coderef_stub> above. (default: '<undefined coderef>').

=head3 end_separator

When set, the last item on an array or hash will always contain a
trailing L<separator|/separator>. (default: 0)

=head3 show_memsize

Set to true and Data::Printer will show the estimate memory size of the data
structure being printed. Requires Devel::Size. (default: 0)

=head3 memsize_unit

If L<show_memsize|/show_memsize> is on, this option lets you specify the
unit in which to show the memory size. Can be set to "b" to show size in
bytes, "k" for kilobytes, "m" for megabytes or "auto", which will use the
biggest unit that makes sense. (default: auto)

=head3 output

Where you want the output to be printed. Can be set to the following values:

=over 4

=item * C<'stderr'> - outputs to the standard error handle.

=item * C<'stdout'> - outputs to the standard output handle.

=item * reference to a scalar (e.g. C<\$string>) - outputs to the scalar reference.

=item * file handle - any open file handle:

    open my $fh, '>>', '/path/to/some/file.log' or die $!;
    p @{[ 1,2,3 ]}, output => $fh;

=item * file path - if you pass a non-empty string that is not 'stderr' nor 'stdout',
Data::Printer will consider it to be a file path and create/append to it automatically
for you. So you can do this in your C<.dataprinter>:

    output = /path/to/some/file.log

By default, Data::Printer will print to the standard error (stderr).

=back

=head3 max_depth

This setting controls how far inside the data structure we should go
(default: 0 for no depth limit)

=head3 return_value

Whether the user wants the return value to be a pass-through of the source
data ('pass'), the dump content itself ('dump') or nothing at all ('void').

Defaults to C<'pass'> since version 0.36. B<NOTE>: if you set it to 'dump',
make sure it's not the last statement of a subroutine or that, if it is, the
sub is only called in void context.

=head3 separator

The separator character(s) to use for arrays and hashes. The default is the
comma ",".

=head3 show_readonly

When this option is set, Data::Printer will let you know whenever a value is
read-only. (default: 1)

=head3 show_refcount

Whether to show data refcount it's above 1 (default: 0)

=head3 show_weak

When this option is set, Data::Printer will let you know whenever it finds a
weak reference (default: 1)

=head3 show_tied

When set to true, this option will let you know whenever a tied variable
is detected, including what is tied to it (default: 1)

=head3 theme

    theme = Monokai

This setting gets/sets the current color theme module. The default theme
is L<Material|Data::Printer::Theme::Material>. Data::Printer ships with
several themes for you to choose, and you can create your own theme or use
any other from CPAN.

=head3 warnings

If something goes wrong when parsing your data or printing it to the selected
output, Data::Printer by default shows you a warning from the standpoint of
the actual call to C<p()> or C<np()>. To silence those warnings, set this
option to 0.


=head2 Class / Object Options

=head3 class_method

When Data::Printer is printing an object, it first looks for a method
named "C<_data_printer>" and, if one is found, we call it instead of actually
parsing the structure.

This way, module authors can control how Data::Printer outputs their objects
the best possible way by simply adding a private method instead of having
to write a full filter or even adding Data::Printer as a dependency.

To disable this behavior, simply set this option to false or an empty string.
You can also change it to a different name and Data::Printer will look for
that instead.

=head3 class - class properties to override.

This "namespace" gets/sets all class properties that are used by the
L<standard class filter|Data::Printer::Filter::GenericClass> that ships
with Data::Printer. Note that, if you are using a specific filter for that
object, most (if not all) of the settings below will not apply.

In your C<.dataprinter> file, the defaults would look like this:

    class.parents            = 1
    class.linear_isa         = auto
    class.universal          = 0
    class.expand             = 1
    class.stringify          = 1
    class.show_reftype       = 0
    class.show_overloads     = 1
    class.show_methods       = all
    class.sort_methods       = 1
    class.inherited          = public
    class.format_inheritance = lines
    class.parent_filters     = 1
    class.internals          = 1

In code, you should use the "class" namespace as a key to a hash reference:

    use Data::Printer class => {
        parents            => 1,
        linear_isa         => 'auto',
        universal          => 0,
        expand             => 1,
        stringify          => 1,
        show_reftype       => 0,
        show_overloads     => 1,
        show_methods       => 'all',
        sort_methods       => 1,
        inherited          => 'public',
        format_inheritance => 'lines',
        parent_filters     => 1,
        internals          => 1,
    };

Or inline:

    p $some_object, class => { internals => 1,  ... };


=head4 parents

When set, shows all superclasses of the object being printed. (default: 1)

=head4 linear_isa

This setting controls whether to show the linearized @ISA, which is the
order of preference in which the object's methods and attributes are resolved
according to its inheritance. Can be set to 1 (always show), 0 (never show)
or 'auto', which shows only when the object has more than one superclass.
(default: 'auto')

=head4 universal

Set this option to 1 to include UNIVERSAL methods to the list of public
methods (like C<can> and C<isa>). (default: 0)

=head4 expand

Sets how many levels to descend when printing classes, in case their internals
point to other classes. Set this to 0 to never expand any objects, just show
their name. Set to any integer number and when Data::Printer reaches that
depth, only the class name will be printed. Set to 'all' to always expand
objects found inside your object. (default: 1)

=head4 stringify

When this option is set, Data::Printer will check if the object being printed
contains any methods named C<as_string>, C<to_string> or C<stringify>. If it
does, Data::Printer will use it as the object's output instead of the
generic class plugin. (default: 1)

=head4 show_reftype

If set to a true value, Data::Printer will show the internal reference type
of the object. (default: 0)

=head4 show_overloads

This option includes a list of all overloads implemented by the object.
(default: 1)

=head4 show_methods

Controls which of the object's direct methods to show. Can be set to 'none',
'all', 'private' or 'public'. When applicable (Moo, Moose) it will also
show attributes and roles. (default: 'all')

=head4 sort_methods

When listing methods, attributes and roles, this option will order them
alphabetically, rather than on whatever order the list of methods returned.
(default: 1)

=head4 inherited

Controls which of the object's parent methods to show. Can be set to 'none',
'all', 'private' or 'public'. (default: 'public')

=head4 format_inheritance

This option controls how to format the list of methods set by a parent class
(and not the class itself). Setting it to C<'lines'> it will print one line
for each parent, like so:

    public methods (5):
        foo, bar
        Parent::Class:
            baz, meep
        Other::Parent:
            moop


Setting it to C<'string'>, it will put all methods on the same line:

    public methods (5): foo, bar, baz (Parent::Class), meep (Parent::CLass), moop (Other::Parent)

Default is: 'lines'.


=head4 parent_filters

If there is no filter for the given object's class, there may still be a
filter for one of its parent classes. When this option is set, Data::Printer
will traverse the object's superclass and use the first filter it finds,
if one is present. (default: 1)

=head4 internals

Shows the object's internal data structure. (default: 1)


=head2 "Shortcuts"

Some options are so often used together we have created shortcuts for them.

=head3 as

    p $somevar, as => 'is this right?';

The "C<as>" shortcut activates L<caller_info|/caller_info> and sets
L<caller_message|/caller_message> to whatever you set it to. It's really
useful to quickly differentiate between sequential uses of C<p()>.

=head3 multiline

    p $somevar, multiline => 0;

When set to 0, disables array index and linebreaks, uses ':' as hash separator
and '(...)' as overflow for hashes, arrays and strings, and also disables
'caller_message_newline' so any caller message is shown on the same line as
the variable being printed. If this is set on a global configuration or on the
C<.dataprinter> file, Can be "undone" by setting it to "1".

=head3 fulldump

    p $somevar, fulldump => 1;

By default, Data::Printer limits the size of string/array/hash dumps to a
(hopefully) reasonable size. Still, sometimes you really need to see
everything. To completely disable such limits, just set this option to true.


=head2 Methods and Accessors for Filter Writers

The following attributes could be useful if you're writing your own custom
filters or maybe even a non-obvious profile. Otherwise, no need to worry about
any of them ;)

And make sure to check out the current filter list for real usage examples!

=head3 indent

=head3 outdent

=head3 newline

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

=head3 extra_config

Data::Printer will read and pass-through any unrecognized settings in either
your C<.dataprinter> file or your inline arguments inside this structure.
This is useful to create custom settings for your filters.

While any and all unknown settings will be readable here, we recommend you
prepend them with a namespace like C<filter_xxx> as those are reserved for
filters and thus guaranteed not to colide with any core Data::Printer
settings now or in the future.

For example, on the L<Web filter|Data::Printer::Filter::Web> we have the
C<expand_headers> option, and even though Data::Printer itself doesn't have
this option, we prepend everything with the C<filter_web> namespace, either
in the config file:

    filter_web.expand_headers = 1

or inline:

    p $http_response, filters => ['Web'], filter_web => { expand_headers => 1 };


=head3 maybe_colorize( $string, $label )

=head3 maybe_colorize( $string, $label, $default_color )

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

=head3 current_depth

Shows the current depth level, from 0 onwards.

=head3 current_name

Gets/sets the name for the current posistion, to be printed when the parser
visits that data again. E.g. C<var[0]{abc}[2]>.

=head3 parse( $data_ref )

=head3 parse( $data_ref, %options )

This method receives a reference to a data structure to parse, and returns the
parsed string. It will call each filter and colorize the output accordingly.

Use this inside filters whenever you want to use the result of a parsed data
strucure.

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
when you want to print the same data structure twice, like when you're doing
a second pass on a blessed object to print its internals, or if you're using
the same object over and over again. This setting overrides the internal
counter and prints the same data again. Check L<unsee|/unsee( $data )> below
for another way to achieve this.

=back

=head3 parse_as( $type, $data_ref )

This is a convenience method to force some data to be interpreted as a
particular type. It is the same as:

    $ddp->parse( $data, force_type => $type, seen_override => 1 );

=head2 unsee( $data )

Sometimes you are writing a filter for data that you know will be repeated
several times, like JSON Boolean objects. To prevent Data::Printer from
showing this content as repeated, you can use the C<unsee> method to make
the current object forget about having ever visited this data.


=head1 OBJECT CONSTRUCTION

You'll most like never need this unless you're planning on extending
Data::Printer itself.

=head2 new( %options )

Creates a new Data::Printer::Object instance. It may (optionally) receive a
hash or hash reference with custom settings for any of its properties.


=head1 SEE ALSO

L<Data::Printer>
