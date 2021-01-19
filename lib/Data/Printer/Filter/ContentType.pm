package Data::Printer::Filter::ContentType;
use strict;
use warnings;
use Data::Printer::Filter;

filter 'SCALAR' => sub {
    my ($data, $ddp) = @_;

    # don't bother looking on files that are just too small
    return unless defined $$data;
    my $len = length($$data);
    return if $len < 22;

    my $hex = unpack('H22', $$data);
    my $hex_8 = substr($hex,0,8);

    my $type;

    if ($hex_8 eq '89504e47') {
        $type = 'PNG Image';
    }
    elsif ($hex_8 eq '4d4d002a' || $hex_8 eq '49492a00') {
        $type = 'TIFF Image';
    }
    elsif ($hex_8 eq '00000100') {
        $type = 'ICO Image';
    }
    elsif ($hex_8 eq '52494646') {
        my $rest = substr($hex,12,8);
        if ($rest eq '57415645') {
            $type = 'WAV Audio';
        }
        elsif ($rest =~ /\A415649/) {
            $type = 'AVI Video';
        }
    }
    elsif ($hex_8 =~ /\A504b(?:30|50|70)(?:40|60|80)/) {
        $type = 'Zip Archive';
    }
    elsif ($hex_8 eq '25504446') {
        $type = 'PDF Document';
    }
    elsif ($hex_8 eq '7f454c46') {
        $type = 'Binary ELF data';
    }
    elsif ($hex_8 eq '664c6143') {
        $type = 'FLAC Audio';
    }
    elsif ($hex_8 eq '4f676753') {
        $type = 'OGG Audio';
    }
    else {
        my $hex_6 = substr($hex,0,6);
        if($hex_6 eq '474946') {
            $type = 'GIF Image';
        }
        elsif ($hex_6 eq 'ffd8ff') {
            $type = 'JPEG Image';
        }
        elsif ($hex_6 eq '000001') {
            if (hex(substr($hex,6,2)) >= 0xb0
                && hex(substr($hex,8,2)) <= 0xbf
            ) {
                $type = 'MPEG Video';
            }
        }
        elsif ($hex_6 eq '1f8b80') {
            $type = 'Gzip Archive';
        }
        elsif ($hex_6 eq '494433') {
            $type = 'MP3 Audio';
        }
        elsif ($hex_6 eq '425a68') {
            $type = 'Bzip2 Archive';
        }
        else {
            my $hex_4 = substr($hex,0,4);
            if ($hex_4 eq 'fffb') {
                $type = 'MP3 Audio';
            }
            elsif ($hex_4 eq '424d') {
                $type = 'BMP Image';
            }
            elsif ($hex_4 eq '4d5a') {
                $type = 'Binary Windows EXE data'
            }
            elsif ($hex_8 eq '3d73726c') {
                my $v = substr($hex, 9, 1);
                if ($v == 1 || $v == 2) {
                    $type = "Binary Sereal v$v data";
                }
            }
            elsif ($hex_8 eq '3df3726c') {
                my $v = substr($hex, 9, 1);
                if ($v == 3 || $v == 4) {
                    $type = "Binary Sereal v$v data";
                }
            }
            else {
                # type not found! Let other filters have a go.
                return;
            }
        }
    }
    return unless $type;

    my $unit = 'AUTO';
    if (exists $ddp->extra_config->{filter_contenttype}{size_unit}) {
        $unit = uc $ddp->extra_config->{filter_contenttype}{size_unit};
        if (!$unit || ($unit ne 'AUTO' && $unit ne 'B' && $unit ne 'K' && $unit ne 'M')) {
            Data::Printer::Common::_warn($ddp, 'filter_contenttype.size_unit must be auto, b, k or m');
            $unit = 'auto';
        }
    }
    if ($unit eq 'M' || ($unit eq 'AUTO' && $len > 1024*1024)) {
        $len = $len / (1024*1024);
        $unit = 'M';
    }
    elsif ($unit eq 'K' || ($unit eq 'AUTO' && $len > 1024)) {
        $len = $len / 1024;
        $unit = 'K';
    }
    else {
        $unit = 'B';
    }

    my $show_size = !exists $ddp->extra_config->{filter_contenttype}{show_size}
                 || $ddp->extra_config->{filter_contenttype}{show_size};

    my $symbol = '';
    if (!exists $ddp->extra_config->{filter_contenttype}{show_symbol}
        || $ddp->extra_config->{filter_contenttype}{show_symbol}
    ) {
        if ($type =~ /Image/) {
            $symbol = "\x{f0}\x{9f}\x{96}\x{bc}  "; # FRAME WITH PICTURE
        }
        elsif ($type =~ /Video/) {
            $symbol = "\x{f0}\x{9f}\x{8e}\x{ac}  "; # CLAPPER BOARD
        }
        elsif ($type =~ /Audio/) {
            $symbol = "\x{f0}\x{9f}\x{8e}\x{b5}  "; # MUSICAL NOTE
        }
        elsif ($type =~ /Archive/) {
            $symbol = "\x{f0}\x{9f}\x{97}\x{84}  "; # FILE CABINET
        }
        elsif ($type =~ /Document/) {
            $symbol = "\x{f0}\x{9f}\x{93}\x{84}  "; # PAGE FACING UP
        }
        elsif ($type =~ /Binary/) {
            $symbol = "\x{f0}\x{9f}\x{96}\x{a5}  "; # DESKTOP COMPUTER
        }
    }
    my $output = $symbol . $ddp->maybe_colorize('(', 'brackets')
         . $ddp->maybe_colorize(
             $type
             . ((', ' . ($len < 0 ? sprintf("%.2f", $len) : int($len)) . $unit)x!!$show_size),
             'filter_contenttype',
             '#ca88dd'
         )
         . $ddp->maybe_colorize(')', 'brackets')
         ;

    return $output if !exists $ddp->extra_config->{filter_contenttype}{hexdump}
                     || !$ddp->extra_config->{filter_contenttype}{hexdump};

    my ($h_size, $h_offset, $h_indent) = (0, 0, 0);
    $h_size = $ddp->extra_config->{filter_contenttype}{hexdump_size}
        if exists $ddp->extra_config->{filter_contenttype}{hexdump_size};
    $h_offset = $ddp->extra_config->{filter_contenttype}{hexdump_offset}
        if exists $ddp->extra_config->{filter_contenttype}{hexdump_offset};
    $h_indent = $ddp->extra_config->{filter_contenttype}{hexdump_indent}
        if exists $ddp->extra_config->{filter_contenttype}{hexdump_indent};
    $output .= hexdump($ddp, $$data, $h_size, $h_offset, $h_indent);
    return $output;
};

