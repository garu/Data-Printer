package Data::Printer::Common;
# Private library of shared Data::Printer code.
use strict;
use warnings;
use if $] >= 5.010, 'Hash::Util::FieldHash'         => qw(fieldhash);
use if $] <  5.010, 'Hash::Util::FieldHash::Compat' => qw(fieldhash);

my $mro_initialized = 0;
my $nsort_initialized;

sub merge_options {
    my ($old, $new) = @_;
    if (ref $new eq 'HASH') {
        my %merged;
        my $to_merge = ref $old eq 'HASH' ? $old : {};
        foreach my $k (keys %$new, keys %$to_merge) {
            # if the key exists in $new, we recurse into it:
            if (exists $new->{$k}) {
                $merged{$k} = merge_options($to_merge->{$k}, $new->{$k});
            }
            else {
                # otherwise we keep the old version (recursing in case of refs)
                $merged{$k} = merge_options(undef, $to_merge->{$k});
            }
        }
        return \%merged;
    }
    elsif (ref $new eq 'ARRAY') {
        # we'll only use the array on $new, but we still need to recurse
        # in case array elements contain other data structures.
        my @merged;
        foreach my $element (@$new) {
            push @merged, merge_options(undef, $element);
        }
        return \@merged;
    }
    else {
        return $new;
    }
}

