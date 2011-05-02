package Data::Printer::Filter::DB;
use strict;
use warnings;
use Data::Printer::Filter;
use Term::ANSIColor;

filter 'DBI::db', sub {
    my ($dbh, $p) = @_;
    my $name = $dbh->{Driver}{Name};

    my $string = "$name Database Handle ("
               . ($dbh->{Active} 
                  ? colored('connected', 'bright_green')
                  : colored('disconnected', 'bright_red'))
               . ') {'
               ;
    indent;
    my %dsn = split( /[;=]/, $dbh->{Name} );
    foreach my $k (keys %dsn) {
        $string .= newline . "$k: " . $dsn{$k};
    }
    $string .= newline . 'Auto Commit: ' . $dbh->{AutoCommit};

    my $kids = $dbh->{Kids};
    $string .= newline . 'Statement Handles: ' . $kids;
    if ($kids > 0) {
        $string .= ' (' . $dbh->{ActiveKids} . ' active)';
    }

    if ( defined $dbh->err ) {
        $string .= newline . 'Error: ' . $dbh->errstr;
    }
    $string .= newline . 'Last Statement: '
            . colored( ($dbh->{Statement} || '-'), 'bright_yellow');

    outdent;
    $string .= newline . '}';
    return $string;
};

filter 'DBI::st', sub {
    my ($sth, $properties) = @_;
    my $str = colored( ($sth->{Statement} || '-'), 'bright_yellow');

    if ($sth->{NUM_OF_PARAMS} > 0) {
        my $values = $sth->{ParamValues};
        if ($values) {
            $str .= '  (' 
                 . join(', ',
                      map {
                         my $v = $values->{$_};
                         $v || 'undef';
                      } 1 .. $sth->{NUM_OF_PARAMS}
                   )
                 . ')';
        }
        else {
            $str .= colored('  (bindings unavailable)', 'yellow');
        }
    }
    return $str;
};

1;
__END__









