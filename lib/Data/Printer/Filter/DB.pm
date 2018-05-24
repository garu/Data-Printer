package Data::Printer::Filter::DB;
use strict;
use warnings;
use Data::Printer::Filter;

filter 'DBI::db', sub {
    my ($dbh, $ddp) = @_;
    my $name = $dbh->{Driver}{Name};

    my $string = "$name Database Handle ("
               . ($dbh->{Active}
                  ? $ddp->maybe_colorize('connected', 'filter_db_connected', '#a0d332')
                  : $ddp->maybe_colorize('disconnected', 'filter_db_disconnected', '#b3422d'))
               . ') {'
               ;
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
    return ref($schema) . ' DBIC Schema with ' . $ddp->parse( $schema->storage->dbh );
    # TODO: show a list of all class_mappings available for the schema
    #       (a.k.a. tables)
};

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

And if you have a statement handler like this (for example):

    my $sth = $dbh->prepare('SELECT * FROM foo WHERE bar = ?');
    $sth->execute(42);

    use DDP; p $sth;

This is what you'll get:

    SELECT * FROM foo WHERE bar = ?  (42)

Note that if your driver does not support holding of parameter values, you'll get a
C<bindings unavailable> message instead of the bound values.

=head3 L<DBIx::Class>


=head1 SEE ALSO

L<Data::Printer>
