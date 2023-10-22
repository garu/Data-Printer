package Data::Printer::Profile;
1;
__END__

=head1 NAME

Data::Printer::Profile - customize your Data::Printer with code

=head1 SYNOPSIS

    package Data::Printer::Profile::MyProfile;

    sub profile {
        return {
            show_tainted => 1,
            show_unicode => 0,
            array_max    => 30,

            # ...and so on...
        }
    }
    1;

Then put in your '.dataprinter' file:

    profile = MyProfile

or load it at compile time:

    use DDP profile => 'MyProfile';

or anytime during execution:

    p $some_data, profile => 'MyProfile';


=head1 DESCRIPTION

Usually a C<.dataprinter> file is enough to customize Data::Printer. But
sometimes you want to use actual code to create special filters and rules,
like a dynamic color scheme depending on terminal background or even the
hour of the day, or a custom message that includes the hostname. Who knows!

Or maybe you just want to be able to upload your settings to CPAN and load
them easily anywhere, as shown in the SYNOPSIS.

For all those cases, use a profile class!

=head2 Creating a profile class

Simply create a module named C<Data::Printer::Profile::MyProfile>
(replacing, of course, "MyProfile" for the name of your profile).

That class doesn't have to inherit from C<Data::Printer::Profile>, nor
add Data::Printer as a dependency. All you have to do is implement a
subroutine called C<profile()> that returns a hash reference with
all the options you want to use.


=head2 Load order

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
though it will still be overridden by other inline arguments.


=head1 SEE ALSO

L<Data::Printer>
L<Data::Printer::Filter>
