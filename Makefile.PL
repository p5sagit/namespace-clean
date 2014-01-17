use strict;
use warnings;
use 5.008001;

use ExtUtils::MakeMaker;

my $mymeta_works = eval { ExtUtils::MakeMaker->VERSION('6.5707'); 1 };
my $mymeta = $mymeta_works || eval { ExtUtils::MakeMaker->VERSION('6.5702'); 1 };

my %BUILD_DEPS = (
  'Test::More' => '0.88',
);

my %RUN_DEPS = (
  'Package::Stash' => '0.23',
  'B::Hooks::EndOfScope' => '0.12',
);

# these pieces are needed if using the debugger on the perl range
my %OPT_RUN_DEPS = ( $] > 5.008_008_9 and $] < 5.013_005_1 and can_xs() )
  # when changing versions, also change $sn_ver and $si_ver in namespace/clean.pm
  ? ( 'Sub::Name' => '0.04', 'Sub::Identify' => '0.04' ) : ()
;

my %META_BITS = (
  resources => {
    homepage => 'http://search.cpan.org/dist/namespace-clean',

    # EUMM not supporting nested meta :(
    #repository => {
    #  type => 'git',
    #  url => 'git://git.shadowcat.co.uk/p5sagit/namespace-clean.git',
    #  web => 'http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=p5sagit/namespace-clean.git',
    #}
    #bugtracker => {
    #  mailto => 'bug-namespace-clean@rt.cpan.org',
    #  web => 'http://rt.cpan.org/Public/Dist/Display.html?Name=namespace-clean',
    #},

    repository => 'git://git.shadowcat.co.uk/p5sagit/namespace-clean.git',
    bugtracker => 'http://rt.cpan.org/Public/Dist/Display.html?Name=namespace-clean',
  },
);

my %WriteMakefileArgs = (
  'NAME' => 'namespace::clean',
  'VERSION_FROM' => 'lib/namespace/clean.pm',
  'ABSTRACT' => 'Keep imports and functions out of your namespace',
  'AUTHOR' => 'Robert \'phaylon\' Sedlacek <rs@474.at>, Florian Ragwitz <rafl@debian.org>, Jesse Luehrs <doy@tozt.net>',
  'CONFIGURE_REQUIRES' => { 'ExtUtils::CBuilder' => 0.27 },
   'PREREQ_PM' => {
    %RUN_DEPS, %OPT_RUN_DEPS,
    $mymeta_works ? () : (%BUILD_DEPS),
  },

  $mymeta_works
    ? ( # BUILD_REQUIRES makes MYMETA right, requires stops META being wrong
      'BUILD_REQUIRES' => \%BUILD_DEPS,
      'META_ADD' => {
        %META_BITS,
        requires => \%RUN_DEPS,
      },
    )
    : ( # META_ADD both to get META right - only Makefile written
      'META_ADD' => {
        %META_BITS,
        requires => \%RUN_DEPS,
        build_requires => \%BUILD_DEPS,
      },
    )
  ,

  ($mymeta and !$mymeta_works) ? ( 'NO_MYMETA' => 1 ) : (),

  'LICENSE' => 'perl',
);


unless ( eval { ExtUtils::MakeMaker->VERSION('6.56') } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION('6.52') };

WriteMakefile(%WriteMakefileArgs);

# Secondary compile testing via ExtUtils::CBuilder
sub can_xs {
  # Do we have the configure_requires checker?
  local $@;
  eval "require ExtUtils::CBuilder;";
  if ( $@ ) {
    # They don't obey configure_requires, so it is
    # someone old and delicate. Try to avoid hurting
    # them by falling back to an older simpler test.
    return can_cc();
  }

  return ExtUtils::CBuilder->new( quiet => 1 )->have_compiler;
}

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

  for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
    next if $dir eq '';
    my $abs = File::Spec->catfile($dir, $cmd);
    return $abs if (-x $abs or $abs = MM->maybe_command($abs));
  }

  return;
}
