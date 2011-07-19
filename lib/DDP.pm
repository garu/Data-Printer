package DDP;
BEGIN {
    require Data::Printer;
    push @ISA, 'Data::Printer';
    our $VERSION = $Data::Printer::VERSION;
}
1;
