package # hide from the pauses
  namespace::clean::_PP_SG;

use warnings;
use strict;

sub arm { bless [ $_[1] ] }
sub DESTROY { $_[0]->[0]->() }

1;
