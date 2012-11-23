use strict;
use warnings;
use Test::More;

plan skip_all => "PP tests already executed"
  if $ENV{NAMESPACE_CLEAN_USE_PP};

eval { require B::Hooks::EndOfScope }
  or plan skip_all => "PP tests already executed";

# the PP tests will run either wih D::H (mainly on smokers)
# or by setting the envvar (for users)
my $has_d_h = eval { require Devel::Hide };

use Config;
use FindBin qw($Bin);
use IPC::Open2 qw(open2);
use File::Glob 'bsd_glob';

# for the $^X-es
$ENV{PERL5LIB} = join ($Config{path_sep}, @INC);

# rerun the tests under the assumption of pure-perl
my $this_file = quotemeta(__FILE__);

for my $fn (bsd_glob("$Bin/*.t")) {
  next if $fn =~ /${this_file}$/;

  local $ENV{DEVEL_HIDE_VERBOSE} = 0;
  local $ENV{NAMESPACE_CLEAN_USE_PP} = 1 unless $has_d_h;
  my @cmd = (
    $^X,
    $has_d_h ? '-MDevel::Hide=B::Hooks::EndOfScope' : (),
    $fn
  );

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
