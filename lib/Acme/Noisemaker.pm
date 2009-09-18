package Acme::Noisemaker;

our $VERSION = '0.009';

use strict;
use warnings;

use Imager;
use Math::Trig qw| :radial deg2rad |;

use constant Rho => 1;

use base qw| Exporter |;

our @NOISE_TYPES = qw|
  white wavelet square perlin ridged block complex gel sgel pgel rgel stars
  mandel buddha fern
|;

our @EXPORT_OK = ( qw|
  make img smooth offset clamp noise lerp coslerp spheremap
|, @NOISE_TYPES );

our %EXPORT_TAGS = (
  'flavors' => [ (
    qw| make spheremap img smooth offset |, @NOISE_TYPES
  ) ],

  'all' => \@EXPORT_OK,
);

our $QUIET;

sub usage {
  my $warning = shift;
  print "$warning\n" if $warning;

  print "noisetypes:\n";
  print "  white           ### pseudo-random values\n";
  print "  square          ### diamond-square algorithm\n";
  print "  perlin          ### Perlin algorithm\n";
  print "  ridged          ### ridged multifractal\n";
  print "  block           ### unsmoothed Perlin\n";
  print "  complex         ### complex layered\n";
  print "  gel             ### self-displaced smooth\n";
  print "  sgel            ### self-displaced diamond-square\n";
  print "  pgel            ### self-displaced Perlin\n";
  print "  rgel            ### self-displaced ridged\n";
  print "  stars           ### starfield\n";
  print "\n";
  print "Usage:\n";
  print "$0 \\\n";
  print "  [-type <noisetype>] \\       ## noise type\n";
  print "  [-stype <white|square|gel|sgel|stars>]\\ ## perlin slice type\n";
  print "  [-lbase <any type except complex>]    \\ ## complex basis\n";
  print "  [-ltype <any type except complex>]    \\ ## complex layer\n";
  print "  [-amp <num>] \\              ## base amplitude (eg .5)\n";
  print "  [-freq <num>] \\             ## base frequency (eg 2)\n";
  print "  [-len <int>] \\              ## side length (eg 256)\n";
  print "  [-octaves <int>] \\          ## octave count (eg 4)\n";
  print "  [-bias <num>] \\             ## value bias (0..1)\n";
  print "  [-gap <num>] \\              ## gappiness (0..1)\n";
  print "  [-feather <num>] \\          ## feather amt (0..255)\n";
  print "  [-layers <int>] \\           ## complex layers (eg 3)\n";
  print "  [-smooth <0|1>] \\           ## anti-aliasing off/on\n";
  print "  [-sphere <0|1>] \\           ## make fake spheremap\n";
  print "  [-refract <0|1>] \\          ## refractive noise\n";
  print "  [-offset <num>] \\           ## fractal pixel offset (eg .25)\n";
  print "  [-clut <filename>] \\        ## color table (ex.bmp)\n";
  print "  [-clutdir 0|1|2] \\          ## displace hyp|vert|fract\n";
  print "  [-limit 0|1] \\              ## scale|clip pixel values\n";
  print "  [-zoom <num>] \\             ## mag for fractals\n";
  print "  [-maxiter <num>] \\          ## iter limit for fractals\n";
  print "  [-quiet <0|1>] \\            ## no STDOUT spam\n";
  print "  -out <filename>              # Output file (foo.bmp)\n";
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
    if ( $arg =~ /help/ ) { usage(); }
    elsif ( $arg =~ /(^|-)type/ ) { $args{type} = shift; }
    elsif ( $arg =~ /stype/ ) { $args{stype} = shift; }
    elsif ( $arg =~ /lbase/ ) { $args{lbase} = shift; }
    elsif ( $arg =~ /ltype/ ) { $args{ltype} = shift; }
    elsif ( $arg =~ /amp/ ) { $args{amp} = shift; }
    elsif ( $arg =~ /freq/ ) { $args{freq} = shift; }
    elsif ( $arg =~ /len/ ) { $args{len} = shift; }
    elsif ( $arg =~ /octaves/ ) { $args{octaves} = shift; }
    elsif ( $arg =~ /bias/ ) { $args{bias} = shift; }
    elsif ( $arg =~ /gap/ ) { $args{gap} = shift; }
    elsif ( $arg =~ /feather/ ) { $args{feather} = shift; }
    elsif ( $arg =~ /layers/ ) { $args{layers} = shift; }
    elsif ( $arg =~ /smooth/ ) { $args{smooth} = shift; }
    elsif ( $arg =~ /out/ ) { $args{out} = shift; }
    elsif ( $arg =~ /sphere/ ) { $args{sphere} = shift; }
    elsif ( $arg =~ /refract/ ) { $args{refract} = shift; }
    elsif ( $arg =~ /offset/ ) { $args{offset} = shift; }
    elsif ( $arg =~ /clut$/ ) { $args{clut} = shift; }
    elsif ( $arg =~ /clutdir$/ ) { $args{clutdir} = shift; }
    elsif ( $arg =~ /limit/ ) { $args{auto} = shift() ? 0 : 1; }
    elsif ( $arg =~ /zoom/ ) { $args{zoom} = shift; }
    elsif ( $arg =~ /quiet/ ) { $QUIET = shift; }
    else { usage("Unknown argument: $arg") }
  }

  usage("Specified CLUT file not found") if $args{clut} && !-e $args{clut};

  $args{type} ||= 'perlin';
  $args{stype} ||= 'white';
  $args{lbase} ||= 'perlin';
  $args{ltype} ||= 'perlin';

  if ( ( $args{lbase} =~ /[prs]gel/ ) || ( $args{ltype} =~ /[prs]gel/ ) || $args{stype} =~ /[prs]gel/ ) {
    $args{freq}    ||= 2;
    $args{offset}  ||= .125;
  } elsif ( ( $args{lbase} eq 'gel' ) || ( $args{ltype} eq 'gel' ) || $args{stype} eq 'gel' ) {
    $args{freq}    ||= 4;
    $args{offset}  ||= .5;
  } else {
    $args{octaves} ||= 8;
  }

  if ( !$args{out} ) {
    if ( $args{type} eq 'complex' ) {
      $args{out} = "$args{lbase}-$args{ltype}-$args{stype}.bmp";
    } elsif ( $args{type} =~ /perlin|ridged|block|pgel|rgel/ ) {
      $args{out} = "$args{type}-$args{stype}.bmp";
    } else {
      $args{out} = "$args{type}.bmp";
    }
  }

  # XXX
  # return if -e $args{out};

  my $grid;
  if ( $args{type} eq 'white' ) {
    $grid = white(%args);
  } elsif ( $args{type} eq 'square' ) {
    $grid = square(%args);
  } elsif ( $args{type} eq 'perlin' ) {
    $grid = perlin(%args);
  } elsif ( $args{type} eq 'ridged' ) {
    $grid = ridged(%args);
  } elsif ( $args{type} eq 'block' ) {
    $grid = block(%args);
  } elsif ( $args{type} eq 'complex' ) {
    $grid = complex(%args);
  } elsif ( $args{type} eq 'gel' ) {
    $grid = gel(%args);
  } elsif ( $args{type} eq 'sgel' ) {
    $grid = sgel(%args);
  } elsif ( $args{type} eq 'pgel' ) {
    $grid = pgel(%args);
  } elsif ( $args{type} eq 'rgel' ) {
    $grid = rgel(%args);
  } elsif ( $args{type} eq 'mandel' ) {
    $grid = mandel(%args);
  } elsif ( $args{type} eq 'buddha' ) {
    $grid = buddha(%args);
  } elsif ( $args{type} eq 'fern' ) {
    $grid = fern(%args);
  } elsif ( $args{type} eq 'gasket' ) {
    $grid = gasket(%args);
  } elsif ( $args{type} eq 'wavelet' ) {
    $grid = wavelet(%args);
  } elsif ( $args{type} eq 'stars' ) {
    $grid = stars(%args);
  } else {
    usage("Unknown noise type");
  }

  if ( $args{refract} ) {
    $grid = refract($grid,%args);
  }

  if ( $args{sphere} ) {
    %args = defaultArgs(%args);

    $grid = spheremap($grid,%args);
  }

  my $img;

  if ( $args{clut} && $args{clutdir} ) {
    $img = vertclut($grid,%args);
  } elsif ( $args{clut} ) {
    $img = hypoclut($grid,%args);
  } else {
    $img = img($grid,%args);
  }

  # $img->filter(type=>'autolevels');

  $img->write(file => $args{out}) || die $img->errstr;

  print "Saved file to $args{out}\n" if !$QUIET;

  return($grid, $img, $args{out});
}

