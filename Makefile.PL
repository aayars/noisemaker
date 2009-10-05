use ExtUtils::MakeMaker;

my $prereqs = {
  Imager => 0.67,
  Math::Trig => 1.2,
  Test::More => 0.86,
};

WriteMakefile(
  ABSTRACT_FROM => 'lib/Math/Fractal/Noisemaker.pm',
  VERSION_FROM  => 'lib/Math/Fractal/Noisemaker.pm',
  NAME          => 'Math::Fractal::Noisemaker',
  PREREQ_PM     => $prereqs,
  LICENSE       => 'open_source',
  AUTHOR        => 'Alex Ayars <pause@nodekit.org>',
  EXE_FILES     => ['bin/make-noise'],
);
