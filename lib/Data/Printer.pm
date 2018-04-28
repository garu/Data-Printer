package Data::Printer;
use strict;
use warnings;
use Data::Printer::Object;
use Data::Printer::Common;
use Data::Printer::Config;

our $VERSION = '0.99_002';

my $rc_arguments;
my %arguments_for;

sub import {
    my $class = shift;

    _initialize();

    # export to the caller's namespace:
    my $caller = caller;

    # every time you load it, we override the version from *your* caller
    my $args;
    if (@_ > 0) {
        $args = @_ == 1 ? shift : {@_};
        Data::Printer::Common::_warn(
            'Data::Printer can receive either a hash or a hash reference'
        ) unless ref $args eq 'HASH';
    }
    $arguments_for{$caller} = $args;

    my $use_prototypes = exists $args->{use_prototypes}
            ? $args->{use_prototypes}
        : exists $rc_arguments->{$caller} && exists $rc_arguments->{$caller}{use_prototypes}
            ? $rc_arguments->{$caller}{use_prototypes}
        : exists $rc_arguments->{'_'}{use_prototypes}
            ? $rc_arguments->{'_'}{use_prototypes}
        : 1
        ;
    my $exported = ($use_prototypes ? \&p : \&p_without_prototypes);

    my $imported = exists $args->{alias}
            ? $args->{alias}
        : exists $rc_arguments->{$caller} && exists $rc_arguments->{$caller}{alias}
            ? $rc_arguments->{$caller}{alias}
        : exists $rc_arguments->{'_'}{alias}
            ? $rc_arguments->{'_'}{alias}
        : 'p'
        ;

    { no strict 'refs';
        *{"$caller\::$imported"} = $exported;
        *{"$caller\::np"}        = \&np;
    }
}

sub _initialize {
    # potential race but worst case is we read it twice :)
    { no warnings 'redefine'; *_initialize = sub {} }
    $rc_arguments = Data::Printer::Config::load_rc_file();
}

sub np (\[@$%&];%) {
    my ($data, %properties) = @_;

    _initialize();

    my $caller = caller;
    my $args_to_use = _fetch_args_with($caller, \%properties);
    my $printer = Data::Printer::Object->new($args_to_use);
    my $ref = ref $_[0];
    if ($ref eq 'ARRAY' || $ref eq 'HASH' || ($ref eq 'REF' && ref ${$_[0]} eq 'REF')) {
        $printer->{_refcount_base}++;
    }
    return $printer->write_label . $printer->parse($data);
}


sub p (\[@$%&];%) {
    my (undef, %properties) = @_;

    _initialize();

    my $caller = caller;
    my $args_to_use = _fetch_args_with($caller, \%properties);
    my $printer = Data::Printer::Object->new($args_to_use);
    my $ref = ref $_[0];
    if ($ref eq 'ARRAY' || $ref eq 'HASH' || ($ref eq 'REF' && ref ${$_[0]} eq 'REF')) {
        $printer->{_refcount_base}++;
    }
    my $output = $printer->write_label . $printer->parse($_[0]);

    return _handle_output($printer, $output, !!defined wantarray, $_[0]);
}

# This is a p() clone without prototypes. Just like regular Data::Dumper,
# this version expects a reference as its first argument. We make a single
# exception for when we only get one argument, in which case we ref it
# for the user and keep going.
sub p_without_prototypes  {
    my (undef, %properties) = @_;

    my $item;
    if (!ref $_[0] && @_ == 1) {
        my $item_value = $_[0];
        $item = \$item_value;
    }

    _initialize();

    my $caller = caller;
    my $args_to_use = _fetch_args_with($caller, \%properties);
    my $printer = Data::Printer::Object->new($args_to_use);
    my $ref = ref( defined $item ? $item : $_[0] );
    if ($ref eq 'ARRAY' || $ref eq 'HASH' || ($ref eq 'REF'
        && ref(defined $item ? $item : ${$_[0]}) eq 'REF')) {
        $printer->{_refcount_base}++;
    }
    my $output = $printer->write_label . $printer->parse((defined $item ? $item : $_[0]));

    return _handle_output($printer, $output, !!defined wantarray, $_[0]);
}


sub _handle_output {
    my ($printer, $output, $wantarray, $data) = @_;

    if ($printer->return_value eq 'pass') {
        print { $printer->output_handle } $output . "\n";
        my $ref = ref $data;
        if (!$ref) {
            return $data;
        }
        elsif ($ref eq 'ARRAY') {
            return @$data;
        }
        elsif ($ref eq 'HASH') {
            return %$data;
        }
        elsif ( grep { $ref eq $_ } qw(REF SCALAR CODE Regexp GLOB VSTRING) ) {
            return $$data;
        }
        else {
            return $data;
        }
    }
    elsif ($printer->return_value eq 'void') {
        print { $printer->output_handle } $output . "\n";
        return;
    }
    else {
        print { $printer->output_handle } $output . "\n" unless $wantarray;
        return $output;
    }
}

sub _fetch_args_with {
    my ($caller, $run_properties) = @_;

    my $args_to_use = {};
    if (keys %$rc_arguments) {
        $args_to_use = Data::Printer::Common::merge_options(
            $args_to_use, $rc_arguments->{'_'}
        );
        if (exists $rc_arguments->{$caller}) {
            $args_to_use = Data::Printer::Common::merge_options(
                $args_to_use, $rc_arguments->{$caller}
            );
        }
    }
    if ($arguments_for{$caller}) {
        $args_to_use = Data::Printer::Common::merge_options(
            $args_to_use, $arguments_for{$caller}
        );
    }
    if (keys %$run_properties) {
        $args_to_use = Data::Printer::Common::merge_options(
            $args_to_use, $run_properties
        );
    }
    return $args_to_use;
}

'Marielle, presente.';
__END__

=encoding utf8

=head1 NAME

Data::Printer - colored pretty-print of Perl data structures and objects


