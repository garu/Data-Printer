package Data::Printer::Filter::DB;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;

filter 'DBI::db', sub {
    my ($dbh, $ddp) = @_;
    my $name = $dbh->{Driver}{Name};

    my $string = "$name Database Handle "
               . $ddp->maybe_colorize('(', 'brackets')
               . _get_db_status($dbh->{Active}, $ddp)
               . $ddp->maybe_colorize(')', 'brackets')
               ;
    return $string
        if exists $ddp->extra_config->{filter_db}{connection_details}
           && !$ddp->extra_config->{filter_db}{connection_details};

    $string .= ' ' . $ddp->maybe_colorize('{', 'brackets');
    $ddp->indent;
    my %dsn = split( /[;=]/, $dbh->{Name} );
    foreach my $k (keys %dsn) {
        $string .= $ddp->newline . $k . $ddp->maybe_colorize(':', 'separator')
                . ' ' . $dsn{$k};
    }
    $string .= $ddp->newline . 'Auto Commit: ' . $dbh->{AutoCommit};

    my $kids = $dbh->{Kids};
    $string .= $ddp->newline . 'Statement Handles: ' . $kids;
    if ($kids > 0) {
        $string .= ' (' . $dbh->{ActiveKids} . ' active)';
    }

    if ( defined $dbh->err ) {
        $string .= $ddp->newline . 'Error: ' . $dbh->errstr;
    }
    $string .= $ddp->newline . 'Last Statement: '
            . $ddp->maybe_colorize(($dbh->{Statement} || '-'), 'string');

    $ddp->outdent;
    $string .= $ddp->newline . $ddp->maybe_colorize('}', 'brackets');
    return $string;
};

filter 'DBI::st', sub {
    my ($sth, $ddp) = @_;
    my $str = $ddp->maybe_colorize(($sth->{Statement} || '-'), 'string');

    if ($sth->{NUM_OF_PARAMS} > 0) {
        my $values = $sth->{ParamValues};
        if ($values) {
            $str .= '  ' . $ddp->maybe_colorize('(', 'brackets')
                 . join($ddp->maybe_colorize(',', 'separator') . ' ',
                      map {
                         my $v = $values->{$_};
                         $ddp->parse($v);
                      } 1 .. $sth->{NUM_OF_PARAMS}
                   )
                 . $ddp->maybe_colorize(')', 'brackets');
        }
        else {
            $str .= '  ' . $ddp->maybe_colorize('(bindings unavailable)', 'undef');
        }
    }
    return $str;
};

# DBIx::Class filters
filter 'DBIx::Class::Schema' => sub {
    my ($schema, $ddp) = @_;

    my $name = $ddp->maybe_colorize(ref($schema), 'class');
    my $storage = $schema->storage;
    my $config = {};
    $config = $ddp->extra_config->{filter_db}{schema}
        if exists $ddp->extra_config->{filter_db}
           && exists $ddp->extra_config->{filter_db}{schema};

    my $expand = exists $config->{expand}
        ? $config->{expand}
        : $ddp->class->expand
        ;
    my $connected = _get_db_status($storage->connected, $ddp);
    if (!$expand) {
        return "$name " . $ddp->maybe_colorize('(', 'brackets')
            . $storage->sqlt_type . " - $connected"
            . $ddp->maybe_colorize(')', 'brackets')
            ;
    }

    $ddp->indent;
    my $output = $name . ' ' . $ddp->maybe_colorize('{', 'brackets')
        . $ddp->newline
        . 'connection: ' . ($config->{show_handle}
            ? $ddp->parse($storage->dbh)
            : $storage->sqlt_type . " Database Handle ($connected)"
        );
    if ($storage->is_replicating) {
         $output .= $ddp->newline . 'replication lag: ' . $storage->lag_behind_master;
    }
    my $load_sources = 'names';
    if (exists $config->{loaded_sources}) {
        my $type = $config->{loaded_sources};
        if ($type && ($type eq 'names' || $type eq 'details' || $type eq 'none')) {
            $load_sources = $type;
        }
        else {
            Data::Printer::Common::_warn(
                $ddp,
                "filter_db.schema.loaded_sources must be names, details or none"
            );
        }
    }
    if ($load_sources ne 'none') {
        my @sources = $schema->sources;
        @sources = Data::Printer::Common::_nsort(@sources)
            if $ddp->class->sort_methods && @sources;

        $output .= $ddp->newline . 'loaded sources:';
        if ($load_sources eq 'names') {
            $output .= ' ' . (@sources
                ? join(', ', map($ddp->maybe_colorize($_, 'method'), @sources))
                : '-'
            );
        }
        else {
            $ddp->indent;
            foreach my $i (0 .. $#sources) {
                my $source = $schema->source($sources[$i]);
                $output .= $ddp->newline . $ddp->parse($source);
                $output .= $ddp->maybe_colorize(',', 'separator') if $i < $#sources;
            }
            $ddp->outdent;
        }
    }
    $ddp->outdent;
    $output .= $ddp->newline . $ddp->maybe_colorize('}', 'brackets');
    return $output;
};

