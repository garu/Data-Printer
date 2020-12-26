package Data::Printer::Config;
use strict;
use warnings;
use Data::Printer::Common;

sub load_rc_file {
    my ($filename) = @_;
    if (!$filename) {
        $filename = _get_first_rc_file_available();
    }
    return unless $filename && -e $filename && !-d $filename;
    if (open my $fh, '<', $filename) {

        # slurp the file:
        my $rc_data;
        { local $/ = undef; $rc_data = <$fh> }
        close $fh;
        return _str2data($filename, $rc_data);
    }
    else {
        Data::Printer::Common::_warn("error opening '$filename': $!");
        return;
    }
}

sub _get_first_rc_file_available {
    return $ENV{DATAPRINTERRC} if exists $ENV{DATAPRINTERRC};

    # look for a .dataprinter file on the project home up until we reach '/'
    my $dir = _project_home();
    require File::Spec;
    while (defined $dir) {
        my $file = File::Spec->catfile($dir, '.dataprinter');
        return $file if -f $file;
        (my $updir = $dir) =~ s{/[^\/]+/?\z}{/};
        last if !defined $updir || $updir eq $dir;
        $dir = $updir;
    }
    # still here? look for .dataprinter on the user's HOME:
    return File::Spec->catfile( _my_home(), '.dataprinter');
}

sub _my_cwd {
    require Cwd;
    my $cwd = Cwd::getcwd();
    # try harder if we can't access the current dir.
    $cwd = Cwd::cwd() unless defined $cwd;
    return $cwd;
}

sub _project_home {
    require Cwd;
    if ($0 eq '-e' || $0 eq '-') {
        my $path = _my_cwd();
        return Cwd::abs_path($path) if defined $path;
    }
    else {
        my $script = $0;
        return unless -f $script;
        require File::Spec;
        require File::Basename;
        # we need the full path if we have chdir'd:
        $script = File::Spec->catfile(_my_cwd(), $script)
            unless File::Spec->file_name_is_absolute($script);
        my (undef, $path) = File::Basename::fileparse($script);
        return Cwd::abs_path($path) if defined $path;
    }
    return;
}

# adapted from File::HomeDir && File::HomeDir::Tiny
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
    elsif ($^O eq 'MSWin32' and "$]" < 5.016) {
        return $ENV{HOME} || $ENV{USERPROFILE};
    }
    elsif ($^O eq 'MacOS') {
        my $error = _tryme(sub { require Mac::SystemDirectory; 1 });
        return Mac::SystemDirectory::HomeDirectory() unless $error;
    }
    # this is the most common case, for most breeds of unix, as well as
    # MSWin32 in more recent perls.
    my $home = (<~>)[0];
    return $home if $home;

    # desperate measures that should never be needed.
    if (exists $ENV{LOGDIR} and $ENV{LOGDIR}) {
        $home = $ENV{LOGDIR};
    }
    if (not $home and exists $ENV{HOME} and $ENV{HOME}) {
        $home = $ENV{HOME};
    }
    # Light desperation on any (Unixish) platform
    SCOPE: { $home = (getpwuid($<))[7] if not defined $home }
    if (defined $home and ! -d $home ) {
        $home = undef;
    }
    return $home;
}

