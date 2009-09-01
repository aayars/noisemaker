package Acme::Noisemaker;

our $VERSION = '0.003';

use strict;
use warnings;

use Imager;

sub usage {
  my $warning = shift;
  print "$warning\n" if $warning;

  print "Usage:\n";
  print "$0 \\\n";
  print "  [-type <white|square|perlin|complex>] \\ ## Noise type\n";
  print "  [-amp <num>] \\                          ## Base amplitude (eg .5)\n";
  print "  [-freq <num>] \\                         ## Base frequency (eg 2)\n";
  print "  [-len <int>] \\                          ## Side length (eg 256)\n";
  print "  [-oct <int>] \\                          ## Octave count (eg 4)\n";
  print "  [-bias <num>] \\                         ## Value bias (0..1)\n";
  print "  [-feather <num>] \\                      ## Feather amt (0..255)\n";
  print "  [-layers <int>] \\                       ## Complex layers (eg 3)\n";
  print "  [-smooth <0|1>] \\                       ## Anti-aliasing off/on\n";
  print "  -out <filename>                         ## Output file (foo.bmp)\n";
  print "\n";
  print "perldoc Acme::Noisemaker for more help.\n";
  print "\n";

  exit 2;
}

sub make {
  my %args;

  ###
  ### type
  ###
  while ( my $arg = shift ) {
    if ( $arg =~ /type/ ) { $args{type} = shift; }
    elsif ( $arg =~ /amp/ ) { $args{amp} = shift; }
    elsif ( $arg =~ /freq/ ) { $args{freq} = shift; }
    elsif ( $arg =~ /len/ ) { $args{len} = shift; }
    elsif ( $arg =~ /oct/ ) { $args{octaves} = shift; }
    elsif ( $arg =~ /bias/ ) { $args{bias} = shift; }
    elsif ( $arg =~ /feather/ ) { $args{feather} = shift; }
    elsif ( $arg =~ /layers/ ) { $args{layers} = shift; }
    elsif ( $arg =~ /smooth/ ) { $args{smooth} = shift; }
    elsif ( $arg =~ /out/ ) { $args{out} = shift; }
    else { usage("Unknown argument: $arg") }
  }

  %args = defaultArgs(%args);

  usage("No output file specified") if !$args{out};

  my $grid;
  if ( $args{type} eq 'white' ) {
    $grid = white(%args);
  } elsif ( $args{type} eq 'square' ) {
    $grid = square(%args);
  } elsif ( $args{type} eq 'perlin' ) {
    $grid = perlin(%args);
  } elsif ( $args{type} eq 'complex' ) {
    $grid = complex(%args);
  } else {
    usage("Unknown noise type");
  }

  my $img = img($grid);

  $img->write(file => $args{out}) || die $img->errstr;

  return($grid, $img);
}

sub defaultArgs {
  my %args = @_;

  $args{smooth} = 1 if !defined $args{smooth};

  $args{type}    ||= 'perlin';
  $args{freq}    ||= 4;
  $args{len}     ||= 256;
  $args{octaves} ||= 4;
  $args{bias}    ||= .5;

  return %args;
}

sub img {
  my $grid = shift;

  my $length = scalar(@{ $grid });

  ###
  ### Save the image
  ###
  my $img = Imager->new(
    xsize => $length,
    ysize => $length,
  );

  for ( my $x = 0; $x < $length; $x++ ) {
    for ( my $y = 0; $y < $length; $y++ ) {
      my $gray = clamp($grid->[$x]->[$y]);

      do {
        $img->setpixel(
          x => $x,
          y => $y,
          color => [ $gray, $gray, $gray ],
        );
      };
    }
  }

  return $img;
}

