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
  can_cc() ? (
    'B::Hooks::EndOfScope' => '0.07', # when changing, also change version in namespace/clean.pm
    is_smoker() ? ( 'Devel::Hide' => 0 ) : (),  # make sure we smoke the pure-perl version
  ) : (),
);

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

  'PREREQ_PM' => {
    %RUN_DEPS,
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

sub is_smoker {
  return ( $ENV{AUTOMATED_TESTING} && ! $ENV{PERL5_CPANM_IS_RUNNING} && ! $ENV{RELEASE_TESTING} )
}