sub defaultArgs {
  my %args = @_;

  $args{bias} = .5 if !defined $args{bias};
  $args{smooth} = 1 if !defined $args{smooth};
  $args{auto} = 1 if !defined($args{auto}) && $args{type} ne 'fern';

  $args{gap}     ||= 0;
  $args{type}    ||= 'perlin';
  $args{freq}    ||= 4;
  $args{len}     ||= 256;
  $args{octaves} ||= 8;

  return %args;
}

sub img {
  my $grid = shift;
  my %args = defaultArgs(@_);

  print "Generating image...\n" if !$QUIET;

  my $length = scalar(@{ $grid });

  ###
  ### Save the image
  ###
  my $img = Imager->new(
    xsize => $length,
    ysize => $length,
  );

  ###
  ### Scale pixel values to sane levels
  ###
  my ( $min, $max, $range );

  if ( $args{auto} || $args{type} eq 'ridged' ) {
    for ( my $x = 0; $x < $length; $x++ ) {
      for ( my $y = 0; $y < $length; $y++ ) {
        my $gray = $grid->[$x]->[$y];

        if ( $args{type} eq 'ridged' && $gray < 0 ) {
          $gray = abs($gray);
          $grid->[$x]->[$y] = $gray;
        }

        $min = $gray if !defined $min;
        $max = $gray if !defined $max;

        $min = $gray if $gray < $min;
        $max = $gray if $gray > $max;
      }
    }

    $range = $max - $min;
  }

  for ( my $x = 0; $x < $length; $x++ ) {
    for ( my $y = 0; $y < $length; $y++ ) {
      my $gray = $grid->[$x]->[$y];

      my $scaled;

      if ( $args{auto} ) {
        $scaled = $range ? (($gray-$min)/$range)*255 : 0;
      } else {
        $scaled = clamp($gray);
      }

      if ( $args{type} eq 'ridged' ) {
        $scaled = abs(255-$scaled);
      }

      do {
        $img->setpixel(
          x => $x,
          y => $y,
          color => [ $scaled, $scaled, $scaled ],
        );
      };
    }
  }

  return $img;
}