filter 'DBIx::Class::Row' => sub {
    my ($row, $ddp) = @_;

    my $output = $row->result_source->source_name
               . ' Row ' . $ddp->maybe_colorize('(', 'brackets')
               . ($row->in_storage ? '' : 'NOT ') . 'in storage'
               . $ddp->maybe_colorize(') {', 'brackets');

    $ddp->indent;
    my %orig_columns = map { $_ => 1 } $row->columns;
    my %data     = $row->get_columns;
    my %dirty    = $row->get_dirty_columns;
    # TODO: maybe also get_inflated_columns() ?
    my @ordered = Data::Printer::Common::_nsort(keys %data);
    my $longest = 0;
    foreach my $col (@ordered) {
        my $l = length $col;
        $longest = $l if $l > $longest;
    }
    my $show_updated_label = !exists $ddp->extra_config->{filter_db}{show_updated_label}
                          || $ddp->extra_config->{filter_db}{show_updated_label};
    my $show_extra_label = !exists $ddp->extra_config->{filter_db}{show_extra_label}
                        || $ddp->extra_config->{filter_db}{show_extra_label};

    foreach my $col (@ordered) {
        my $padding = $longest - length($col);
        my $content = $data{$col};
        $output .= $ddp->newline . $col
                . $ddp->maybe_colorize(':', 'separator')
                . ' ' . (' ' x $padding)
                . $ddp->parse(\$content, seen_override => 1)
                ;

        if (exists $dirty{$col} && $show_updated_label) {
            $output .= ' (updated)';
        }
        if (!exists $orig_columns{$col} && $show_extra_label) {
            $output .= ' (extra)';
        }
    }
    # TODO: methods: foo, bar <-- follows class.*, but can be overriden by filter_db.class.*
    $ddp->outdent;
    $output .= $ddp->newline . $ddp->maybe_colorize('}', 'brackets');
    return $output;
};