sub white {
  my %args = @_;

  %args = defaultArgs(%args);

  my $freq = $args{freq};
  my $amp = $args{amp} || .5;
  my $bias = $args{bias};

  my $grid = [ ];

  my $length = $args{len} || 2*$freq;

  my $ampValue = 255 * $amp;
  my $biasValue = 255 * $bias;

  for ( my $x = 0; $x < $length; $x++ ) {
    $grid->[$x] = [ ];

    for ( my $y = 0; $y < $length; $y++ ) {
      my $randAmp = rand($ampValue);
      $randAmp *= -1 if rand(1) >= .5;

      $grid->[$x]->[$y] = $randAmp + $biasValue;
    }
  }

  return $args{smooth} ? smooth($grid) : $grid;
}

sub square {
  my %args = @_;

  %args = defaultArgs(%args);

  my $freq = $args{freq};
  my $amp = $args{amp} || .5;
  my $bias = $args{bias};
  my $length = $args{len};

  my $grid = white(%args,
    freq => $freq,
    amp => $amp,
    bias => $bias
  );

  my $haveLength = $freq * 2;
  my $baseOffset = 255 * $amp;

  print "    ... Frequency: $freq, Amplitude $amp, Bias $bias\n";

  until ( $haveLength >= $length ) {
    my $grown = [ ];

    for ( my $x = 0; $x < $haveLength*2; $x++ ) {
      $grown->[$x] = [ ];
      for ( my $y = 0; $y < $haveLength*2; $y++ ) {
        push @{ $grown->[$x] }, undef;
      }
    }

    for ( my $x = 0; $x < $haveLength; $x++ ) {
      my $thisX = $x * 2;

      for ( my $y = 0; $y < $haveLength; $y++ ) {
        my $thisY = $y * 2;

        my $offset = rand($baseOffset);
        $offset *= -1 if ( rand(1) >= .5 );
        # $grown->[$thisX]->[$thisY] = clamp($grid->[$x]->[$y] + $offset);
        $grown->[$thisX]->[$thisY] = $grid->[$x]->[$y] + $offset;
      }
    }

    for ( my $x = 0; $x < $haveLength; $x++ ) {
      my $thisX = $x * 2;
      $thisX += 1;

      for ( my $y = 0; $y < $haveLength; $y++ ) {
        my $thisY = $y * 2;
        $thisY += 1;

        my $corners = (
          noise($grid, $x-1,$y-1)
           + noise($grid, $x+1,$y-1)
           + noise($grid, $x-1,$y+1)
           + noise($grid, $x+1,$y+1)
        ) / 4;

        my $offset = rand($baseOffset);
        $offset *= -1 if ( rand(1) >= .5 );
        # $grown->[$thisX]->[$thisY] = clamp($corners + $offset);
        $grown->[$thisX]->[$thisY] = $corners + $offset;
      }
    }

    $haveLength *= 2;

    for ( my $x = 0; $x < $haveLength; $x++ ) {
      for ( my $y = 0; $y < $haveLength; $y++ ) {
        next if defined $grown->[$x]->[$y];

        my $sides = (
          noise($grown,$x-1,$y)
           + noise($grown,$x+1,$y)
           + noise($grown,$x,$y-1)
           + noise($grown,$x,$y+1)
        ) / 4; 

        my $offset = rand($baseOffset);
        $offset *= -1 if ( rand(1) >= .5 );
        # $grown->[$x]->[$y] = clamp($sides + $offset);
        $grown->[$x]->[$y] = $sides + $offset;
      }
    }

    $baseOffset /= 2;

    $grid = $grown;
  }

  return $args{smooth} ? smooth($grid) : $grid;
}

sub perlin {
  my %args = @_;

  %args = defaultArgs(%args);

  $args{amp} ||= $args{octaves};

  my $length = $args{len};
  my $amp = $args{amp};
  my $freq = $args{freq};
  my $bias = $args{bias};
  my $octaves = $args{octaves};

  my @layers;

  for ( my $o = 0; $o < $octaves; $o++ ) {
    print "  ... Working on octave ". ($o+1) ."... \n";

    push @layers, square(%args,
      freq => $freq,
      amp => $amp,
      bias => $bias,
      len => $length
    );

    $amp *= .5;

    $freq *= 2;
  }

  my $combined = [ ];

  for ( my $x = 0; $x < $length; $x++ ) {
    $combined->[$x] = [ ];

    for ( my $y = 0; $y < $length; $y++ ) {
      my $n;
      my $t;

      for ( my $z = 0; $z < @layers; $z++ ) {
        $n++;

        $t += $layers[$z][$x]->[$y];
      }

      # $combined->[$x]->[$y] = clamp($t/$n);
      $combined->[$x]->[$y] = $t/$n;
    }
  }

  return $args{smooth} ? smooth($combined) : $combined;
}

