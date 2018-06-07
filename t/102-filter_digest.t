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
        $digest->add( $data );

        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['Digest'],
        );

        my $dump = $ddp->parse($digest);

        $ddp = Data::Printer::Object->new(
            colored       => 0,
            filters       => ['Digest'],
            filter_digest => { show_class_name => 1 },
        );
        my %is_readonly = (
            'Digest::SHA'  => 1,
            'Digest::SHA1' => 1,
            'Digest::MD2'  => 1,
            'Digest::MD4'  => 1,
        );
        my $named_dump = $ddp->parse($digest);
        my $hex = $digest->hexdigest;
        is( $dump, $hex . ($is_readonly{$module} ? ' (read-only)' : ''), $module );
        is(
            $named_dump,
            "$hex ($module)" . ($is_readonly{$module} ? ' (read-only)' : ''),
            "$module with class name"
        );

        $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['Digest'],
        );
        is( $ddp->parse($digest), $digest->hexdigest . ' [reset]'
            . ($is_readonly{$module} ? ' (read-only)' : ''), "reset $module"
        );
    };

}


