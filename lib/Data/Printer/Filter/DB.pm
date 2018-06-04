package Data::Printer::Filter::DB;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;

filter 'DBI::db', sub {
    my ($dbh, $ddp) = @_;
    my $name = $dbh->{Driver}{Name};

    my $string = "$name Database Handle ("
               . _get_db_status($dbh->{Active}, $ddp)
               . ')'
               ;
    return $string
        if exists $ddp->extra_config->{filter_db}{connection_details}
           && !$ddp->extra_config->{filter_db}{connection_details};

    $string .= ' {';
    $ddp->indent;
    my %dsn = split( /[;=]/, $dbh->{Name} );
    foreach my $k (keys %dsn) {
        $string .= $ddp->newline . "$k: " . $dsn{$k};
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
    $string .= $ddp->newline . '}';
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
    return "$name (" . $storage->sqlt_type . " - $connected)"
        unless $expand;

    $ddp->indent;
    my $output = $name . ' {' . $ddp->newline
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
        if ($type && ($type eq 'names' || $type eq 'expand' || $type eq 'none')) {
            $load_sources = $type;
        }
        else {
            Data::Printer::Common::_warn(
                "filter_db.schema.loaded_sources must be names,expand or none"
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
                $output .= ',' if $i < $#sources;
            }
            $ddp->outdent;
        }
    }
    $ddp->outdent;
    $output .= $ddp->newline . '}';
    return $output;
};

filter 'DBIx::Class::ResultSource' => sub {
    my ($source, $ddp) = @_;
    my $cols = $source->columns_info;

    my $output = $source->source_name . ' ResultSource';
    if ($source->isa('DBIx::Class::ResultSource::View')) {
        $output .= ' ('
            . ($source->is_virtual ? 'Virtual ' : '')
            . 'View)'
            ;
    }
    $ddp->indent;
    $output .= ' {' . $ddp->newline
            . 'table: ' . $ddp->parse(\$source->name)
            ;

    my $columns = $source->columns_info;
    my %parsed_columns;
    my $has_meta;
    foreach my $colname (keys %$columns) {
        my $meta = $columns->{$colname};
        next unless keys %$meta;
        $has_meta = 1;
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
            $parsed .= '(unknown data type)';
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
        $output .= $ddp->newline . 'columns:';
        if ($has_meta) {
            $ddp->indent;
            foreach my $colname (@primary_keys) {
                my $value = exists $parsed_columns{$colname}
                    ? delete $parsed_columns{$colname} : '';
                $output .= $ddp->newline . $colname
                        . (defined $value ? $value : '')
                        . ' (primary)'
                        . (keys %parsed_columns ? ',' : '')
                        ;
            }
            if (keys %parsed_columns) {
                my @sorted_columns = Data::Printer::Common::_nsort(keys %parsed_columns);
                foreach my $i (0 .. $#sorted_columns) {
                    my $colname = $sorted_columns[$i];
                    $output .= $ddp->newline . $colname
                    . $parsed_columns{$colname}
                    . ($i == $#sorted_columns ? '' : ',')
                    ;
                }
            }
            $ddp->outdent;
        }
        else {
            foreach my $colname (@primary_keys) {
                $output .= $colname . ' (primary)';
                delete $parsed_columns{$colname};
                $output .= ', 'if keys %parsed_columns;
            }
            if (keys %parsed_columns) {
                my @sorted_cols = Data::Printer::Common::_nsort(keys %parsed_columns);
                $output .= join(', ' => @sorted_cols);
            }
        }
        my %uniques = $source->unique_constraints;
        delete $uniques{primary};
        if (keys %uniques) {
            $output .= $ddp->newline . 'non-primary uniques:';
            $ddp->indent;
            foreach my $key (Data::Printer::Common::_nsort(keys %uniques)) {
                $output .= $ddp->newline
                        . '(' . join(',', @{$uniques{$key}})
                        . ") as '$key'"
                        ;
            }
            $ddp->outdent;
        }

        # TODO: use $source->relationships and $source->relationship_info
        # to list relationships between sources.
        # TODO: public methods implemented by the user
    }
    $ddp->outdent;
    return $output . $ddp->newline . '}';
};

sub _get_db_status {
    my ($status, $ddp) = @_;
    return $status
        ? $ddp->maybe_colorize('connected', 'filter_db_connected', '#a0d332')
        : $ddp->maybe_colorize('disconnected', 'filter_db_disconnected', '#b3422d')
        ;
}

filter '-class' => sub {
    my ($obj, $ddp) = @_;

    # TODO: if it's a Result, show columns and relationships (anything that
    #       doesn't involve touching the database
    if ( grep { $obj->isa($_) } qw(DBIx::Class::ResultSet DBIx::Class::ResultSetColumn) ) {

        my $str = $ddp->maybe_colorize( ref($obj), 'class' );
        $str .= ' (' . $obj->result_class . ')'
          if $obj->can( 'result_class' );

        if (my $query_data = $obj->as_query) {
          my @query_data = @$$query_data;
          $ddp->indent;
          my $sql = shift @query_data;
          $str .= ' {'
               . $ddp->newline . $ddp->maybe_colorize($sql, 'string')
               . $ddp->newline . join ( $ddp->newline, map {
                      $_->[1] . ' (' . $_->[0]{sqlt_datatype} . ')'
                    } @query_data
               )
               ;
          $ddp->outdent;
          $str .= $ddp->newline . '}';
        }

        return $str;
    }
    else {
        return;
    }
};

1;
__END__

=head1 NAME

Data::Printer::Filter::DB - pretty-printing database objects (DBI, DBIx::Class, etc)

=head1 SYNOPSIS

In your C<.dataprinter> file:

    filters = DB

You may also customize the look and feel with the following options:

    filter_db.expand_dbh = 1

    # you can even customize your themes:
    colors.filter_db_connected    = #00cc00
    colors.filter_db_disconnected = #cc0000

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

    # set to 'expand' to view source details, or 'none' to skip it:
    filter_db.schema.loaded_sources = names

B<DBIx::Class::ResultSource> objects will be expanded to show details
of what that source represents on the database, including column information
and whether the table is virtual or not. For example:

    User ResultSource (Virtual View) {
        table: "user"
        columns:
            name varchar(100) null
        belongs to: 
    }

=head4 Ever got bit by DBIx::Class?

Let us know if we can help by creating an issue on Data::Printer's Github.
Patches are welcome!

=head1 SEE ALSO

L<Data::Printer>