sub grow {
  my $noise = shift;
  my %args = @_;

  my $grid = $noise;

  my $wantLength = $args{len};
  my $haveLength = scalar( @{ $noise } );

  until ( $haveLength >= $wantLength ) {
    my $grown = [ ];

    for ( my $x = 0; $x < $haveLength*2; $x++ ) {
      $grown->[$x] = [ ];

      for ( my $y = 0; $y < $haveLength*2; $y++ ) {
        $grown->[$x]->[$y] = $grid->[$x/2]->[$y/2];
      }
    }

    $grid = $args{smooth} ? smooth($grown,%args) : $grown;

    $haveLength *= 2;
  }

  return $grid;
}

sub shrink {
  my $noise = shift;
  my %args = @_;

  my $grid = $noise;

  my $wantLength = $args{len};
  my $haveLength = scalar( @{ $noise } );

  until ( $haveLength <= $wantLength ) {
    my $grown = [ ];

    for ( my $x = 0; $x < $haveLength/2; $x++ ) {
      $grown->[$x] = [ ];

      for ( my $y = 0; $y < $haveLength/2; $y++ ) {
        $grown->[$x]->[$y] = $grid->[$x*2]->[$y*2]/4;
        $grown->[$x]->[$y] += $grid->[(($x*2)+1) % $haveLength]->[$y*2]/4;
        $grown->[$x]->[$y] += $grid->[$x*2]->[(($y*2)+1) % $haveLength]/4;
        $grown->[$x]->[$y] += $grid->[(($x*2)+1) % $haveLength]->[($y*2)+1]/4;
      }
    }

    $haveLength /= 2;

    $grid = $grown;
  }

  return $grid;
}

sub white {
  my %args = @_;

  print "Generating white noise...\n" if !$QUIET;

  $args{len} ||= 256;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $grid = [ ];

  my $freq = $args{freq};
  my $gap  = $args{gap};

  $args{amp} = .5 if !defined $args{amp};

  my $ampVal  = $args{amp} * 255;
  my $biasVal = $args{bias} * 255;

  for ( my $x = 0; $x < $freq; $x++ ) {
    $grid->[$x] = [ ];

    for ( my $y = 0; $y < $freq; $y++ ) {
      if ( rand() < $gap ) {
        $grid->[$x]->[$y] = 0;
        next;
      }

      my $randAmp = rand($ampVal);

      $randAmp *= -1 if rand(1) >= .5;

      $grid->[$x]->[$y] = $randAmp + $biasVal;
    }
  }

  return grow($grid,%args);
}

sub stars {
  my %args = @_;

  $args{bias} = .5;
  $args{amp}  = .5;
  $args{gap}  = .995;

  my $grid = white(%args);

  return smooth($grid, %args);
}

sub gel {
  my %args = @_;

  print "Generating gel noise...\n" if !$QUIET;

  $args{offset} = 4 if !defined $args{offset};
  $args{freq}   = 8 if !defined $args{freq};

  %args = defaultArgs(%args);

  my $grid = white(%args);

  return offset($grid,%args);
}

sub offset {
  my $grid = shift;
  my %args = @_;

  print "Applying fractal XY displacement...\n" if !$QUIET;

  my $out = [ ];

  my $length = $args{len};
  my $offset = $args{offset};

  $offset = .5 if !defined $offset;

  $offset = ($offset/1)*($length/256); # Same visual offset for diff size imgs

  for ( my $x = 0; $x < $length; $x++ ) {
    $out->[$x] = [ ];

    for ( my $y = 0; $y < $length; $y++ ) {
      my $offsetX = noise($grid,$x,$y)*$offset;
      my $offsetY = noise($grid,$length-$x,$length-$y)*$offset;

      $out->[$x]->[$y] = noise($grid,
        int($x + $offsetX),
        int($y + $offsetY)
      );
    }
  }

  return $out;
}

sub square {
  my %args = defaultArgs(@_);

  print "Generating square noise...\n" if !$QUIET;

  my $freq = $args{freq};
  my $amp = $args{amp};
  my $bias = $args{bias};
  my $length = $args{len};

  $amp = .5 if !defined $amp;

  my $grid = white(%args, len => $freq*2);

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
        # $grown->[$thisX]->[$thisY] = $grid->[$x]->[$y] + $offset;
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
        $grown->[$x]->[$y] = $sides + $offset;
      }
    }

    $baseOffset /= 2;

    $grid = $grown;
  }

  if ( $args{smooth} ) {
    $grid = smooth($grid,%args);
  }

  return $grid;
}

sub sgel {
  my %args = defaultArgs(@_);

  print "Generating square gel noise...\n" if !$QUIET;

  my $grid = square(%args);

  return offset($grid,%args);
}

