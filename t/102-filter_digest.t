use strict;
use warnings;
use Test::More tests => 3 * 7; # tests * modules
use Data::Printer::Object;

my $data = 'I can has Digest?';

foreach my $module (qw(
    Digest::Adler32
    Digest::MD2
    Digest::MD4
    Digest::MD5
    Digest::SHA
    Digest::SHA1
    Digest::Whirlpool
)) {

    SKIP: {
        eval "use $module; 1";
        skip "$module not available", 3 if $@;

        my $digest = $module->new;
        skip "$module is too old", 3 if $module eq 'Digest::MD5' and !$digest->isa('Digest::base');

        $digest->add( $data );

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            show_readonly => 0,
            filters => ['Digest'],
            filter_digest => { show_class_name => 0 },
        );

        my $dump = $ddp->parse($digest);

        $ddp = Data::Printer::Object->new(
            colored       => 0,
            show_readonly => 0,
            filters       => ['Digest'],
        );
        my $named_dump = $ddp->parse($digest);
        my $hex = $digest->hexdigest;
        is( $dump, $hex, "$module digest dump");
        is(
            $named_dump,
            "$hex ($module)",
            "$module digest dump with class name"
        );

        $ddp = Data::Printer::Object->new(
            colored => 0,
            show_readonly => 0,
            filters => ['Digest'],
        );
        is(
            $ddp->parse($digest),
            $digest->hexdigest . " ($module) [reset]",
            "reset $module"
        );
    };

}
