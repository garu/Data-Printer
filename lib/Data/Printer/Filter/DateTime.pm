package Data::Printer::Filter::DateTime;
use strict;
use warnings;
use Data::Printer::Filter;
use Scalar::Util;

filter 'Time::Piece'          => sub { _format($_[0]->cdate       , @_) };
filter 'DateTime::TimeZone'   => sub { _format($_[0]->name        , @_) };
filter 'DateTime::Incomplete' => sub { _format($_[0]->iso8601     , @_) };
filter 'DateTime::Tiny'       => sub { _format($_[0]->as_string   , @_) };
filter 'Date::Tiny'           => sub { _format($_[0]->as_string   , @_) };
filter 'Date::Calc::Object'   => sub { _format($_[0]->string(2)   , @_) };
filter 'Date::Pcalc::Object'  => sub { _format($_[0]->string(2)   , @_) };
filter 'Date::Handler'        => sub { _format("$_[0]"            , @_) };
filter 'Date::Handler::Delta' => sub { _format($_[0]->AsScalar    , @_) };
filter 'Date::Simple'         => sub { _format("$_[0]"            , @_) };
filter 'Mojo::Date'           => sub { _format($_[0]->to_datetime , @_) };
filter 'Date::Manip::Obj'     => sub { _format(scalar $_[0]->value, @_) };

filter 'Panda::Date'      => sub { _format(_filter_Panda_Date(@_), @_) };
filter 'Panda::Date::Rel' => sub { _format( "$_[0]", @_) };
filter 'Panda::Date::Int' => sub {
    my ($date, $ddp) = @_;
    _format(
          _filter_Panda_Date($date->from, $ddp)
        . ' ~ '
        . _filter_Panda_Date($date->till, $ddp),
        @_
    );
};

sub _filter_Panda_Date {
    my ($date, $ddp) = @_;
    my $string = $date->iso;
    if (!exists $ddp->extra_config->{filter_datetime}{show_timezone}
        || $ddp->extra_config->{filter_datetime}{show_timezone}
    ) {
        $string .= ' [' . $date->tzabbr . ']';
    }
    return $string;
}

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
        $string .= ' [' . $obj->time_zone->name . ']';
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
        $string .= ' [' . $obj->tzdst . ']';
    }
    return _format( $string, @_ );
};

sub _format {
    my ($str, $obj, $ddp) = @_;

    if ($ddp->extra_config->{filter_datetime}{show_class_name}) {
        $str .= ' (' . Scalar::Util::blessed($obj) . ')';
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

You may also customize the look and feel with the following options:

    datetime_filter.show_class_name = 1
    datetime_filter.show_timezone   = 0

    # you can even customize your themes:
    color.datetime = #cc7a23

That's it!

=head1 DESCRIPTION

This is a filter plugin for L<Data::Printer>. It filters through several
date and time manipulation classes and displays the time (or time duration)
as a string.

=head2 Parsed Modules

=over 4

=item * L<Time::Piece>

=item * L<DateTime>

=item * L<DateTime::Duration>

=item * L<DateTime::Incomplete>

=item * L<DateTime::TimeZone>

=item * L<DateTime::Tiny>

=item * L<Date::Tiny>

=item * L<Date::Calc::Object>

=item * L<Date::Pcalc::Object>

=item * L<Date::Handler>

=item * L<Date::Handler::Delta>

=item * L<Date::Simple>

=item * L<Mojo::Date>

=item * L<Class::Date>

=item * L<Class::Date::Rel>

=item * L<Date::Manip>

=back

If you have any suggestions for more modules or better output,
please let us know.

=head1 SEE ALSO

L<Data::Printer>
