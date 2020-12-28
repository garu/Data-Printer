package Data::Printer::Filter::DateTime;
use strict;
use warnings;
use Data::Printer::Filter;
use Scalar::Util;

filter 'Time::Piece'          => sub { _format($_[0]->cdate       , @_) };
filter 'Time::Moment'         => sub { _format($_[0]->to_string   , @_) };
filter 'DateTime::TimeZone'   => sub { _format($_[0]->name        , @_) };
filter 'DateTime::Incomplete' => sub { _format($_[0]->iso8601     , @_) };
filter 'DateTime::Tiny'       => sub { _format($_[0]->as_string   , @_) };
filter 'Date'                 => sub { _format($_[0]->to_string   , @_) };
filter 'Date::Tiny'           => sub { _format($_[0]->as_string   , @_) };
filter 'Date::Calc::Object'   => sub { _format($_[0]->string(2)   , @_) };
filter 'Date::Handler'        => sub { _format("$_[0]"            , @_) };
filter 'Date::Handler::Delta' => sub { _format($_[0]->AsScalar    , @_) };
filter 'Date::Simple'         => sub { _format("$_[0]"            , @_) };
filter 'Date::Manip::Obj'     => sub { _format(scalar $_[0]->value, @_) };

filter 'Mojo::Date' => sub {
    my $date = $_[0]->can('to_datetime')
      ? $_[0]->to_datetime
      : $_[0]->to_string
      ;
    return _format($date , @_);
};

filter 'Class::Date::Rel' => sub {
    my ($obj, $ddp) = @_;
    my $string = '';
    if (my $months = $obj->mon_part) {
        if (my $years = int($months / 12)) {
            $string .= $years . 'Y';
            $months -= $years * 12;
        }
        if ($months) {
            $string .= (length($string) ? ' ' : '') . $months . 'M';
        }
    }
    if (my $seconds = $obj->sec_part) {
        my $minutes = int($seconds / 60);
        my $hours   = int($minutes / 60);
        my $days    = int($hours   / 24);
        my $delta = 0;
        if ($days) {
            $string .= (length($string) ? ' ' : '') . $days . 'D';
            $delta = $days * 24;
            $hours -= $delta;
        }
        if ($hours) {
            $string .= (length($string) ? ' ' : '') . $hours . 'h';
            $delta = $delta * 60 + $hours * 60;
            $minutes -= $delta;
        }
        if ($minutes) {
            $string .= (length($string) ? ' ' : '') . $minutes . 'm';
            $delta = $delta * 60 + $minutes * 60;
            $seconds -= $delta;
        }
        if ($seconds) {
            $string .= (length($string) ? ' ' : '') . $seconds . 's';
        }
    }
    return _format( $string, @_ );
};

filter 'DateTime', sub {
    my ($obj, $ddp) = @_;
    my $string = "$obj";
    if (!exists $ddp->extra_config->{filter_datetime}{show_timezone}
        || $ddp->extra_config->{filter_datetime}{show_timezone}
    ) {
        $string .= ' ' . $ddp->maybe_colorize('[', 'brackets')
                . $obj->time_zone->name
                . $ddp->maybe_colorize(']', 'brackets');
    }
    return _format( $string, @_ );
};

filter 'DateTime::Duration', sub {
    my ($obj, $ddp) = @_;

    my @dur    = $obj->in_units(qw(years months days hours minutes seconds));
    my $string = "$dur[0]y $dur[1]m $dur[2]d $dur[3]h $dur[4]m $dur[5]s";
    return _format( $string, @_ );
};

filter 'Class::Date', sub {
    my ($obj, $ddp) = @_;

    my $string = $obj->strftime("%Y-%m-%d %H:%M:%S");
    if (!exists $ddp->extra_config->{filter_datetime}{show_timezone}
        || $ddp->extra_config->{filter_datetime}{show_timezone}
    ) {
        $string .= ' ' . $ddp->maybe_colorize('[', 'brackets')
                . $obj->tzdst
                . $ddp->maybe_colorize(']', 'brackets');
    }
    return _format( $string, @_ );
};

sub _time_seconds_formatter {
    my ($n, $counted) = @_;
    my $number = sprintf("%d", $n); # does a "floor"
    $counted .= 's' if 1 != $number;
    return ($number, $counted);
}
filter 'Time::Seconds', sub {
    my ($obj, $ddp) = @_;
    my $str = '';
    if ($obj->can('pretty')) {
        $str = $obj->pretty;
    }
    else {
        # simple pretty() implementation:
        if ($obj < 0) {
            $obj = -$obj;
            $str = 'minus ';
        }
        if ($obj >= 60) {
            if ($obj >= 3600) {
                if ($obj >= 86400) {
                    my ($days, $sd) = _time_seconds_formatter($obj->days, "day");
                    $str .= "$days $sd, ";
                    $obj -= ($days * 86400);
                }
                my ($hours, $sh) = _time_seconds_formatter($obj->hours, "hour");
                $str .= "$hours $sh, ";
                $obj -= ($hours * 3600);
            }
            my ($mins, $sm) = _time_seconds_formatter($obj->minutes, "minute");
            $str .= "$mins $sm, ";
            $obj -= ($mins * 60);
        }
        $str .= join ' ', _time_seconds_formatter($obj->seconds, "second");
    }
    return _format($str, $obj, $ddp);
};

sub _format {
    my ($str, $obj, $ddp) = @_;

    if ($ddp->extra_config->{filter_datetime}{show_class_name}) {
        $str .= ' ' . $ddp->maybe_colorize('(', 'brackets')
             . Scalar::Util::blessed($obj)
             . $ddp->maybe_colorize(')', 'brackets');
    }
    return $ddp->maybe_colorize($str, 'datetime', '#aaffaa');
}

1;

__END__

=head1 NAME

Data::Printer::Filter::DateTime - pretty-printing date and time objects (not just DateTime!)

=head1 SYNOPSIS

In your C<.dataprinter> file:

    filters = DateTime

You may also customize the look and feel with the following options (defaults shown):

    filter_datetime.show_class_name = 1
    filter_datetime.show_timezone   = 0

    # you can even customize your themes:
    colors.datetime = #cc7a23

That's it!

=head1 DESCRIPTION

This is a filter plugin for L<Data::Printer>. It filters through several
date and time manipulation classes and displays the time (or time duration)
as a string.

=head2 Parsed Modules

=over 4

=item * L<Time::Piece>, L<Time::Seconds>

=item * L<Time::Moment>

=item * L<DateTime>,  L<DateTime::Duration>, L<DateTime::Incomplete>, L<DateTime::TimeZone>

=item * L<DateTime::Tiny>

=item * L<Date>

=item * L<Date::Tiny>

=item * L<Date::Calc::Object>

=item * L<Date::Handler>, L<Date::Handler::Delta>

=item * L<Date::Simple>

=item * L<Mojo::Date>

=item * L<Class::Date>, L<Class::Date::Rel>

=item * L<Date::Manip>

=back

If you have any suggestions for more modules or better output,
please let us know.

=head1 SEE ALSO

L<Data::Printer>
