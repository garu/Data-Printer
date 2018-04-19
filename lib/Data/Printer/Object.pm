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
            'linear_isa' => Data::Printer::Common::_fetch_scalar_or_default($params, 'linear_isa', 'auto'),
            'show_reftype' => Data::Printer::Common::_fetch_scalar_or_default($params, 'show_reftype', 0),
            'show_overloads' => Data::Printer::Common::_fetch_scalar_or_default($params, 'show_overloads', 1),
            'stringify' => Data::Printer::Common::_fetch_scalar_or_default($params, 'stringify', 1),
            'expand' => Data::Printer::Common::_fetch_scalar_or_default($params, 'expand', 1),
            'show_methods' => Data::Printer::Common::_fetch_anyof(
                $params, 'show_methods', 'all', [qw(none all private public)]
            ),
            'inherited' => Data::Printer::Common::_fetch_anyof(
                $params, 'inherited', 'none', [qw(none all private public)]
            ),
            'format_inheritance' => Data::Printer::Common::_fetch_anyof(
                $params, 'format_inheritance', 'string', [qw(string lines)]
            ),
            'universal' => Data::Printer::Common::_fetch_scalar_or_default($params, 'universal', 1),
            'sort_methods' => Data::Printer::Common::_fetch_scalar_or_default($params, 'sort_methods', 1),
            'internals' => Data::Printer::Common::_fetch_scalar_or_default($params, 'internals', 1),
            'parents' => Data::Printer::Common::_fetch_scalar_or_default($params, 'parents', 1),
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

my $_has_devel_refcount;

sub name               { $_[0]->{'name'}               }
sub show_tainted       { $_[0]->{'show_tainted'}       }
sub show_unicode       { $_[0]->{'show_unicode'}       }
sub show_readonly      { $_[0]->{'show_readonly'}      }
sub show_lvalue        { $_[0]->{'show_lvalue'}        }
sub show_refcount      { $_[0]->{'show_refcount'}      }
sub show_memsize       { $_[0]->{'show_memsize'}       }
sub memsize_unit       { $_[0]->{'memsize_unit'}       }
sub print_escapes      { $_[0]->{'print_escapes'}      }
sub scalar_quotes      { $_[0]->{'scalar_quotes'}      }
sub escape_chars       { $_[0]->{'escape_chars'}       }
sub caller_info        { $_[0]->{'caller_info'}        }
sub caller_message     { $_[0]->{'caller_message'}     }
sub string_max         { $_[0]->{'string_max'}         }
sub string_overflow    { $_[0]->{'string_overflow'}    }
sub string_preserve    { $_[0]->{'string_preserve'}    }
sub array_max          { $_[0]->{'array_max'}          }
sub array_overflow     { $_[0]->{'array_overflow'}     }
sub array_preserve     { $_[0]->{'array_preserve'}     }
sub hash_max           { $_[0]->{'hash_max'}           }
sub hash_overflow      { $_[0]->{'hash_overflow'}      }
sub hash_preserve      { $_[0]->{'hash_preserve'}      }
sub ignore_keys        { $_[0]->{'ignore_keys'}        }
sub unicode_charnames  { $_[0]->{'unicode_charnames'}  }
sub colored            { $_[0]->{'colored'}            }
sub theme              { $_[0]->{'theme'}              }
sub show_weak          { $_[0]->{'show_weak'}          }
sub max_depth          { $_[0]->{'max_depth'}          }
sub index              { $_[0]->{'index'}              }
sub separator          { $_[0]->{'separator'}          }
sub end_separator      { $_[0]->{'end_separator'}      }
sub current_depth      { $_[0]->{'_depth'}             }
sub class_method       { $_[0]->{'class_method'}       }
sub class              { $_[0]->{'class'}              }
sub hash_separator     { $_[0]->{'hash_separator'}     }
sub multiline          { $_[0]->{'multiline'}          }
sub align_hash         { $_[0]->{'align_hash'}         }
sub sort_keys          { $_[0]->{'sort_keys'}          }
sub quote_keys         { $_[0]->{'quote_keys'}         }
sub deparse            { $_[0]->{'deparse'}            }

