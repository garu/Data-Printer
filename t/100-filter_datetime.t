use strict;
use warnings;
use Test::More tests => 25;
use Data::Printer::Object;

my $has_timepiece;

BEGIN {
    # Time::Piece is only able to overload
    # localtime() if it's loaded during compile-time
    $has_timepiece = !! eval 'use Time::Piece; 1';
};

test_time_piece();
test_datetime();
test_datetime_timezone();
test_datetime_incomplete();
test_datetime_tiny();
test_date_tiny();
test_date_calc_object();
test_date_pcalc_object();
test_date_handler();
test_date_simple();
test_mojo_date();
test_date_manip();
test_class_date();
test_panda_date();
test_time_seconds();
test_time_moment();

sub test_time_piece {
    SKIP: {
        my $how_many = 3;
        skip 'Time::Piece not available', $how_many
            unless $has_timepiece;

        my $t = localtime 1234567890;
        skip 'localtime not returning an object', $how_many
            unless ref $t and ref $t eq 'Time::Piece';

        # we can't use a literal in our tests because of
        # timezone and epoch issues
        my $time_str = $t->cdate;

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );

        is ( $ddp->parse($t), $time_str, 'Time::Piece' );

        $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
            filter_datetime => { show_class_name => 1 }
        );

        is ( $ddp->parse($t),
            "$time_str (Time::Piece)",
            'Time::Piece with class name'
        );

        $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime', { HASH => sub { 'a hash!' } }],
        );

        is (
            $ddp->parse([$t, {}]),
            "[
    [0] $time_str,
    [1] a hash!
]", 'inline and class filters together (Time::Piece)'
        );
    };
}

sub test_datetime {
    SKIP: {
        skip 'DateTime not available', 3 unless eval 'use DateTime; 1';
        my $d1 = DateTime->new(
            year      => 1981,
            month     =>  9,
            day       => 29,
            time_zone => 'floating',
        );
        my $d2 = DateTime->new(
            year      => 1984,
            month     => 11,
            day       => 15,
            time_zone => 'floating',
        );

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime']
        );
        is( $ddp->parse($d1), '1981-09-29T00:00:00 [floating]', 'DateTime' );

        $ddp = Data::Printer::Object->new(
            colored         => 0,
            filters         => ['DateTime'],
            filter_datetime => { show_timezone => 0 },
        );
        is( $ddp->parse($d1), '1981-09-29T00:00:00', 'DateTime without TZ data' );

        my $diff;
        skip 'DateTime::Duration not available', 1
            unless eval { $diff = $d2 - $d1; $diff && $diff->isa('DateTime::Duration') };

        $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is( $ddp->parse($diff), '3y 1m 16d 0h 0m 0s', 'DateTime::Duration' );
    };
}

sub test_datetime_timezone {
    SKIP: {
        my $d;
        skip 'DateTime::TimeZone not found', 1
            unless eval 'use DateTime::Duration; use DateTime::TimeZone; 1';
        eval { $d = DateTime::TimeZone->new( name => 'America/Sao_Paulo' ) };
        skip 'Error creating DateTime::TimeZone object', 1 unless $d;
        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );

        is( $ddp->parse($d), 'America/Sao_Paulo', 'DateTime::TimeZone' );
    };
}

sub test_datetime_incomplete {
    SKIP: {
        skip 'DateTime::Incomplete not found', 1, unless eval 'use DateTime::Incomplete; 1';
        my $d = DateTime::Incomplete->new( year => 2018 );
        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is( $ddp->parse($d), '2018-xx-xxTxx:xx:xx', 'DateTime::Incomplete' );
    };
}

sub test_datetime_tiny {
    SKIP: {
        skip 'DateTime::Tiny not found', 1, unless eval 'use DateTime::Tiny; 1';
        my $d = DateTime::Tiny->new( year => 2003, month => 3, day => 11 );
        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is( $ddp->parse($d), '2003-03-11T00:00:00', 'DateTime::Tiny' );
    };
}

sub test_date_tiny {
    SKIP: {
        skip 'Date::Tiny not found', 1, unless eval 'use Date::Tiny; 1';
        my $d = Date::Tiny->new( year => 2003, month => 3, day => 11 );
        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is( $ddp->parse($d), '2003-03-11', 'Date::Tiny' );
    };
}

sub test_date_calc_object {
    SKIP: {
        skip 'Date::Calc::Object not found', 1, unless eval 'use Date::Calc::Object; 1';
        my $d = Date::Calc::Object->localtime( 1234567890 );

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        my $string = $d->string(2); # not sure when the epoch is :X
        is( $ddp->parse($d), $string, 'Date::Calc::Object' );
    };
}

