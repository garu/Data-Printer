use strict;
use warnings;
use Test::More tests => 23;
use Data::Printer::Config;
use Data::Printer::Object;
use File::Spec;

my @warnings;
{ no warnings 'redefine';
    *Data::Printer::Common::_warn = sub { push @warnings, $_[1] };
}

my $profile = Data::Printer::Config::_expand_profile({ profile => 'Invalid;Name!' });

is ref $profile, 'HASH', 'profile expanded into hash';
is_deeply $profile, {}, 'bogus profile not loaded';
is @warnings, 1, 'invalid profile triggers warning';
like $warnings[0], qr/invalid profile name/, 'right message on invalid profile';

@warnings = ();
$profile = Data::Printer::Config::_expand_profile({ colored => 1, profile => 'Invalid;Name!' });
is ref $profile, 'HASH', 'profile expanded into hash';
is_deeply $profile, { colored => 1 }, 'options preserved after bogus profile not loaded';
is @warnings, 1, 'invalid profile triggers warning (2)';
like $warnings[0], qr/invalid profile name/, 'right message on invalid profile (2)';

@warnings = ();
$profile = Data::Printer::Config::_expand_profile({ colored => 1, profile => 'BogusProfile' });
is ref $profile, 'HASH', '(bad) profile expanded into hash';
is_deeply $profile, { colored => 1 }, 'options preserved after bogus profile not loaded (3)';
is @warnings, 1, 'invalid profile triggers warning (3)';
like $warnings[0], qr/unable to load profile/, 'right message on invalid profile (3)';

@warnings = ();
$profile = Data::Printer::Config::_expand_profile({ profile => 'Dumper' });
is @warnings, 0, 'no warnings after proper profile loaded';
is $profile->{name}, '$VAR1->', 'profile loaded ok';
is $profile->{colored}, 0, 'profile color set';

@warnings = ();
$profile = Data::Printer::Config::_expand_profile({ colored => 1, profile => 'Dumper' });
is @warnings, 0, 'no warnings after proper profile loaded with extra options';
is $profile->{name}, '$VAR1->', 'profile with extra options loaded ok';
is $profile->{colored}, 1, 'profile color properly overriden';

@warnings = ();
$profile = Data::Printer::Config::_expand_profile({ profile => 'Dumper' });
is @warnings, 0, 'dumper profile loaded';

my $ddp = Data::Printer::Object->new($profile);

my $lvalue = \substr("abc", 2);
my $file = File::Spec->catfile(
    Data::Printer::Config::_my_home('testing'), 'test_file.dat'
);
open my $glob, '>', $file or skip "error opening '$file': $!", 1;

format TEST =
.
my $format = *TEST{FORMAT};

my $vstring = v1.2.3;

my $scalar = 1;

@warnings = ();
my $output = $ddp->parse({
    foo => [undef, $scalar, 'two', qr/123/, $glob, $lvalue, \321, $vstring, $format, sub {}, bless \$scalar, 'TestClass']
});
is @warnings, 2, 'dumper profile is unable to parse 2 types of ref';
like $warnings[0], qr/cannot handle ref type 10/, 'dumper warning on lvalue';
like $warnings[1], qr/cannot handle ref type 14/, 'dumper warning on format';

my $expected = <<'EODUMPER';
$VAR1 = {
          'foo' => [
                    undef,
                    1,
                    'two',
                    qr/123/,
                    \*{'::$glob'},
                    ,
                    \ 321,
                    v1.2.3,
                    ,
                    sub { "DUMMY" },
                    bless( do{\(my $o = 1)}, 'TestClass' )
          ]
};
EODUMPER
chop $expected; # remove last newline

is $output, $expected, 'proper result in dumper profile';
