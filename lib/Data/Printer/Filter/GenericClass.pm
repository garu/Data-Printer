package Data::Printer::Filter::GenericClass;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;
use Scalar::Util;

filter '-class' => sub {
    my ($object, $ddp) = @_;

    # if the class implements its own Data::Printer method, we use it!
    if ($ddp->class_method and my $method = $object->can( $ddp->class_method )) {
        return $method->($object, $ddp) if ref $method eq 'CODE';
    }

    my $class_name = ref $object;

    # there are many parts of the class filter that require the object's
    # linear ISA, so we declare it earlier and load it only once:
    my $linear_ISA = Data::Printer::Common::_linear_ISA_for($class_name, $ddp);

    # if the object overloads stringification, use it!
    if ($ddp->class->stringify) {
        my $str = _get_stringification($object, $class_name);
        return $ddp->maybe_colorize("$str ($class_name)", 'class')
            if defined $str;
    }

    # otherwise, do our generic object representation:
    my $show_reftype = $ddp->class->show_reftype;
    my $show_internals = $ddp->class->internals;
    my $reftype;
    $reftype = Scalar::Util::reftype($object) if $show_reftype || $show_internals;

    $ddp->{_class_depth}++;
    my $string = $ddp->maybe_colorize( $class_name, 'class' );

    if ($show_reftype) {
        $string .= ' '
                . $ddp->maybe_colorize('(', 'brackets')
                . $ddp->maybe_colorize( $reftype, 'class' )
                . $ddp->maybe_colorize(')', 'brackets');
    }

    if ($ddp->class->expand eq 'all' || $ddp->class->expand >= $ddp->{_class_depth}) {
        $ddp->indent;
        $string .= '  ' . $ddp->maybe_colorize('{', 'brackets');

        my @superclasses = Data::Printer::Common::_get_superclasses_for($class_name);
        if (@superclasses && $ddp->class->parents) {
            $string .= $ddp->newline . 'Parents       '
                    . join(', ', map $ddp->maybe_colorize($_, 'class'), @superclasses)
                    ;
        }

        my $show_linear_isa = $ddp->class->linear_isa && (
             ($ddp->class->linear_isa eq 'auto' and @superclasses > 1)
          or ($ddp->class->linear_isa ne 'auto')
        );
        my $show_methods = $ddp->class->show_methods && $ddp->class->show_methods ne 'none';

        if ($show_linear_isa && @$linear_ISA) {
            $string .= $ddp->newline . 'Linear @ISA   '
                    . join(', ' => map $ddp->maybe_colorize($_, 'class'), @$linear_ISA)
                    ;
        }

        if ($show_methods) {
            $string .= _show_methods($class_name, $linear_ISA, $ddp);
        }

        if ($ddp->class->show_overloads) {
            my @overloads = _get_overloads($object);
            if (@overloads) {
                $string .= $ddp->newline . 'overloads: ' . join(', ' => @overloads);
            }
        }

        if ($show_internals) {
            $string .= $ddp->newline
                    . 'internals: '
                    . $ddp->parse_as($reftype, $object)
                    ;
        }

        $ddp->outdent;
        $string .= $ddp->newline . $ddp->maybe_colorize('}', 'brackets');
    }
    $ddp->{_class_depth}--;

    if ($ddp->show_tied and my $tie = ref tied $object) {
        $string .= " (tied to $tie)";
    }
    return $string;
};

#######################################
### Private auxiliary helpers below ###
#######################################

sub _get_stringification {
    my ($object, $class_name) = @_;
    require overload;
    if (overload::Overloaded($object)
        && (overload::Method($object, q(""))
            || overload::Method($object, q(0+))
        )
    ) {
        my $string;
        my $error = Data::Printer::Common::_tryme(sub { $string = '' . $object });
        if ($error) {
            Data::Printer::Common::_warn(
                "string/number overload error for object $class_name: $error"
            );
        }
        else {
            return $string;
        }
    }
    foreach my $method (qw(as_string stringify to_string)) {
        if ($object->can($method)) {
            my $string;
            my $error = Data::Printer::Common::_tryme(sub { $string = $object->$method });
            if ($error) {
                Data::Printer::Common::_warn(
                    "error stringifying object $class_name with $method\(\): $error"
                );
            }
            else {
                return $string;
            }
        }
    }
    return;
}

# returns array of all overloads in class;
sub _get_overloads {
    my ($object) = @_;
    require overload;
    return () unless overload::Overloaded($object);
    return sort grep overload::Method($object, $_),
           map split(/\s+/), values %overload::ops;
}

