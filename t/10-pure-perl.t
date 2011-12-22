use strict;
use warnings;
use Test::More;

plan skip_all => "PP tests already executed"
  if $ENV{NAMESPACE_CLEAN_USE_PP};

eval { require B::Hooks::EndOfScope }
  or plan skip_all => "PP tests already executed";

eval { require Devel::Hide }
  or plan skip_all => "Devel::Hide required for this test in presence of B::Hooks::EndOfScope";

use Config;
use FindBin qw($Bin);
use IPC::Open2 qw(open2);

# for the $^X-es
$ENV{PERL5LIB} = join ($Config{path_sep}, @INC);

# rerun the tests under the assumption of pure-perl
my $this_file = quotemeta(__FILE__);

for my $fn (glob("$Bin/*.t")) {
  next if $fn =~ /${this_file}$/;

  local $ENV{DEVEL_HIDE_VERBOSE} = 0;
  my @cmd = ( $^X, '-MDevel::Hide=B::Hooks::EndOfScope', $fn );

  # this is cheating, and may even hang here and there (testing on windows passed fine)
  # if it does - will have to fix it somehow (really *REALLY* don't want to pull
  # in IPC::Cmd just for a fucking test)
  # the alternative would be to have an ENV check in each test to force a subtest
  open2(my $out, my $in, @cmd);
  while (my $ln = <$out>) {
    print "   $ln";
  }

  wait;
  ok (! $?, "Exit $? from: @cmd");
}

done_testing;
