use strict;
use warnings;
use Test::More tests => 14;
use Data::Printer::Config;
use Data::Printer::Common;

my $good_content = <<'EOTEXT';

# some comment
    # another comment
whatever = Something Interesting
answer         =   42
class.data.may.be.deep = 0 but true
class.data.may.not = 1
class.simple = bla
    ; and
; some more comments
filters = Foo, Bar
spaced1 = '   '
spaced2 = '  " '
spaced3 = "   "
spaced4 = " ' "

[Some::Module]
meep = moop
filters = Meep

   [Other::Module]
hard.times = come.easy
filters =

EOTEXT

my $expected = {
    _ => {
        answer => 42,
        spaced1 => q(   ),
        spaced2 => q(  " ),
        spaced3 => q(   ),
        spaced4 => q( ' ),
        whatever => 'Something Interesting',
        class => {
            simple => 'bla',
            data => {
                may => {
                    not => 1,
                    be => {
                        deep => '0 but true',
                    }
                }
            }
        },
        filters => ['Foo', 'Bar'],
    },
    'Some::Module' => { meep => 'moop', filters => ['Meep'] },
    'Other::Module' => { hard => { times => 'come.easy' }, filters => [] }
};

my $data = Data::Printer::Config::_str2data('data.rc', $good_content);
is_deeply($data, $expected, 'parsed rc file');


my $warn_count = 0;
{ no warnings 'redefine';
    *Data::Printer::Common::_warn = sub {
        my $message = shift;
        $warn_count++;
        if ($warn_count == 1) {
            like $message, qr/error reading rc file/, 'message about parse error found';
        }
        else {
            like $message, qr/RC file format changed in/, 'helper message found';
        }
    };
}

my $bad_content = <<'EOLEGACY';
{
    foo => 123
}
EOLEGACY

my $data2 = Data::Printer::Config::_str2data('data.rc', $bad_content);
is_deeply($data2, {}, 'parse error returns valid structure');

SKIP: {
    my $skipped_tests = 4;
    my $dir = Data::Printer::Common::_my_home('testing');
    skip "unable to create temp dir", $skipped_tests unless $dir && -d $dir;
    require File::Spec;
    my $filename = File::Spec->catfile($dir, '.dataprinter');

    my $error = Data::Printer::Common::_tryme(sub {
        open my $fh, '>', $filename
            or die "error creating test rc file $filename: $!";
        print $fh $good_content or die "error writing to test rc file $filename: $!";
        return 1;
    });
    skip $error, 11 if $error;

    my $data_from_rc = Data::Printer::Config::load_rc_file($filename);
    is_deeply($data_from_rc, $expected, 'loaded rc file');
    {
        local %ENV = %ENV;
        $ENV{DATAPRINTERRC} = $filename;
        { no warnings 'redefine';
          *Data::Printer::Common::_my_home = sub { fail 'should never be reached'; die };
        }
        my $data_from_env = Data::Printer::Config::load_rc_file();
        is_deeply($data_from_env, $expected, 'loaded rc file from ENV');
        delete $ENV{DATAPRINTERRC};
        my $found_me = 0;
        { no warnings 'redefine';
          *Data::Printer::Common::_my_home = sub { $found_me = 1; return $dir };
        }
        my $data_from_home = Data::Printer::Config::load_rc_file();
        is $found_me, 1, 'overriden homedir was found';
        is_deeply($data_from_home, $expected, 'loaded rc file from (custom) home');
    }

    $error = Data::Printer::Common::_tryme(sub {
        Data::Printer::Config::convert();
    });
    like $error, qr/please provide a .dataprinter file path/, 'convert() with no file';
    $error = Data::Printer::Common::_tryme(sub {
        Data::Printer::Config::convert($dir);
    });
    like $error, qr/file '\Q$dir\E' not found/, 'convert() with dir, not file';
    $error = Data::Printer::Common::_tryme(sub {
        open my $fh, '>', $filename
            or die "error creating test rc file $filename: $!";
        print $fh '1' or die "error writing to test rc file $filename: $!";
        return 1;
    });
    skip $error, 4 if $error;
    $error = Data::Printer::Common::_tryme(sub {
        Data::Printer::Config::convert($filename);
    });
    like $error, qr/config file must return a hash reference/, 'convert() with file not returning hash reference';

    my $content_to_convert = <<'EOCONTENT';
{
   foo => 1,
   bar => 'bla',
   outer => {
     inner    => { further => 'hello!' },
     greeting => 'hej hej',
     other    => sub { return 1 },
   },
}
EOCONTENT

    my $warn_message;
    my $warn_count = 0;
    {no warnings 'redefine';
     *Data::Printer::Common::_warn = sub { $warn_message = shift; $warn_count++; };
    };

    $error = Data::Printer::Common::_tryme(sub {
        open my $fh, '>', $filename
            or die "error creating test rc file $filename: $!";
        print $fh $content_to_convert or die "error writing to test rc file $filename: $!";
        return 1;
    });

    ####
    skip $error, 3 if $error;
    my $converted;
    $error = Data::Printer::Common::_tryme(sub {
        $converted = Data::Printer::Config::convert($filename);
    });
    is $warn_count, 1, 'only got one warning';
    like $warn_message, qr/path 'outer.other': expected scalar, found/, 'proper warning';
    is $converted, <<'EOCONFIG';
bar = bla
foo = 1
outer.greeting = hej hej
outer.inner.further = hello!
EOCONFIG
};
