use strict;
use warnings;
use Test::More;
use Data::Printer::Object;
use Data::Printer::Common;

if ($] < 5.038) {
    plan skip_all => 'perl native classes only available after 5.38';
    exit;
}

my $error = Data::Printer::Common::_tryme(<<'EOCODE'
  use 5.38.0;
  use warnings;
  use feature 'class';
  no warnings 'experimental::class';

  class MyBaseClass {
    field $one :param;
    field $two;
    field $three :param //= 0;

    method base_foo { }
  }

  class MyClass :isa(MyBaseClass) {
    field $four;
    field $five   :param = 42;
    field $six    :param;
    field $seven  :param(four);

    ADJUST { $four = $five }

    method foo ($x) {
      return $x * 2;
    }
    sub not_a_method { }
  };

  1;
EOCODE
);

if ($error) {
  plan skip_all => "error creating class: $error";
  exit;
}
plan tests => 1;

my $obj = MyClass->new( one => 'um', six => 'seis', four => 'quatro' );

my $ddp = Data::Printer::Object->new( colored => 0 );
my $res = $ddp->parse($obj);

is $res, 'MyClass  {
    parents: MyBaseClass
    public methods (4):
        foo, new, not_a_method
        MyBaseClass:
            base_foo
    private methods (0)
    internals: (opaque object)
}', 'parsed perl 5.38 native object type';
