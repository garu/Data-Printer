### Contributing to Data::Printer

Hey! Thank you for wanting to contribute 🎉

Regardless of your experience, all contributions and suggestions are welcome!

#### Getting started

Data::Printer has *a lot* of customization options and extensive documentation so [check it out first](). If something looks outdated or not as clear as it could be, or even if you just found a typo, please [open a ticket on Github](https://github.com/garu/Data-Printer/issues/new/choose).

#### Expected behaviour on discussions

The main place to discuss about DDP's bugs and features is [Github's ticketing system](https://github.com/garu/Data-Printer/issues).

Whether you're sending patches or asking questions, we ask everyone to be respectful, mindful and open to collaboration, favoring a welcoming and inclusive language. In short: please be nice to each other - it goes a long way :)

(if you need a better definition of "nice", you may check [here](https://github.com/stumpsyn/policies/blob/master/citizen_code_of_conduct.md))

#### Navigating through the code

We have a single main branch on our git repository, where all the work
is performed and/or merged into. When we make a release, we tag it.

To help you naviage the codebase, below is a rough project outline:

DDP.pm - an alias to Data::Printer;
Data/Printer.pm - initialization, main imported functions and output handling;
Data/Printer/Common.pm - shared code (string processing, try/catch, sorting, etc);
Data/Printer/Config.pm - rc file loading, option merging;
Data/Printer/Object.pm - stores options, dispatches data to active filters;
Data/Printer/Filter.pm - used in filters, exports the 'filter' command;
Data/Printer/Filter/*.pm - filters that print each data type;
Data/Printer/Theme.pm - handles color themes;
Data/Printer/Theme/*.pm - each contain a theme's color settings;

#### Submitting your patch / pull request

Getting your hands dirty is even better than opening an issue 🥰

Before you send your Pull Request, please make sure you create a test case for
the new behaviour. We expect all patches to have been properly tested before
they can be accepted and merged.

Oh! And make sure you add your name to the "CONTRIBUTORS" list as part of
your patch.

Bug fixes are usually accepted quickly, but if you're adding a new feature or
changing Data::Printer's behaviour, please note your changes may take some
time to be merged or *may even not be merged at all* - not because there's
anything wrong with it, but simply because it may not be aligned with the
project's long-term vision. If you are unsure as to whether the feature
you're trying to implement adheres to that vision, talk to us by opening
an issue on Github.

That's it! Thank you for your work, and have fun!
