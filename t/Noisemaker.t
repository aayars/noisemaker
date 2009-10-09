package Math::Fractal::Noisemaker;

our @NOISE_TYPES;

package main;

use strict;
use warnings;

use Test::More qw| no_plan |;

use File::Tempdir;

use vars qw| $tempdir $path $nofs %args $testfile |;

BEGIN {
  $testfile = "testimage.bmp";

  $tempdir = File::Tempdir->new;

  $path = $tempdir->name;

  if ( !-d $path ) {
    $nofs = "Couldn't find usable tempdir for testing";
  }
}

use_ok("Math::Fractal::Noisemaker");

my %args = (
  len     => 32,
  in      => $testfile,
  quiet   => 1,
  workdir => $path,
);

while ( my $arg = shift @ARGV ) {
  if    ( $arg =~ /workdir/ ) { $args{workdir} = shift @ARGV }
  elsif ( $arg =~ /format/ )  { $args{format}  = shift @ARGV }
  elsif ( $arg =~ /len/ )     { $args{len}     = shift @ARGV }
  elsif ( $arg =~ /quiet/ )   { $args{quiet}   = shift @ARGV }
  else                        { usage() }
}

if ( $args{workdir} ) {
  $args{in} = join( "/", $args{workdir}, $args{in} );
}

SKIP: {
  skip( $nofs, 1 ) if $nofs;

  ok(
    Math::Fractal::Noisemaker::make(
      %args,
      type => 'mandel',
      out  => $testfile,
    ),
    "infile src"
  );
}

SKIP: {
  ### Test all
  for my $type (@Math::Fractal::Noisemaker::NOISE_TYPES) {
    skip( $nofs, 1 ) if $nofs;

    ok( Math::Fractal::Noisemaker::make( type => $type, %args ), $type );
  }
}

sub usage {
  print "Usage:\n";
  print "$0 \\\n";
  print "  [-workdir <workdir>] \\ ## output directory (eg /tmp)\n";
  print "  [-format <fmt>]\\       ## image format (eg bmp)\n";
  print "  [-len <num>]\\          ## image size length (eg 256)\n";
  print "  [-quiet <0|1>]\\        ## do|don't spam console\n";
  print "\n";

  exit 2;
}