sub perlin {
  my %args = @_;

  print "Generating Perlin noise...\n" if !$QUIET;

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
    last if $freq > $length;

    print "Octave ". ($o+1) ." ... \n"
      if !$QUIET;

    my $generator;

    if ( $args{stype} eq 'white' ) {
      $generator = \&white;
    } elsif ( $args{stype} eq 'square' ) {
      $generator = \&square;
    } elsif ( $args{stype} eq 'gel' ) {
      $generator = \&gel;
    } elsif ( $args{stype} eq 'sgel' ) {
      $generator = \&sgel;
    } elsif ( $args{stype} eq 'stars' ) {
      $generator = \&stars;
    } elsif ( $args{stype} eq 'mandel' ) {
      $generator = \&mandel;
    } elsif ( $args{stype} eq 'buddha' ) {
      $generator = \&buddha;
    } elsif ( $args{stype} eq 'wavelet' ) {
      $generator = \&wavelet;
    } elsif ( $args{stype} eq 'fern' ) {
      $generator = \&fern;
    } else {
      usage("Unknown layer type specified");
    }

    push @layers, &$generator(%args,
      freq => $freq,
      amp => $amp,
      bias => $bias,
      len => $length,
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

        my $gray = $layers[$z][$x]->[$y];

        if ( $args{ridged} ) {
          $t += abs($gray);
        } else {
          $t += $gray;
        }
      }

      $combined->[$x]->[$y] = $t/$n;
    }
  }

  return $combined;
}

sub block {
  my %args = @_;

  print "Generating block noise...\n" if !$QUIET;

  $args{smooth} = 0;

  return perlin(%args);
}

sub pgel {
  my %args = @_;

  print "Generating Perlin gel noise...\n" if !$QUIET;

  my $grid = perlin(%args);

  $args{offset} = 2 if !defined $args{offset};

  %args = defaultArgs(%args);

  return offset($grid,%args);
}

sub ridged {
  my %args = @_;

  print "Generating ridged multifractal noise...\n" if !$QUIET;

  $args{ridged} = 1;
  $args{bias} ||= 0;
  $args{amp}  ||= 1;

  return perlin(%args);
}

sub rgel {
  my %args = @_;

  print "Generating ridged multifractal gel noise...\n" if !$QUIET;

  $args{ridged} = 1;

  return pgel(%args);
}

sub refract {
  my $grid = shift;
  my %args = @_;

  print "Applying fractal Z displacement...\n" if !$QUIET;

  my $haveLength = scalar(@{ $grid });

  my $out = [ ];

  for ( my $x = 0; $x < $haveLength; $x++ ) {
    $out->[$x] = [ ];

    for ( my $y = 0; $y < $haveLength; $y++ ) {
      my $color = $grid->[$x]->[$y] || 0;
      my $srcY = ($color/255)*$haveLength;
      $srcY -= $haveLength if $srcY > $haveLength;
      $srcY += $haveLength if $srcY < 0;

      $out->[$x]->[$y] = $grid->[0]->[$srcY];
    }
  }

  return $out;
}