sub _show_methods {
    my ($class_name, $linear_ISA, $ddp) = @_;

    my %methods = ( public => {}, private => {} );
    my @all_methods = map _methods_of(
        $_, Data::Printer::Common::_get_namespace($_)
    ), @$linear_ISA;
    my $show_methods   = $ddp->class->show_methods;
    my $show_inherited = $ddp->class->inherited;
    my %seen_method_name;
    foreach my $method (@all_methods) {
        my ($package_string, $method_string) = @$method;
        next if $seen_method_name{$method_string}++;
        next if $method_string eq '__ANON__'; # anonymous subs don't matter here.
        my $type = substr($method_string, 0, 1) eq '_' ? 'private' : 'public';
        if ($package_string eq $class_name) {
            next unless $show_methods eq 'all' || $show_methods eq $type;
            $methods{$type}{$method_string} = undef;
        }
        else {
            next unless $show_inherited eq 'all' || $show_inherited eq $type;
            $methods{$type}{$method_string} = $package_string;
        }
    }
    my $string = '';
    foreach my $type (qw(public private)) {
        next unless $show_methods   eq 'all' or $show_methods   eq $type
                 or $show_inherited eq 'all' or $show_inherited eq $type
        ;
        if ($ddp->class->format_inheritance eq 'string') {
            my @method_list = keys %{$methods{$type}};
            @method_list = Data::Printer::Common::_nsort(@method_list)
                if $ddp->class->sort_methods && @method_list;

            $string .= $ddp->newline . "$type methods (" . scalar(@method_list) . ')';
            if (@method_list) {
                $string .= ': '
                    . join(', ' => map {
                        $ddp->maybe_colorize(
                            $_ . (defined $methods{$type}{$_} ? " ($methods{$type}{$_})" : ''),
                            'method'
                        )
                      } @method_list)
                    ;
            }
        }
        else { # 'lines'
            # first we convert our hash to { pkg => [ @methods ] }
            my %lined_methods;
            my @base_methods;
            my $total_methods = 0;
            foreach my $method (keys %{$methods{$type}}) {
                my $pkg_name = $methods{$type}{$method};
                if (defined $pkg_name) {
                    push @{ $lined_methods{$pkg_name} }, $method;
                }
                else {
                    push @base_methods, $method;
                }
                $total_methods++;
            }

            # then we print them, starting with our own methods:
            @base_methods = Data::Printer::Common::_nsort(@base_methods)
                if $ddp->class->sort_methods && @base_methods;

            $string .= $ddp->newline . "$type methods ($total_methods)"
                    . ($total_methods ? ':' : '')
                    ;
            if (@base_methods) {
                my $base_string = join(', ' => map {
                    $ddp->maybe_colorize($_, 'method')
                } @base_methods);
                $ddp->indent;
                # newline only if we have parent methods to show:
                $string .= (keys %lined_methods ? $ddp->newline : ' ') . $base_string;
                $ddp->outdent;
            }
            foreach my $pkg (@$linear_ISA) {
                next unless exists $lined_methods{$pkg};
                $ddp->indent;
                $string .= $ddp->newline . "$pkg:";
                @{$lined_methods{$pkg}} = Data::Printer::Common::_nsort(@{$lined_methods{$pkg}})
                    if $ddp->class->sort_methods;
                $ddp->indent;
                $string .= $ddp->newline . join(', ' => map {
                    $ddp->maybe_colorize($_, 'method')
                  } @{$lined_methods{$pkg}}
                );
                $ddp->outdent;
                $ddp->outdent;
            }
        }
    }

    return $string;
}

sub _methods_of {
    require B;
    my ($class_name, $namespace) = @_;
    my @methods;
    foreach my $subref (_get_all_subs_from($class_name, $namespace)) {
        next unless $subref;
        my $m = B::svref_2object($subref);
        next unless $m && $m->isa('B::CV');
        my $gv = $m->GV;
        next unless $gv && !$gv->isa('B::Special') && $gv->NAME;
        push @methods, [ $gv->STASH->NAME, $gv->NAME ];
    }
    return @methods;
}

sub _get_all_subs_from {
    my ($class_name, $namespace) = @_;
    my @subs;
    foreach my $key (keys %$namespace) {
        # perlsub says any sub starting with '(' is reserved for overload,
        # so we skip those:
        next if substr($key, 0, 1) eq '(';
        if (
            # any non-typeglob in the symbol table is a constant or stub
            ref(\$namespace->{$key}) ne 'GLOB'
            # regular subs are stored in the CODE slot of the typeglob
            || defined(*{$namespace->{$key}}{CODE})
        ) {
            push @subs, $key;
        }
    }
    my @symbols;
    foreach my $sub (@subs) {
        push @symbols, Data::Printer::Common::_get_symbol($class_name, $namespace, $sub, 'CODE');
    }
    return @symbols;
}

1;
