package Data::Printer::Common;
# Private library of shared Data::Printer code.
use strict;
use warnings;
use Scalar::Util;

my $mro_initialized = 0;
my $nsort_initialized;


sub _filter_category_for {
    my ($name) = @_;
    my %core_types = map { $_ => 1 }
        qw(SCALAR LVALUE ARRAY HASH REF VSTRING GLOB FORMAT Regexp CODE OBJECT);
    return exists $core_types{$name} ? 'type_filters' : 'class_filters';
}

# strings are tough to process: there are control characters like "\t",
# unicode characters to name or escape (or do nothing), max_string to
# worry about, and every single piece of that could have its own color.
# That, and hash keys and strings share this. So we put it all in one place.
sub _process_string {
    my ($ddp, $string, $src_color) = @_;

    # colorizing messes with reduce_string because we are effectively
    # adding new (invisible) characters to the string. So we need to
    # handle reduction first. But! Because we colorize string_max
    # *and* we should escape any colors already present, we need to
    # do both at the same time.
    $string = _reduce_string($ddp, $string, $src_color);

    # now we escape all other control characters except for "\e", which was
    # already escaped in _reduce_string(), and convert any chosen charset
    # to the \x{} format. These could go in any particular order:
    $string = _escape_chars($ddp, $string, $src_color);
    $string = _print_escapes($ddp, $string, $src_color);

    # finally, send our wrapped string:
    return $ddp->maybe_colorize($string, $src_color);
}