# strings are tough to process: there are control characters like "\t",
# unicode characters to name or escape (or do nothing), max_string to
# worry about, and every single piece of that could have its own color.
# That, and hash keys and strings share this. So we put it all in one place.
sub _process_string {
    my ($ddp, $string, $src_name) = @_;

    # colorizing messes with reduce_string because we are effectively
    # adding new (invisible) characters to the string. So we need to
    # handle reduction first. But! Because we colorize string_max
    # *and* we should escape any colors already present, we need to
    # do both at the same time.
    $string = _reduce_string($ddp, $string, $src_name);

    # now we escape all other control characters except for "\e", which was
    # already escaped in _reduce_string(), and convert any chosen charset
    # to the \x{} format. These could go in any particular order:
    $string = _escape_chars($ddp, $string, $src_name);
    $string = _print_escapes($ddp, $string, $src_name);

    # finally, send our wrapped string:
    return $ddp->maybe_colorize($string, $src_name);
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
        my $skip_message = $ddp->maybe_colorize($ddp->string_overflow, 'caller_info', $src_color);
        $skip_message =~ s/__SKIPPED__/$skipped_chars/g;
        if ($preserve eq 'end') {
            substr $string, 0, $skipped_chars, '';
            $string =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', $src_color)}ge
                if $ddp->print_escapes;
            $string = $skip_message . $string;
        }
        elsif ($preserve eq 'begin') {
            $string = substr($string, 0, $max);
            $string =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', $src_color)}ge
                if $ddp->print_escapes;
            $string = $string . $skip_message;
        }
        elsif ($preserve eq 'extremes') {
            my $leftside_chars = int($max / 2);
            my $rightside_chars = $max - $leftside_chars;
            my $leftside = substr($string, 0, $leftside_chars);
            my $rightside = substr($string, -$rightside_chars);
            if ($ddp->print_escapes) {
                $leftside  =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', $src_color)}ge;
                $rightside =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', $src_color)}ge;
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
            $string =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', $src_color)}ge
                if $ddp->print_escapes;
            $string = $ddp->maybe_colorize($message_begin, 'caller_info', $src_color)
                    . $string
                    . $ddp->maybe_colorize($message_end, 'caller_info', $src_color)
                    ;
        }
        else {
            # preserving 'none' only shows the skipped message:
            $string = $skip_message;
        }
    }
    else {
        # nothing to do? ok, then escape any colors already present:
        $string =~ s{\e}{$ddp->maybe_colorize('\\e', 'escaped', $src_color)}ge
            if $ddp->print_escapes;
#        $string =~ s{\e}{$escape_color\\e$main_color}g if $ddp->print_escapes;
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
            $scalar =~ s{($target_for{$escape_kind})}{$ddp->maybe_colorize( (join '', map { sprintf '\N{%s}', charnames::viacode(ord $_) } split //, $1), 'escaped', $src_color)}ge if exists $target_for{$escape_kind};
        }
    }
    elsif ($escape_kind eq 'all') {
        $scalar = join('', map { sprintf '\x{%02x}', ord $_ } split //, $scalar);
        $scalar = $ddp->maybe_colorize($scalar, 'escaped');
    }
    else {
        $scalar =~ s{($target_for{$escape_kind})}{$ddp->maybe_colorize((join '', map { sprintf '\x{%02x}', ord $_ } split //, $1), 'escaped', $src_color)}ge if exists $target_for{$escape_kind};
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
    $string =~ s/\0/$ddp->maybe_colorize('\\0', 'escaped', $src_color)/ge;

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
        $string =~ s/$k/$ddp->maybe_colorize($escaped{$k}, 'escaped', $src_color)/ge;
    }
    return $string;
}

sub _initialize_nsort {
    return 'Sort::Naturally::XS' if $INC{'Sort/Naturally/XS.pm'};
    return 'Sort::Key::Natural'  if $INC{'Sort/Key/Natural.pm'};
    return 'Sort::Naturally'     if $INC{'Sort/Naturally.pm'};
    return 'Sort::Naturally::XS' if eval { require Sort::Naturally::XS; 1; };
    return 'Sort::Key::Natural'  if eval { require Sort::Key::Natural;  1; };
    return 'Sort::Naturally'     if eval { require Sort::Naturally;     1; };
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

# this is a very simple 'natural-ish' sorter, heavily inspired on
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

sub _linear_ISA_for {
    my ($class, $ddp) = @_;
    _initialize_mro() unless $mro_initialized;
    my $isa = mro::get_linear_isa($class) if $mro_initialized > 0;
    return [@$isa, ($ddp->class->universal ? 'UNIVERSAL' : ())];
}

sub _initialize_mro {
    my $error= _tryme(sub {
        if ($] < 5.009_005) { require MRO::Compat }
        else { require mro }
        1;
    });
    $mro_initialized = $error ? -1 : 1;
}


sub _fetch_arrayref_of_scalars {
    my ($props, $name) = @_;
    return [] unless exists $props->{$name} && ref $props->{$name} eq 'ARRAY';
    my @valid;
    foreach my $option (@{$props->{$name}}) {
        if (ref $option) {
            _warn("'$name' option requires scalar values only. Ignoring $option.");
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
    require Carp;
    Carp::croak('[Data::Printer] ' . $message);
}

sub _warn {
    my ($message) = @_;
    require Carp;
    Carp::carp('[Data::Printer] ' . $message);
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

# adapted from File::HomeDir
sub _my_home {
    my ($testing) = @_;
    if ($testing) {
        require File::Temp;
        require File::Spec;
        my $BASE  = File::Temp::tempdir( CLEANUP => 1 );
        my $home  = File::Spec->catdir( $BASE, 'my_home' );
        $ENV{HOME} = $home;
        mkdir($home, 0755) unless -d $home;
        return $home;
    }
    elsif (exists $ENV{HOME} && defined $ENV{HOME}) {
        return $ENV{HOME};
    }

    elsif ($^O eq 'MSWin32') {
        return $ENV{USERPROFILE} if exists $ENV{USERPROFILE} and $ENV{USERPROFILE};
        if (exists $ENV{HOMEDRIVE} and exists $ENV{HOMEPATH} and $ENV{HOMEDRIVE} and $ENV{HOMEPATH} ) {
            require File::Spec;
            return File::Spec->catpath($ENV{HOMEDRIVE}, $ENV{HOMEPATH}, '');
        }
        return undef;
    }
    elsif ($^O eq 'darwin' || $^O eq 'MacOS') {
        my $error = _tryme(sub { require Mac::SystemDirectory; 1; });
        return Mac::SystemDirectory::HomeDirectory() unless $error;
        $error = _tryme(sub { require Mac::Files; 1; });
        if (!$error) {
            my $folder = Mac::Files::FindFolder(
                Mac::Files::kUserDomain(),
                Mac::Files::kCurrentUserFolderType()
            );
            return undef unless defined $folder;
            if (!-d $folder) {
                # Make sure that symlinks resolve to directories.
                return undef unless -l $folder;
                my $dir = readlink $folder or return undef;
                return undef unless -d $dir;
            }
            require Cwd;
            return Cwd::abs_path($folder);
        }
        my $home;
        SCOPE: { $home = (getpwuid($<))[7] }
        if (defined $home && !-d $home) {
            $home = undef;
        }
        return $home;
    }
    else { # unix/linux/bsd/...
        my $home;
        if (exists $ENV{HOME} and defined $ENV{HOME}) {
            $home = $ENV{HOME};
        }
        elsif (exists $ENV{LOGDIR} and $ENV{LOGDIR}) {
            $home = $ENV{LOGDIR};
        }
        else {
            # Light desperation on any (Unixish) platform
            SCOPE: { $home = (getpwuid($<))[7] }
        }
        if (defined $home and ! -d $home ) {
            $home = undef;
        }
        return $home;
    }
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

{
#    fieldhash my %IDs;
    my %IDs;

    my $Last_ID = "a";
    sub _object_id {
        my ($self) = @_;

        $self = Scalar::Util::refaddr( $self ); # maybe not required - use 

        # This is 15% faster than ||=
        return $IDs{$self} if exists $IDs{$self};
        return $IDs{$self} = ++$Last_ID;
    }
}

1;
