use strict;
use warnings;
use Test::More;
use Data::Printer::Object;
use Scalar::Util;

package DDPTestObject;
sub new { bless {}, shift }
1;

package main;


my $ddp = Data::Printer::Object->new(
    colored       => 1,
    print_escapes => 1,
    escape_chars  => 'nonascii',
    string_max    => 30,
    class         => { show_reftype => 1 },
    show_refcount => 1,
);

sub testsub {}

my $data = {
    arrayref => [[10], DDPTestObject->new],
   hashref => {
       string  => "this is a string",
       special => "one\t\x{2603}two\0\n\e[0m\x{2603}" . ('B' x 100),
       number  => 3.14,
       ref     => \42,
       regex   => qr{(?:\s+)$}ix,
       lvalue  => \substr("abc", 2),
       undef   => undef,
       sub     => \&testsub,
       "we\e[0mird\0key\x{2603}!" => 1,
   },
};
use Devel::Peek; Dump( $data->{hashref} );
#use Devel::Peek; Dump( \*main::foo );

#push @{$data->{arrayref}}, $data->{arrayref}[0];


is $ddp->parse(\$data), q({
arrayref   [
    [0] 1,
    [1] [
            [0] 10
        ] (weak),
    [2] DDPTestObject (HASH)  {
            public methods (1): new
            private methods (0)
            internals: {}
        },
    [3] {
            lvalue  "c" (LVALUE),
            number  3.14,
            ref     \ 42,
            regex   (?:\s+)$  (modifiers: ix),
            special \e[0;38;2;137;221;243m"\e[0m\e[0;38;2;195;232;141mone\e[0;38;2;0;150;136m\\t\e[0;38;2;195;232;141m\e[0;38;2;0;150;136m\\x{2603}\e[0;38;2;195;232;141mtwo\e[0;38;2;0;150;136m\\0\e[0;38;2;195;232;141m\e[0;38;2;0;150;136m\\n\e[0;38;2;195;232;141m\e[0;38;2;0;150;136m\\e\e[0;38;2;195;232;141m[0m\e[0;38;2;0;150;136m\\x{2603}\e[0;38;2;195;232;141mBBBBBBBBBBBBBBB\e[0;38;2;38;50;56m(...skipping 85 chars...)\e[0;38;2;195;232;141m\e[0m\e[0;38;2;137;221;243m"\e[0m,
            string  "this is a string",
            sub      sub { ... } (refcount: 2),
            undef    undef,
            'weird\dkey\x{2603!'  undef
        },
    [4] var{arrayref}[1],
],
hashref var{arrayref}[3]
}), 'colored output';

ok 1;
done_testing;
