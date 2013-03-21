package Data::Printer::ColorTheme;
use strict;
use warnings;

use Carp qw();

sub new {
    my ($class, @args) = @_;
    Carp::croak "Initialize with type/color pairs" if @args % 2;
    return bless { @args } => $class;
}

sub provides {
    my ($self) = @_;
    return grep {
        defined &{$_}
        and $_ ne 'new'
        and $_ ne 'provides'
    } keys %Data::Printer::ColorTheme::;
}

sub array       { my ($self) = @_; return defined($self->{array       }) ? $self->{array       } : 'bright_white'           }
sub number      { my ($self) = @_; return defined($self->{number      }) ? $self->{number      } : 'red on_white'           }
sub string      { my ($self) = @_; return defined($self->{string      }) ? $self->{string      } : 'bright_yellow'          }
sub class       { my ($self) = @_; return defined($self->{class       }) ? $self->{class       } : 'bright_green'           }
sub method      { my ($self) = @_; return defined($self->{method      }) ? $self->{method      } : 'bright_green'           }
sub undef       { my ($self) = @_; return defined($self->{undef       }) ? $self->{undef       } : 'bright_red'             }
sub hash        { my ($self) = @_; return defined($self->{hash        }) ? $self->{hash        } : 'magenta'                }
sub regex       { my ($self) = @_; return defined($self->{regex       }) ? $self->{regex       } : 'yellow'                 }
sub code        { my ($self) = @_; return defined($self->{code        }) ? $self->{code        } : 'green'                  }
sub glob        { my ($self) = @_; return defined($self->{glob        }) ? $self->{glob        } : 'bright_cyan'            }
sub vstring     { my ($self) = @_; return defined($self->{vstring     }) ? $self->{vstring     } : 'bright_blue'            }
sub lvalue      { my ($self) = @_; return defined($self->{lvalue      }) ? $self->{lvalue      } : 'bright_white'           }
sub format      { my ($self) = @_; return defined($self->{format      }) ? $self->{format      } : 'bright_cyan'            }
sub repeated    { my ($self) = @_; return defined($self->{repeated    }) ? $self->{repeated    } : 'white on_red'           }
sub caller_info { my ($self) = @_; return defined($self->{caller_info }) ? $self->{caller_info } : 'bright_cyan'            }
sub weak        { my ($self) = @_; return defined($self->{weak        }) ? $self->{weak        } : 'cyan'                   }
sub tainted     { my ($self) = @_; return defined($self->{tainted     }) ? $self->{tainted     } : 'red'                    }
sub escaped     { my ($self) = @_; return defined($self->{escaped     }) ? $self->{escaped     } : 'bright_red'             }
sub unknown     { my ($self) = @_; return defined($self->{unknown     }) ? $self->{unknown     } : 'bright_yellow on_blue'  }

1;
