Data::Printer
=============

[![Build status](https://travis-ci.org/garu/Data-Printer.svg?branch=master)](https://travis-ci.org/garu/Data-Printer)
[![Coverage Status](https://coveralls.io/repos/garu/Data-Printer/badge.png)](https://coveralls.io/r/garu/Data-Printer)
[![CPAN version](https://badge.fury.io/pl/Data-Printer.png)](http://badge.fury.io/pl/Data-Printer)

Data::Printer is a Perl module to
*pretty-print Perl data structures and objects* in full color,
in a way that is *properly formatted to be inspected by a human*.

Basic Usage:
------------

```perl
    my $data = get_some_data_from_somewhere();
    ...
    use DDP; p $data;  # <-- pretty-prints $data's content to STDERR
```

Main features:
--------------

* Variable dumps designed for _easy parsing by the human brain_, not a machine;

* _Highly customizable_, from indentation size to depth level.
You can even rename the exported p() function!

* Beautiful (and customizable) colors to highlight variable dumps and make
issues stand-out quickly on your console. Comes bundled with 4 themes for you
to pick.

* Filters for specific data structures and objects to make debugging much,
much easier. Includes filters for several popular classes from CPAN like
JSON::\*, URI, HTTP::\*, LWP, Digest::\*, DBI and DBIx::Class. Also lets you
create your own custom filters easily.

* Lets you inspect information that's otherwise difficult to find/debug
in Perl 5, like circular references, reference counting (refcount),
weak/read-only information, even estimated data size - all to help you
spot issues with your data like leaks without having to know a lot about
internal data structures or install heavy-weight tools like Devel::Gladiator.

* output to many different targets like files, variables or open handles
(defaults to STDERR)

* keep your customized settings on a `.dataprinter` file that allows
_different options per module_ being analyzed!

* Best of all? *No non-core dependencies*, Zero. Nada. so don't worry about
adding extra weight to your project, as Data::Printer can be easily
added/removed.

Please refer to [Data::Printer's complete documentation](https://metacpan.org/pod/Data::Printer)
for details on how to customize the output to your needs. Or (after installation) type:

    perldoc Data::Printer

To view the complete docs on your terminal.


Installation
------------

To install this module via cpanm:

    > cpanm Data::Printer

Or, at the cpan shell:

    cpan> install Data::Printer

If you wish to install it manually, download and unpack the tarball and
run the following commands:

	perl Makefile.PL
	make
	make test
	make install

Of course, instead of downloading the tarball you may simply clone the
git repository:

    $ git clone git://github.com/garu/Data-Printer.git


Thank you for using Data::Printer! Please let me know of potential issues,
bugs and wishlists :)


LICENSE AND COPYRIGHT
---------------------

Copyright (C) 2011-2018 Breno G. de Oliveira

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