sub smooth {
  my $grid = shift;
  my %args = @_;

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

  print "Generating complex noise...\n" if !$QUIET;

  $args{amp} = 1 if !defined $args{amp};
  $args{feather} = 75 if !defined $args{feather};
  $args{layers}  ||= 4;

  %args = defaultArgs(%args);

  my $refGenerator = __complexGenerator($args{lbase});

  my $reference = &$refGenerator(%args);

  my @layers;

  do {
    my $biasOffset = .5;
    my $bias = 0;
    my $amp = $args{amp};

    for ( my $i = 0; $i < $args{layers}; $i++ ) {
      print "---------------------------------------\n" if !$QUIET;
      print "Complex layer $i ...\n" if !$QUIET;

      my $generator = __complexGenerator($args{ltype});

      push @layers, &$generator(%args,
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

sub __complexGenerator {
  my $type = shift;

  my $generator;

  if ( $type eq 'white' ) {
    $generator = \&white;
  } elsif ( $type eq 'square' ) {
    $generator = \&square;
  } elsif ( $type eq 'perlin' ) {
    $generator = \&perlin;
  } elsif ( $type eq 'ridged' ) {
    $generator = \&ridged;
  } elsif ( $type eq 'block' ) {
    $generator = \&block;
  } elsif ( $type eq 'gel' ) {
    $generator = \&gel;
  } elsif ( $type eq 'sgel' ) {
    $generator = \&sgel;
  } elsif ( $type eq 'pgel' ) {
    $generator = \&pgel;
  } elsif ( $type eq 'rgel' ) {
    $generator = \&rgel;
  } elsif ( $type eq 'stars' ) {
    $generator = \&stars;
  } elsif ( $type =~ /rand/ ) {
    my $num = rand(10);

    if ( int($num) == 0 ) {
      $generator = \&white;
    } elsif ( int($num) == 1 ) {
      $generator = \&square;
    } elsif ( int($num) == 2 ) {
      $generator = \&perlin;
    } elsif ( int($num) == 3 ) {
      $generator = \&ridged;
    } elsif ( int($num) == 4 ) {
      $generator = \&block;
    } elsif ( int($num) == 5 ) {
      $generator = \&gel;
    } elsif ( int($num) == 6 ) {
      $generator = \&sgel;
    } elsif ( int($num) == 7 ) {
      $generator = \&pgel;
    } elsif ( int($num) == 8 ) {
      $generator = \&rgel;
    } elsif ( int($num) == 9 ) {
      $generator = \&stars;
    }
  } else {
    usage("Unknown layer type specified");
  }

  return $generator;
}

sub clamp {
  my $val = shift;
  my $max = shift || 255;
  my $ridged = shift;

  if ( $ridged ) {
    $val = abs($val) if $val < 0;
    $val = $max if $val > $max;
    # $val = $max - ($val-$max) if $val > $max;
  } else {
    $val = 0 if $val < 0;
    $val = $max if $val > $max;
  }

  return $val;
}

sub noise {
  my $noise = shift;
  my $x = shift;
  my $y = shift;
  
  my $length  = @{ $noise };

  $x = $x % $length;
  $y = $y % $length;

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

sub wavelet {
  my %args = @_;

  %args = defaultArgs(%args);

  my $source = white(%args, len => $args{freq});

  my $down = shrink($source,%args,len => $args{freq}/2);

  my $up = grow($down,%args,len => $args{freq});

  my $out = [ ];

  for ( my $x = 0; $x < $args{freq}; $x++ ) {
    $out->[$x] = [ ];
    for ( my $y = 0; $y < $args{freq}; $y++ ) {
      $out->[$x]->[$y] = $source->[$x]->[$y] - $up->[$x]->[$y];
    }
  }

  return grow($out,%args);
}

sub gasket {
  my %args = @_;

  $args{len} ||= 256;
  $args{freq} = $args{len} if !defined $args{freq};
  $args{amp} ||= 1;

  my $freq = $args{freq};
  my $amp = $args{amp}*255;

  %args = defaultArgs(%args);

  my $grid = [ ];

  for ( my $x = 0; $x < $freq; $x++ ) {
    $grid->[$x] = [ ];

    for ( my $y = 0; $y < $freq; $y++ ) {
      $grid->[$x]->[$y] = 0;
    }
  }

  my $f1 = sub { return($_[0]/2, $_[1]/2) };
  my $f2 = sub { return(($_[0]+1)/2, $_[1]/2) };
  my $f3 = sub { return($_[0]/2, ($_[1]+1)/2) };

  my $iters = $args{maxiter} || $freq*$freq;

  my $x = rand(1);
  my $y = rand(1);

  for ( my $i = 0; $i < $iters; $i++ ) {
    if ( $i > 20 ) {
      my $thisX = ( $x * $freq ) % $freq;
      my $thisY = ( $y * $freq ) % $freq;
      $grid->[$thisX]->[$thisY] = 255;
    }

    my $rand = rand(3);
    if ( $rand < 1 ) {
      ($x,$y) = &$f1($x,$y);
    } elsif ( $rand < 2 ) {
      ($x,$y) = &$f2($x,$y);
    } else {
      ($x,$y) = &$f3($x,$y);
    }
  }

  return $grid;
}

sub fern {
  my %args = @_;

  $args{len} ||= 256;
  $args{freq} = $args{len} if !defined $args{freq};
  $args{amp} ||= 1;

  my $freq = $args{freq};
  my $amp = $args{amp}*255;

  %args = defaultArgs(%args);

  my $grid = [ ];

  for ( my $x = 0; $x < $freq; $x++ ) {
    $grid->[$x] = [ ];

    for ( my $y = 0; $y < $freq; $y++ ) {
      $grid->[$x]->[$y] = 0;
    }
  }

  my $steps = $freq*$freq*10;

  my $x = 0;
  my $y = 0;

  my $scale = $args{zoom} || 1;

  for ( my $n = 0; $n < $steps; $n++ ) {
    my $gx = ($freq-( (($x*$scale)+2.1818)/4.8374*$freq )) % $freq;
    my $gy = ($freq-( (($y*$scale)/9.95851)*$freq )) % $freq;

    $grid->[$gx]->[$gy] += sqrt(rand()*$amp);

    my $rand = rand();

    $grid->[$gx]->[$gy] ||= 0;

    if ( $rand <= .01 ) {
      ($x, $y) = _fern1($x, $y);
    } elsif ( $rand <= .08 ) {
      ($x, $y) = _fern2($x, $y);
    } elsif ( $rand <= .15 ) {
      ($x, $y) = _fern3($x, $y);
    } else {
      ($x, $y) = _fern4($x, $y);
    }
  }

  return grow($grid,%args);
}

sub _fern1 {
  my $x = shift;
  my $y = shift;

  return( 0, .16*$y );
}

sub _fern2 {
  my $x = shift;
  my $y = shift;

  return( (.2*$x)-(.26)*$y, (.23*$x)+(.22*$y)+1.6 );
}

sub _fern3 {
  my $x = shift;
  my $y = shift;

  return( (-.15*$x)+(.28*$y), (.26*$x)+(.24*$y)+.44 );
}

sub _fern4 {
  my $x = shift;
  my $y = shift;

  return( (.85*$x)+(.04*$y), (-.04*$x)+(.85*$y)+1.6 );
}

sub mandel {
  my %args = @_;

  $args{len} ||= 256;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $grid = [ ];

  my $freq = $args{freq};

  my $iters = $args{maxiter} || $freq;

  my $scale = $args{zoom} || 1;

  for ( my $x = 0; $x < $freq; $x += 1 ) {
    $grid->[$x] = [ ];

    my $cx = ($x/$freq)*2 - 1;
    $cx -= .5;
    $cx /= $scale;

    for ( my $y = 0; $y < $freq; $y += 1 ) {
      $grid->[$x]->[$y] ||= 0;

      my $cy = ($y/$freq)*2 - 1;
      $cy /= $scale;

      my $zx = 0; 
      my $zy = 0; 
      my $n = 0;
      while (($zx*$zx + $zy*$zy < $freq) && $n < $iters ) {
        my $new_zx = $zx*$zx - $zy*$zy + $cx;
        $zy = 2*$zx*$zy + $cy;
        $zx = $new_zx;
        $n++;
      }

      $grid->[$x]->[$y] = 255 - (($n/$iters)*255);
    }
  }

  return grow($grid,%args);
}

sub buddha {
  my %args = @_;

  $args{len} ||= 256;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $freq = $args{freq};

  my $grid = [ ];

  for ( my $x = 0; $x < $freq; $x++ ) {
    $grid->[$x] = [ ];

    for ( my $y = 0; $y < $freq; $y++ ) {
      $grid->[$x]->[$y] = 0;
    }
  }

  my $iters = $args{maxiter} || 1024;

  my $gap = $args{gap};

  my $scale = $args{zoom} || 1;

  for ( my $x = 0; $x < $freq; $x++ ) {
    for ( my $y = 0; $y < $freq; $y++ ) {
      next if rand() < $gap;

      my $cx = ($x/$freq)*2 - 1;
      $cx -= .5;

      my $cy = ($y/$freq)*2 - 1;

      $cx /= $scale;
      $cy /= $scale;

      my $zx = 0;
      my $zy = 0;
      my $n = 0;
      while (($zx*$zx + $zy*$zy < $freq) && $n < $iters ) {
        my $new_zx = $zx*$zx - $zy*$zy + $cx;
        $zy = 2*$zx*$zy + $cy;
        $zx = $new_zx;
        $n++;
      }

      next if $n == $iters;
      next if $n <= sqrt($iters);

      $zx = 0;
      $zy = 0;
      $n = 0;
      while (($zx*$zx + $zy*$zy < $freq) && $n < $iters ) {
        my $new_zx = $zx*$zx - $zy*$zy + $cx;
        $zy = 2*$zx*$zy + $cy;
        $zx = $new_zx;
        $n++;

        my $thisX = ((($zx+1)/2)*$freq+($freq*.25)) % $freq;
        my $thisY = (($zy+1)/2)*$freq % $freq;

        $grid->[$thisY]->[$thisX]++;
      }
    }
  }

  return grow($grid,%args);
}

sub spheremap {
  my $grid = shift;
  my %args = defaultArgs(@_);

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
      my ($cartX, $cartY, $cartZ) = cartCoords($x,$y,$len,$scale);

      ### North Pole
      $out->[$x]->[$y/2] = noise($grid,
        ($srclen-$cartX)/2, $cartY/2
      );

      ### South Pole
      $out->[$x]->[$len-($y/2)] = noise($grid,
        $cartX/2, ($offset*$scale)+($cartY/2)
      );
    }
  }

  #
  # Equator
  #
  for ( my $x = 0; $x < $len; $x++ ) {
    for ( my $y = 0; $y < $len; $y++ ) {
      my $diff = abs($offset - $y);
      my $pct = $diff/$offset;

      my $srcY = $scale * $y / 2; # Stretch Y*2 to avoid smooshed equator
                                  # when viewing texture on a real sphere
      #
      # Scale to size of input image
      #
      $srcY += ($offset/2) * $scale;
      $srcY -= $srclen if $srcY > $srclen;

      my $source = noise($grid, $scale*$x, $srcY);

      my $target = $out->[$x]->[$y] || 0;

      $out->[$x]->[$y] = coslerp($source, $target, $pct);
    }
  }

  # return $out;
  return $args{smooth} ? smooth($out,%args) : $out;
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

##
## Look up color values using vertical offset
##
sub vertclut {
  my $grid = shift;
  my %args = @_;

  print "Applying vertical CLUT...\n";

  my $palette = Imager->new;
  $palette->read(file => $args{clut}) || die $palette->errstr;

  my $srcHeight = $palette->getheight();
  my $srcWidth  = $palette->getwidth();

  my $len = scalar(@{$grid});

  my $out = Imager->new(
    xsize => $len,
    ysize => $len,
  );

  #
  # Polar regions
  #
  for ( my $x = 0; $x < $len; $x++ ) {
    for ( my $y = 0; $y < $len; $y++ ) {
      my $gray = $grid->[$x]->[$y];

      my $srcY;

      if ( $args{clutdir} == 1 ) {
        ##
        ## Vertical displacement
        ##
        $srcY = $y/$len;
      } else {
        ##
        ## Fractal displacement
        ##
        $srcY = noise($grid,
          $len/2,
          ($gray/255)*$len
        )/255;
      }

      $out->setpixel(
        x => $x,
        y => $y,
        color => $palette->getpixel(
          x => clamp(($gray/255)*($srcWidth-1), $srcWidth-1),
          y => clamp($srcY*($srcHeight-1), $srcHeight-1),
        )
      );
    }
  }

  return $out;
}

##
## Look up color values in a hypotenuse from palette
##
sub hypoclut {
  my $grid = shift;
  my %args = @_;

  print "Applying hypotenuse (corner-to-corner) CLUT...\n";

  my $palette = Imager->new;
  $palette->read(file => $args{clut}) || die $palette->errstr;

  my $srcHeight = $palette->getheight();
  my $srcWidth  = $palette->getwidth();

  my $len = scalar(@{$grid});

  my $out = Imager->new(
    xsize => $len,
    ysize => $len,
  );

  for ( my $x = 0; $x < $len; $x++ ) {
    for ( my $y = 0; $y < $len; $y++ ) {
      my $gray = $grid->[$x]->[$y];

      $out->setpixel(
        x => $x,
        y => $y,
        color => $palette->getpixel(
          y => clamp($gray)/255*($srcHeight-1),
          x => clamp($gray)/255*($srcWidth-1),
        )
      );
    }
  }

  return $out;
}

1;
__END__
=pod

=head1 NAME

Acme::Noisemaker - Visual noise generator

=head1 VERSION

This document is for version 0.009 of Acme::Noisemaker.

=head1 SYNOPSIS

  use Acme::Noisemaker qw| :all |;

  make;

A wrapper script, C<make-noise>, is included with this distribution.

  make-noise --help

Noise sets are just 2D arrays:

  use Acme::Noisemaker qw| :flavors |;

  my $grid = square(%args);

  #
  # Look up a value, given X and Y coords
  #
  my $value = $grid->[$x]->[$y];

L<Imager> can take care of further post-processing.

  my $grid = perlin(%args);

  my $img = img($grid,%args);

  #
  # Insert image manip methods here!
  #

  $img->write(file => "oot.png");

=head1 DESCRIPTION

Acme::Noisemaker provides a simple functional interface for generating
various types of 2D noise.

As long as the provided side length is a power of the noise's base
frequency, this module will produce seamless tiles. For example, a base
frequency of 2 would work fine for an image with a side length of 256
(256x256).

=head1 FUNCTION

=over 4

=item * make(type => $type, out => $filename, %ARGS)

  #
  # Just make some noise:
  #
  make();

  #
  # Care slightly more:
  #
  my ( $grid, $img, $filename ) = make(
    #
    # Any MAKE ARGS or noise args here!
    #
  );

=back

Creates the specified noise type (see NOISE TYPES), writing the
resulting image to the received filename.

Unless seriously tinkering, C<make> may be the only function you need.
C<make-noise>, included with this distribution, provides a CLI for
this function.

Returns the resulting dataset, as well as the L<Imager> object which
was created from it and filename used.

In addition to any argument appropriate to the type of noise being
generated, C<make> accepts the following arguments:

=over 4

=item * type => $noiseType

The type of noise to generate, defaults to Perlin. Specify any type.

  make(type => 'gel');

=item * sphere => $bool

Generate a pseudo-spheremap from the resulting noise.

This feature is a work in progress.

  make(sphere => 1);

=item * refract => $bool

"Refracted" pixel values. Can be used to enhance the fractal
appearance of the resulting noise. Often makes it look dirty.

  make(refract => 1);

=item * clut => $filename

Use an input image as a color lookup table

This feature is a work in progress.

  make(clut => $filename);

=item * clutdir => <0|1|2>

0: Hypotenuse lookup (corner to corner, so it doesn't matter if the input table is oriented horizontally or vertically). This is the default.

1: Vertical lookup, good for generating maps which have ice caps
at the poles and tropical looking colors at the equator.

2: Fractal lookup, uses the same methodology as C<refract>

This feature is a work in progress.

  make(clut => $filename, clutdir => 1);

=item * limit => <0|1>

0: Scale the pixel values of the noise set to image-friendly levels

1: Clamp pixel values outside of a representable range

  make(limit => 1);

=item * quiet => <0|1>

Don't spam console

  make(quiet => 1);

=item * out => $filename

Output image filename. Defaults to the name of the noise type being
generated.

  make(out => "oot.bmp");

=back

=head1 NOISE TYPES

=head2 SIMPLE NOISE

Simple noise types are generated from a single noise source.

=over 4

=item * white(%args)

Each non-smoothed pixel contains a pseudo-random value

=item * wavelet(%args)

Basis function for sharper Perlin slices, invented by Pixar

=item * square(%args)

Diamond-Square

=item * gel(%args)

Low-frequency smooth white noise with XY offset; see GEL TYPES

=item * sgel(%args)

Diamond-Square noise with XY offset; see GEL TYPES

=item * stars(%args)

White noise generated with extreme gappiness

=item * mandel(%args)

Fractal type - Mandelbrot fractal set. Not currently very useful,
this is a work in progress.

=item * buddha(%args)

Fractal type - "Buddhabrot" Mandelbrot variant. Not currently very
useful, this is a work in progress.

This is a very, very slow function.

=item * fern(%args)

Fractal type - Barnsley's fern. Not currently very useful, this is
a proof of concept for future IFS noise types.
  
=back

Simple noise types accept the following arguments in hash key form:

=over 4

=item * amp => $num

Amplitude, or max variance from the bias value.

For the purposes of this module, amplitude actually means semi-
amplitude (peak-to-peak amp/2).

  make(amp => 1);

=item * freq => $num

Frequency, or "density" of the noise produced.

For the purposes of this module, frequency represents the edge
length of the starting noise grid.

  make(freq => 8);

=item * len => $int

Side length of the output images, which are always square.

  make(len => 512);

=item * bias => $num

"Baseline" value for all pixels, .5 = 50%

  make(bias => .25);

=item * smooth => $bool

Enable/disable noise smoothing. 1 is default/recommended

  make(smooth => 0);

=item * zoom => $num

Used for fractal types only. Magnifaction factor.

  make(type => 'buddha', zoom => 2);

=item * maxiter => $int

Used for fractal types only. Iteration limit for determining
infinite boundaries, larger values take longer but are more
accurate/look nicer.

  make(type => 'mandel', maxiter => 2000);

=back

=cut

=head2 PERLIN TYPES

Perlin noise combines the values from multiple 2D slices (octaves),
which are generated using successively higher frequencies and lower
amplitudes.

The slice type used for generating Perlin noise may be controlled
with the C<stype> argument. Any simple type may be specified.

The default slice type is smoothed C<white> noise.

=over 4

=item * perlin(%args)

Perlin

  make(type => 'perlin', stype => 'wavelet');

=item * ridged(%args)

Ridged multifractal

  make(type => 'ridged', stype => 'wavelet');

=item * block(%args)

Unsmoothed Perlin

  make(type => 'block', stype => ...);

=item * pgel(%args)

Perlin noise with an XY offset; see GEL TYPES

  make(type => 'pgel', stype => ...);

=item * rgel(%args)

Ridged multifractal noise with an XY offset; see GEL TYPES

  make(type => 'rgel', stype => ...);

=back

In addition to any of the args which may be used for simple noise
types, Perlin noise types accept the following arguments in hash
key form:

=over 4

=item * octaves => $int

e.g. 1..8

Octave (slice) count, increases the complexity of Perlin noise.
Higher generally looks nicer.

  my $blurry = make(octaves => 3);

  my $sharp = make(octaves => 8);

=item * stype => $simpleType

Perlin slice type, defaults to C<white>. Any simple type may be
specified.

  my $grid = make(stype => 'gel');

=back

=head2 COMPLEX NOISE

=over 4

=item * complex

B<Complex layered noise>

Complex noise is a homebrew noise recipe inspired by (but not using)
I<libnoise>.

This function generates a noise base and multiple noise layers.
Each pixel in the resulting noise is blended towards the value in
the noise layer which corresponds to the reference value in the
noise base. Finally, the noise base itself is very slightly
superimposed over the combined layers.

  my $grid = complex();

Presets for hundreds of noise variants (many of them quite interesting
visually) may be generated through this function, by combining
different base types, layer types, and slice types.

  my $grid = complex(
    lbase => <any noise type but complex>,
    ltype => <any noise type but complex>,
    stype => <any simple type>,
    # ...
  );

=back

In addition to all simple and Perlin args, complex noise accepts
the following args in hash key form:

=over 4

=item * feather => $num

e.g. 0..255

Amount of blending between different regions of the noise.

  make(type => 'complex', feather => 50);

=item * layers => $int

Number of complex layers to generate

  make(type => 'complex', layers => 4);

=item * lbase => $noiseType

Complex layer base - defaults to "perlin". Any type
except for C<complex> may be used.

  make(type => 'complex', lbase => 'gel');

=item * ltype => $noiseType

Complex layer type - defaults to "perlin". Any type
except for C<complex> may be used.

  make(type => 'complex', ltype => 'gel');

=back

=head2 GEL TYPES

The simple and Perlin "gel" types - C<gel>, C<sgel>, C<pgel> and
C<rgel>, accept the following additional arguments:

=over 4

=item * offset => $float

Amount of self-displacement to apply to gel noise

  make(type => 'gel', offset => .125);

=back

=head1 MORE FUNCTIONS

=over 4

=item * img($grid,%args)

  my $grid = perlin();

  my $img = img($grid,%args);

  #
  # Insert Imager image manip stuff here!
  #

  $img->write(file => "oot.png");

Returns an L<Imager> object from the received two-dimensional grid.

=item * clamp($value)

Limits the received value to between 0 and 255. If the received
value is less than 0, returns 0; more than 255, returns 255; otherwise
returns the same value which was received.

  my $clamped = clamp($num);

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

=item * coslerp($a, $b, $x)

Cosine interpolate from $a to $b, by $x percent. $x is between 0 and 1.

=item * smooth($grid, %args)

  #
  # Unsmoothed noise source
  #
  my $grid = white(smooth => 0);

  my $smooth = smooth($grid,%args);

Perform smoothing of the values contained in the received two-dimensional
grid. Returns a new grid.

Smoothing is on by default.

=item * spheremap($grid, %args)

Generates a fake (but convincing) spheremap from the received 2D
noise grid, by embellishing the polar regions.

Re-maps the pixel values along the north and south edges of the
source image using polar coordinates, slowly blending back into
original pixel values towards the middle.

Returns a new 2D grid of pixel values.

  my $grid = perlin(%args);

  my $spheremap = spheremap($grid,%args);

See MAKE ARGS

=item * refract($grid,%args)

Return a new grid, replacing the color values in the received grid
with one-dimensional indexed noise values from itself. This can
enhance the "fractal" appearance of noise.

  my $grid = perlin(%args);

  my $refracted = refract($grid);

See MAKE ARGS

=item * offset($grid,%args)

Return a new grid containing XY offset values from the original,
by a factor of the received C<offset> argument.

See GEL TYPES

=back

=head1 SEE ALSO

L<Imager>, L<Math::Trig>

Acme::Noisemaker is on GitHub: http://github.com/aayars/noisemaker

Uses adapted pseudocode from:

  - http://freespace.virgin.net/hugo.elias/models/m_perlin.htm
    Perlin

  - http://gameprogrammer.com/fractal.html
    Diamond-Square

  - http://graphics.pixar.com/library/WaveletNoise/paper.pdf
    Wavelet

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