sub _colorstrip {
    my ($string) = @_;
    $string =~ s{ \e\[ [\d;]* m }{}xmsg;
    return $string;
}

sub _reduce_string {
    my ($ddp, $string, $src_color) = @_;
    my $max = $ddp->string_max;
    my $str_len = length($string);
    if ($max && $str_len && $str_len > $max) {
        my $preserve = $ddp->string_preserve;
        my $skipped_chars = $str_len - ($preserve eq 'none' ? 0 : $max);
        my $skip_message = $ddp->maybe_colorize(
            $ddp->string_overflow,
            'caller_info',
            undef,
            $src_color
        );
        $skip_message =~ s/__SKIPPED__/$skipped_chars/g;
        if ($preserve eq 'end') {
            substr $string, 0, $skipped_chars, '';
            $string =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', undef, $src_color)}ge
                if $ddp->print_escapes;
            $string = $skip_message . $string;
        }
        elsif ($preserve eq 'begin') {
            $string = substr($string, 0, $max);
            $string =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', undef, $src_color)}ge
                if $ddp->print_escapes;
            $string = $string . $skip_message;
        }
        elsif ($preserve eq 'extremes') {
            my $leftside_chars = int($max / 2);
            my $rightside_chars = $max - $leftside_chars;
            my $leftside = substr($string, 0, $leftside_chars);
            my $rightside = substr($string, -$rightside_chars);
            if ($ddp->print_escapes) {
                $leftside  =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', undef, $src_color)}ge;
                $rightside =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', undef, $src_color)}ge;
            }
            $string = $leftside . $skip_message . $rightside;
        }
        elsif ($preserve eq 'middle') {
            my $string_middle = int($str_len / 2);
            my $middle_substr = int($max / 2);
            my $substr_begin  = $string_middle - $middle_substr;
            my $message_begin = $ddp->string_overflow;
            $message_begin =~ s/__SKIPPED__/$substr_begin/gs;
            my $chars_left = $str_len - ($substr_begin + $max);
            my $message_end = $ddp->string_overflow;
            $message_end =~ s/__SKIPPED__/$chars_left/gs;
            $string = substr($string, $substr_begin, $max);
            $string =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', undef, $src_color)}ge
                if $ddp->print_escapes;
            $string = $ddp->maybe_colorize($message_begin, 'caller_info', undef, $src_color)
                    . $string
                    . $ddp->maybe_colorize($message_end, 'caller_info', undef, $src_color)
                    ;
        }
        else {
            # preserving 'none' only shows the skipped message:
            $string = $skip_message;
        }
    }
    else {
        # nothing to do? ok, then escape any colors already present:
        $string =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', undef, $src_color)}ge
            if $ddp->print_escapes;
    }
    return $string;
}


# _escape_chars() replaces characters with their "escaped" versions.
# Because it may be called on scalars or (scalar) hash keys and they
# have different colors, we need to be aware of that.
sub _escape_chars {
    my ($ddp, $scalar, $src_color) = @_;

    my $escape_kind = $ddp->escape_chars;
    my %target_for = (
        nonascii  => '[^\x{00}-\x{7f}]+',
        nonlatin1 => '[^\x{00}-\x{ff}]+',
    );

    if ($ddp->unicode_charnames) {
        require charnames;
        if ($escape_kind eq 'all') {
            $scalar = join('', map { sprintf '\N{%s}', charnames::viacode(ord $_) } split //, $scalar);
            $scalar = $ddp->maybe_colorize($scalar, 'escaped');
        }
        else {
            $scalar =~ s{($target_for{$escape_kind})}{$ddp->maybe_colorize( (join '', map { sprintf '\N{%s}', charnames::viacode(ord $_) } split //, $1), 'escaped', undef, $src_color)}ge if exists $target_for{$escape_kind};
        }
    }
    elsif ($escape_kind eq 'all') {
        $scalar = join('', map { sprintf '\x{%02x}', ord $_ } split //, $scalar);
        $scalar = $ddp->maybe_colorize($scalar, 'escaped');
    }
    else {
        $scalar =~ s{($target_for{$escape_kind})}{$ddp->maybe_colorize((join '', map { sprintf '\x{%02x}', ord $_ } split //, $1), 'escaped', undef, $src_color)}ge if exists $target_for{$escape_kind};
    }
    return $scalar;
}

# _print_escapes() prints invisible chars if they exist on a string.
# Because it may be called on scalars or (scalar) hash keys and they
# have different colors, we need to be aware of that. Also, \e is
# deliberately omitted because it was escaped from the original
# string earlier, and the \e's we have now are our own colorized
# output.
sub _print_escapes {
    my ($ddp, $string, $src_color) = @_;

    # always escape the null character
    $string =~ s/\0/$ddp->maybe_colorize('\\0', 'escaped', undef, $src_color)/ge;

    return $string unless $ddp->print_escapes;

    my %escaped = (
        "\n" => '\n',  # line feed
        "\r" => '\r',  # carriage return
        "\t" => '\t',  # horizontal tab
        "\f" => '\f',  # formfeed
        "\b" => '\b',  # backspace
        "\a" => '\a',  # alert (bell)
    );
    foreach my $k ( keys %escaped ) {
        $string =~ s/$k/$ddp->maybe_colorize($escaped{$k}, 'escaped', undef, $src_color)/ge;
    }
    return $string;
}

sub _initialize_nsort {
    return 'Sort::Key::Natural'  if $INC{'Sort/Key/Natural.pm'};
    return 'Sort::Naturally'     if $INC{'Sort/Naturally.pm'};
    return 'Sort::Key::Natural'  if !_tryme('use Sort::Key::Natural; 1;');
    return 'Sort::Naturally'     if !_tryme('use Sort::Naturally; 1;');
    return 'core';
}

sub _nsort {
    if (!$nsort_initialized) {
        my $nsort_class = _initialize_nsort();
        if ($nsort_class eq 'Sort::Key::Natural') {
            $nsort_initialized = \&{ $nsort_class . '::natsort' };
        }
        elsif ($nsort_class ne 'core') {
            $nsort_initialized = \&{ $nsort_class . '::nsort' };
        }
        else {
            $nsort_initialized = \&_nsort_pp
        }
    }
    return $nsort_initialized->(@_);
}

# this is a very simple 'natural-ish' sorter, heavily inspired in
# http://www.perlmonks.org/?node_id=657130 by thundergnat and tye
sub _nsort_pp {
    my $i;
    my @unsorted = map lc, @_;
    foreach my $data (@unsorted) {
        no warnings 'uninitialized';
        $data =~ s/((\.0*)?)(\d+)/("\x0" x length $2) . (pack 'aNa*', 0, length $3, $3)/eg;
        $data .= ' ' . $i++;
    }
    return @_[ map { (split)[-1] } sort @unsorted ];
}

sub _fetch_arrayref_of_scalars {
    my ($props, $name) = @_;
    return [] unless exists $props->{$name} && ref $props->{$name} eq 'ARRAY';
    my @valid;
    foreach my $option (@{$props->{$name}}) {
        if (ref $option) {
            # FIXME: because there is no object at this point, we need to check
            # the 'warnings' option ourselves.
            _warn(undef, "'$name' option requires scalar values only. Ignoring $option.")
                if !exists $props->{warnings} || !$props->{warnings};
            next;
        }
        push @valid, $option;
    }
    return \@valid;
}

sub _fetch_anyof {
    my ($props, $name, $default, $list) = @_;
    return $default unless exists $props->{$name};
    foreach my $option (@$list) {
        return $option if $props->{$name} eq $option;
    }
    _die(
        "invalid value '$props->{$name}' for option '$name'"
      . "(must be one of: " . join(',', @$list) . ")"
    );
};


sub _fetch_scalar_or_default {
    my ($props, $name, $default) = @_;
    return $default unless exists $props->{$name};

    if (my $ref = ref $props->{$name}) {
        _die("'$name' property must be a scalar, not a reference to $ref");
    }
    return $props->{$name};
}

sub _die {
    my ($message) = @_;
    my ($file, $line) = _get_proper_caller();
    die '[Data::Printer] ' . $message . " at $file line $line.\n";
}

sub _warn {
    my ($ddp, $message) = @_;
    return if $ddp && !$ddp->warnings;
    my ($file, $line) = _get_proper_caller();
    warn '[Data::Printer] ' . $message . " at $file line $line.\n";
}

sub _get_proper_caller {
    my $frame = 1;
    while (my @caller = caller($frame++)) {
        if ($caller[0] !~ /\AD(?:DP|ata::Printer)/) {
            return ($caller[1], $caller[2]);
        }
    }
    return ('n/d', 'n/d');
}


# simple eval++ adapted from Try::Tiny.
# returns a (true) error message if failed.
sub _tryme {
    my ($subref_or_string) = @_;

    my $previous_error = $@;
    my ($failed, $error);

    if (ref $subref_or_string eq 'CODE') {
        $failed = not eval {
            local $SIG{'__DIE__'}; # make sure we don't trigger any exception hooks.
            $@ = $previous_error;
            $subref_or_string->();
            return 1;
        };
        $error = $@;
    }
    else {
        my $code = q(local $SIG{'__DIE__'};) . $subref_or_string;
        $failed = not eval $code;
        $error = $@;
    }
    $@ = $previous_error;
    # at this point $failed contains a true value if the eval died,
    # even if some destructor overwrote $@ as the eval was unwinding.
    return unless $failed;
    return ($error || '(unknown error)');
}


# When printing array elements or hash keys, we may traverse all of it
# or just a few chunks. This function returns those chunks' indexes, and
# a scalar ref to a message whenever a chunk was skipped.
sub _fetch_indexes_for {
    my ($array_ref, $prefix, $ddp) = @_;

    my $max_function      = $prefix . '_max';
    my $preserve_function = $prefix . '_preserve';
    my $overflow_function = $prefix . '_overflow';
    my $max      = $ddp->$max_function;
    my $preserve = $ddp->$preserve_function;

    return (0 .. $#{$array_ref}) if !$max || @$array_ref <= $max;

    my $skip_message = $ddp->maybe_colorize($ddp->$overflow_function, 'overflow');
    if ($preserve eq 'begin' || $preserve eq 'end') {
        my $n_elements = @$array_ref - $max;
        $skip_message =~ s/__SKIPPED__/$n_elements/g;
        return $preserve eq 'begin'
            ? ((0 .. ($max - 1)), \$skip_message)
            : (\$skip_message, ($n_elements .. $#{$array_ref}))
            ;
    }
    elsif ($preserve eq 'extremes') {
        my $half_max = int($max / 2);
        my $last_index_of_chunk_one = $half_max - 1;
        my $n_elements = @$array_ref - $max;

        my $first_index_of_chunk_two = @$array_ref - ($max - $half_max);
        $skip_message =~ s/__SKIPPED__/$n_elements/g;
        return (
            (0 .. $last_index_of_chunk_one),
            \$skip_message,
            ($first_index_of_chunk_two .. $#{$array_ref})
        );
    }
    elsif ($preserve eq 'middle') {
        my $array_middle = int($#{$array_ref} / 2);
        my $first_index_to_show = $array_middle - int($max / 2);
        my $last_index_to_show = $first_index_to_show + $max - 1;
        my ($message_begin, $message_end) = ($skip_message, $skip_message);
        $message_begin =~ s/__SKIPPED__/$first_index_to_show/gse;
        my $items_left = $#{$array_ref} - $last_index_to_show;
        $message_end =~ s/__SKIPPED__/$items_left/gs;
        return (
            \$message_begin,
            $first_index_to_show .. $last_index_to_show,
            \$message_end
        );
    }
    else { # $preserve eq 'none'
        my $n_elements = scalar(@$array_ref);
        $skip_message =~ s/__SKIPPED__/$n_elements/g;
        return (\$skip_message);
    }
}

# helpers below strongly inspired by the excellent Package::Stash:
sub _linear_ISA_for {
    my ($class, $ddp) = @_;
    _initialize_mro($ddp) unless $mro_initialized;
    my $isa;
    if ($mro_initialized > 0) {
        $isa = mro::get_linear_isa($class);
    }
    else {
        # minimal fallback in case Class::MRO isn't available
        # (should only matter for perl < 5.009_005):
        $isa = [ $class, _get_superclasses_for($class) ];
    }
    return [@$isa, ($ddp->class->universal ? 'UNIVERSAL' : ())];
}

sub _initialize_mro {
    my ($ddp) = @_;
    my $error = _tryme(sub {
        if ($] < 5.009_005) { require MRO::Compat }
        else { require mro }
        1;
    });
    if ($error && index($error, 'in @INC') != -1 && $mro_initialized == 0) {
        _warn(
            $ddp,
            ($] < 5.009_005 ? 'MRO::Compat' : 'mro') . ' not found in @INC.'
          . ' Objects may display inaccurate/incomplete ISA and method list'
        );
    }
    $mro_initialized = $error ? -1 : 1;
}

sub _get_namespace {
    my ($class_name) = @_;
    my $namespace;
    {
        no strict 'refs';
        $namespace = \%{ $class_name . '::' }
    }
    # before 5.10, stashes don't ever seem to drop to a refcount of zero,
    # so weakening them isn't helpful
    Scalar::Util::weaken($namespace) if $] >= 5.010;

    return $namespace;
}

sub _get_superclasses_for {
    my ($class_name) = @_;
    my $namespace = _get_namespace($class_name);
    my $res = _get_symbol($class_name, $namespace, 'ISA', 'ARRAY');
    return @{ $res || [] };
}

sub _get_symbol {
    my ($class_name, $namespace, $symbol_name, $symbol_kind) = @_;

    if (exists $namespace->{$symbol_name}) {
        my $entry_ref = \$namespace->{$symbol_name};
        if (ref($entry_ref) eq 'GLOB') {
            return *{$entry_ref}{$symbol_kind};
        }
        else {
            if ($symbol_kind eq 'CODE') {
                no strict 'refs';
                return \&{ $class_name . '::' . $symbol_name };
            }
        }
    }
    return;
}

1;