sub smooth {
  print "Smoothing...\n";

  my $grid = shift;
  my $haveLength = scalar(@{ $grid });

  my $smooth = [ ];

  for ( my $x = 0; $x <= $haveLength; $x++ ) {
    $smooth->[$x] = [ ];

    for ( my $y = 0; $y <= $haveLength; $y++ ) {
      my $corners = (
        noise($grid,$x-1,$y-1)
         + noise($grid,$x+1,$y-1)
         + noise($grid,$x-1,$y+1)
         + noise($grid,$x+1,$y+1)
      ) / 16;

      my $sides = (
        noise($grid,$x-1,$y)
         + noise($grid,$x+1,$y)
         + noise($grid,$x,$y-1)
         + noise($grid,$x,$y+1)
      ) / 8;

      my $center = noise($grid,$x,$y) / 4;

      $smooth->[$x]->[$y] = clamp($corners + $sides + $center);
    }
  }

  return $smooth;
}

sub complex {
  my %args = @_;

  %args = defaultArgs(%args);

  $args{amp} ||= $args{octaves};
  $args{feather} ||= 25;
  $args{layers}  ||= 4;

  my $reference = perlin(%args);

  my @layers;

  do {
    my $bias = 0;
    my $biasOffset = .5;
    my $amp = $args{amp} * $args{octaves};

    for ( my $i = 0; $i < $args{layers}; $i++ ) {
      push @layers, perlin(%args,
        amp  => $amp,
        bias => $bias,
      );

      $bias += $biasOffset;
      $amp = ( $args{amp} - $bias ) * $args{octaves};

      $biasOffset /= 2;
    }
  };

  my $out = [ ];

  my $feather = $args{feather};
  my $length = $args{len};

  for ( my $x = 0; $x < $length; $x++ ) {
    $out->[$x] = [ ];

    for ( my $y = 0; $y < $length; $y++ ) {
      my $value = $reference->[$x]->[$y];

      $out->[$x]->[$y] = $value if !defined $out->[$x]->[$y];

      my $level = 0;
      my $levelOffset = 128;

      for ( my $z = 0; $z < $args{layers}; $z++ ) {
        my $diff = $level - $value;

        if ( $value >= $level ) {
          ##
          ## Reference pixel value is greater than current level,
          ## so use the current level's pixel value
          ##
          $out->[$x]->[$y] = $layers[$z][$x]->[$y];

        } elsif ( $diff <= $feather ) {
          my $fadeAmt = $diff / $feather;

          ##
          ## Reference pixel value is less than current level,
          ## but within the feather range, so fade it
          ##
          my $color = coslerp(
            $layers[$z][$x]->[$y],
            $out->[$x]->[$y],
            $fadeAmt,
          );

          $out->[$x]->[$y] = $color;
        }

        $out->[$x]->[$y] = coslerp(
          $out->[$x]->[$y],
          $value,
          .25
        );

        $level += $levelOffset;
        $levelOffset /= 2;
      }
    }
  }

  return $args{smooth} ? smooth($out) : $out;
}

sub clamp {
  my $val = shift;

  $val = 0 if $val < 0;
  $val = 255 if $val > 255;

  return $val;
}

sub noise {
  my $noise = shift;
  my $x = shift;
  my $y = shift;
  
  my $length  = @{ $noise };

  $x -= $length if $x >= $length;
  $y -= $length if $y >= $length;
        
  die "no data for $x,$y" if !defined $noise->[$x]->[$y];
      
  return $noise->[$x]->[$y];
}

