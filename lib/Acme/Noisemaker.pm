package Acme::Noisemaker;

our $VERSION = '0.005';

use strict;
use warnings;

use Imager;
use Math::Trig qw| :radial deg2rad |;

use constant Rho => 1;

use base qw| Exporter |;

our @EXPORT_OK = qw|
  make img smooth clamp noise lerp coslerp spheremap
  white square perlin complex
|;

our %EXPORT_TAGS = (
  'flavors' => [
    qw| white square perlin complex spheremap img smooth |
  ],

  'all' => \@EXPORT_OK,
);

our $QUIET;

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
  print "  [-sphere <0|1>] \\                       ## Make fake spheremap\n";
  print "  [-refract <0|1>] \\                      ## Refractive noise\n";
  print "  [-quiet <0|1>] \\                        ## No STDOUT spam\n";
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
    elsif ( $arg =~ /sphere/ ) { $args{sphere} = shift; }
    elsif ( $arg =~ /refract/ ) { $args{refract} = shift; }
    elsif ( $arg =~ /quiet/ ) { $QUIET = shift; }
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

  if ( $args{sphere} ) {
    $grid = spheremap($grid,%args);
  }

  if ( $args{refract} ) {
    $grid = refract($grid);
  }

  my $img = img($grid);

  # $img->filter(type=>'autolevels');

  $img->write(file => $args{out}) || die $img->errstr;

  print "Saved file to $args{out}\n" if !$QUIET;

  return($grid, $img);
}