filter 'DBIx::Class::ResultSet' => sub {
    my ($rs, $ddp) = @_;

    $ddp->indent;
    my $output = $rs->result_source->source_name
               . ' ResultSet ' . $ddp->maybe_colorize('{', 'brackets')
               . $ddp->newline;

    # NOTE: we're totally breaking DBIC's encapsulation here. But since DDP
    # is a tool to inspect the inner workings of objects, it's okay. Ish.
    $output .= 'current search parameters: ';
    my $attrs;
    if ($rs->can('_resolved_attrs') && eval {
            $attrs = { %{ $rs->_resolved_attrs } }; 1;
        } && ref $attrs eq 'HASH'
    ) {
        if (exists $attrs->{where}) {
            $output .= $ddp->parse($attrs->{where})
        }
        else {
            $output .= '-';
        }
    }
    else {
        $output .= $ddp->maybe_colorize('(unable to lookup - patches welcome!)', 'unknown');
    }
    # TODO: show joins/prefetches/from
    # TODO: look at get_cache() for results
    if ($rs->can('as_query')) {
        my $query_data = $rs->as_query;
        my @query_data = @$$query_data;
        my $sql = shift @query_data;
        $output .= $ddp->newline . 'as query:';
        $ddp->indent;
        $output .= $ddp->newline
                . $ddp->maybe_colorize( $sql, 'string' )
                ;
        if (@query_data) {
            $output .= $ddp->newline . join( $ddp->newline, map {
                    my $bound = $_->[1];
                    if ($_->[0]{sqlt_datatype}) {
                      $bound .= ' ' . $ddp->maybe_colorize('(', 'brackets')
                        . $_->[0]{sqlt_datatype} . $ddp->maybe_colorize(')', 'brackets');
                    }
                    $bound
                  } @query_data
                );
        }
        $ddp->outdent;
    }
    if (my $cached = $rs->get_cache) {
        $output .= $ddp->newline . 'cached results:';
        $ddp->indent;
        $output .= $ddp->newline . $ddp->parse($cached);
        $ddp->outdent;
    }

    $ddp->outdent;
    $output .= $ddp->newline . $ddp->maybe_colorize('}', 'brackets');
    return $output;
};

filter 'DBIx::Class::ResultSource' => sub {
    my ($source, $ddp) = @_;
    my $cols = $source->columns_info;

    my $output = $source->source_name . ' ResultSource';
    if ($source->isa('DBIx::Class::ResultSource::View')) {
        $output .= ' ' . $ddp->maybe_colorize('(', 'brackets')
            . ($source->is_virtual ? 'Virtual ' : '')
            . 'View' . $ddp->maybe_colorize(')', 'brackets')
            ;
    }

    my $show_source_table = !exists $ddp->extra_config->{filter_db}{show_source_table}
                         || $ddp->extra_config->{filter_db}{show_source_table};
    my $column_info = 'details';
    if (exists $ddp->extra_config->{filter_db}{column_info}) {
        my $new = $ddp->extra_config->{filter_db}{column_info};
        if ($new && ($new eq 'names' || $new eq 'details' || $new eq 'none')) {
            $column_info = $new;
        }
        else {
            Data::Printer::Common::_warn(
                $ddp,
                "filter_db.column_info must be names, details or none"
            );
        }
    }
    return $output if !$show_source_table && $column_info eq 'none';

    $ddp->indent;
    $output .= ' ' . $ddp->maybe_colorize('{', 'brackets');
    if ($show_source_table) {
        $output .= $ddp->newline . 'table: ' . $ddp->parse(\$source->name);
    }
    if ($column_info ne 'none') {
        my $columns = $source->columns_info;
        $output .= $ddp->newline . 'columns:';
        $output .= ' - ' unless %$columns;
        my $separator = $ddp->maybe_colorize(',', 'separator') . ' ';
        if ($column_info eq 'names') {
            my %parsed_cols = map { $_ => 1 } keys %$columns;
            my @primary = Data::Printer::Common::_nsort($source->primary_columns);
            if (@primary) {
                delete $parsed_cols{$_} foreach @primary;
                $output .= ' ' . join($separator => map {
                        $ddp->maybe_colorize($_, 'method') . ' (primary)'
                    } @primary
                );
                $output .= ',' if keys %parsed_cols;
            }
            if (keys %parsed_cols) {
                $output .= ' ' . join($separator => map {
                        $ddp->maybe_colorize($_, 'method')
                    } Data::Printer::Common::_nsort(keys %parsed_cols)
                );
            }
        }
        else { # details!
            $output .= _show_column_details($source, $columns, $ddp);
        }
        my %uniques = $source->unique_constraints;
        delete $uniques{primary};
        if (keys %uniques) {
            $output .= $ddp->newline . 'non-primary uniques:';
            $ddp->indent;
            foreach my $key (Data::Printer::Common::_nsort(keys %uniques)) {
                $output .= $ddp->newline
                        . $ddp->maybe_colorize('(', 'brackets')
                        . join($separator, @{$uniques{$key}})
                        . $ddp->maybe_colorize(')', 'brackets') . " as '$key'"
                        ;
            }
            $ddp->outdent;
        }

        # TODO: use $source->relationships and $source->relationship_info
        # to list relationships between sources. (filter_db.show_relationships
        # TODO: public methods implemented by the user
        # TODO; "current result count" (touching the db)
        # TODO: "first X eresults" (touching the db)
    }
    $ddp->outdent;
    return $output . $ddp->newline . $ddp->maybe_colorize('}', 'brackets');
};

