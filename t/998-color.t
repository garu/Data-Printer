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

if ($ddp->{_output_color_level} == 3) {
    plan tests => 1;
}
else {
    plan skip_all => 'color level ' . $ddp->{_output_color_level} . ' < 3';
}

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
push @{$data->{arrayref}}, $data->{arrayref}[0];

my $got = $ddp->parse(\$data);
my $expected = qq|\e[0;38;2;102;217;239m{\e[m
    \e[0;38;2;121;134;203marrayref\e[m\e[0;38;2;102;217;239m   \e[m\e[0;38;2;102;217;239m[\e[m
        \e[0;38;2;161;187;197m[0] \e[m\e[0;38;2;102;217;239m[\e[m
                \e[0;38;2;161;187;197m[0] \e[m\e[0;38;2;247;140;106m10\e[m
            \e[0;38;2;102;217;239m]\e[m (refcount: 2)\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;161;187;197m[1] \e[m\e[0;38;2;199;146;234mDDPTestObject\e[m \e[0;38;2;102;217;239m(\e[m\e[0;38;2;199;146;234mHASH\e[m\e[0;38;2;102;217;239m)\e[m  \e[0;38;2;102;217;239m{\e[m
                public methods (1): \e[0;38;2;130;170;255mnew\e[m
                private methods (0)
                internals: \e[0;38;2;102;217;239m{}\e[m
            \e[0;38;2;102;217;239m}\e[m\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;161;187;197m[2] \e[m\e[0;38;2;240;113;120mvar{arrayref}[0]\e[m
    \e[0;38;2;102;217;239m]\e[m\e[0;38;2;102;217;239m,\e[m
    \e[0;38;2;121;134;203mhashref\e[m \e[0;38;2;102;217;239m   \e[m\e[0;38;2;102;217;239m{\e[m
        \e[0;38;2;121;134;203mlvalue\e[m                    \e[0;38;2;102;217;239m   \e[m\e[0;38;2;102;217;239m"\e[m\e[0;38;2;144;181;90mc\e[m\e[0;38;2;102;217;239m"\e[m\e[0;38;2;247;140;106m (LVALUE)\e[m| . (q{ (refcount: 2)}x!!($] < 5.014000)) . qq|\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;121;134;203mnumber\e[m                    \e[0;38;2;102;217;239m   \e[m\e[0;38;2;247;140;106m3.14\e[m\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;121;134;203mref\e[m                       \e[0;38;2;102;217;239m   \e[m\\ \e[0;38;2;247;140;106m42\e[m (read-only)\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;121;134;203mregex\e[m                     \e[0;38;2;102;217;239m   \e[m\e[0;38;2;255;203;107m(?:\\s+)\$\e[m  (modifiers: ix)| . (q{ (refcount: 2)}x!!($] =~ /5.01100[12]/)) . qq|\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;121;134;203mspecial\e[m                   \e[0;38;2;102;217;239m   \e[m\e[0;38;2;102;217;239m"\e[m\e[0;38;2;144;181;90mone\e[0;38;2;0;150;136m\\t\e[0;38;2;144;181;90m\e[0;38;2;0;150;136m\\x{2603}\e[0;38;2;144;181;90mtwo\e[0;38;2;0;150;136m\\0\e[0;38;2;144;181;90m\e[0;38;2;0;150;136m\\n\e[0;38;2;144;181;90m\e[0;38;2;0;150;136m\\e\e[0;38;2;144;181;90m[0m\e[0;38;2;0;150;136m\\x{2603}\e[0;38;2;144;181;90mBBBBBBBBBBBBBBB\e[0;38;2;79;90;97m(...skipping 85 chars...)\e[0;38;2;144;181;90m\e[m\e[0;38;2;102;217;239m"\e[m\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;121;134;203mstring\e[m                    \e[0;38;2;102;217;239m   \e[m\e[0;38;2;102;217;239m"\e[m\e[0;38;2;144;181;90mthis is a string\e[m\e[0;38;2;102;217;239m"\e[m\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;121;134;203msub\e[m                       \e[0;38;2;102;217;239m   \e[m\e[0;38;2;79;90;97msub { ... }\e[m (refcount: 2)\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;121;134;203mundef\e[m                     \e[0;38;2;102;217;239m   \e[m\e[0;38;2;255;83;112mundef\e[m\e[0;38;2;102;217;239m,\e[m
        \e[0;38;2;102;217;239m"\e[m\e[0;38;2;121;134;203mwe\e[0;38;2;0;150;136m\\e\e[0;38;2;121;134;203m[0mird\e[0;38;2;0;150;136m\\0\e[0;38;2;121;134;203mkey\e[0;38;2;0;150;136m\\x{2603}\e[0;38;2;121;134;203m!\e[m\e[0;38;2;102;217;239m"\e[m\e[0;38;2;102;217;239m   \e[m\e[0;38;2;247;140;106m1\e[m
    \e[0;38;2;102;217;239m}\e[m
\e[0;38;2;102;217;239m}\e[m|;

is($got, $expected, 'colored output');
if ($got ne $expected) {
    $got =~ s{\e}{\\e}gsm;
    diag("escaped version for debug:\n$got");
}