sub indent  { $_[0]->{_depth}++ }
sub outdent { $_[0]->{_depth}-- }
sub newline {
    my ($self) = @_;
    return $self->{_linebreak}
         . (' ' x ($self->{_depth} * $self->{indent}))
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

sub new {
    my $class = shift;
    my $props = { @_ == 1 ? %{$_[0]} : @_ };

    my $self = {
        '_linebreak'    => "\n",
        '_depth'         => 0,
        '_array_padding' => 0,
        '_seen'          => {},
        'indent'        => Data::Printer::Common::_fetch_scalar_or_default($props, 'indent', 4),
        'index'        => Data::Printer::Common::_fetch_scalar_or_default($props, 'index', 1),
        'name'           => Data::Printer::Common::_fetch_scalar_or_default($props, 'name', 'var'),
        'show_tainted'   => Data::Printer::Common::_fetch_scalar_or_default($props, 'show_tainted', 1),
        'show_weak'      => Data::Printer::Common::_fetch_scalar_or_default($props, 'show_weak', 1),
        'show_unicode'   => Data::Printer::Common::_fetch_scalar_or_default($props, 'show_unicode', 0),
        'show_readonly'  => Data::Printer::Common::_fetch_scalar_or_default($props, 'show_readonly', 0),
        'show_lvalue'    => Data::Printer::Common::_fetch_scalar_or_default($props, 'show_lvalue', 1),
        'show_refcount'    => Data::Printer::Common::_fetch_scalar_or_default($props, 'show_refcount', 0),
        'show_memsize'    => Data::Printer::Common::_fetch_scalar_or_default($props, 'show_memsize', 0),
        'memsize_unit'   => Data::Printer::Common::_fetch_anyof(
                                $props,
                                'memsize_unit',
                                'auto',
                                [qw(auto b k m)]
                            ),
        'print_escapes'  => Data::Printer::Common::_fetch_scalar_or_default($props, 'print_escapes', 0),
        'scalar_quotes'  => Data::Printer::Common::_fetch_scalar_or_default($props, 'scalar_quotes', q(")),
        'escape_chars'   => Data::Printer::Common::_fetch_anyof(
                                $props,
                                'escape_chars',
                                'none',
                                [qw(none nonascii nonlatin1 all)]
                            ),
        'caller_info'    => Data::Printer::Common::_fetch_scalar_or_default($props, 'caller_info', 0),
        'caller_message' => Data::Printer::Common::_fetch_scalar_or_default(
                                $props,
                                'caller_message',
                                'Printing in line __LINE__ of __FILENAME__:'
                            ),
        'string_max'      => Data::Printer::Common::_fetch_scalar_or_default($props, 'string_max', 0),
        'string_preserve' => Data::Printer::Common::_fetch_anyof(
                                 $props,
                                 'string_preserve',
                                 'begin',
                                 [qw(begin end middle extremes none)]
                             ),
        'string_overflow' => Data::Printer::Common::_fetch_scalar_or_default(
                                    $props,
                                    'string_overflow',
                                    '(...skipping __SKIPPED__ chars...)'
                                ),
        'array_max'      => Data::Printer::Common::_fetch_scalar_or_default($props, 'array_max', 0),
        'array_preserve' => Data::Printer::Common::_fetch_anyof(
                                 $props,
                                 'array_preserve',
                                 'begin',
                                 [qw(begin end middle extremes none)]
                             ),
        'array_overflow' => Data::Printer::Common::_fetch_scalar_or_default(
                                    $props,
                                    'array_overflow',
                                    '(...skipping __SKIPPED__ items...)'
                            ),
        'hash_max'      => Data::Printer::Common::_fetch_scalar_or_default($props, 'hash_max', 0),
        'hash_preserve' => Data::Printer::Common::_fetch_anyof(
                                 $props,
                                 'hash_preserve',
                                 'begin',
                                 [qw(begin end middle extremes none)]
                           ),
        'hash_overflow' => Data::Printer::Common::_fetch_scalar_or_default(
                                    $props,
                                    'hash_overflow',
                                    '(...skipping __SKIPPED__ keys...)'
                           ),
        'ignore_keys' => Data::Printer::Common::_fetch_arrayref_of_scalars($props, 'ignore_keys'),
        'unicode_charnames' => Data::Printer::Common::_fetch_scalar_or_default(
                                   $props,
                                   'unicode_charnames',
                                   0
                               ),
        'colored' => Data::Printer::Common::_fetch_scalar_or_default($props, 'colored', 'auto'),
        'max_depth' => Data::Printer::Common::_fetch_scalar_or_default($props, 'max_depth', 0),
        'separator' => Data::Printer::Common::_fetch_scalar_or_default($props, 'separator', ','),
        'end_separator' => Data::Printer::Common::_fetch_scalar_or_default($props, 'end_separator', 0),
        'class_method' => Data::Printer::Common::_fetch_scalar_or_default($props, 'class_method', '_data_printer'),
        'class' => Data::Printer::Object::ClassOptions->new($props->{'class'}),
        'hash_separator' => Data::Printer::Common::_fetch_scalar_or_default($props, 'hash_separator', '   '),
        'multiline' => Data::Printer::Common::_fetch_scalar_or_default($props, 'multiline', 1),
        'align_hash' => Data::Printer::Common::_fetch_scalar_or_default($props, 'align_hash', 1),
        'sort_keys' => Data::Printer::Common::_fetch_scalar_or_default($props, 'sort_keys', 1),
        'quote_keys' => Data::Printer::Common::_fetch_scalar_or_default($props, 'quote_keys', 'auto'),
        'deparse' => Data::Printer::Common::_fetch_scalar_or_default($props, 'deparse', 0),
    };

    if (exists $props->{as}) {
        my $msg = Data::Printer::Common::_fetch_scalar_or_default($props, 'as', '');
        $self->{caller_info} = 1;
        $self->{caller_message} = $msg;
    }

    bless $self, $class;

    $self->_load_colors($props);
    $self->_load_filters($props);

    return $self;
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

sub merge_properties {
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

# _see($data): if data was never seen before, we "see" it but return undef.
# otherwise, we return its stringified position ("var", "var{foo}[7]", etc)
# unless $options{seen_override} is passed. Why seen_override? Sometimes we
# want to print the same data twice, like the GenericClass filter, which
# prints the object's metadata via parse() and then the internal structure
# via parse_as(). But if we simply do that, we'd get the "seen" version
# (because we have already visited it!)
sub _see {
    my ($self, $data, %options) = @_;
    return {} unless ref $data;

    my $id = Data::Printer::Common::_object_id($data);
    if (!exists $self->{_seen}{$id}) {
        $self->{_seen}{$id} = { name => $self->current_name, refcount => _ez_refcnt($data) };
        return { refcount => $self->{_seen}{$id}->{refcount} };
    }
    return { refcount => $self->{_seen}{$id}->{refcount} } if $options{seen_override};
    return $self->{_seen}{$id};
}

sub _ez_refcnt {
    my ( $data ) = @_;
    
    #use B qw(SVf_ROK);
    require B;
    
    # some SV's are special (represented by B::SPECIAL)
    # and don't have a ->REFCNT (e.g. \undef)
    my $count;


    # my $count = B::svref_2object(\$data)->RV->REFCNT;
    # #warn "--- $data";
    # if ( ref($data) eq 'REF' && ref($$data)) {
    #     $count = B::svref_2object($data)->RV->REFCNT;
    # }

    my $rv = B::svref_2object(\$data)->RV;
    if ( ref($data) eq 'REF' && ref($$data)) {
        $rv = B::svref_2object($data)->RV;
    }

    #return 0 if $rv->isa('B::SPECIAL');
    return 0 unless $rv->can( 'REFCNT' );
    return $rv->REFCNT - 3;
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

    #warn "$str_weak ---\n";

    my ($data, %options) = @_;
    #my $refcount = $self->_check_refcount($data);
    # make sure we don't influence refcount
#    Scalar::Util::weaken($data) if ref $data;

    #warn "--  $data";

    # $options{force_type} = 'SCALAR'
    #     unless ref $data && !exists $options{force_type};

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
        #$parsed_string .= "XXX";
        # if ($self->show_refcount) {
        #     $parsed_string .=  $self->_check_refcount($data);
        # }

        #my $after = $self->_check_refcount($data);
        return $parsed_string;# . "(had refcount of $refcount, after: $after)";
    }


    #warn "\nrefcount Before for " . $self->current_name . ": $refcount";
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
        # $self->_check_refcount($data, $options{extra_ref});
    }


#warn $parsed_string;
#use Devel::Peek; Dump( $data );
 

    return $parsed_string;
    # FIXME: write_label should be public and not part of
    # parse(), which should do only 1 thing: parse.
    # return $self->_write_label . $parsed_string;
    # $self->{_seen} = {}; # cleanup auxiliary data after full parse.
    # ^^^ also only once per run
}

sub _check_refcount {
    my ($self, $data, $extra_ref) = @_;
return;
    return '' unless ref $data;

    if (!defined $_has_devel_refcount) {
        my $error = Data::Printer::Common::_tryme(sub {
            require Devel::Refcount; 1;
        });
        $_has_devel_refcount = $error ? 0 : 1;
    }

    my $count;

        use B qw(SVf_ROK);
        # some SV's are special (represented by B::SPECIAL)
        # and don't have a ->REFCNT (e.g. \undef)
        #eval 
        {
#            $count = B::svref_2object(
#                \$data
                #(ref $data eq 'REF' || ref $data eq 'SCALAR') ? $$data : $data
#            )->RV->REFCNT
            
#     warn "EXTRA $extra_ref . ". ref($data). " -> ". eval { ref($$data) } . "\n";
# warn "="x10;
# use Devel::Peek; Dump $data;
        my $rv;

            if ( $extra_ref && $extra_ref == 1 && ref($data) && ref($$data)) {
                $rv = B::svref_2object($data)->RV;
                $count = $rv->REFCNT;
                ##warn "EXTRA $extra_ref . ". ref($data). " -> ". eval { ref($$data) } . " --- REFCNT $count\n";
                #use Devel::Peek; Dump $data;
                #$count += 3 if ref $$data ne 'REF';

            } else {
                $rv = B::svref_2object(\$data)->RV;    
                $count = $rv->REFCNT;    
            }
            
            # if ( ref $data ne 'REF' && ($rv->FLAGS & SVf_ROK) == SVf_ROK) {
                
            #     $count = $rv->RV->REFCNT + 3;
            # }
            # else {
            #     $count = $rv->REFCNT;
            # }
            # .... 3 


        } ;

    # refcount is always 2 more than what the users have on their code,
    # because refcounting increases as we reference it in our own subs:
#    warn $self->current_name . ' is refcount ' . $count . "\n";
    #use Carp;
    #warn Carp::confess;
    return '' unless $count && $count > 4;
    return $self->maybe_colorize(" (refcount: " . ($count - 3) . ")", 'refcount');
}


sub _check_memsize {
    my ($self, $data) = @_;
    return '' unless $self->show_memsize
                  && (   $self->show_memsize eq 'all'
                      || $self->show_memsize > $self->current_depth);
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
                if $self->current_depth == 0;
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

sub _write_label {
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

    if ($self->{_output_color_level}) {
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
    my ($self, $var) = @_;
    return ' (read-only)' if $self->show_readonly && &Internals::SvREADONLY(\$var);
    return '';
}



42;
__END__
