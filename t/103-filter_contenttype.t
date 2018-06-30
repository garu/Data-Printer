use strict;
use warnings;
use Test::More tests => 32;
use Data::Printer::Object;

# we pad a bunch of 'dd' because of a minimum length check inside the filter:
my %signatures = (
    "\x89\x50\x4E\x47" => 'PNG Image',
    "\x47\x49\x46"     => 'GIF Image',
    "\x4D\x4D\x00\x2A" => 'TIFF Image',
    "\x49\x49\x2A\x00" => 'TIFF Image',
    "\xff\xd8\xff"     => 'JPEG Image',
    "\x00\x00\x01\x00" => 'ICO Image',
    "\x00\x00\x01\xb0\xbf" => 'MPEG Video',
    "\x00\x00\x01\xc3\xa8" => 'MPEG Video',
    "\x52\x49\x46\x46\x00\x00\x57\x41\x56\x45" => 'WAV Audio',
    "\x52\x49\x46\x46\x00\x00\x41\x56\x49" => 'AVI Video',
    "\x50\x4b\x30\x40" => 'Zip Archive',
    "\x50\x4b\x70\x60" => 'Zip Archive',
    "\x25\x50\x44\x46" => "PDF Document",
    "\x7F\x45\x4C\x46" => "Binary ELF data",
    "\x66\x4C\x61\x43" => "FLAC Audio",
    "\x4F\x67\x67\x53" => "OGG Audio",
    "\x1F\x8B\x80"     => "Gzip Archive",
    "\x49\x44\x33"     => "MP3 Audio",
    "\x42\x5A\x68"     => "Bzip2 Archive",
    "\x4D\x5A"         => "Binary Windows EXE data",
    "\x42\x4D"         => "BMP Image",
    "\xFF\xFB"         => "MP3 Audio",
    "\x3d\x73\x72\x6c\x01" => "Binary Sereal v1 data",
    "\x3d\x73\x72\x6c\x02" => "Binary Sereal v2 data",
    "\x3d\xf3\x72\x6c\x03" => "Binary Sereal v3 data",
    "\x3d\xf3\x72\x6c\x04" => "Binary Sereal v4 data",
);

my $ddp = Data::Printer::Object->new(
    colored => 0,
    filters => ['ContentType'],
);

foreach my $k (keys %signatures) {
    # increase content length deliberately:
    my $content = $k . ("\xdd" x 20);
    like(
        $ddp->parse(\$content, seen_override => 1),
        qr/\($signatures{$k}, \d\dB\)/,
        "found the right content type for " . $signatures{$k}
    );
}

my $png = "\x89\x50\x4E\x47";
foreach my $i (1 .. 32) {
    $png .= hex($i);
}

$ddp = Data::Printer::Object->new(
    colored => 0,
    filters => ['ContentType'],
    filter_contenttype => { show_size => 0 },
);
is(
    $ddp->parse(\$png),
    "\x{f0}\x{9f}\x{96}\x{bc}  (PNG Image)",
    'content type without size'
);

$ddp = Data::Printer::Object->new(
    colored => 0,
    filters => ['ContentType'],
    filter_contenttype => {
        size_unit => 'k',
        show_symbol => 0,
    },
);

is $ddp->parse(\$png), '(PNG Image, 0K)', 'content type with forced size unit';

$ddp = Data::Printer::Object->new(
    colored => 0,
    filters => ['ContentType'],
    filter_contenttype => {
        hexdump => 1,
        show_symbol => 0,
    },
);
is $ddp->parse(\$png), '(PNG Image, 59B)
0x00000000 (00000)  89504e47 31323334 35363738 39313631  .PNG123456789161
0x00000010 (00016)  37313831 39323032 31323232 33323432  7181920212223242
0x00000020 (00032)  35333233 33333433 35333633 37333833  5323334353637383
0x00000030 (00048)  39343034 31343834 393530             94041484950',
    'content type with hexdump';


$ddp = Data::Printer::Object->new(
    colored => 0,
    filters => ['ContentType'],
    filter_contenttype => {
        hexdump => 1,
        hexdump_size => 19,
        show_symbol => 0,
    },
);
is $ddp->parse(\$png), '(PNG Image, 59B)
0x00000000 (00000)  89504e47 31323334 35363738 39313631  .PNG123456789161
0x00000010 (00016)  373138                               718',
    'content type with hexdump size 19';

$ddp = Data::Printer::Object->new(
    colored => 0,
    filters => ['ContentType'],
    filter_contenttype => {
        hexdump => 1,
        hexdump_size => 19,
        hexdump_indent => 1,
        show_symbol => 0,
    },
);
$ddp->indent;
is $ddp->parse(\$png), '(PNG Image, 59B)
    0x00000000 (00000)  89504e47 31323334 35363738 39313631  .PNG123456789161
    0x00000010 (00016)  373138                               718',
    'content type with hexdump size 19 (indented)';

$ddp = Data::Printer::Object->new(
    colored => 0,
    filters => ['ContentType'],
    filter_contenttype => {
        hexdump        => 1,
        hexdump_size   => 5,
        hexdump_offset => 10,
        show_symbol    => 0,
    },
);
is $ddp->parse(\$png), '(PNG Image, 59B)
0x0000000a (00010)  37383931 36                          78916',
    'content type with hexdump size 5 from offset 10';
