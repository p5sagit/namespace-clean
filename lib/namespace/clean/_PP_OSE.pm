package # hide from the pauses
  namespace::clean::_PP_OSE;

use warnings;
use strict;

use Tie::Hash;
use Hash::Util::FieldHash 'fieldhash';

# Here we rely on a combination of several behaviors:
#
# * %^H is deallocated on scope exit, so any references to it disappear
# * A lost weakref in a fieldhash causes the corresponding key to be deleted
# * Deletion of a key on a tied hash triggers DELETE
#
# Therefore the DELETE of a tied fieldhash containing a %^H reference will
# be the hook to fire all our callbacks.
#
# The SUPER:: gimmick is there to ensure the fieldhash is cleaned up in a
# timely manner. When you call delete() in non-void context, you get a mortal
# scalar whose reference count decreases at the end of the current statement.
# During scope exit, ‘statement’ is not clearly defined, so more scope
# unwinding could happen before the mortal gets freed. Forcing the DELETE
# in void context localizes the life of the mortal scalar.

fieldhash my %hh;
{
  package namespace::clean::_TieHintHashFieldHash;
  use base 'Tie::StdHash';
  sub DELETE {
    $_->() for @{ $_[0]->{$_[1]} };
    shift->SUPER::DELETE(@_);
    1; # put the preceding statement in void context so the free is immediate
  }
}

sub on_scope_end (&) {
  $^H |= 0x020000;

  tie(%hh, 'namespace::clean::_TieHintHashFieldHash')
    unless tied %hh;

  push @{ $hh{\%^H} ||= [] }, shift;
}

1;