sub lerp {
  my $a = shift;
  my $b = shift;
  my $x = shift;

  return( $a * (1-$x) + $b*$x );
}

sub coslerp {
  my $a = shift;
  my $b = shift;
  my $x = shift;

  my $ft = ( $x * 3.145927 );
  my $f = ( 1 - cos($ft)) * .5;

  return( $a * (1-$f) + $b*$f );
}

1;
__END__
=pod

=head1 NAME

Acme::Noisemaker - Visual noise generator

=head1 VERSION

This document is for version B<0.003> of Acme::Noisemaker.

=head1 SYNOPSIS;

  use Acme::Noisemaker;

Make some noise and save it as an image to the specified filename:

  Acme::Noisemaker::make(
    type => $type,        # white|square|perlin|complex
    out  => $filename,    # "pattern.bmp"
  );

A wrapper script, C<bin/make-noise>, is included with this distribution.

  bin/make-noise --type complex --out pattern.bmp

Noise sets are just 2D arrays:

  my $grid = Acme::Noisemaker::square(%args);

  #
  # Look up a value, given X and Y coords
  #
  my $value = $grid->[$x]->[$y];

L<Imager> can take care of further post-processing.

  my $grid = Acme::Noisemaker::perlin(%args);

  my $img = Acme::Noisemaker::img($grid);

  #
  # Insert image manip methods here!
  #

  $img->write(file => "oot.png");

=head1 DESCRIPTION

This module generates various types of two-dimensional grayscale
noise. It is not fast, it is not a faithful implementation of any
particular algorithm, and it probably never will be.

It is, possibly, a fun and/or educational toy if you are interested
in procedural texture generation, or might be useful if you just
want a simple module to make a few unique patterns with.

As long as the provided side length is a power of the noise's base
frequency, this module will produce seamless tiles. For example, a
base frequency of 2 would work fine for an image with a side length
of 256 (256x256).

Other than using L<Imager> for output, this is a pure Perl module.

=head1 FUNCTIONS

=over 4

=item * make(type => $type, out => $filename, %ARGS)

  my ( $grid, $img ) = Acme::Noisemaker::make(
    type => "perlin",
    out  => "perlin.bmp"
  );
  
Creates the specified noise type (white, square, perlin, or complex),
writing the resulting image to the received filename.

Returns the resulting dataset, as well as the Imager object which
was created from it.

=item * img($grid)

  my $grid = Acme::Noisemaker::perlin();

  my $img = Acme::Noisemaker::img($grid);

  #
  # Insert Imager image manip stuff here!
  #

  $img->write(file => "oot.png");

Returns an L<Imager> object from the received two-dimensional grid.

=item * smooth($grid)

  #
  # Unsmoothed noise source
  #
  my $grid = Acme::Noisemaker::white(smooth => 0);

  my $smooth = smooth($grid);

Perform smoothing of the values contained in the received two-dimensional
grid. Returns a new grid.

=item * clamp($value)

  my $clamped = clamp($num);

Limits the received value to between 0 and 255. If the received
value is less than 0, returns 0; more than 255, returns 255; otherwise
returns the same value which was received.

=item * noise($grid, $x, $y)