sub test_date_pcalc_object {
    SKIP: {
        skip 'Date::Pcalc::Object not found', 1, unless eval 'use Date::Pcalc::Object; 1';
        my $d = Date::Pcalc::Object->localtime( 1234567890 );

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        my $string = $d->string(2); # not sure when the epoch is :X
        is( $ddp->parse($d), $string, 'Date::Pcalc::Object' );
    };
}

sub test_date_handler {
    SKIP: {
        skip 'Date::Handler not found', 2, unless eval 'use Date::Handler; 1';
        my $d = Date::Handler->new( date => 1234567890 );
        my $string = "$d"; # not sure when the epoch is :X

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is( $ddp->parse($d), $string, 'Date::Handler' );
        my $diff;
        skip 'Date::Handler::Delta not found', 1 unless eval {
            require Date::Handler::Delta;
            $diff = Date::Handler->new( date => 1234567893 ) - $d;
            $diff && $diff->isa('Date::Handler::Delta')
        };
        $string = $diff->AsScalar;
        is( $ddp->parse($diff), $string, 'Date::Handler::Delta' );
    };
}

sub test_date_simple {
    SKIP: {
        skip 'Date::Simple not found', 1, unless eval 'use Date::Simple; 1';
        my $d = Date::Simple->new('2018-05-19');

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is( $ddp->parse($d), '2018-05-19', 'Date::Simple' );
    };
}

sub test_mojo_date {
    SKIP: {
        skip 'Mojo::Date not found', 1 unless eval 'use Mojo::Date; 1';
        my $d = Mojo::Date->new('Sun, 06 Nov 1994 08:49:37 GMT');
        skip 'Mojo::Date is too old', 1 unless $d->can('to_datetime');

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is( $ddp->parse($d), '1994-11-06T08:49:37Z', 'Mojo::Date' );
    };
}

sub test_date_manip {
    SKIP: {
        skip 'Date::Manip::Date not found', 1, unless eval 'use Date::Manip::Date; 1';

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        my $d;
        skip 'Date::Manip too old, skipping test', 1 unless eval {
            $d = Date::Manip::Date->new('2000-01-21-12:00:00')
        };
        is( $ddp->parse(\$d), '2000012112:00:00', 'Date::Manip::Obj' );
    };
}

sub test_class_date {
    SKIP: {
        skip 'Class::Date not found', 2, unless eval 'use Class::Date; 1';
        my $d = Class::Date::date({ year => 2003, month => 3, day => 11 }, 'GMT');

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        my $parsed = $ddp->parse($d);
        ok(
               $parsed eq '2003-03-11 00:00:00 [GMT]'
            || $parsed eq '2003-03-11 00:00:00 [UTC]' # some BSDs name GTM as UTC
            , "Class::Date is '$parsed'"
        );

        skip 'Class::Date::Rel not found', 1 unless eval 'use Class::Date::Rel; 1';
        my $reldate = Class::Date::Rel->new( "3Y 1M 3D 6h 2m 4s" );
        is( $ddp->parse($reldate), '3Y 1M 3D 6h 2m 4s', 'Class::Date::Rel' );
    };
}

sub test_time_seconds {
    SKIP: {
        skip 'Time:Seconds not found', 1, unless eval 'use Time::Seconds; 1';
        my $d = Time::Seconds->new();

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is($ddp->parse($d), '0 seconds', "Time::Seconds");
    };
}

sub test_time_moment {
    SKIP: {
        skip 'Time:Moment not found', 1, unless eval 'use Time::Moment; 1';
        my $d = Time::Moment->new(
            year       => 2012,
            month      => 12,
            day        => 24,
            hour       => 15,
            minute     => 30,
            second     => 45,
            offset     => 0,
        );

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );
        is($ddp->parse($d), '2012-12-24T15:30:45Z', "Time::Moment");
    };
}

sub test_panda_date {
    SKIP: {
        skip 'Panda::Date not found', 4, unless eval 'use Panda::Date; 1';
        my $d = Panda::Date->new(
            { year => 2003, month => 3, day => 11 },
            'GMT'
        );

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );

        is( $ddp->parse($d), '2003-03-11 00:00:00 [GMT]', 'Panda::Date' );

        $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
            filter_datetime => { show_timezone => 0 },
        );
        is( $ddp->parse($d), '2003-03-11 00:00:00', 'Panda::Date (no timezone)' );

        $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DateTime'],
        );

        my $delta = Panda::Date::Rel->new('1M 2D 7h');
        is( $ddp->parse($delta), "1M 2D 7h", 'Panda::Date::Rel' );

        my $interval = Panda::Date::Int->new($d, $d + $delta);
        is(
            $ddp->parse($interval),
            '2003-03-11 00:00:00 [GMT] ~ 2003-04-13 07:00:00 [GMT]',
            'Panda::Date::Int'
        );
    };
}
