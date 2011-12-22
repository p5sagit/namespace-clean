package # hide from the pauses
  namespace::clean::_PP_OSE_5_8;

use warnings;
use strict;

use namespace::clean::_PP_SG;

# This is the original implementation, which sadly is broken
# on perl 5.10+ withing string evals
sub on_scope_end (&) {
  $^H |= 0x020000;

  push @{$^H{'__namespace::clean__guardstack__'} ||= [] },
    namespace::clean::_PP_SG->arm(shift);
}

1;