sub _show_column_details {
    my ($source, $columns, $ddp) = @_;
    my $output = '';
    my %parsed_columns;
    foreach my $colname (keys %$columns) {
        my $meta = $columns->{$colname};
        my $parsed = ' ';
        if (exists $meta->{data_type} && defined $meta->{data_type}) {
            $parsed .= $meta->{data_type};
            if (exists $meta->{size}) {
                my @size = ref $meta->{size} eq 'ARRAY'
                    ? @{$meta->{size}} : ($meta->{size})
                ;
                if ($meta->{data_type} =~ /\((.+?)\)/) {
                    my @other_size = split ',' => $1;
                    my $different_sizes = @size != @other_size;
                    if (!$different_sizes) {
                        foreach my $i (0 .. $#size) {
                            if ($size[$i] != $other_size[$i]) {
                                $different_sizes = 1;
                                last;
                            }
                        }
                    }
                    if ($different_sizes) {
                        $parsed .= ' (meta size as ' . join(',' => @size) . ')';
                    }
                }
                else {
                    $parsed .= '(' . join(',' => @size) . ')';
                }
            }
        }
        else {
            $parsed .= $ddp->maybe_colorize('(unknown data type)', 'unknown');
        }
        if (exists $meta->{is_nullable}) {
            $parsed .= ((' not')x !$meta->{is_nullable}) . ' null';
        }
        if (exists $meta->{default_value} && defined $meta->{default_value}) {
            my $default = $meta->{default_value};
            if (ref $default) {
                $default = $$default;
            }
            elsif (defined $meta->{is_numeric}) { # <-- not undef!
                $default = $meta->{is_numeric} ? 0+$default : qq("$default");
            }
            elsif ($source->storage->is_datatype_numeric($meta->{data_type})) {
                $default = 0+$default;
            }
            else {
                $default = qq("$default");
            }
            $parsed .= " default $default";
        }
        if (exists $meta->{is_auto_increment} && $meta->{is_auto_increment}) {
            $parsed .= ' auto_increment';
        }
        $parsed_columns{$colname} = $parsed;
    }

    my @primary_keys = $source->primary_columns;
    if (keys %parsed_columns || @primary_keys) {
        my $separator = $ddp->maybe_colorize(',', 'separator');
        $ddp->indent;
        foreach my $colname (@primary_keys) {
            my $value = exists $parsed_columns{$colname}
                ? delete $parsed_columns{$colname} : '';
            $output .= $ddp->newline . $colname
                    . (defined $value ? $value : '')
                    . ' (primary)'
                    . (keys %parsed_columns ? $separator : '')
                    ;
        }
        if (keys %parsed_columns) {
            my @sorted_columns = Data::Printer::Common::_nsort(keys %parsed_columns);
            foreach my $i (0 .. $#sorted_columns) {
                my $colname = $sorted_columns[$i];
                # TODO: v-align column names (like hash keys)
                $output .= $ddp->newline . $colname
                . $parsed_columns{$colname}
                . ($i == $#sorted_columns ? '' : $separator)
                ;
            }
        }
        $ddp->outdent;
    }
    return $output;
}


sub _get_db_status {
    my ($status, $ddp) = @_;
    return $status
        ? $ddp->maybe_colorize('connected', 'filter_db_connected', '#a0d332')
        : $ddp->maybe_colorize('disconnected', 'filter_db_disconnected', '#b3422d')
        ;
}

1;
__END__

=head1 NAME

Data::Printer::Filter::DB - pretty-printing database objects (DBI, DBIx::Class, etc)

=head1 SYNOPSIS

In your C<.dataprinter> file:

    filters = DB

You may also customize the look and feel with the following options
(defaults shown):

    ### DBH settings:

    # expand database handle objects
    filter_db.connection_details = 1


    ### DBIx::Class settings:

    # signal when a result column is dirty:
    filter_db.show_updated_label = 1

    # signal when result rows contain extra columns:
    filter_db.show_extra_label = 1

    # override class.expand for schema dump
    filter_db.schema.expand = 1

    # expand DBH handle on schema dump (may touch DB)
    filter_db.schema.show_handle = 0

    # show source details (connected tables) on schema dump
    # (may be set to 'names', 'details' or 'none')
    filter_db.schema.loaded_sources = names

    # show source table name ResultSource objects
    filter_db.show_source_table = 1

    # show source columns ('names', 'details' or 'none'):
    filter_db.column_info = details

    # this plugin honors theme colors where applicable
    # and provides the following custom colors for you to use:
    colors.filter_db_connected    = #a0d332
    colors.filter_db_disconnected = #b3422d

That's it!

=head1 DESCRIPTION

This is a filter plugin for L<Data::Printer> that displays (hopefully)
more relevant information on database objects than a regular dump.


=head2 Parsed Modules

=head3 L<DBI>

If it's a database handle, for example, this filter may show you something
like this:

    SQLite Database Handle (connected) {
        dbname: file.db
        Auto Commit: 1
        Statement Handles: 2 (1 active)
        Last Statement: SELECT * FROM some_table
    }

You can show less information by setting this option on your C<.dataprinter>:

    filter_db.connection_details = 0

If you have a statement handler like this (for example):

    my $sth = $dbh->prepare('SELECT * FROM foo WHERE bar = ?');
    $sth->execute(42);

    use DDP; p $sth;

This is what you'll get:

    SELECT * FROM foo WHERE bar = ?  (42)

Note that if your driver does not support holding of parameter values, you'll get a
C<bindings unavailable> message instead of the bound values.

=head3 L<DBIx::Class>

This filter is able to pretty-print many common DBIx::Class objects for
inspection. Unless otherwrise noted, none of those calls will touch the
database.

B<DBIx::Class::Schema> objects are dumped by default like this:

    MyApp::Schema {
        connection: MySQL Database Handle (connected)
        replication lag: 4
        loaded sources: ResultName1, ResultName2, ResultName3
    }

If your C<.dataprinter> settings have C<class.expand> set to C<0>, it will
only show this:

    MyApp::Schema (MySQL - connected)

You may override this with C<filter_db.schema.expand = 1> (or 0).
Other available options for the schema are (default values shown):

    # if set to 1, expands 'connection' into a complete DBH dump
    # NOTE: this may touch the database as it could try to reconnect
    # to fetch a healthy DBH:
    filter_db.schema.show_handle = 0

    # set to 'details' to view source details, or 'none' to skip it:
    filter_db.schema.loaded_sources = names

B<DBIx::Class::ResultSource> objects will be expanded to show details
of what that source represents on the database (as perceived by DBIx::Class),
including column information and whether the table is virtual or not.

    User ResultSource {
        table: "user"
        columns:
            user_id integer not null auto_increment (primary),
            email varchar(100),
            bio text
        non-primary uniques:
            (email) as 'user_email'
    }

=head4 Ever got bit by DBIx::Class?

Let us know if we can help by creating an issue on Data::Printer's Github.
Patches are welcome!

=head1 SEE ALSO

L<Data::Printer>
