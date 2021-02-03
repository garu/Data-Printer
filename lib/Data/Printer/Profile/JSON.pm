package Data::Printer::Profile::JSON;
use strict;
use warnings;

sub profile {
    return {
        show_tainted => 0,
        show_unicode => 0,
        show_lvalue  => 0,
        print_escapes => 0,
        scalar_quotes => q("),
        escape_chars => 'none',
        string_max => 0,
        unicode_charnames => 0,
        array_max => 0,
        index => 0,
        hash_max => 0,
        hash_separator => ': ',
        align_hash => 0,
        sort_keys => 0,
        quote_keys => 1,
        name => 'var',
        return_value => 'dump',
        output => 'stderr',
        indent => 2,
        show_readonly => 0,
        show_tied => 0,
        show_dualvar => 'off',
        show_weak => 0,
        show_refcount => 0,
        show_memsize => 0,
        separator => ',',
        end_separator => 0,
        caller_info => 0,
        colored => 0,
        class_method => undef,
        # Data::Printer doesn't provide a way to directly
        # decorate filters, so we do it ourselves:
        filters => [
            {
                '-class'  => \&_json_class_filter,
                'SCALAR'  => \&_json_scalar_filter,
                'LVALUE'  => \&_json_scalar_filter,
                'CODE'    => \&_json_code_filter,
                'FORMAT'  => \&_json_format_filter,
                'GLOB'    => \&_json_glob_filter,
                'REF'     => \&_json_ref_filter,,
                'Regexp'  => \&_json_regexp_filter,
                'VSTRING' => \&_json_vstring_filter,
            },
        ],
    };
}

sub _json_class_filter {
    my ($obj, $ddp) = @_;
    Data::Printer::Common::_warn($ddp, 'json cannot express blessed objects. Showing internals only');
    require Scalar::Util;
    my $reftype = Scalar::Util::reftype($obj);
    $reftype = 'Regexp' if $reftype eq 'REGEXP';
    $ddp->indent;
    my $string = $ddp->parse_as($reftype, $obj);
    $ddp->outdent;
    return $string;
}

sub _json_ref_filter {
    my ($ref, $ddp) = @_;
    my $reftype = ref $$ref;
    if ($reftype ne 'HASH' && $reftype ne 'ARRAY') {
        Data::Printer::Common::_warn($ddp, 'json cannot express references to scalars. Cast to non-reference');
    }
    require Scalar::Util;
    my $id = pack 'J', Scalar::Util::refaddr($$ref);
    if ($ddp->seen($$ref)) {
        Data::Printer::Common::_warn($ddp, 'json cannot express circular references. Cast to string');
        return '"' . $ddp->parse($$ref) . '"';
    }
    return $ddp->parse($$ref);
}

sub _json_glob_filter {
    my (undef, $ddp) = @_;
    Data::Printer::Common::_warn($ddp, 'json cannot express globs.');
    return '';
}

sub _json_format_filter {
    my $res = Data::Printer::Filter::FORMAT::parse(@_);
    return '"' . $res . '"';
}

sub _json_regexp_filter {
    my ($re, $ddp) = @_;
    Data::Printer::Common::_warn($ddp, 'regular expression cast to string (flags removed)');
    my $v = "$re";
    my $mod = "";
    if ($v =~ /^\(\?\^?([msixpadlun-]*):([\x00-\xFF]*)\)\z/) {
      $mod = $1;
      $v = $2;
      $mod =~ s/-.*//;
    }
    $v =~ s{/}{\\/}g;
    return '"' . "/$v/$mod" . '"';
}

sub _json_vstring_filter {
    my ($scalar, $ddp) = @_;
    Data::Printer::Common::_warn($ddp, 'json cannot express vstrings. Cast to string');
    my $ret = Data::Printer::Filter::VSTRING::parse(@_);
    return '"' . $ret . '"';
}

sub _json_scalar_filter {
    my ($scalar, $ddp) = @_;
    return $ddp->maybe_colorize('null', 'undef') if !defined $$scalar;
    return Data::Printer::Filter::SCALAR::parse(@_);
}

sub _json_code_filter {
    my (undef, $ddp) = @_;
    Data::Printer::Common::_warn($ddp, 'json cannot express subroutines. Cast to string');
    my $res = Data::Printer::Filter::CODE::parse(@_);
    return '"' . $res . '"';
}

1;
__END__

=head1 NAME

Data::Printer::Profile::JSON - dump variables in JSON format

=head1 SYNOPSIS

While loading Data::Printer:

    use DDP profile => 'JSON';

While asking for a print:

    p $var, profile => 'JSON';

or in your C<.dataprinter> file:

    profile = JSON

=head1 DESCRIPTION

This profile outputs your variables in JSON format. It's not nearly as efficient
as a regular JSON module, but it may be useful, specially if you're changing
the format directly in your .dataprinter.

=head1 CAVEATS

JSON is a super simple format that allows scalar, hashes and arrays. It doesn't
support many types that could be present on Perl data structures, such as
functions, globs and circular references. When printing those types, whenever
possible, this module will stringify the result.

Objects are also not shown, but their internal data structure is exposed.

This module also attempts to render Regular expressions as plain JS regexes.
While not directly supported in JSON, it should be parseable.

=head1 SEE ALSO

L<Data::Printer>
L<JSON::MaybeXS>>
