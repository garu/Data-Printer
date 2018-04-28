use strict;
use warnings;
use Test::More tests => 4;
use Data::Printer::Config;

my $content = <<'EOTEXT';

# some comment
    # another comment
whatever = Something Interesting
answer         =   42    
class.data.may.be.deep = 0 but true
class.data.may.not = 1
class.simple = bla
    ; and
; some more comments

[Some::Module]
meep = moop

   [Other::Module]
hard.times = come.easy

EOTEXT

my $data = Data::Printer::Config::_str2data('data.rc', $content);
is_deeply($data, {
    _ => {
        answer => 42,
        whatever => 'Something Interesting',
        class => {
            simple => 'bla',
            data => {
                may => {
                    not => 1,
                    be => {
                        deep => '0 but true',
                    }
                }
            }
        }
    },
    'Some::Module' => { meep => 'moop' },
    'Other::Module' => { hard => { times => 'come.easy' } },
}, 'parsed rc file');

my $warn_count = 0;
use Data::Printer::Common;
{ no warnings 'redefine';
    *Data::Printer::Common::_warn = sub {
        my $message = shift;
        $warn_count++;
        if ($warn_count == 1) {
            like $message, qr/error reading rc file/, 'message about parse error found';
        }
        else {
            like $message, qr/RC file format changed in/, 'helper message found';
        }
    };
}

$content = <<'EOLEGACY';
{
    foo => 123
}
EOLEGACY

my $data2 = Data::Printer::Config::_str2data('data.rc', $content);
is_deeply($data2, {}, 'parse error returns valid structure');
