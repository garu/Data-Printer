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

if ($ddp->color_level) {
    plan tests => 1;
}
else {
    plan skip_all => 'console does not have enough colors to test';
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
is $ddp->parse(\$data), qq{\e[0;38;2;137;221;243m{\e[0m
    \e[0;38;2;121;134;203marrayref\e[0m\e[0;38;2;137;221;243m   \e[0m\e[0;38;2;137;221;243m[\e[0m
        \e[0;38;2;178;204;214m[0] \e[0m\e[0;38;2;137;221;243m[\e[0m
                \e[0;38;2;178;204;214m[0] \e[0m\e[0;38;2;247;140;106m10\e[0m
            \e[0;38;2;137;221;243m]\e[0m (refcount: 2)\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;178;204;214m[1] \e[0m\e[0;38;2;199;146;234mDDPTestObject\e[0m \e[0;38;2;137;221;243m(\e[0m\e[0;38;2;199;146;234mHASH\e[0m\e[0;38;2;137;221;243m)\e[0m  \e[0;38;2;137;221;243m{\e[0m
                public methods (1): \e[0;38;2;130;170;255mnew\e[0m
                private methods (0)
                internals: \e[0;38;2;137;221;243m{}\e[0m
            \e[0;38;2;137;221;243m}\e[0m\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;178;204;214m[2] \e[0m\e[0;38;2;240;113;120mvar{arrayref}[0]\e[0m
    \e[0;38;2;137;221;243m]\e[0m\e[0;38;2;137;221;243m,\e[0m
    \e[0;38;2;121;134;203mhashref\e[0m \e[0;38;2;137;221;243m   \e[0m\e[0;38;2;137;221;243m{\e[0m
        \e[0;38;2;121;134;203mlvalue\e[0m                    \e[0;38;2;137;221;243m   \e[0m\e[0;38;2;137;221;243m"\e[0m\e[0;38;2;144;181;90mc\e[0m\e[0;38;2;137;221;243m"\e[0m\e[0;38;2;247;140;106m (LVALUE)\e[0m\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;121;134;203mnumber\e[0m                    \e[0;38;2;137;221;243m   \e[0m\e[0;38;2;247;140;106m3.14\e[0m\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;121;134;203mref\e[0m                       \e[0;38;2;137;221;243m   \e[0m\\ \e[0;38;2;247;140;106m42\e[0m (read-only)\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;121;134;203mregex\e[0m                     \e[0;38;2;137;221;243m   \e[0m\e[0;38;2;255;203;107m(?:\\s+)\$\e[0m  (modifiers: ix)\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;121;134;203mspecial\e[0m                   \e[0;38;2;137;221;243m   \e[0m\e[0;38;2;137;221;243m"\e[0m\e[0;38;2;144;181;90mone\e[0;38;2;0;150;136m\\t\e[0;38;2;144;181;90m\e[0;38;2;0;150;136m\\x{2603}\e[0;38;2;144;181;90mtwo\e[0;38;2;0;150;136m\\0\e[0;38;2;144;181;90m\e[0;38;2;0;150;136m\\n\e[0;38;2;144;181;90m\e[0;38;2;0;150;136m\\e\e[0;38;2;144;181;90m[0m\e[0;38;2;0;150;136m\\x{2603}\e[0;38;2;144;181;90mBBBBBBBBBBBBBBB\e[0;38;2;38;50;56m(...skipping 85 chars...)\e[0;38;2;144;181;90m\e[0m\e[0;38;2;137;221;243m"\e[0m\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;121;134;203mstring\e[0m                    \e[0;38;2;137;221;243m   \e[0m\e[0;38;2;137;221;243m"\e[0m\e[0;38;2;144;181;90mthis is a string\e[0m\e[0;38;2;137;221;243m"\e[0m\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;121;134;203msub\e[0m                       \e[0;38;2;137;221;243m   \e[0m\e[0;38;2;55;59;65msub { ... }\e[0m (refcount: 2)\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;121;134;203mundef\e[0m                     \e[0;38;2;137;221;243m   \e[0m\e[0;38;2;255;83;112mundef\e[0m\e[0;38;2;137;221;243m,\e[0m
        \e[0;38;2;137;221;243m'\e[0m\e[0;38;2;121;134;203mwe\e[0;38;2;0;150;136m\\e\e[0;38;2;121;134;203m[0mird\e[0;38;2;0;150;136m\\0\e[0;38;2;121;134;203mkey\e[0;38;2;0;150;136m\\x{2603}\e[0;38;2;121;134;203m!\e[0m\e[0;38;2;137;221;243m'\e[0m\e[0;38;2;137;221;243m   \e[0m\e[0;38;2;247;140;106m1\e[0m
    \e[0;38;2;137;221;243m}\e[0m
\e[0;38;2;137;221;243m}\e[0m}, 'colored output';

done_testing;
