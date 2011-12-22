package # hide from the pauses
  namespace::clean::_PP_OSE;

use warnings;
use strict;

use namespace::clean::_PP_SG;
use Tie::Hash;
use Hash::Util::FieldHash 'fieldhash';

# Hash::Util::FieldHash is not deleting elements in void context. When
# you call delete() in non-void context, a mortal scalar is returned. A
# mortal scalar is one whose reference count decreases at the end of the
# current statement. During scope exit, ‘statement’ is not clearly
# defined, so more scope unwinding could happen before the mortal gets
# freed.
# By tying it and overriding DELETE, we can force the deletion into
# void context.

fieldhash my %hh;

{
  package namespace::clean::_TieHintHashFieldHash;
  use base 'Tie::StdHash';
  sub DELETE {
    shift->SUPER::DELETE(@_);
    1; # put the preceding statement in void context
  }
}


sub on_scope_end (&) {
  $^H |= 0x020000;

  tie(%hh, 'namespace::clean::_TieHintHashFieldHash')
    unless tied %hh;

  push @{$hh{\%^H} ||= []},
    namespace::clean::_PP_SG->arm(shift);
}

1;