# inspired by https://www.perlmonks.org/?node_id=1140391
sub hexdump {
    my ($ddp, $data, $size, $offset, $indent) = @_;

    my $output = '';
    my $current_size = 0;
    my $is_last = 0;
    my $linebreak = $indent ? $ddp->newline : "\n";
    if ($offset > 0) {
        return '' if $offset >= length($data);
        $data = substr($data, $offset);
    }
    elsif ($offset < 0) {
        $offset = length($data) + $offset;
        $offset = 0 if $offset < 0;
        $data = substr($data, $offset);
    }
    foreach my $chunk (unpack "(a16)*", $data) {
        if ($size) {
            $current_size += length($chunk);
            if ($current_size >= $size) {
                $chunk = substr $chunk, 0, 16 - ($current_size - $size);
                $is_last = 1;
            }
        }
        my $hex = unpack "H*", $chunk;
        $chunk =~ tr/ -~/./c;          # replace unprintables
        $hex =~ s/(.{1,8})/$1 /gs;   # insert spaces
        $output .= $linebreak . $ddp->maybe_colorize(
            sprintf("0x%08x (%05u)  %-*s %s", $offset, $offset, 36, $hex, $chunk),
            'filter_contenttype_hexdump',
            '#ffcb68'
        );
        last if $is_last;
        $offset += 16;
    }
    return $output;
}

1;
__END__

=head1 NAME

Data::Printer::Filter::ContentType - detect popular (binary) content in strings

=head1 SYNOPSIS

In your C<.dataprinter> file:

    filters = ContentType

You may also customize the look and feel with the following options (defaults shown):

    filter_contenttype.show_size = 1
    filter_contenttype.size_unit = auto

    # play around with these if you want to print the binary content:
    filter_contenttype.hexdump        = 0
    filter_contenttype.hexdump_size   = 0
    filter_contenttype.hexdump_offset = 0
    filter_contenttype.hexdump_indent = 0

    # you can even customize your themes:
    colors.filter_contenttype         = #ca88dd
    colors.filter_contenttype_hexdump = #ffcb68

That's it!

=head1 DESCRIPTION

This is a filter plugin for L<Data::Printer> that looks for binary strings
with signatures from popular file types. If one is detected, instead of the
bogus binary dump it will print the content type and the string size.

For example, let's say you've read an image file into C<$data>, maybe from
a user upload or from Imager or ImageMagick. If you use Data::Printer with
this filter, it will show you something like this:

    my $data = get_image_content_from_somewhere();

    use DDP; p $data;   # (PNG Image, 32K)

=head2 hexdump

If, for whatever reason, you want to inspect the actual content of the binary
data, you may set C<filter_contenttype.hexdump> to true. This will pretty-print
your data in hexadecimal, similar to tools like C<hexdump>. Once active, it
will print the entire content, but you may limit the size by changing
C<filter_contenttype.hexdump_size> to any value (unit == bytes), and you can
even start from a different position using
C<filter_contenttype.hexdump_offset>. Set it to a negative value to make your
offset relative to the end to the data.

Finally, the default hexdump mode will not indent your content. Since it's a
binary dump, we want to get as much terminal space as we can. If you rather
have the dump properly indented (relative to your current dump indentation
level), just set C<filter_contenttype.hexdump_indent> to 1.

=head2 Detected Content

Below are the signatures detected by this filter.

=head3 Images

=over 4

=item * PNG

=item * JPEG

=item * GIF

=item * ICO

=item * TIFF

=item * BMP

=back

=head3 Video

=over 4

=item * AVI

=item * MPEG

=back

=head3 Audio

=over 4

=item * WAV

=item * MP3

=item * FLAC

=item * OGG

=back

=head3 Documents and Archives

=over 4

=item * ZIP

=item * GZIP

=item * BZIP2

=item * PDF

=item * Binary Executables (ELF and Win32)

=back

We don't want this list to grow into a full-blown detection system, and
instead just focus on common types. So if you want to contribute with patches
or open an issue for a missing type, please make sure you
I<actually have data structures with that content> (e.g. you were bit by this
in your code and DDP didn't help).

We want to help people debug code, not add content types just
for the sake of it :)

=head1 SEE ALSO

L<Data::Printer>
