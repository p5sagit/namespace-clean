use strict;
use warnings;
use 5.008001;

my %META = (
  name => 'namespace-clean',
  license => 'perl_5',

  abstract => 'Keep imports and functions out of your namespace',
  author => [
    'Robert \'phaylon\' Sedlacek <rs@474.at>',
    'Florian Ragwitz <rafl@debian.org>',
    'Jesse Luehrs <doy@tozt.net>',
    'Peter Rabbitson <ribasushi@cpan.org>',
    'Father Chrysostomos <sprout@cpan.org>',
  ],

  prereqs => {
    configure => {
      requires => {
        'ExtUtils::MakeMaker'   => 0,
        'ExtUtils::CBuilder'    => 0.27,
      }
    },
    runtime => {
      requires => {
        'Package::Stash' => '0.23',
        'B::Hooks::EndOfScope' => '0.12',
        'perl' => '5.008001',
      },
    },
    test => {
      requires => {
        'Test::More' => '0.88',
      }
    },
  },

  resources => {
    x_IRC => 'irc://irc.perl.org/#toolchain',
    homepage => 'http://search.cpan.org/dist/namespace-clean',
    repository => {
      type => 'git',
      url => 'git://git.shadowcat.co.uk/p5sagit/namespace-clean.git',
      web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=p5sagit/namespace-clean.git',
    },
    bugtracker => {
      mailto => 'bug-namespace-clean@rt.cpan.org',
      web => 'http://rt.cpan.org/Public/Dist/Display.html?Name=namespace-clean',
    },
  },
);

my %MM_ARGS = ( (
  # a sub-namer is needed if using the debugger on some perls
  require 'lib/namespace/clean/_Util.pm'
    and
  namespace::clean::_Util::DEBUGGER_NEEDS_CV_RENAME()
    and
  namespace::clean::_Util::_namer_load_error()
    and
  can_xs()
)
  # when changing version, also change $sn_ver in namespace/clean/_Util.pm
  ? ( PREREQ_PM => { 'Sub::Name' => '0.04' } )
  : ()
);


## BOILERPLATE ###############################################################
require ExtUtils::MakeMaker;

# have to do this since old EUMM dev releases miss the eval $VERSION line
my $eumm_version  = eval $ExtUtils::MakeMaker::VERSION;
my $mymeta        = $eumm_version >= 6.57_02;
my $mymeta_broken = $mymeta && $eumm_version < 6.57_07;

($MM_ARGS{NAME} = $META{name}) =~ s/-/::/g;
($MM_ARGS{VERSION_FROM} = "lib/$MM_ARGS{NAME}.pm") =~ s{::}{/}g;
$META{license} = [ $META{license} ]
  if $META{license} && !ref $META{license};
$MM_ARGS{LICENSE} = $META{license}[0]
  if $META{license} && $eumm_version >= 6.30;
$MM_ARGS{NO_MYMETA} = 1
  if $mymeta_broken;
$MM_ARGS{META_ADD} = { 'meta-spec' => { version => 2 }, %META }
  unless -f 'META.yml';

for (qw(configure build test runtime)) {
  my $key = $_ eq 'runtime' ? 'PREREQ_PM' : uc $_.'_REQUIRES';
  my $r = $MM_ARGS{$key} = {
    %{$META{prereqs}{$_}{requires} || {}},
    %{delete $MM_ARGS{$key} || {}},
  };
  defined $r->{$_} or delete $r->{$_} for keys %$r;
}

$MM_ARGS{MIN_PERL_VERSION} = delete $MM_ARGS{PREREQ_PM}{perl} || 0;

delete $MM_ARGS{MIN_PERL_VERSION}
  if $eumm_version < 6.47_01;
$MM_ARGS{BUILD_REQUIRES} = {%{$MM_ARGS{BUILD_REQUIRES}}, %{delete $MM_ARGS{TEST_REQUIRES}}}
  if $eumm_version < 6.63_03;
$MM_ARGS{PREREQ_PM} = {%{$MM_ARGS{PREREQ_PM}}, %{delete $MM_ARGS{BUILD_REQUIRES}}}
  if $eumm_version < 6.55_01;
delete $MM_ARGS{CONFIGURE_REQUIRES}
  if $eumm_version < 6.51_03;

ExtUtils::MakeMaker::WriteMakefile(%MM_ARGS);
## END BOILERPLATE ###########################################################


# FIXME
# Need to replace with EU::HC, but too many changes for this release already
###########################################
# can we locate a (the) C compiler
sub can_cc {
  my @chunks = split(/ /, $Config::Config{cc}) or return;

  # $Config{cc} may contain args; try to find out the program part
  while (@chunks) {
    return can_run("@chunks") || (pop(@chunks), next);
  }

  return;
}

# check if we can run some command
sub can_run {
  my ($cmd) = @_;

  return $cmd if -x $cmd;
  if (my $found_cmd = MM->maybe_command($cmd)) {
    return $found_cmd;
  }

  require File::Spec;
  for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
    next if $dir eq '';
    my $abs = File::Spec->catfile($dir, $cmd);
    return $abs if (-x $abs or $abs = MM->maybe_command($abs));
  }

  return;
}

# Can our C compiler environment build XS files
sub can_xs {
  # Do we have the configure_requires checker?
  local $@;
  eval "require ExtUtils::CBuilder; ExtUtils::CBuilder->VERSION(0.27)";
  if ( $@ ) {
    # They don't obey configure_requires, so it is
    # someone old and delicate. Try to avoid hurting
    # them by falling back to an older simpler test.
    return can_cc();
  }

  # Do we have a working C compiler
  my $builder = ExtUtils::CBuilder->new(
    quiet => 1,
  );
  unless ( $builder->have_compiler ) {
    # No working C compiler
    return 0;
  }

  # Write a C file representative of what XS becomes
  require File::Temp;
  my ( $FH, $tmpfile ) = File::Temp::tempfile(
    "compilexs-XXXXX",
    SUFFIX => '.c',
  );
  binmode $FH;
  print $FH <<'END_C';
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

int main(int argc, char **argv) {
    return 0;
}

int boot_sanexs() {
    return 1;
}

END_C
  close $FH;

  # Can the C compiler access the same headers XS does
  my @libs   = ();
  my $object = undef;
  eval {
    local $^W = 0;
    $object = $builder->compile(
      source => $tmpfile,
    );
    @libs = $builder->link(
      objects     => $object,
      module_name => 'sanexs',
    );
  };
  my $result = $@ ? 0 : 1;

  # Clean up all the build files
  foreach ( $tmpfile, $object, @libs ) {
    next unless defined $_;
    1 while unlink;
  }

  return $result;
}