The so-called "noise function" required to generate coherent noise.
Returns the same "random" value each time it is called with the same
arguments (makes it more like a key hashing function a la memcached
doesn't it? Not very random, if you ask me).

Acme::Noisemaker diverges from most Perlin implementations in that its
noise function simply utilizes a lookup table. The lookup table
contains pre-populated random values. Turns out, this works fine.

=item * lerp($a, $b, $x)

Linear interpolate from $a to $b, by $x percent. $x is between 0
and 1. Not currently used, but it's there.

http://en.wikipedia.org/wiki/Linear_interpolation

=item * coslerp($a, $b, $x)

Cosine interpolate from $a to $b, by $x percent. $x is between 0 and 1.

=back

=head1 GENERATORS

Each noise function returns a two-dimentional array containing
grayscale values.

All function args are optional-- the built-in defaults should be
reasonable to get started with. Each noise function accepts the
following args in hash key form:

  amp     - Amplitude, or max variance from the bias value
  freq    - Frequency, or "density" of the noise produced
  len     - Side length of the output images, which are always square
  bias    - "Baseline" value for all pixels, .5 = 50%
  smooth  - Enable/disable noise smoothing. 1 is recommended.

...in addition, Perlin and Complex noise accept:

  oct     - Octave count, increases the complexity of Perlin noise

...and Complex noise has several more possible args:

  feather - Edge falloff amount for Complex noise. 0-255
  layers  - Number of noise sources to use for Complex noise

=over 4

=item * White

  my $grid = Acme::Noisemaker::white(
    amp     => <num>,
    freq    => <num>,
    len     => <int>,
    bias    => <num>,
    smooth  => <0|1>
  );

White noise, for the purposes of this module, is probably what most
people think of as noise. It looks like television static-- every
pixel contains a pseudo-random value.

=item * Diamond-Square

  my $grid = Acme::Noisemaker::square(
    amp     => <num>,
    freq    => <num>,
    len     => <int>,
    bias    => <num>,
    smooth  => <0|1>
  );

Sometimes called "cloud" or "plasma" noise. Often suffers from
diamond- and square-shaped artifacts, but there are ways of dealing
with them.

This module seeds the initial values with White noise.

=item * Perlin

  my $grid = Acme::Noisemaker::perlin(
    amp     => <num>,
    freq    => <num>,
    len     => <int>,
    oct     => <int>,
    bias    => <num>,
    smooth  => <0|1>
  )

Perlin noise (not related to Perl) combines multiple noise sources
to produce very turbulent-looking noise.

This module generates its Perlin slices from Diamond-Square noise.

=item * Complex Perlin

  my $grid = Acme::Noisemaker::complex(
    amp     => <num>,
    freq    => <num>,
    len     => <int>,
    oct     => <int>,
    bias    => <num>,
    feather => <num>,
    layers  => <int>,
    smooth  => <0|1>
  )

Complex Perlin noise combines multiple Perlin noise sources. This
is not a real name for any noise type beyond this module, as far
as I can tell, but the methodology used to combine the noise is
heavily inspired by the way I<libnoise> allows the daisy-chaining
of different noise modules.

=back

=head1 SEE ALSO

Acme::Noisemaker is on github: http://github.com/aayars/noisemaker

=over 4

=item * Wikipedia

As usual, Wikipedia is there for us.

Diamond-Square algorithm:
  http://en.wikipedia.org/wiki/Diamond-square_algorithm

Perlin Noise:
  http://en.wikipedia.org/wiki/Perlin_noise

White Noise:
  http://en.wikipedia.org/wiki/White_noise

Interpolation:
  http://en.wikipedia.org/wiki/Interpolation

=item * Generating Random Fractal Terrain -
http://gameprogrammer.com/fractal.html

This page has a good intro to Diamond-Square noise. It taught
me how to make clouds.

=item * Perlin Noise -
http://freespace.virgin.net/hugo.elias/models/m_perlin.htm

Acme::Noisemaker heavily pilfers the pseudo-code for interpolation and
smoothing functions which I found at the above site.

=item * libnoise - http://libnoise.sourceforge.net/

"A portable, open-source, coherent noise-generating library for C++"

Though it does not use it, Acme::Noisemaker is inspired by B<libnoise>,
which is what you should really be using if you're serious about
this sort of thing. It is very cool stuff. The developer has provided
many examples which let you write C++ without actually knowing it
(cue Sorcerer's Apprentice music...)

=item * pynoise - http://home.gna.org/pynoise/

Python bindings to libnoise via swig. I would like to make a package
like this for Perl one day, unless someone else wants to first.

=back

=head1 AUTHOR

  Alex Ayars <pause@nodekit.org>

=head1 COPYRIGHT

  File: Acme/Noisemaker.pm
 
  Copyright (c) 2009 Alex Ayars
 
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Common Public License v1.0
  which accompanies this distribution, and is available at
  http://opensource.org/licenses/cpl1.0.txt

=cut
