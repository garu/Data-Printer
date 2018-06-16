package Data::Printer::Filter::HASH;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;
use Scalar::Util ();

filter 'HASH' => sub {
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

    my %ignore = map { $_ => 1 } @{$ddp->ignore_keys};

    my @src_keys = grep !exists $ignore{$_}, keys %$hash_ref;
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

        if ($ddp->quote_keys) {
            my $needs_quote = 1;
            if ($ddp->quote_keys eq 'auto') {
                if ($raw_key eq $new_key && $new_key !~ /\s|\r|\n|\t|\f/) {
                    $needs_quote = 0;
                }
            }
            if ($needs_quote) {
                $new_key     = q(') . $new_key . q(');
                $colored_key = $ddp->maybe_colorize(q('), 'quotes')
                             . $colored_key
                             . $ddp->maybe_colorize(q('), 'quotes')
                             ;
            }
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

        # update 'var' to 'var{key}':
        $ddp->current_name( $ddp->current_name . '{' . $key->{raw} . '}' );

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
            $string .= $ddp->parse(\\$hash_ref->{ $key->{raw} });
        }
        elsif ( $ref && $ref ne 'REF' ) {
            $string .= $ddp->parse( $hash_ref->{ $key->{raw} });
        } else {
            $string .= $ddp->parse(\$hash_ref->{ $key->{raw} });
        }

        $string .= $ddp->maybe_colorize($ddp->separator, 'separator')
            if $total_keys > 0 || $ddp->end_separator;

        # restore var name back to "var"
        my $size = 2 + length($key->{raw});
        my $name = $ddp->current_name;
        substr $name, -$size, $size, '';
        $ddp->current_name($name);
    }
    $ddp->outdent;
    $string .= $ddp->newline . $ddp->maybe_colorize('}', 'brackets');
    return $string . $tied;
};

#######################################
### Private auxiliary helpers below ###
#######################################


1;
