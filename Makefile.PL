use ExtUtils::MakeMaker;

my $prereqs = {
  Imager => 0.67,
  Math::Trig => 1.2,
  Test::More => 0.86,
};

WriteMakefile(
  ABSTRACT_FROM => 'lib/Acme/Noisemaker.pm',
  VERSION_FROM  => 'lib/Acme/Noisemaker.pm',
  NAME          => 'Acme::Noisemaker',
  PREREQ_PM     => $prereqs,
  LICENSE       => 'open_source',
  AUTHOR        => 'Alex Ayars <pause@nodekit.org>',
);
