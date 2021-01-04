package Data::Printer::Profile;
1;
__END__

=head1 NAME

=head1 DESCRIPTION

Profiles are read first and expanded into their options. So if you have a
profile called MyProfile with, for example:

    show_tainted = 0
    show_lvalue  = 0

And your C<< .dataprinter >> file contains something like:

    profile     = MyProfile
    show_lvalue = 1

The specific 'show_lvalues = 1' will override the other setting in the profile
and the final outcome will be as if your setup said:

    show_tainted = 0
    show_lvalue  = 1

However, that is of course only true when the profile is loaded together with
the other settings. If you set a profile later, for instance as an argument to
C<p()> or C<np()>, then the profile will override any previous settings -
though it will still be overriden by other inline arguments.
