use strict;
use warnings;
use Test::More tests => 39;
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

[Module::With::CustomFilter]
option = val

begin filter MockObj
    return ($ddp, $obj, 'ok!');
end filter

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
    'Other::Module' => { hard => { times => 'come.easy' }, filters => [] },
    'Module::With::CustomFilter' => { option => 'val', filters => [{ MockObj => sub {}}] }
};

my $warn_count = 0;
{ no warnings 'redefine';
    *Data::Printer::Common::_warn = sub {
        my (undef, $message) = @_;
        $warn_count++;
        like $message, qr/ignored filter 'MockObj' from rc file/, 'skip filters on permissive rc files';
    }
}
my $data = Data::Printer::Config::_str2data('data.rc', $good_content);
is $warn_count, 1, 'warning caught due to bad filters';
is_deeply($data, {
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
    'Other::Module' => { hard => { times => 'come.easy' }, filters => [] },
    'Module::With::CustomFilter' => { option => 'val' }
}, 'filter was properly ignored');

{ no warnings 'redefine';
    *Data::Printer::Config::_file_mode_is_restricted = sub { 1 };
}
$warn_count = 0;
$data = Data::Printer::Config::_str2data('data.rc', $good_content);
is $warn_count, 0, 'no new warnings caught';
ok exists $data->{'Module::With::CustomFilter'}{filters}[0]{MockObj}, 'parsed MockObj';
is ref $data->{'Module::With::CustomFilter'}{filters}[0]{MockObj}, 'CODE', 'subref was set.';

ok my @filter_ret = $data->{'Module::With::CustomFilter'}{filters}[0]{MockObj}->(123, 456), 'able to call filter function';
is_deeply(\@filter_ret, [456, 123, 'ok!'], 'variables and code properly set!');

$expected->{'Module::With::CustomFilter'}{filters}[0]{MockObj}
    = $data->{'Module::With::CustomFilter'}{filters}[0]{MockObj};
is_deeply($data, $expected, 'parsed rc file');

{ no warnings 'redefine';
    *Data::Printer::Common::_warn = sub {
        my (undef, $message) = @_;
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
is $warn_count, 2, 'parse error issues warnings';
$warn_count = 0;

$bad_content = <<'EODOUBLEBEGIN';
begin filter lala
begin filter lele
end filter lele
end filter lala
EODOUBLEBEGIN

my $double_begin = Data::Printer::Config::_str2data('data.rc', $bad_content);
is_deeply($double_begin, {}, 'double begin returns valid structure');
is $warn_count, 1, 'double begin issues warnings';
$warn_count = 0;


SKIP: {
    my $dir = Data::Printer::Config::_my_home('testing');
    skip "unable to create temp dir", 22 unless $dir && -d $dir;
    require File::Spec;
    my $filename = File::Spec->catfile($dir, '.dataprinter');

    my $error = Data::Printer::Common::_tryme(sub {
        open my $fh, '>', $filename
            or die "error creating test rc file $filename: $!";
        print $fh $good_content or die "error writing to test rc file $filename: $!";
        return 1;
    });
    skip $error, 22 if $error;

    my $data_from_rc = Data::Printer::Config::load_rc_file($filename);
    $expected->{'Module::With::CustomFilter'}{filters}[0]{MockObj}
        = $data_from_rc->{'Module::With::CustomFilter'}{filters}[0]{MockObj};
    is_deeply($data_from_rc, $expected, 'loaded rc file');
    is $warn_count, 0, 'no warnings after proper rc file';

    {
        local %ENV = %ENV;
        $ENV{DATAPRINTERRC} = $filename;
        { no warnings 'redefine';
          *Data::Printer::Config::_project_home = sub { fail '(project) should never be reached'; die };
          *Data::Printer::Config::_my_home = sub { fail '(home) should never be reached'; die };
        }
        my $data_from_env = Data::Printer::Config::load_rc_file();
        is $warn_count, 0, 'no warnings after proper rc loaded from env';
        ok exists $data_from_env->{'Module::With::CustomFilter'}{filters}[0]{MockObj}, 'parsed MockObj';
        is ref $data_from_env->{'Module::With::CustomFilter'}{filters}[0]{MockObj}, 'CODE', 'subref was set.';
        $expected->{'Module::With::CustomFilter'}{filters}[0]{MockObj}
            = $data_from_env->{'Module::With::CustomFilter'}{filters}[0]{MockObj};

        is_deeply($data_from_env, $expected, 'loaded rc file from ENV');
        delete $ENV{DATAPRINTERRC};
        my $found_me = 0;
        { no warnings 'redefine';
            *Data::Printer::Config::_project_home = sub { $found_me = 1; return File::Spec->catdir($dir, 'lala') };
        }
        my $data_from_project = Data::Printer::Config::load_rc_file();
        is $found_me, 1, 'overriden project dir was found';
        is $warn_count, 0, 'no warnings after rc loaded from project home';
        ok exists $data_from_project->{'Module::With::CustomFilter'}{filters}[0]{MockObj}, 'parsed MockObj';
        is ref $data_from_project->{'Module::With::CustomFilter'}{filters}[0]{MockObj}, 'CODE', 'subref was set.';
        $expected->{'Module::With::CustomFilter'}{filters}[0]{MockObj}
            = $data_from_project->{'Module::With::CustomFilter'}{filters}[0]{MockObj};

        is_deeply($data_from_project, $expected, 'loaded rc file from (custom) project dir');

        $found_me = 0;
        { no warnings 'redefine';
            *Data::Printer::Config::_project_home = sub { return; };
            *Data::Printer::Config::_my_home = sub { $found_me = 1; return $dir };
        }
        my $data_from_home = Data::Printer::Config::load_rc_file();
        is $found_me, 1, 'overriden homedir was found';
        is $warn_count, 0, 'no warnings after rc loaded from project home';
        ok exists $data_from_home->{'Module::With::CustomFilter'}{filters}[0]{MockObj}, 'parsed MockObj';
        is ref $data_from_home->{'Module::With::CustomFilter'}{filters}[0]{MockObj}, 'CODE', 'subref was set.';
        $expected->{'Module::With::CustomFilter'}{filters}[0]{MockObj}
            = $data_from_home->{'Module::With::CustomFilter'}{filters}[0]{MockObj};

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
   color => { number => 'cyan' },
   filters => {
     -external => ['Something'],
     SCALAR => sub { 1 },
   },
}
EOCONTENT

    my @warn_messages;
    {no warnings 'redefine';
     *Data::Printer::Common::_warn = sub { push @warn_messages, $_[1]; };
    };

    $error = Data::Printer::Common::_tryme(sub {
        open my $fh, '>', $filename
            or die "error creating test rc file $filename: $!";
        print $fh $content_to_convert or die "error writing to test rc file $filename: $!";
        return 1;
    });

    ####
    skip $error, 4 if $error;
    my $converted;
    $error = Data::Printer::Common::_tryme(sub {
        $converted = Data::Printer::Config::convert($filename);
    });
    is @warn_messages, 2, 'two warnings generated';
    like $warn_messages[0], qr/path 'filters.SCALAR': expected scalar, found/, 'proper warning for filter subref';
    like $warn_messages[1], qr/path 'outer.other': expected scalar, found/, 'proper warning for subref';

    my $expected_conversion = <<'EOCONFIG';
bar = bla
colors.number = cyan
filters = Something
foo = 1
outer.greeting = 'hej hej'
outer.inner.further = hello!
EOCONFIG

    is $converted, $expected_conversion, 'rc file converted successfully';
};
