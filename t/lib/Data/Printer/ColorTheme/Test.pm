package Data::Printer::ColorTheme::Test;
use strict;
use warnings;

use base 'Data::Printer::ColorTheme';

# ColorTheme for Solarized terminal

sub array       { 'bright_green'    }
sub number      { 'cyan'            }
sub string      { 'cyan'            }
sub class       { 'yellow'          }
sub method      { 'blue'            }
sub undef       { 'green'           }
sub hash        { 'cyan'            }
sub regex       { 'red'             }
sub glob        { 'bright_red'      }
sub vstring     { 'cyan'            }
sub repeated    { 'bright_magenta'  }
sub caller_info { 'bright_green'    }
sub weak        { 'magenta'         }
sub tainted     { 'bright_magenta'  }
sub escaped     { 'red'             }

1;