sub defaultArgs {
  my %args = @_;

  $args{smooth} = 1 if !defined $args{smooth};

  $args{type}    ||= 'perlin';
  $args{freq}    ||= 4;
  $args{len}     ||= 256;
  $args{octaves} ||= 3;
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

  print "    ... Frequency: $freq, Amplitude $amp, Bias $bias\n"
    if !$QUIET;

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

  $args{amp} ||= .5;
  $args{amp} *= $args{octaves};

  my $length = $args{len};
  my $amp = $args{amp};
  my $freq = $args{freq};
  my $bias = $args{bias};
  my $octaves = $args{octaves};

  my @layers;

  for ( my $o = 0; $o < $octaves; $o++ ) {
    print "  ... Working on octave ". ($o+1) ."... \n"
      if !$QUIET;

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

sub refract {
  print "Refracting...\n" if !$QUIET;

  my $grid = shift;
  my $haveLength = scalar(@{ $grid });

  my $out = [ ];

  for ( my $x = 0; $x < $haveLength; $x++ ) {
    $out->[$x] = [ ];

    for ( my $y = 0; $y < $haveLength; $y++ ) {
      my $color = $grid->[$x]->[$y] || 0;
      my $srcY = ($color/256)*$haveLength;
      $srcY -= $haveLength if $srcY > $haveLength;
      $srcY += $haveLength if $srcY < 0;

      $out->[$x]->[$y] = $grid->[0]->[$srcY];
    }
  }

  return $out;
}

sub smooth {
  print "Smoothing...\n" if !$QUIET;

  my $grid = shift;
  my $haveLength = scalar(@{ $grid });

  my $smooth = [ ];

  for ( my $x = 0; $x < $haveLength; $x++ ) {
    $smooth->[$x] = [ ];

    for ( my $y = 0; $y < $haveLength; $y++ ) {
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

      $smooth->[$x]->[$y] = $corners + $sides + $center;
    }
  }

  return $smooth;
}

sub complex {
  my %args = @_;

  %args = defaultArgs(%args);

  $args{amp} ||= .5;
  $args{feather} = 50 if !defined $args{feather};
  $args{layers} ||= 4;

  my $reference = perlin(%args);

  my @layers;

  do {
    my $biasOffset = .5;
    my $bias = 0;
    my $amp = $args{amp};

    for ( my $i = 0; $i < $args{layers}; $i++ ) {
      print "### Complex Layer $i...\n" if !$QUIET;

      push @layers, perlin(%args,
        # amp  => $amp,
        bias => $bias,
      );

      $bias += $biasOffset;
      $biasOffset *= .5;
      $amp *= .5;
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

        } elsif (
          ( ( $feather > 0 ) && $diff <= $feather )
           || ( ( $feather < 0 ) && $diff <= $feather*-1 )
        ) {
          my $fadeAmt = $diff / abs($feather);

          if ( $feather < 0 ) {
            $fadeAmt = 1 - $fadeAmt;
          }

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

  return $out;
  # return $args{smooth} ? smooth($out) : $out;
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

sub spheremap {
  my $grid = shift;
  my %args = @_;

  print "Generating spheremap...\n" if !$QUIET;

  my $len = $args{len};
  my $offset = $len/2;

  my $out = [ ];

  my $srclen = scalar(@{$grid});
  my $scale = $srclen/$len;

  #
  # Polar regions
  #
  for ( my $x = 0; $x < $len; $x++ ) {
    for ( my $y = 0; $y < $len; $y++ ) {
      ### North Pole
      do {
        my ($cartX, $cartY, $cartZ) = cartCoords($x,$y,$len,$scale);
        $out->[$x]->[$y/2] =
          $grid->[$srclen - $cartX]->[$cartY/2];
      };

      ### South Pole
      do {
        my ($cartX, $cartY, $cartZ) = cartCoords($x,$y,$len,$scale);

        $out->[$x]->[$len-($y/2)] =
          $grid->[$cartX]->[($offset*$scale)+($cartY/2)];
      };
    }
  }

  #
  # Equator
  #
  for ( my $x = 0; $x < $len; $x++ ) {
    for ( my $y = 0; $y < $len; $y++ ) {
      my $diff = abs($offset - $y);
      my $pct = $diff/$offset;

      my $srcY = $scale * $y / 2;
      $srcY += ($offset/2) * $scale;
      $srcY -= $srclen if $srcY > $srclen;

      my $source = $grid->[$scale*$x]->[$srcY];

      my $target = $out->[$x]->[$y] || 0;

      $out->[$x]->[$y] = coslerp($source, $target, $pct);
    }
  }

  return $args{smooth} ? smooth($out) : $out;
  # return $out;
}

sub cartCoords {
  my $x = shift;
  my $y = shift;
  my $len = shift;
  my $scale = shift || 1;

  my $thisLen = $len * $scale;
  $x *= $scale;
  $y *= $scale;

  $x -= $thisLen if $x > $thisLen;
  $y -= $thisLen if $y > $thisLen;
  $x += $thisLen if $x < 0;
  $y += $thisLen if $y < 0;

  my $theta = deg2rad( ($x/$thisLen)*360 );
  my $phi   = deg2rad( ($y/$thisLen)*90 );

  my ($cartX, $cartY, $cartZ) = spherical_to_cartesian(Rho, $theta, $phi);

  $cartX = int( (($cartX+1)/2)*$thisLen );
  $cartY = int( (($cartY+1)/2)*$thisLen );
  $cartZ = int( (($cartZ+1)/2)*$thisLen );

  return($cartX, $cartY, $cartZ);
}

1;
__END__
=pod

=head1 NAME

Acme::Noisemaker - Visual noise generator

=head1 VERSION

This document is for version B<0.005> of Acme::Noisemaker.

=head1 SYNOPSIS;

  use Acme::Noisemaker qw| make |;

Make some noise and save it as an image to the specified filename:

  make(
    type => $type,        # white|square|perlin|complex
    out  => $filename,    # "pattern.bmp"

    #
    # Any noise args or post-processing args
    #
  );

A wrapper script, C<bin/make-noise>, is included with this distribution.

  bin/make-noise --type complex --out pattern.bmp

Noise sets are just 2D arrays:

  use Acme::Noisemaker qw| :flavors |;

  my $grid = square(%args);

  #
  # Look up a value, given X and Y coords
  #
  my $value = $grid->[$x]->[$y];

L<Imager> can take care of further post-processing.

  my $grid = perlin(%args);

  my $img = img($grid);

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

=head1 FUNCTIONS

=over 4

=item * make(type => $type, out => $filename, %ARGS)

  my ( $grid, $img ) = make(
    type => "perlin",
    out  => "perlin.bmp",

    #
    # Any noise args or post-processing args
    #
  );
  
Creates the specified noise type (white, square, perlin, or complex),
writing the resulting image to the received filename.

Returns the resulting dataset, as well as the L<Imager> object which
was created from it.

See POST-PROCESSING FUNCTIONS for additional fun-ctionality.

C<make-noise>, included with this distribution, provides a CLI for
this function.

=item * img($grid)

  my $grid = perlin();

  my $img = img($grid);

  #
  # Insert Imager image manip stuff here!
  #

  $img->write(file => "oot.png");

Returns an L<Imager> object from the received two-dimensional grid.

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

=head1 POST-PROCESSING FUNCTIONS

=over 4

=item * smooth($grid)

  #
  # Unsmoothed noise source
  #
  my $grid = white(smooth => 0);

  my $smooth = smooth($grid);

Perform smoothing of the values contained in the received two-dimensional
grid. Returns a new grid.

Smoothing is on by default.

=item * spheremap($grid, %args)

Generates a fake spheremap from the received 2D noise grid by
embellishing the polar regions.

Applies polar coordinates along the north and south edges of the
source image, slowly blending back into original pixel values towards
the middle.

Polar regions are currently twice the frequency of the equator-- I
hope to fix this eventually.

Returns a new 2D grid of pixel values.

  my $grid = perlin(%args);

  my $spheremap = spheremap($grid);

C<sphere> may also be passed as an arg to to C<make>.

  my $grid = make(
    type => "perlin",
    sphere => 1,
  );

=item * refract($grid)

Return a new grid, replacing the color values in the received grid
with one-dimensional indexed noise values from itself. This can
enhance the "fractal" appearance of noise.

  my $grid = perlin(%args);

  my $refracted = refract($grid);

C<refract> may also be passed as an arg to C<make>.

  my $grid = make(
    type => "perlin",
    refract => 1,
  );

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

For the purposes of this module, amplitude actually means semi-amplitude
(peak-to-peak amp/2), and frequency represents the edge length of
the starting white noise grid.

...in addition, Perlin and Complex noise accept:

  oct     - Octave count, increases the complexity of Perlin noise

...and Complex noise has several more possible args:

  feather - Edge falloff amount for Complex noise. 0-255
  layers  - Number of noise sources to use for Complex noise

=over 4

=item * White

  my $grid = white(
    amp     => <num>,
    freq    => <num>,
    len     => <int>,
    bias    => <num>,
    smooth  => <0|1>
  );

=begin html

<p><img src="data:image/jpg;base64,
/9j/4AAQSkZJRgABAQEASABIAAD/7QAcUGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAD/2wBDAAIB
AQIBAQICAQICAgICAwUDAwMDAwYEBAMFBwYHBwcGBgYHCAsJBwgKCAYGCQ0JCgsLDAwMBwkNDg0M
DgsMDAv/2wBDAQICAgMCAwUDAwULCAYICwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsL
CwsLCwsLCwsLCwsLCwsLCwv/wAARCACBAIEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAA
AAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEI
I0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlq
c3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW
19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL
/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLR
ChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOE
hYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn
6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwCT4N32pPp+qeE7q+0m72Ws1uLy8k85dPYKGEjk8BwO
4PHNJZ/BLXvFfwr8WSazq9hFaxmC5ttURyZNSEf/ACytAThcnPFcBJpniDxz+05oep+J5WsPCPiu
d7DWINPQR21k2CpDEDgN1wa6L4j3E/wps5/C3gnxHquo2WhXQjtrm5tgYYrR+ClqzDDAHgtzjtQB
0Xgv4KeD9Tsxo3iMR65qnifRnWK4MuZoy/JEyD7rLgrnpXIPY2XwU1PRrz9nG4lvLbw7CbS2to1F
3dWc4fDu0YwfL69e9X/iD4H1PQ/AHhGaefSLLX7nbNb3FrctFezwbjsjfaMbgPmJOM1rfATVvC3w
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
" title="Example of white noise" alt="Example of white noise" height="128" width="128"></p>

=end html

White noise, for the purposes of this module, is probably what most
people think of as noise. It looks like television static-- every
pixel contains a pseudo-random value.

=item * Diamond-Square

  my $grid = square(
    amp     => <num>,
    freq    => <num>,
    len     => <int>,
    bias    => <num>,
    smooth  => <0|1>
  );

=begin html

<p><img src="data:image/jpg;base64,
/9j/4AAQSkZJRgABAQEASABIAAD/7QAcUGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAD/2wBDAAIB
AQIBAQICAQICAgICAwUDAwMDAwYEBAMFBwYHBwcGBgYHCAsJBwgKCAYGCQ0JCgsLDAwMBwkNDg0M
DgsMDAv/2wBDAQICAgMCAwUDAwULCAYICwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsL
CwsLCwsLCwsLCwsLCwsLCwv/wAARCACBAIEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAA
AAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEI
I0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlq
c3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW
19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL
/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLR
ChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOE
hYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn
6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD2Kf8AaA13wP8ADGVLS8it7qY+aY2l6KPY1y/xJ+Ml
z8RPhlayvfA3c1ssawsdykk9eKzviDYxfEnUrk36GzQ7oH3KOM+orI8UaRp3w6+GLX8Eq+Tp+LXO
wHacetAGJ4Tu9U8N67YEyGApGEnEH3CuevvX0r8OtGluNEWaO8c2zgzbUk2EnsfrXxPb/tMW1krR
2H764mtmeAnnZ2/KtrTv2tPEHw/0Ca5ulElt9nEhMsvyRHHb2oA5/wDb18JR6p4qnuLC5s5Z2ics
t9JhmyeTiuH+CutWnw502z1WKCxi+wKIFlt4zkt1PNbPxJ+PeifE3QhqfiJLC5uJIwocR7igPYH0
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
B//Z
" title="Example of square noise" alt="Example of square noise" height="128" width="128"></p>

=end html

Sometimes called "cloud" or "plasma" noise. Often suffers from
diamond- and square-shaped artifacts, but there are ways of dealing
with them.

This module seeds the initial values with White noise.

=item * Perlin

  my $grid = perlin(
    amp     => <num>,
    freq    => <num>,
    len     => <int>,
    oct     => <int>,
    bias    => <num>,
    smooth  => <0|1>
  )

=begin html

<p><img src="data:image/jpg;base64,
/9j/4AAQSkZJRgABAQEASABIAAD/7QAcUGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAD/2wBDAAIB
AQIBAQICAQICAgICAwUDAwMDAwYEBAMFBwYHBwcGBgYHCAsJBwgKCAYGCQ0JCgsLDAwMBwkNDg0M
DgsMDAv/2wBDAQICAgMCAwUDAwULCAYICwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsL
CwsLCwsLCwsLCwsLCwsLCwv/wAARCACBAIEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAA
AAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEI
I0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlq
c3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW
19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL
/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLR
ChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOE
hYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn
6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD758G3vij4daXY6j4k/wCJjDcQbrlrgAyb/wDCvE/i
D8NtR+JvxGnvY0jk8OzyedcxMPnSXsF9q9+u/iDP4/8AFyXf9lTW+g20HlvFMNuCO4rxX4tftCWV
j45it/B9o0VtbuUkypKlvegDif2kP2fvCuueE520/Ube3ubJMTWiON0gI615n+xtZ2/gnxUPC8Fv
KNNvpMyOwwW9x6gVofFmS6+LCvdeGI447i7vhBM8QIVB7ntXZeGPAVt8KvCv/CTeNHlaTQYmhS5D
BY8nufWgD6t+FkOl65ot34etLi9iO5kTAwkq98E14P8AHX9mvRtC+ICPpNvEtjJGVMN5lkY/xCvE
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
" title="Example of Perlin noise" alt="Example of Perlin noise" height="128" width="128"></p>

=end html

Perlin noise (not related to Perl) combines multiple noise sources
to produce very turbulent-looking noise.

This module generates its Perlin slices from Diamond-Square noise.

=item * Complex Perlin

  my $grid = complex(
    amp     => <num>,
    freq    => <num>,
    len     => <int>,
    oct     => <int>,
    bias    => <num>,
    feather => <num>,
    layers  => <int>,
    smooth  => <0|1>
  )

=begin html

<p><img src="data:image/jpg;base64,
/9j/4AAQSkZJRgABAQEASABIAAD/7QAcUGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAD/2wBDAAIB
AQIBAQICAQICAgICAwUDAwMDAwYEBAMFBwYHBwcGBgYHCAsJBwgKCAYGCQ0JCgsLDAwMBwkNDg0M
DgsMDAv/2wBDAQICAgMCAwUDAwULCAYICwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsL
CwsLCwsLCwsLCwsLCwsLCwv/wAARCACBAIEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAA
AAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEI
I0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlq
c3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW
19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL
/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLR
ChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOE
hYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn
6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD5N8IeCvGHhXUNe1qJLmRZMmKREIBc9MetaXgrwH42
8Y6is2vXM0MLkeY5G1vyr688WafFF4LaLw3d2zzQDcoZQFjx3ri9D03V9a0S9MMtpLe26rMkoH7s
jPIbHtQBT8KeHBpy6fbaHqM0ktq586KRuWPuKr/Cv9m208c/tAf2F4yMv2DUbg3WVHyBz2zXUaX8
OEvXh8RW92H1CSQI1pByWHqBXongzQNU1PUIBpltJZagso2SMNrNQBs+Jfgz4e+F/iWe0umt7K0s
0B8wYGAPU180ftgz3vjr4v6Hf/D25trzw/a2nlv5Zy0r5719IfHj4e3GuX4s/Ed+lxceRmWNW5Yn
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
PEv/AF6n+Vcnov8AyCZ/95qKKAPPaKKKAP/Z
" title="Example of complex noise" alt="Example of complex noise" height="128" width="128"></p>

=end html

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