sub _str2data {
    my ($filename, $content) = @_;
    my $config = { _ => {} };
    my $counter = 0;
    my $filter;
    my $can_use_filters;
    my $ns = '_';
    # based on Config::Tiny
    foreach ( split /(?:\015{1,2}\012|\015|\012)/, $content ) {
        $counter++;
        if (defined $filter) {
            if ( /^end filter\s*$/ ) {
                if (!defined $can_use_filters) {
                    my $mode = sprintf('%04o', (stat(q(/Users/garu/.dataprinter)))[2] & 07777);
                    $can_use_filters = (length($mode) == 4 && substr($mode, 2, 2) eq '00') ? 1 : 0;
                }
                if ($can_use_filters) {
                    my $sub_str = 'sub { my ($obj, $ddp) = @_; '
                                . $filter->{code_str}
                                . '}'
                                ;
                    push @{$config->{$ns}{filters}}, +{ $filter->{name} => eval $sub_str };
                }
                else {
                    Data::Printer::Common::_warn("ignored filter '$filter->{name}' from rc file '$filename': file is readable/writeable by others");
                }
                $filter = undef;
            }
            elsif ( /^begin\s+filter/ ) {
                Data::Printer::Common::_warn("error reading rc file '$filename' line $counter: found 'begin filter' inside another filter definition ($filter->{name}). Are you missing an 'end filter' on line " . ($counter - 1) . '?');
                return {};
            }
            else {
                $filter->{code_str} .= $_;
            }
        }
        elsif ( /^\s*(?:\#|\;|$)/ ) {
            next # skip comments and empty lines
        }
        elsif ( /^\s*\[\s*(.+?)\s*\]\s*$/ ) {
            # Create the sub-hash if it doesn't exist.
            # Without this sections without keys will not
            # appear at all in the completed struct.
            $config->{$ns = $1} ||= {};
        }
        elsif ( /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ ) {
            # Handle properties:
            my ($path_str, $value) = ($1, $2);
            # turn a.b.c.d into {a}{b}{c}{d}
            my @subpath = split /\./, $path_str;
            my $current = $config->{$ns};

            # remove single/double (enclosing) quotes
            $value =~ s/\A(['"])(.*)\1\z/$2/;

            # the root "filters" key is a special case, because we want
            # it to always be an arrayref. In other words:
            #     filters = abc,def    --> filters => ['abc', 'def']
            #     filters = abc        --> filters => ['abc']
            #     filters =            --> filters => []
            if (@subpath == 1 && $subpath[0] eq 'filters') {
                $value = [ split /\s*,\s*/ => $value ];
            }

            while (my $subpath = shift @subpath) {
                if (@subpath > 0) {
                    $current->{$subpath} ||= {};
                    $current = $current->{$subpath};
                }
                else {
                    $current->{$subpath} = $value;
                }
            }
        }
        elsif ( /^begin\s+filter\s+([^\s]+)\s*$/ ) {
            my $filter_name = $1;
            $filter = { name => $filter_name, code_str => '' };
        }
        else {
            Data::Printer::Common::_warn("error reading rc file '$filename': syntax error at line $counter: $_");
            if ($counter == 1 && /\A\s*{/s) {
                Data::Printer::Common::_warn(
                    "RC file format changed in 1.00. Usually all it takes is:\n"
                  . "cp $filename $filename.old && perl -MData::Printer::Config -E 'say Data::Printer::Config::convert(q($filename))' > $filename\n"
                  . "Please visit https://metacpan.org/pod/Data::Printer::Config for details."
                );
            }
            return {};
        }
    }
    return $config;
}

# converts the old format to the new one
sub convert {
    my ($filename) = @_;
    Data::Printer::Common::_die("please provide a .dataprinter file path")
        unless $filename;
    Data::Printer::Common::_die("file '$filename' not found")
        unless -e $filename && !-d $filename;
    open my $fh, '<', $filename
        or Data::Printer::Common::_die("error reading file '$filename': $!");

    my $rc_data;
    { local $/; $rc_data = <$fh> }
    close $fh;

    my $config = eval $rc_data;
    if ( $@ ) {
        Data::Printer::Common::_die("error loading file '$filename': $@");
    }
    elsif (!ref $config or ref $config ne 'HASH') {
        Data::Printer::Common::_die("error loading file '$filename': config file must return a hash reference");
    }
    else {
        return _convert('', $config);
    }
}

sub _convert {
    my ($key_str, $value) = @_;
    if (ref $value eq 'HASH') {
        my $str = '';
        foreach my $k (sort keys %$value) {
            $str .= _convert(($key_str ? "$key_str.$k" : $k), $value->{$k});
        }
        return $str;
    }
    if ($key_str && $key_str eq 'filters.-external' && ref $value eq 'ARRAY') {
        return 'filters = ' . join(', ' => @$value) . "\n";
    }
    elsif (ref $value) {
        Data::Printer::Common::_warn(
            " [*] path '$key_str': expected scalar, found " . ref($value)
          . ". Filters must be in their own class now, loaded with 'filter'.\n"
          . "If you absolutely must put custom filters in, use the 'begin filter'"
          . " / 'end filter' options manually, as explained in the documentation,"
          . " making sure your .dataprinter file is not readable nor writeable to"
          . " anyone other than your user."
        );
        return '';
    }
    else {
        $value = "'$value'" if $value =~ /\s/;
        return "$key_str = $value\n";
    }
}

1;
__END__

=head1 NAME

Data::Printer::Config - Load run-control (.dataprinter) files for Data::Printer

=head1 DESCRIPTION

This module is used internally to load C<.dataprinter> files.

=head1 THE RC FILE

    # line comments are ok with "#" or ";"
    ; this is also a full line comment.
    ; Comments at the end of a line (inline) are not allowed
    multiline  = 0
    hash_max   = 5
    array_max  = 5
    string_max = 50
    # use quotes if you need spaces to be significant:
    hash_separator = " => "
    class.show_methods = none
    class.internals    = 0
    filters = DB, Web

    # if you tag a class, those settings will override your basic ones
    # whenever you call p() inside that class.
    [MyApp::Some::Class]
    multiline = 1
    show_tainted: 1
    class.format_inheritance = lines
    filters = MyAwesomeDebugFilter

    [Other::Class]
    theme = Monokai

    ; use "begin filter NAME" and "end filter" to add custom filter code.
    ; it will expose $obj (the data structure to be parsed) and $ddp
    ; (data printer's object). YOU MAY ONLY DO THIS IF YOUR FILE IS ONLY
    ; READABLE AND WRITEABLE BY THE USER (i.e. chmod 0600).
    begin filter HTTP::Request
        return $ddp->maybe_colorize($obj->method . ' ' . $obj->uri, 'string')
             . $obj->decoded_content;
    end filter


=head1 PUBLIC INTERFACE

This module is not meant for public use. However, because Data::Printer
changed the format of the configuration file, we provide the following
public function for people to use:

=head2 convert( $filename )

    perl -MDDP -E 'say Data::Printer::Config::convert( q(/path/to/my/.dataprinter) )'

Loads a deprecated (pre-1.0) configuration file and returns a string
with a (hopefully) converted version, which you can use for newer (post-1.0)
versions.

Other public functions, not really meant for general consumption, are:

=over 4

=item * C<load_rc_file( $filename )> - loads a configuration file and returns
the associated data structure. If no filename is provided, looks
for C<.dataprinter>.

=back

=head1 SEE ALSO

L<Data::Printer>
