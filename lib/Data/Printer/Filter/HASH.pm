package Data::Printer::Filter::HASH;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;
use Scalar::Util ();

filter 'HASH' => \&parse;


sub parse {
    my ($hash_ref, $ddp) = @_;
    my $tied = '';
    if ($ddp->show_tied and my $tie = ref tied %$hash_ref) {
        $tied = " (tied to $tie)";
    }
    return       $ddp->maybe_colorize('{', 'brackets')
         . ' ' . $ddp->maybe_colorize('...', 'hash')
         . ' ' . $ddp->maybe_colorize('}', 'brackets')
         . $tied
         if $ddp->max_depth && $ddp->current_depth >= $ddp->max_depth;

    my @src_keys = keys %$hash_ref;
    return $ddp->maybe_colorize('{}', 'brackets') . $tied unless @src_keys;
    @src_keys = Data::Printer::Common::_nsort(@src_keys) if $ddp->sort_keys;

    my $len = 0;
    my $align_keys = $ddp->multiline && $ddp->align_hash;

    my @i = Data::Printer::Common::_fetch_indexes_for(\@src_keys, 'hash', $ddp);

    my %processed_keys;
    # first pass, preparing keys and getting largest key size:
    foreach my $idx (@i) {
        next if ref $idx;
        my $raw_key = $src_keys[$idx];
        my $colored_key = Data::Printer::Common::_process_string($ddp, $raw_key, 'hash');
        my $new_key = Data::Printer::Common::_colorstrip($colored_key);

        if (_needs_quote($ddp, $raw_key, $new_key)) {
            my $quote_char = $ddp->scalar_quotes;
            # foo'bar ==> 'foo\'bar'
            if (index($new_key, $quote_char) >= 0) {
                $new_key =~ s{$quote_char}{\\$quote_char}g;
                $colored_key =~ s{$quote_char}{\\$quote_char}g;
            }
            $new_key     = $quote_char . $new_key . $quote_char;
            $colored_key = $ddp->maybe_colorize($quote_char, 'quotes')
                            . $colored_key
                            . $ddp->maybe_colorize($quote_char, 'quotes')
                            ;
        }
        $processed_keys{$idx} = {
            raw     => $raw_key,
            colored => $colored_key,
            nocolor => $new_key,
        };
        if ($align_keys) {
            my $l = length $new_key;
            $len = $l if $l > $len;
        }
    }
    # second pass, traversing and rendering:
    $ddp->indent;
    my $total_keys = scalar @i; # yes, counting messages so ',' appear in between.
    #keys %processed_keys;
    my $string = $ddp->maybe_colorize('{', 'brackets');
    foreach my $idx (@i) {
        $total_keys--;
        # $idx is a message to display, not a real index
        if (ref $idx) {
            $string .= $ddp->newline . $$idx;
            next;
        }
        my $key = $processed_keys{$idx};

        my $original_varname = $ddp->current_name;
        # update 'var' to 'var{key}':
        $ddp->current_name(
            $original_varname
            . ($ddp->arrows eq 'all' || ($ddp->arrows eq 'first' && $ddp->current_depth == 1) ? '->' : '')
            . '{' . $key->{nocolor} . '}'
        );

        my $padding = $len - length($key->{nocolor});
        $padding = 0 if $padding < 0;
        $string .= $ddp->newline
                . $key->{colored}
                . (' ' x $padding)
                . $ddp->maybe_colorize($ddp->hash_separator, 'separator')
                ;

        # scalar references should be re-referenced to gain
        # a '\' in front of them.
        my $ref = ref $hash_ref->{$key->{raw}};
        if ( $ref && $ref eq 'SCALAR' ) {
            $string .= $ddp->parse(\$hash_ref->{ $key->{raw} }, tied_parent => !!$tied);
        }
        elsif ( $ref && $ref ne 'REF' ) {
            $string .= $ddp->parse( $hash_ref->{ $key->{raw} }, tied_parent => !!$tied);
        } else {
            $string .= $ddp->parse(\$hash_ref->{ $key->{raw} }, tied_parent => !!$tied);
        }

        $string .= $ddp->maybe_colorize($ddp->separator, 'separator')
            if $total_keys > 0 || $ddp->end_separator;

        # restore var name back to "var"
        $ddp->current_name($original_varname);
    }
    $ddp->outdent;
    $string .= $ddp->newline . $ddp->maybe_colorize('}', 'brackets');
    return $string . $tied;
};

#######################################
### Private auxiliary helpers below ###
#######################################

sub _needs_quote {
    my ($ddp, $raw_key, $new_key) = @_;
    my $quote_keys = $ddp->quote_keys;
    my $scalar_quotes = $ddp->scalar_quotes;
    return 0 unless defined $quote_keys && defined $scalar_quotes;;
    if ($quote_keys eq 'auto'
        && $raw_key eq $new_key
        && $new_key !~ /\s|\r|\n|\t|\f/) {
            return 0;
    }
    return 1;
}

1;
