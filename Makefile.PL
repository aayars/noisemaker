use ExtUtils::MakeMaker;

my $prereqs = {
  Imager                 => 0.70,
  File::Tempdir          => 0.02,
  Math::Complex          => 1.56,
  Test::Simple           => 0.86,
  Tie::CArray            => 0.15,
};

WriteMakefile(
  VERSION_FROM => 'lib/Math/Fractal/Noisemaker.pm',
  NAME         => 'Math::Fractal::Noisemaker',
  PREREQ_PM    => $prereqs,
  LICENSE      => 'perl',
  AUTHOR       => 'Alex Ayars <pause@nodekit.org>',
  EXE_FILES    => ['bin/make-noise'],
);
