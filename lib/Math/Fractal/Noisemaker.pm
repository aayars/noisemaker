package Math::Fractal::Noisemaker;

our $VERSION = '0.013';

use strict;
use warnings;

use Imager;
use Math::Trig qw| :radial deg2rad tan pi |;

use base qw| Exporter |;

our @SIMPLE_TYPES = qw|
  white wavelet square gel sgel stars spirals voronoi dla fflame
  mandel dmandel buddha fern gasket infile intile moire textile sparkle
  |;

our @PERLIN_TYPES = qw|
  perlin ridged block pgel fur tesla
  |;

our @NOISE_TYPES = (
  @SIMPLE_TYPES, @PERLIN_TYPES, qw|
    complex delta chiral stereo
    |
);

our @EXPORT_OK = (
  qw|
    make img smooth displace clamp noise lerp coslerp spheremap
    |, @NOISE_TYPES
);

our %EXPORT_TAGS = (
  'flavors' => [ ( qw| make spheremap img smooth displace |, @NOISE_TYPES ) ],

  'all' => \@EXPORT_OK,
);

our $defaultLen       = 256;
our $defaultType      = 'perlin';
our $defaultSliceType = 'wavelet';
our $defaultLayerBase = 'perlin';
our $defaultLayerType = 'perlin';

our $maxColor = 255;

our $defaultRho = 1;

our $QUIET;

sub showVersion {
  print "Noisemaker $VERSION\n";
}

sub showTypes {
  showVersion();

  print "\n";
  print "Noise Types:\n";
  print "\n";
  print "  * white           ## pseudo-random values\n";
  print "  * wavelet         ## band-limited ortho\n";
  print "  * square          ## diamond-square algorithm\n";
  print "  * gel             ## self-displaced smooth\n";
  print "  * sgel            ## self-displaced diamond-square\n";
  print "  * mandel          ## Mandelbrot (demo)\n";
  print "  * dmandel         ## \"deep\" mandel\n";
  print "  * buddha          ## buddhabrot\n";
  print "  * fflame          ## IFS fractal flame\n";
  print "  * fern            ## IFS fern (demo)\n";
  print "  * gasket          ## IFS gasket (demo)\n";
  print "  * dla             ## diffusion-limited aggregation\n";
  print "  * stars           ## starfield\n";
  print "  * spirals         ## tiny logspirals\n";
  print "  * voronoi         ## ridged voronoi cells\n";
  print "  * moire           ## interference patterns\n";
  print "  * textile         ## random high-freq moire\n";
  print "  * infile          ## image file named by 'in' arg\n";
  print "  * intile          ## input file + blends edges\n";
  print "  * sparkle         ## stylized stars\n";
  print "\n";
  print "  ! perlin          ## multi-resolution\n";
  print "  ! ridged          ## ridged multifractal\n";
  print "  ! block           ## unsmoothed multi-res\n";
  print "  ! pgel            ## self-displaced multi-res\n";
  print "  ! fur             ## based on \"Perlin Worms\"\n";
  print "  ! tesla           ## worms/fur variant\n";
  print "\n";
  print " !! delta           ## difference noise\n";
  print " !! chiral          ## joined noise\n";
  print " !! stereo          ## stereoscopic depthmap\n";
  print "\n";
  print "!!! complex         ## multi-layer multi-res\n";
  print "\n";
  print "Legend:";
  print "\n";
  print "  * simple type: may be used as a Perlin slice type (stype)\n";
  print "  ! control basis func via 'stype'\n";
  print " !! control basis funcs via 'ltype' and/or 'stype'\n";
  print "!!! control basis funcs via 'lbase', 'ltype' and/or 'stype'\n";
  print "\n";
  print "perldoc Math::Fractal::Noisemaker for more help.\n";
  print "\n";
}

sub usage {
  showVersion();

  print "\n";
  print "Usage:\n";
  print "$0 \\\n";
  print "  [-type <noisetype>] \\             ## noise type\n";
  print "  [-stype <simple type>]\\           ## perlin slice type\n";
  print "  [-lbase <any type but complex>] \\ ## complex basis\n";
  print "  [-ltype <any type but complex>] \\ ## complex layer\n";
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
  print "  [-displace <num>] \\         ## self-displacement (eg .25)\n";
  print "  [-clut <filename>] \\        ## color table (ex.bmp)\n";
  print "  [-clutdir 0|1|2] \\          ## displace hyp|vert|fract\n";
  print "  [-limit 0|1] \\              ## scale|clip pixel values\n";
  print "  [-zoom <num>] \\             ## mag for fractals\n";
  print "  [-maxiter <num>] \\          ## iter limit for fractals\n";
  print "  [-in <filename>] \\          ## input filename for infile\n";
  print "  [-shadow <0..1>] \\          ## shadow amount\n";
  print "  [-emboss <0|1>] \\           ## emboss output\n";
  print "  [-zshift <-1..1>] \\         ## final z offset for ridged\n";
  print "  [-format <type>] \\          ## file type (default bmp)\n";
  print "  [-workdir <dir>] \\          ## output dir (eg \"mynoise/\")\n";
  print "  [-quiet <0|1>] \\            ## no STDOUT spam\n";
  print "  [-out <filename>]           ## Output file (foo.bmp)\n";
  print "\n";
  print "For a list of available noise types, run:\n";
  print "\n";
  print "  $0 --help types\n";
  print "\n";
  print "perldoc Math::Fractal::Noisemaker for more help.\n";
  print "\n";

  my $warning = shift;
  print "$warning\n" if $warning;

  exit 2;
}

sub make {
  my %args;

  while ( my $arg = shift ) {
    if ( $arg =~ /help/ ) {
      if ( $_[0] && lc( $_[0] ) eq 'types' ) {
        showTypes();
        exit 2;
      } else {
        usage();
      }
    }

    if    ( $arg =~ /(^|-)type/ ) { $args{type}     = shift; }
    elsif ( $arg =~ /stype/ )     { $args{stype}    = shift; }
    elsif ( $arg =~ /lbase/ )     { $args{lbase}    = shift; }
    elsif ( $arg =~ /ltype/ )     { $args{ltype}    = shift; }
    elsif ( $arg =~ /amp/ )       { $args{amp}      = shift; }
    elsif ( $arg =~ /freq/ )      { $args{freq}     = shift; }
    elsif ( $arg =~ /len/ )       { $args{len}      = shift; }
    elsif ( $arg =~ /octaves/ )   { $args{octaves}  = shift; }
    elsif ( $arg =~ /bias/ )      { $args{bias}     = shift; }
    elsif ( $arg =~ /gap/ )       { $args{gap}      = shift; }
    elsif ( $arg =~ /feather/ )   { $args{feather}  = shift; }
    elsif ( $arg =~ /layers/ )    { $args{layers}   = shift; }
    elsif ( $arg =~ /smooth/ )    { $args{smooth}   = shift; }
    elsif ( $arg =~ /out/ )       { $args{out}      = shift; }
    elsif ( $arg =~ /sphere/ )    { $args{sphere}   = shift; }
    elsif ( $arg =~ /refract/ )   { $args{refract}  = shift; }
    elsif ( $arg =~ /displace/ )  { $args{displace} = shift; }
    elsif ( $arg =~ /clut$/ )     { $args{clut}     = shift; }
    elsif ( $arg =~ /clutdir$/ )  { $args{clutdir}  = shift; }
    elsif ( $arg =~ /limit/ )     { $args{auto}     = shift() ? 0 : 1; }
    elsif ( $arg =~ /zoom/ )      { $args{zoom}     = shift; }
    elsif ( $arg =~ /maxiter/ )   { $args{maxiter}  = shift; }
    elsif ( $arg =~ /shadow/ )    { $args{shadow}   = shift; }
    elsif ( $arg =~ /emboss/ )    { $args{emboss}   = shift; }
    elsif ( $arg =~ /(^|-)in$/ )  { $args{in}       = shift; }
    elsif ( $arg =~ /zshift/ )    { $args{zshift}   = shift; }
    elsif ( $arg =~ /quiet/ )     { $QUIET          = shift; }
    elsif ( $arg =~ /format/ )    { $args{format}   = shift; }
    elsif ( $arg =~ /workdir/ )   { $args{workdir}  = shift; }
    else                          { usage("Unknown argument: $arg") }
  }

  usage("Specified CLUT file not found") if $args{clut} && !-e $args{clut};

  $args{type}  ||= $defaultType;
  $args{stype} ||= $defaultSliceType;
  $args{lbase} ||= $defaultLayerBase;
  $args{ltype} ||= $defaultLayerType;

  if ( $args{shadow} && $args{emboss} ) {
    delete $args{shadow};
  }

  if (
    ( $args{type} eq 'complex' )
    && ( ( $args{lbase} =~ /[prs]gel/ )
      || ( $args{ltype} =~ /[prs]gel/ )
      || $args{stype} =~ /[prs]gel/ )
    )
  {
    $args{freq}     ||= 2;
    $args{displace} ||= .125;
  } elsif (
    ( $args{type} eq 'complex' )
    && ( ( $args{lbase} eq 'gel' )
      || ( $args{ltype} eq 'gel' )
      || $args{stype} eq 'gel' )
    )
  {
    $args{freq}     ||= 4;
    $args{displace} ||= .5;
  } else {
    $args{octaves} ||= 8;
  }

  my $format = $args{format} || "bmp";

  if ( !$Imager::formats{$format} ) {
    my $formats = join(",", sort keys %Imager::formats);

    usage("Unsupported format: $format (choose: $formats)");
  }

  if ( !$args{out} ) {
    if ( $args{type} =~ /delta|chiral|stereo/ ) {
      if ( grep { $_ eq $args{ltype} } @PERLIN_TYPES ) {
        $args{out} =
          join( "-", $args{type}, $args{ltype}, $args{stype} ) . ".$format";

      } else {
        $args{out} = join( "-", $args{type}, $args{ltype} ) . ".$format";
      }
    } elsif ( $args{type} eq 'complex' ) {

      #
      #
      #
      if ( grep { ( $_ eq $args{ltype} ) || $_ eq $args{lbase} } @PERLIN_TYPES )
      {
        $args{out} =
          join( "-", "complex", $args{lbase}, $args{ltype}, $args{stype} )
          . ".$format";
      } else {
        $args{out} =
          join( "-", "complex", $args{lbase}, $args{ltype} ) . ".$format";
      }
    } elsif (
      grep {
        $_ eq $args{type}
      } @PERLIN_TYPES
      )
    {
      $args{out} = join( "-", $args{type}, $args{stype} ) . ".$format";
    } else {
      $args{out} = "$args{type}.$format";
    }
  }

  if ( $args{workdir} ) {
    usage("workdir does not exist") if !-e $args{workdir};

    $args{out} = join("/", $args{workdir}, $args{out});
  }

  # XXX
  # return if -e $args{out};

  my $grid;

  for my $type (@NOISE_TYPES) {
    if ( $args{type} eq $type ) {
      my $sub;

      do {
        no strict 'refs';
        $sub = \&{"Math::Fractal::Noisemaker::$type"};
      };

      $grid = &$sub(%args);
    }
  }

  if ( !$grid ) {
    usage("Unknown noise type '$args{type}' specified");
  }

  if ( $args{refract} ) {
    $grid = refract( $grid, %args );
  }

  if ( $args{sphere} ) {
    %args = defaultArgs(%args);

    $grid = spheremap( $grid, %args );
  }

  my $img;

  $img = img( $grid, %args );

  $img->write( file => $args{out} ) || die $img->errstr;

  print "Saved file to $args{out}\n" if !$QUIET;

  return ( $grid, $img, $args{out} );
}

sub defaultArgs {
  my %args = @_;

  $args{bias}   = .5 if !defined $args{bias};
  $args{smooth} = 1  if !defined $args{smooth};
  $args{auto}   = 1  if !defined( $args{auto} ) && $args{type} ne 'fern';

  $args{gap}     ||= 0;
  $args{type}    ||= $defaultType;
  $args{freq}    ||= 8;
  $args{len}     ||= $defaultLen;
  $args{octaves} ||= 6;

  $args{amp} = .5 if !defined $args{amp};

  return %args;
}

sub img {
  my $grid = shift;
  my %args = defaultArgs(@_);

  print "Generating image...\n" if !$QUIET;

  my $length = scalar( @{$grid} );

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

  if ( $args{auto} ) {
    for ( my $x = 0 ; $x < $length ; $x++ ) {
      for ( my $y = 0 ; $y < $length ; $y++ ) {
        my $gray = $grid->[$x]->[$y];

        $min = $gray if !defined $min;
        $max = $gray if !defined $max;

        $min = $gray if $gray < $min;
        $max = $gray if $gray > $max;
      }
    }

    $range = $max - $min;
  }

  my $scaledGrid = [];

  for ( my $x = 0 ; $x < $length ; $x++ ) {
    for ( my $y = 0 ; $y < $length ; $y++ ) {
      my $gray = $grid->[$x]->[$y];

      my $scaled;

      if ( $args{auto} ) {
        $scaled = $range ? ( ( $gray - $min ) / $range ) * $maxColor : 0;
      } else {
        $scaled = clamp($gray);
      }

      do {
        $scaledGrid->[$x]->[$y] = $scaled;
      };
    }
  }

  if ( $args{clut} && $args{clutdir} ) {
    $img = vertclut( $scaledGrid, %args );
  } elsif ( $args{clut} ) {
    $img = hypoclut( $scaledGrid, %args );
  } else {
    if ( $args{emboss} && !$args{shadow} ) {
      $scaledGrid = emboss( $scaledGrid, %args );
      $scaledGrid = smooth( $scaledGrid, %args );
      $scaledGrid = glow( $scaledGrid, %args );
      $scaledGrid = densemap( $scaledGrid, %args );
    }

    for ( my $x = 0 ; $x < $length ; $x++ ) {
      for ( my $y = 0 ; $y < $length ; $y++ ) {
        my $gray = $scaledGrid->[$x]->[$y];
        $img->setpixel(
          x     => $x,
          y     => $y,
          color => [ $gray, $gray, $gray ],
        );
      }
      printRow( $scaledGrid->[$x] );
    }
  }

  if ( $args{shadow} && !$args{emboss} ) {
    my $embossed = emboss( $scaledGrid, %args );
    $embossed = smooth( $embossed, %args );
    $embossed = glow( $embossed, %args );
    $embossed = densemap( $embossed, %args );

    my $shadow = $args{shadow};

    for ( my $x = 0 ; $x < $length ; $x++ ) {
      for ( my $y = 0 ; $y < $length ; $y++ ) {
        my $color = $img->getpixel( x => $x, y => $y );
        my ( $r, $g, $b ) = $color->rgba;

        my $amt = ( 1 - ( $embossed->[$x]->[$y] / $maxColor ) ) * $shadow;

        $r = coslerp( $r, 0, $amt );
        $g = coslerp( $g, 0, $amt );
        $b = coslerp( $b, 0, $amt );

        $img->setpixel(
          x     => $x,
          y     => $y,
          color => [ $r, $g, $b ]
        );
      }
      printRow( $embossed->[$x] );
    }
  }

  if ( $args{sphere} ) {
    return $img->scale( scalefactor => .5 );
  }

  return $img;
}

sub grow {
  my $noise = shift;
  my %args  = @_;

  my $grid = $noise;

  my $wantLength = $args{len};
  my $haveLength = scalar( @{$noise} );

  until ( $haveLength >= $wantLength ) {
    my $grown = [];

    for ( my $x = 0 ; $x < $haveLength * 2 ; $x++ ) {
      $grown->[$x] = [];

      for ( my $y = 0 ; $y < $haveLength * 2 ; $y++ ) {
        $grown->[$x]->[$y] = $grid->[ $x / 2 ]->[ $y / 2 ];
      }
    }

    $grid = $args{smooth} ? smooth( $grown, %args ) : $grown;

    $haveLength *= 2;
  }

  return $grid;
}

sub shrink {
  my $noise = shift;
  my %args  = @_;

  my $grid = $noise;

  my $wantLength = $args{len};
  my $haveLength = scalar( @{$noise} );

  until ( $haveLength <= $wantLength ) {
    my $grown = [];

    for ( my $x = 0 ; $x < $haveLength / 2 ; $x++ ) {
      $grown->[$x] = [];

      for ( my $y = 0 ; $y < $haveLength / 2 ; $y++ ) {
        $grown->[$x]->[$y] = $grid->[ $x * 2 ]->[ $y * 2 ] / 4;
        $grown->[$x]->[$y] +=
          $grid->[ ( ( $x * 2 ) + 1 ) % $haveLength ]->[ $y * 2 ] / 4;
        $grown->[$x]->[$y] +=
          $grid->[ $x * 2 ]->[ ( ( $y * 2 ) + 1 ) % $haveLength ] / 4;
        $grown->[$x]->[$y] +=
          $grid->[ ( ( $x * 2 ) + 1 ) % $haveLength ]->[ ( $y * 2 ) + 1 ] / 4;
      }
    }

    $haveLength /= 2;

    $grid = $grown;
  }

  return $grid;
}

sub grid {
  my %args = defaultArgs(@_);

  my $grid = [];

  my $len = $args{len};

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    $grid->[$x] = [];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $grid->[$x]->[$y] = ( $args{bias} / 1 ) * $maxColor;
    }
  }

  return $grid;
}

sub infile {
  my %args = defaultArgs(@_);

  my $grid = grid(%args);

  print "Loading image...\n" if !$QUIET;

  my $len = $args{len};

  my $img = Imager->new;

  $img->read( file => $args{in} ) || die $img->errstr();

  my $width  = $img->getwidth();
  my $height = $img->getheight();

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $color = $img->getpixel(
        x => ( $x / ( $len / 1 ) ) * ( $width - 1 ),
        y => ( $y / ( $len - 1 ) ) * ( $height - 1 )
      );

      my ( $r, $g, $b ) = $color->rgba;

      $grid->[$x]->[$y] = ( $r + $g + $b ) / 3;
    }
    printRow( $grid->[$x] );
  }

  return $grid;
}

sub intile {
  my $grid = infile(@_);

  return tile( $grid, @_ );
}

sub white {
  my %args = @_;

  print "Generating white noise...\n" if !$QUIET;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $grid = grid(%args);

  my $freq = $args{freq};
  my $gap  = $args{gap};

  $args{amp} = .5 if !defined $args{amp};

  my $ampVal  = $args{amp} * $maxColor;
  my $biasVal = $args{bias} * $maxColor;

  spamConsole(%args) if !$QUIET;

  my $stars = $args{stars};

  my $offX = rand($freq);
  my $offY = rand($freq);

  for ( my $x = 0 ; $x < $freq ; $x++ ) {
    my $thisX = ( $x + $offX ) % $freq;

    for ( my $y = 0 ; $y < $freq ; $y++ ) {
      my $thisY = ( $y + $offY ) % $freq;

      if ( rand() < $gap ) {
        $grid->[$thisX]->[$thisY] = 0;
        next;
      }

      my $randAmp = rand($ampVal);

      if ( !$stars ) {
        $randAmp *= -1 if rand(1) >= .5;
      }

      $grid->[$thisX]->[$thisY] = $randAmp + $biasVal;
    }
    printRow( $grid->[$thisX] );
  }

  return grow( $grid, %args );
}

sub stars {
  my %args = @_;

  print "Generating stars...\n" if !$QUIET;

  $args{bias} = 0;
  $args{amp} ||= .5;
  $args{gap} ||= .995;

  my $grid = white( %args, stars => 1 );

  %args = defaultArgs(%args);

  return $args{smooth} ? smooth( $grid, %args ) : $grid;
}

sub gel {
  my %args = @_;

  print "Generating gel noise...\n" if !$QUIET;

  $args{displace} = 4 if !defined $args{displace};
  $args{freq}     = 8 if !defined $args{freq};

  %args = defaultArgs(%args);

  my $grid = wavelet(%args);

  return displace( $grid, %args );
}

sub displace {
  my $grid = shift;
  my %args = @_;

  print "Applying self-displacement...\n" if !$QUIET;

  my $out = [];

  my $length   = $args{len};
  my $displace = $args{displace};

  $displace = .5 if !defined $displace;

  $displace =
    ( $displace / 1 ) * ( $length / $defaultLen )
    ;    # Same visual offset for diff size imgs

  $grid = smooth( $grid, %args );

  for ( my $x = 0 ; $x < $length ; $x++ ) {
    $out->[$x] = [];

    for ( my $y = 0 ; $y < $length ; $y++ ) {
      my $displaceX = noise( $grid, $x,           $y ) * $displace;
      my $displaceY = noise( $grid, $length - $x, $length - $y ) * $displace;

      $out->[$x]->[$y] =
        noise( $grid, int( $x + $displaceX ), int( $y + $displaceY ) );
    }
  }

  return $out;
}

sub square {
  my %args = defaultArgs(@_);

  print "Generating square noise...\n" if !$QUIET;

  my $freq   = $args{freq};
  my $amp    = $args{amp};
  my $bias   = $args{bias};
  my $length = $args{len};

  $amp = .5 if !defined $amp;

  my $grid = wavelet( %args, len => $freq * 2 );

  my $haveLength = $freq * 2;
  my $baseOffset = $maxColor * $amp;

  spamConsole(%args) if !$QUIET;

  until ( $haveLength >= $length ) {
    my $grown = [];

    for ( my $x = 0 ; $x < $haveLength * 2 ; $x++ ) {
      $grown->[$x] = [];
      for ( my $y = 0 ; $y < $haveLength * 2 ; $y++ ) {
        push @{ $grown->[$x] }, undef;
      }
    }

    for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
      my $thisX = $x * 2;

      for ( my $y = 0 ; $y < $haveLength ; $y++ ) {
        my $thisY = $y * 2;

        my $offset = rand($baseOffset);
        $offset *= -1 if ( rand(1) >= .5 );

        $grown->[$thisX]->[$thisY] = $grid->[$x]->[$y] + $offset;
      }
    }

    for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
      my $thisX = $x * 2;
      $thisX += 1;

      for ( my $y = 0 ; $y < $haveLength ; $y++ ) {
        my $thisY = $y * 2;
        $thisY += 1;

        my $corners =
          ( noise( $grid, $x - 1, $y - 1 ) +
            noise( $grid, $x + 1, $y - 1 ) +
            noise( $grid, $x - 1, $y + 1 ) +
            noise( $grid, $x + 1, $y + 1 ) ) / 4;

        my $offset = rand($baseOffset);
        $offset *= -1 if ( rand(1) >= .5 );
        $grown->[$thisX]->[$thisY] = $corners + $offset;
      }
    }

    $haveLength *= 2;

    for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
      for ( my $y = 0 ; $y < $haveLength ; $y++ ) {
        next if defined $grown->[$x]->[$y];

        my $sides =
          ( noise( $grown, $x - 1, $y ) +
            noise( $grown, $x + 1, $y ) +
            noise( $grown, $x,     $y - 1 ) +
            noise( $grown, $x,     $y + 1 ) ) / 4;

        my $offset = rand($baseOffset);
        $offset *= -1 if ( rand(1) >= .5 );
        $grown->[$x]->[$y] = $sides + $offset;
      }
    }

    $baseOffset /= 2;

    $grid = $grown;
  }

  if ( $args{smooth} ) {
    $grid = smooth( $grid, %args );
  }

  return $grid;
}

sub sgel {
  my %args = defaultArgs(@_);

  print "Generating square gel noise...\n" if !$QUIET;

  my $grid = square(%args);

  return displace( $grid, %args );
}

sub perlin {
  my %args = @_;

  print "Generating Perlin noise...\n" if !$QUIET;

  $args{amp} = .5 if !defined $args{amp};
  $args{amp} *= $args{octaves};

  %args = defaultArgs(%args);

  my $length  = $args{len};
  my $amp     = $args{amp};
  my $freq    = $args{freq};
  my $bias    = $args{bias};
  my $octaves = $args{octaves};

  my @layers;

  spamConsole(%args) if !$QUIET;

  for ( my $o = 0 ; $o < $octaves ; $o++ ) {
    last if $freq > $length;

    print "Octave " . ( $o + 1 ) . " ... \n" if !$QUIET;

    my $generator;

    for my $type (@SIMPLE_TYPES) {
      if ( $args{stype} eq $type ) {
        do {
          no strict 'refs';
          $generator = \&{"Math::Fractal::Noisemaker::$type"};
        };
      }
    }

    if ( !$generator ) {
      usage("Unknown slice type '$args{stype}' specified");
    }

    push @layers,
      &$generator(
      %args,
      freq => $freq,
      amp  => $amp,
      bias => $bias,
      len  => $length,
      );

    $amp  *= .5;
    $freq *= 2;
  }

  #
  # Restore orig values
  #
  $amp  = $args{amp};
  $freq = $args{freq};

  my $combined = [];

  my $zshift;
  if ( $args{ridged} ) {
    $args{zshift} = $amp if !defined $args{zshift};
    $zshift = $args{zshift} * $maxColor;
  }

  for ( my $x = 0 ; $x < $length ; $x++ ) {
    $combined->[$x] = [];

    for ( my $y = 0 ; $y < $length ; $y++ ) {
      my $n;
      my $t;

      for ( my $z = 0 ; $z < @layers ; $z++ ) {
        $n++;

        my $gray = $layers[$z][$x]->[$y];

        if ( $args{ridged} ) {
          $t += abs($gray);
        } else {
          $t += $gray;
        }
      }

      if ( $args{ridged} ) {
        $combined->[$x]->[$y] = ($zshift) - ( $t / $n );
      } else {
        $combined->[$x]->[$y] = $t / $n;
      }
    }
    printRow( $combined->[$x] );
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

  return displace( $grid, %args );
}

sub ridged {
  my %args = @_;

  print "Generating ridged multifractal noise...\n" if !$QUIET;

  $args{bias} = 0 if !defined $args{bias};
  $args{amp}  = 1 if !defined $args{amp};

  return perlin( %args, ridged => 1 );
}

sub refract {
  my $grid = shift;
  my %args = @_;

  print "Applying fractal Z displacement...\n" if !$QUIET;

  my $haveLength = scalar( @{$grid} );

  my $out = [];

  for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
    $out->[$x] = [];

    for ( my $y = 0 ; $y < $haveLength ; $y++ ) {
      my $color = $grid->[$x]->[$y] || 0;
      my $srcY = ( $color / $maxColor ) * $haveLength;
      $srcY -= $haveLength if $srcY > $haveLength;
      $srcY += $haveLength if $srcY < 0;

      $out->[$x]->[$y] = $grid->[0]->[$srcY];
    }
  }

  return $out;
}

sub lsmooth {
  my $grid = shift;
  my %args = @_;

  my $len = scalar( @{$grid} );

  my $smooth = [];

  my $dirs  = 6;
  my $angle = rand(360);

  my $dirAngle = 360 / $dirs;
  my $angle360 = 360 + $angle;

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    $smooth->[$x] = [];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $smooth->[$x]->[$y] += $grid->[$x]->[$y] / $dirs;

      for ( my $a = $angle ; $a < $angle360 ; $a += $dirAngle ) {
        my $rad = 6;

        for ( my $d = 1 ; $d <= $rad ; $d++ ) {    # distance
          my ( $tx, $ty ) = translate( $x, $y, $a, $d );
          $tx = $tx % $len;
          $ty = $ty % $len;

          # print "$x, $y: $tx, $ty\n";

          $smooth->[$x]->[$y] += $grid->[$tx]->[$ty] * ( 1 - ( $d / $rad ) );
        }
      }
    }
  }

  return $smooth;
}

sub smooth {
  my $grid = shift;
  my %args = @_;

  my $haveLength = scalar( @{$grid} );

  my $smooth = [];

  for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
    $smooth->[$x] = [];

    for ( my $y = 0 ; $y < $haveLength ; $y++ ) {
      my $corners =
        ( noise( $grid, $x - 1, $y - 1 ) +
          noise( $grid, $x + 1, $y - 1 ) +
          noise( $grid, $x - 1, $y + 1 ) +
          noise( $grid, $x + 1, $y + 1 ) ) / 16;

      my $sides =
        ( noise( $grid, $x - 1, $y ) +
          noise( $grid, $x + 1, $y ) +
          noise( $grid, $x,     $y - 1 ) +
          noise( $grid, $x,     $y + 1 ) ) / 8;

      my $center = noise( $grid, $x, $y ) / 4;

      $smooth->[$x]->[$y] = $corners + $sides + $center;
    }
  }

  return $smooth;
}

sub complex {
  my %args = @_;

  print "Generating complex noise...\n" if !$QUIET;

  $args{amp}     = 1  if !defined $args{amp};
  $args{feather} = 75 if !defined $args{feather};
  $args{layers} ||= 4;

  %args = defaultArgs(%args);

  my $refGenerator = __generator( $args{lbase} );

  my $reference = &$refGenerator(%args);

  my @layers;

  do {
    my $biasOffset = .5;
    my $bias       = 0;
    my $amp        = $args{amp};

    for ( my $i = 0 ; $i < $args{layers} ; $i++ ) {
      print "---------------------------------------\n" if !$QUIET;
      print "Complex layer $i ...\n"                    if !$QUIET;

      my $generator = __generator( $args{ltype} );

      push @layers, &$generator(
        %args,

        # amp  => $amp,
        bias => $bias,
      );

      $bias += $biasOffset;
      $biasOffset *= .5;
      $amp        *= .5;
    }
  };

  my $out = [];

  my $feather = $args{feather};
  my $length  = $args{len};

  for ( my $x = 0 ; $x < $length ; $x++ ) {
    $out->[$x] = [];

    for ( my $y = 0 ; $y < $length ; $y++ ) {
      my $value = $reference->[$x]->[$y];

      $out->[$x]->[$y] = $value if !defined $out->[$x]->[$y];

      my $level       = 0;
      my $levelOffset = 128;

      for ( my $z = 0 ; $z < $args{layers} ; $z++ ) {
        my $diff = $level - $value;

        if ( $value >= $level ) {
          ##
          ## Reference pixel value is greater than current level,
          ## so use the current level's pixel value
          ##
          $out->[$x]->[$y] = $layers[$z][$x]->[$y];

        } elsif ( ( ( $feather > 0 ) && $diff <= $feather )
          || ( ( $feather < 0 ) && $diff <= $feather * -1 ) )
        {
          my $fadeAmt = $diff / abs($feather);

          if ( $feather < 0 ) {
            $fadeAmt = 1 - $fadeAmt;
          }

          ##
          ## Reference pixel value is less than current level,
          ## but within the feather range, so fade it
          ##
          my $color =
            coslerp( $layers[$z][$x]->[$y], $out->[$x]->[$y], $fadeAmt, );

          $out->[$x]->[$y] = $color;
        }

        # $out->[$x]->[$y] = coslerp( $out->[$x]->[$y], $value, .25 );

        $level += $levelOffset;
        $levelOffset /= 2;
      }
    }
    printRow( $out->[$x] );
  }

  return $out;

  # return $args{smooth} ? smooth($out) : $out;
}

sub __generator {
  my $type = shift;

  my $generator;

  for my $ltype ( @SIMPLE_TYPES, @PERLIN_TYPES ) {
    if ( $type eq $ltype ) {
      do {
        no strict 'refs';
        $generator = \&{"Math::Fractal::Noisemaker::$type"};
      };
    }
  }

  if ( !$generator ) {
    usage("Unknown noise type '$type' specified");
  }

  return $generator;
}

sub clamp {
  my $val = shift;
  my $max = shift || $maxColor;

  $val = 0    if $val < 0;
  $val = $max if $val > $max;

  return $val;
}

sub noise {
  my $noise = shift;
  my $x     = shift;
  my $y     = shift;

  my $length = @{$noise};

  $x = $x % $length;
  $y = $y % $length;

  die "no data for $x,$y" if !defined $noise->[$x]->[$y];

  return $noise->[$x]->[$y];
}

sub lerp {
  my $a = shift;
  my $b = shift;
  my $x = shift;

  return ( $a * ( 1 - $x ) + $b * $x );
}

sub coslerp {
  my $a = shift;
  my $b = shift;
  my $x = shift;

  my $ft = ( $x * pi );
  my $f  = ( 1 - cos($ft) ) * .5;

  return ( $a * ( 1 - $f ) + $b * $f );
}

sub wavelet {
  my %args = @_;

  print "Generating wavelet noise...\n" if !$QUIET;

  $args{amp} = .5 if !defined $args{amp};
  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $source = white( %args, len => $args{freq} );

  my $down = shrink( $source, %args, len => $args{freq} / 2 );

  my $up = grow( $down, %args, len => $args{freq} );

  my $out = [];

  for ( my $x = 0 ; $x < $args{freq} ; $x++ ) {
    $out->[$x] = [];
    for ( my $y = 0 ; $y < $args{freq} ; $y++ ) {
      $out->[$x]->[$y] =
        ( $args{bias} * $maxColor ) + $source->[$x]->[$y] - $up->[$x]->[$y];
    }
    printRow( $out->[$x] );
  }

  return grow( $out, %args );
}

sub gasket {
  my %args = @_;

  print "Generating gasket...\n" if !$QUIET;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};
  $args{amp} ||= 1;

  my $freq = $args{freq};
  my $amp  = $args{amp} * $maxColor;

  %args = defaultArgs(%args);

  my $grid = grid( %args, len => $args{freq} );

  for ( my $x = 0 ; $x < $freq ; $x++ ) {
    $grid->[$x] = [];

    for ( my $y = 0 ; $y < $freq ; $y++ ) {
      $grid->[$x]->[$y] = 0;
    }
  }

  my $f1 = sub { return ( $_[0] / 2, $_[1] / 2 ) };
  my $f2 = sub { return ( ( $_[0] + 1 ) / 2, $_[1] / 2 ) };
  my $f3 = sub { return ( $_[0] / 2, ( $_[1] + 1 ) / 2 ) };

  my $iters = $args{maxiter} || $freq * $freq;

  my $x = rand(1);
  my $y = rand(1);

  for ( my $i = 0 ; $i < $iters ; $i++ ) {
    if ( $i > 20 ) {
      my $thisX = ( $x * $freq ) % $freq;
      my $thisY = ( $y * $freq ) % $freq;
      $grid->[$thisX]->[$thisY] = $maxColor;
    }

    my $rand = rand(3);
    if ( $rand < 1 ) {
      ( $x, $y ) = &$f1( $x, $y );
    } elsif ( $rand < 2 ) {
      ( $x, $y ) = &$f2( $x, $y );
    } else {
      ( $x, $y ) = &$f3( $x, $y );
    }
  }

  return grow( $grid, %args );
}

#
# Set up IFS flame functions once
#
my @flameFns;

do {
  push @flameFns, sub { return @_ };    # linear
  push @flameFns, sub {                 # sinu
    my ( $x, $y ) = @_;
    return sin($x) * 3, sin($y) * 3;
  };
  push @flameFns, sub {                 # sphere
    my ( $x, $y ) = @_;
    my $n = 1 / ( ( $x * $x ) + ( $y + $y ) );
    return $x * $n, $y * $n;
  };
  push @flameFns, sub {                 # swirl
    my ( $x, $y ) = @_;
    my $rsqrd = ( ( $x * $x ) + ( $y + $y ) );
    return (
      ( $x * sin($rsqrd) ) - ( $y * cos($rsqrd) ),
      ( $x * cos($rsqrd) ) + ( $y * sin($rsqrd) )
    );
  };
  push @flameFns, sub {                 # horseshoe
    my ( $x, $y ) = @_;
    my $r = sqrt( ( $x * $x ) + ( $y * $y ) );
    my $rf = 1 / ( $r * $r );
    return ( $rf * ( $x - $y ) * ( $x + $y ), $rf * 2 * $x * $y );
  };
  push @flameFns, sub {                 # popcorn
    my ( $x, $y, $c, $f ) = @_;
    return (
      $x + ( $c * sin( tan( 3 * $y ) ) ),
      $y + ( $f * sin( tan( 3 * $x ) ) ),
    );
  };
};

sub fflame {
  my %args = @_;

  my @fns;

  for ( my $i = 0 ; $i < @flameFns * 2 ; $i++ ) {
    push @fns, $flameFns[ rand(@flameFns) ];
  }

  print "Generating fractal flame!\n" if !$QUIET;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};
  $args{amp} ||= 1;

  my $freq = $args{freq};
  my $amp  = $args{amp} * $maxColor;

  %args = defaultArgs(%args);

  my $grid = grid( %args, len => $freq );

  my $steps = $freq * $freq * 100;

  my $A = rand(.125) + .25;
  my $B = rand(.125) + .25;
  my $c = rand(.125) + .25;
  my $d = rand(.125) + .25;
  my $e = rand(.125) + .25;
  my $f = rand(.125) + .25;

  my $scale = $args{zoom} || 1;

  my $x = 0;
  my $y = 0;

  my $semifreq = $freq / 2;

  my $finalX = rand($freq);
  my $finalY = rand($freq);

  # my $postX = rand(10);
  # my $postY = rand(10);
  my $postX = rand($freq);
  my $postY = rand($freq);

  for ( my $n = 0 ; $n < $steps ; $n++ ) {
    do {
      my $gx = ( ( $x * $scale * $freq ) + $finalX ) % $freq;
      my $gy = ( ( $y * $scale * $freq ) + $finalY ) % $freq;

      if ( $n >= 20 ) {
        $grid->[$gx]->[$gy] ||= 0;
        $grid->[$gx]->[$gy]++;
      }
    };

    my $i = rand(@fns);

    do {
      my $fn = $fns[$i];

      my $thisX = ( $A * $x ) + ( $B * $y ) + $c;
      my $thisY = ( $d * $y ) + ( $e * $y ) + $f;

      ( $x, $y ) = &$fn( $thisX, $thisY, $c, $f );
    };

  }

  $grid = densemap($grid);

  return glow( grow( $grid, %args ), %args );
}

sub densemap {
  my $grid = shift;

  my $len = scalar( @{$grid} );

  my $colors = {};

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $colors->{ $grid->[$x]->[$y] }++;
    }
  }

  my @colors = keys %{$colors};

  my $i = 0;
  for ( sort { $a <=> $b } @colors ) {
    $colors->{$_} = ( sqrt( $i / @colors ) * $maxColor );

    $i++;
  }

  my $out = [];

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    $out->[$x] = [];
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $out->[$x]->[$y] = $colors->{ $grid->[$x]->[$y] };
    }
  }

  return $out;
}

sub fern {
  my %args = @_;

  print "Generating fern...\n" if !$QUIET;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};
  $args{amp} ||= 1;

  my $freq = $args{freq};
  my $amp  = $args{amp} * $maxColor;

  %args = defaultArgs(%args);

  my $grid = grid(%args);

  for ( my $x = 0 ; $x < $freq ; $x++ ) {
    for ( my $y = 0 ; $y < $freq ; $y++ ) {
      $grid->[$x]->[$y] = 0;
    }
  }

  my $steps = $freq * $freq * 10;

  my $x = 0;
  my $y = 0;

  my $scale = $args{zoom} || 1;

  for ( my $n = 0 ; $n < $steps ; $n++ ) {
    my $gx =
      ( $freq - ( ( ( $x * $scale ) + 2.1818 ) / 4.8374 * $freq ) ) % $freq;
    my $gy = ( $freq - ( ( ( $y * $scale ) / 9.95851 ) * $freq ) ) % $freq;

    $grid->[$gx]->[$gy] += sqrt( rand() * $amp );

    my $rand = rand();

    $grid->[$gx]->[$gy] ||= 0;

    if ( $rand <= .01 ) {
      ( $x, $y ) = _fern1( $x, $y );
    } elsif ( $rand <= .08 ) {
      ( $x, $y ) = _fern2( $x, $y );
    } elsif ( $rand <= .15 ) {
      ( $x, $y ) = _fern3( $x, $y );
    } else {
      ( $x, $y ) = _fern4( $x, $y );
    }
  }

  return grow( $grid, %args );
}

sub _fern1 {
  my $x = shift;
  my $y = shift;

  return ( 0, .16 * $y );
}

sub _fern2 {
  my $x = shift;
  my $y = shift;

  return ( ( .2 * $x ) - (.26) * $y, ( .23 * $x ) + ( .22 * $y ) + 1.6 );
}

sub _fern3 {
  my $x = shift;
  my $y = shift;

  return ( ( -.15 * $x ) + ( .28 * $y ), ( .26 * $x ) + ( .24 * $y ) + .44 );
}

sub _fern4 {
  my $x = shift;
  my $y = shift;

  return ( ( .85 * $x ) + ( .04 * $y ), ( -.04 * $x ) + ( .85 * $y ) + 1.6 );
}

sub mandel {
  my %args = @_;

  print "Generating Mandelbrot...\n" if !$QUIET;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $grid = grid(%args);

  my $freq = $args{freq};

  my $iters = $args{maxiter} || $freq;

  my $scale = $args{zoom} || 1;

  $freq *= 2;

  for ( my $x = 0 ; $x < $freq ; $x += 1 ) {
    my $cx = ( $x / $freq ) * 2 - 1;
    $cx -= .5;
    $cx /= $scale;

    for ( my $y = 0 ; $y < $freq / 2 ; $y += 1 ) {
      my $cy = ( $y / $freq ) * 2 - 1;
      $cy /= $scale;

      my $zx = 0;
      my $zy = 0;
      my $n  = 0;
      while ( ( $zx * $zx + $zy * $zy < $freq ) && $n < $iters ) {
        my $new_zx = $zx * $zx - $zy * $zy + $cx;
        $zy = 2 * $zx * $zy + $cy;
        $zx = $new_zx;
        $n++;
      }

      $grid->[$x]->[$y] = $maxColor - ( ( $n / $iters ) * $maxColor );
      $grid->[$x]->[ $freq - 1 - $y ] =
        $maxColor - ( ( $n / $iters ) * $maxColor );
    }
    printRow( $grid->[$x] );
  }

  $grid = shrink( $grid, %args );

  $grid = grow( $grid, %args );

  return $grid;
}

sub dmandel {
  my %args = @_;

  print "Generating Mandelbrot...\n" if !$QUIET;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $freq = $args{freq};
  my $iters = $args{maxiter} || $maxColor;

  my @interesting;

  my $prefreq = 256;

  for ( my $x = 0 ; $x < $prefreq ; $x += 1 ) {
    my $cx = ( $x / $prefreq ) * 2 - 1;

    for ( my $y = 0 ; $y < $prefreq / 2 ; $y += 1 ) {
      my $cy = ( $y / $prefreq ) * 2 - 1;

      my $zx = 0;
      my $zy = 0;
      my $n  = 0;
      while ( ( $zx * $zx + $zy * $zy < $prefreq ) && $n < $prefreq / 2 ) {
        my $new_zx = $zx * $zx - $zy * $zy + $cx;
        $zy = 2 * $zx * $zy + $cy;
        $zx = $new_zx;
        $n++;
      }

      my $pct = ( $n / ( $prefreq / 2 ) );

      if ( $pct > .99 && $pct < 1 ) {
        push @interesting, [ $cx, $cy ];
      }
    }
  }

  my $tuple = $interesting[ rand(@interesting) ];

  my $scale = $args{zoom} || 1024 + rand(1024);

  $freq *= 2;

  my $grid = grid( %args, freq => $freq );

  for ( my $x = 0 ; $x < $freq ; $x += 1 ) {
    my $cx = ( $x / $freq ) * 2 - 1;
    $cx += $tuple->[0] * $scale;
    $cx /= $scale;

    for ( my $y = 0 ; $y < $freq ; $y += 1 ) {
      $grid->[$x]->[$y] ||= 0;

      my $cy = ( $y / $freq ) * 2 - 1;

      $cy += $tuple->[1] * $scale;
      $cy /= $scale;
      my $cyKey = $cy * $scale;

      my $zx = 0;
      my $zy = 0;
      my $n  = 0;
      while ( ( $zx * $zx + $zy * $zy < $freq ) && $n < $iters ) {
        my $new_zx = $zx * $zx - $zy * $zy + $cx;
        $zy = 2 * $zx * $zy + $cy;
        $zx = $new_zx;
        $n++;
      }

      my $color = $maxColor - ( ( $n / ( $iters - 1 ) ) * $maxColor );

      # $color = 0 if $color >= $maxColor;

      $grid->[$x]->[$y] = $color;
    }

    printRow( $grid->[$x] );
  }

  return shrink( $grid, %args );
}

sub buddha {
  my %args = @_;

  print "Generating Buddhabrot (this will take a while)...\n" if !$QUIET;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $freq = $args{freq};

  my $iters = $args{maxiter} || 4096;

  my $gap = $args{gap};

  my $grid = grid( %args, len => $freq, bias => 0 );

  #
  # Zooming in just makes buddhabrots disappear
  #
  my $scale = $args{zoom} || 1;

  for ( my $x = 0 ; $x < $freq ; $x++ ) {
    for ( my $y = 0 ; $y < $freq / 2 ; $y++ ) {
      next if rand() < $gap;

      my $cx = ( $x / $freq ) * 2 - 1;
      $cx -= .5;

      my $cy = ( $y / $freq ) * 2 - 1;

      $cx /= $scale;
      $cy /= $scale;

      my $zx = 0;
      my $zy = 0;
      my $n  = 0;
      while ( ( $zx * $zx + $zy * $zy < $freq ) && $n < $iters ) {
        my $new_zx = $zx * $zx - $zy * $zy + $cx;
        $zy = 2 * $zx * $zy + $cy;
        $zx = $new_zx;
        $n++;
      }

      next if $n == $iters;
      next if $n <= sqrt($iters);

      $zx = 0;
      $zy = 0;
      $n  = 0;
      while ( ( $zx * $zx + $zy * $zy < $freq ) && $n < $iters ) {
        my $new_zx = $zx * $zx - $zy * $zy + $cx;
        $zy = 2 * $zx * $zy + $cy;
        $zx = $new_zx;
        $n++;

        my $thisX = ( ( ( $zx + 1 ) / 2 ) * $freq + ( $freq * .25 ) ) % $freq;
        my $thisY = ( ( $zy + 1 ) / 2 ) * $freq % $freq;

        $grid->[$thisY]->[$thisX] += 25;
        $grid->[ $freq - 1 - $thisY ]->[$thisX] += 25;
      }
    }
    printRow( $grid->[$x] );
  }

  $grid = densemap( $grid, %args );

  $grid = grow( $grid, %args );

  return $grid;
}

sub spheremap {
  my $grid = shift;
  my %args = defaultArgs(@_);

  print "Generating spheremap...\n" if !$QUIET;

  my $len    = $args{len};
  my $offset = $len / 2;

  my $out = [];

  my $srclen = scalar( @{$grid} );
  my $scale  = $srclen / $len;

  #
  # Polar regions
  #
  my $xOffset = $len / 4;
  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my ( $cartX, $cartY, $cartZ ) = cartCoords( $x, $y, $len, $scale );

      ### North Pole
      $out->[$x]->[ $y / 2 ] =
        noise( $grid, $xOffset + ( ( $srclen - $cartX ) / 2 ), $cartY / 2 );

      ### South Pole
      $out->[ $len - 1 - $x ]->[ $len - ( $y / 2 ) ] = noise(
        $grid,
        $xOffset + ( $cartX / 2 ),
        ( $offset * $scale ) + ( $cartY / 2 )
      );
    }
  }

  #
  # Equator
  #
  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $diff = abs( $offset - $y );
      my $pct  = $diff / $offset;

      my $srcY = $scale * $y / 2;    # Stretch Y*2 to avoid smooshed equator
                                     # when viewing texture on a real sphere
                                     #
                                     # Scale to size of input image
                                     #
      $srcY += ( $offset / 2 ) * $scale;
      $srcY -= $srclen if $srcY > $srclen;

      my $source = noise( $grid, $scale * $x, $srcY );

      my $target = $out->[$x]->[$y] || 0;

      $out->[$x]->[$y] = coslerp( $source, $target, $pct );
    }
  }

  return $out;
}

sub cartCoords {
  my $x     = shift;
  my $y     = shift;
  my $len   = shift;
  my $scale = shift || 1;

  my $thisLen = $len * $scale;
  $x *= $scale;
  $y *= $scale;

  $x -= $thisLen if $x > $thisLen;
  $y -= $thisLen if $y > $thisLen;
  $x += $thisLen if $x < 0;
  $y += $thisLen if $y < 0;

  my $theta = deg2rad( ( $x / $thisLen ) * 360 );
  my $phi   = deg2rad( ( $y / $thisLen ) * 90 );

  my ( $cartX, $cartY, $cartZ ) =
    spherical_to_cartesian( $defaultRho, $theta, $phi );

  $cartX = int( ( ( $cartX + 1 ) / 2 ) * $thisLen );
  $cartY = int( ( ( $cartY + 1 ) / 2 ) * $thisLen );
  $cartZ = int( ( ( $cartZ + 1 ) / 2 ) * $thisLen );

  return ( $cartX, $cartY, $cartZ );
}

##
## Look up color values using vertical offset
##
sub vertclut {
  my $grid = shift;
  my %args = @_;

  print "Applying CLUT...\n" if !$QUIET;

  my $palette = Imager->new;
  $palette->read( file => $args{clut} ) || die $palette->errstr;

  my $srcHeight = $palette->getheight();
  my $srcWidth  = $palette->getwidth();

  my $len = scalar( @{$grid} );

  my $out = Imager->new(
    xsize => $len,
    ysize => $len,
  );

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $gray = $grid->[$x]->[$y];

      my $srcY;

      if ( $args{clutdir} == 1 ) {
        ##
        ## Vertical displacement
        ##
        $srcY = $y / $len;
      } else {
        ##
        ## Fractal displacement
        ##
        $srcY =
          noise( $grid, $len / 2, ( $gray / $maxColor ) * $len ) / $maxColor;
      }

      $out->setpixel(
        x     => $x,
        y     => $y,
        color => $palette->getpixel(
          x =>
            clamp( ( $gray / $maxColor ) * ( $srcWidth - 1 ), $srcWidth - 1 ),
          y => clamp( $srcY * ( $srcHeight - 1 ), $srcHeight - 1 ),
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

  print "Applying hypotenuse (corner-to-corner) CLUT...\n" if !$QUIET;

  my $palette = Imager->new;
  $palette->read( file => $args{clut} ) || die $palette->errstr;

  my $srcHeight = $palette->getheight();
  my $srcWidth  = $palette->getwidth();

  my $len = scalar( @{$grid} );

  my $out = Imager->new(
    xsize => $len,
    ysize => $len,
  );

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $gray = $grid->[$x]->[$y];

      my $color = $palette->getpixel(
        x => ( clamp($gray) / $maxColor * ( $srcWidth - 1 ) ),
        y => $srcHeight - 1 - ( clamp($gray) / $maxColor * ( $srcHeight - 1 ) ),
      );

      $out->setpixel(
        x     => $x,
        y     => $y,
        color => $color
      );
    }
  }

  return $out;
}

sub voronoi {
  return smooth( spirals( @_, voronoi => 1 ), @_ );
}

sub spirals {
  my %args = @_;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};

  my $voronoi = $args{voronoi};

  %args = defaultArgs(%args);

  my $len = $args{freq};

  my $grid = grid( %args, len => $len, bias => 0 );

  my $half   = $len / 2;
  my $radius = $half;
  my $rand   = sub { ( rand() >= .5 ) ? 1 : -1 };

  $args{amp} = .5 if !defined $args{amp};

  my $bias = $args{bias} * $maxColor;
  my $amp  = $args{amp} * $maxColor;

  for ( my $n = 0 ; $n < sqrt($len) * 2 ; $n++ ) {
    my ( $coils, $arms, $steps );

    if ($voronoi) {
      $coils = 360;
      $arms  = 1;
      $steps = $len * $len * 2;
    } else {
      $coils = int( rand(5) );
      $arms  = int( rand(7) ) + 1;
      $steps = 180 + rand(180);
    }

    my $aroundStep = ( $coils / $steps );
    my $aroundRads = $aroundStep * 2 * ( 22 / 7 );

    my $centerX = rand($len);
    my $centerY = rand($len);

    my $rotation = rand() * 2 * 22 / 7;

    for ( my $i = 1 ; $i <= $steps ; $i += 1 ) {
      my $away = $radius**( $i / $steps );

      for ( my $r = 0 ; $r < $arms ; $r += 1 / $arms ) {
        my $around = ( $i * $aroundRads ) + $rotation + ( $r * 2 * ( 22 / 7 ) );

        my $x = ( $centerX + cos($around) * $away ) % $len;
        my $y = ( $centerY + sin($around) * $away ) % $len;

        my $color = $maxColor - ( ( ( $i - 1 ) / ( $steps - 1 ) ) * $maxColor );

        if ( $grid->[$x]->[$y] < $color ) {
          $grid->[$x]->[$y] = $color;
        }
      }
    }

    $grid->[$centerX]->[$centerY] = $maxColor;
  }

  if ($voronoi) {
    $grid = densemap($grid);

    for ( my $x = 0 ; $x < $len ; $x++ ) {
      for ( my $y = 0 ; $y < $len ; $y++ ) {
        $grid->[$x]->[$y] =
          $maxColor - ( ( $grid->[$x]->[$y] / $maxColor ) * $maxColor );
      }
    }
  } else {
    $grid = glow( $grid, %args );
  }

  return grow( $grid, %args );
}

sub dla {
  my %args = @_;

  $args{bias} ||= .5;
  $args{amp}  ||= .5;
  $args{len}  ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $amp = $args{amp} * $maxColor;

  my $len = $args{freq};

  my $grid = grid(%args, bias => 0);

  for ( my $i = 0; $i <= sqrt($len); $i++ ) {
    $grid->[rand($len)]->[rand($len)] = $maxColor;
  }

  my @points;

  # my $branches = sqrt($len);
  my $branches = $len * $len / 4;

  for ( my $i = 0 ; $i < $branches ; $i++ ) {
    push @points, [ rand($len), rand($len) ];
  }

  my $prev = 0;

  my $buf = $|;
  $| = 1;

  while (@points) {
    my $color = ( @points / $branches ) * $maxColor;

    print scalar(@points) . " " if !$QUIET && ( $prev != @points );

    $prev = scalar(@points);

    my @newPoints;

    for ( my $i = 0 ; $i < @points ; $i++ ) {
      my $x = $points[$i]->[0] % $len;
      my $y = $points[$i]->[1] % $len;

      if ( ( $grid->[$x]->[$y] )
        || ( $grid->[ ( $x + 1 ) % $len ]->[$y] )
        || ( $grid->[ ( $x - 1 ) % $len ]->[$y] )
        || ( $grid->[$x]->[ ( $y + 1 ) % $len ] )
        || ( $grid->[$x]->[ ( $y - 1 ) % $len ] )
        || ( $grid->[ ( $x + 1 ) % $len ]->[ ( $y + 1 ) % $len ] )
        || ( $grid->[ ( $x + 1 ) % $len ]->[ ( $y - 1 ) % $len ] )
        || ( $grid->[ ( $x - 1 ) % $len ]->[ ( $y - 1 ) % $len ] )
        || ( $grid->[ ( $x - 1 ) % $len ]->[ ( $y + 1 ) % $len ] ) )
      {
        $grid->[$x]->[$y] = $color;
      } else {
        push @newPoints, [ $x, $y ];
      }
    }

    @points = @newPoints;

    last if !@points;

    for ( my $i = 0 ; $i < @points ; $i++ ) {
      my $x = $points[$i]->[0] % $len;
      my $y = $points[$i]->[1] % $len;

      my $offset = rand(3);
      $offset *= -1 if rand() >= .5;
      $points[$i]->[0] = $x + $offset % $len;

      $offset = rand(3);
      $offset *= -1 if rand() >= .5;
      $points[$i]->[1] = $y + $offset % $len;
    }
  }

  $| = $buf;

  return glow( grow( $grid, %args ), %args );
}

sub glow {
  my $grid = shift;
  my %args = @_;

  my $smoothed = smooth( $grid, %args );
  $smoothed = smooth( $smoothed, %args );
  $smoothed = smooth( $smoothed, %args );
  $smoothed = smooth( $smoothed, %args );

  my $len = scalar @{$grid};

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $smoothed->[$x]->[$y] += $grid->[$x]->[$y];
    }
  }

  return $smoothed;
}

sub tesla {
  my %args = @_;

  $args{freq} ||= 8;

  return fur( %args, tesla => 1 );
}

sub fur {
  my %args = @_;

  # $args{octaves} = 4 if !defined $args{octaves};
  $args{freq} = 2 if !defined $args{freq};

  my $perlin = perlin( %args, amp => 1, bias => 0 );
  my $grid = grid(%args);

  my $len = $args{len} || $defaultLen;

  %args = defaultArgs(%args);

  my @worms;

  my ( $numWorms, $threadLen );

  if ( $args{tesla} ) {
    $numWorms  = $len;
    $threadLen = $len;
  } else {
    $numWorms  = $len * $len;
    $threadLen = sqrt($len);
  }

  for ( my $i = 0 ; $i < $numWorms ; $i++ ) {
    my $worm = [ rand($len), rand($len) ];

    push @worms, $worm;
  }

  for ( my $i = 0 ; $i < $threadLen ; $i++ ) {
    my $w = 0;

    for my $worm (@worms) {
      my $x = $worm->[0];
      my $y = $worm->[1];

      my $heading = ( $perlin->[$x]->[$y] / $maxColor ) * 360;

      if ( $args{tesla} ) {
        ### kink it up
        $heading += ( $w / $numWorms ) * 45;
        $grid->[$x]->[$y] +=
          1 - ( abs( $i - ( $threadLen / 2 ) ) / ( $threadLen / 2 ) );
      } else {
        $grid->[$x]->[$y] +=
          1 - ( abs( $i - ( $threadLen / 2 ) ) / ( $threadLen / 2 ) );

        # $grid->[$x]->[$y]++;
      }

      ( $x, $y ) = translate( $x, $y, $heading, 1 );
      $x = ( $x * 100 ) % ( $len * 100 );
      $y = ( $y * 100 ) % ( $len * 100 );
      $worm->[0] = $x / 100;
      $worm->[1] = $y / 100;

      $w++;
    }
  }

  $grid = densemap( $grid, %args );

  if ( $args{tesla} ) {
    $grid = glow( $grid, %args );
  }

  return $grid;
}

sub emboss {
  my $grid = shift;
  my %args = @_;

  my $len = $args{len};

  print "Generating light map\n" if !$QUIET;

  my $lightmap = [];

  my $angle = rand(360);

  for ( my $x = 0 ; $x < $len ; $x += 1 ) {
    $lightmap->[$x] = [];

    for ( my $y = 0 ; $y < $len ; $y += 1 ) {
      my $value;

      my ( $neighborX, $neighborY ) = translate( $x, $y, $angle, 1.5 );

      my $neighbor = noise( $grid, $neighborX, $neighborY );

      my $diff = $grid->[$x]->[$y] - $neighbor;

      $lightmap->[$x]->[$y] = $maxColor - $diff;
    }
  }

  return $lightmap;
}

#
# Make a seamless tile from non-seamless input, such as an infile
#
sub tile {
  my $grid = shift;
  my %args = @_;

  my $len = scalar( @{$grid} );

  my $out = grid( %args, len => $len );

  my $border = $len / 2;

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $out->[$x]->[$y] = $grid->[$x]->[$y];
    }
  }

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $thisX = ( $x - ( $len / 2 ) ) % $len;

      my $blend = 1;
      if ( $x < $border ) {
        $blend = 1 - ( ( $border - $x ) / $border );
      } elsif ( ( $len - $x ) < $border ) {
        $blend = ( $len - $x ) / $border;
      }

      $out->[$x]->[$y] =
        coslerp( $grid->[$thisX]->[$y], $out->[$x]->[$y], $blend );
    }
  }

  my $offX = rand($len);
  my $offY = rand($len);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $thisX = $args{square} ? $x : $x - ( $len / 4 ) % $len;
      my $thisY = $y - ( $len / 2 ) % $len;

      my $blend = 1;
      if ( $y < $border ) {
        $blend = 1 - ( ( $border - $y ) / $border );
      } elsif ( ( $len - $y ) < $border ) {
        $blend = ( $len - $y ) / $border;
      }

      $out->[$x]->[$y] =
        coslerp( $out->[$thisX]->[$thisY], $out->[$x]->[$y], $blend );
    }
  }

  my $final = grid(%args);
  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $final->[ ( $x + $offX ) % $len ]->[ ( $y + $offY ) % $len ] =
        $out->[$x]->[$y];
    }
  }

  return $final;
}

#
# Translate X and Y coordinates according to heading by N units
#
sub translate {
  my $x       = shift;
  my $y       = shift;
  my $heading = shift;    # Euler angle
  my $units   = shift;    # Pixels

  #
  #   A
  #   |\
  # b | \ c
  #   |  \
  #   |___\
  #  C  a  B
  #
  #
  #         0
  #    3/NW | 0/NE
  #         |
  # 270 ----+---- 90
  #         |
  #    2/SW | 1/SE
  #        180
  #

  my $quadrant = 0;    # 0 NE, 1 SE, 2 SW, 3 NW

  my $relativeHeading = $heading % 360;

  if ( $relativeHeading == 0 ) {
    return $x, $y - $units;
  } elsif ( $relativeHeading == 90 ) {
    return $x + $units, $y;
  } elsif ( $relativeHeading == 180 ) {
    return $x, $y + $units;
  } elsif ( $relativeHeading == 270 ) {
    return $x - $units, $y;
  }

  until ( $relativeHeading < 90 ) {
    $relativeHeading -= 90;

    $quadrant += 1;
    $quadrant = 0 if $quadrant > 3;
  }

  my $c = $units;
  my ( $b, $a );

  my $A = $relativeHeading;
  my $C = 90;
  my $B = 180 - 90 - $heading;

  my $rad = deg2rad($A);
  $a = sin($rad) * $c;
  $b = cos($rad) * $c;

  if ( $quadrant == 0 ) {
    $x += $a;
    $y -= $b;
  } elsif ( $quadrant == 1 ) {
    $x += $b;
    $y += $a;
  } elsif ( $quadrant == 2 ) {
    $x -= $a;
    $y += $b;
  } else {
    $x -= $b;
    $y -= $a;
  }

  return $x, $y;
}

sub moire {
  my %args = @_;

  $args{len} ||= $defaultLen;
  my $len = $args{len};

  $args{freq} ||= 64;
  my $freq = $args{freq};

  %args = defaultArgs(%args);

  my $grid = grid( %args, len => $len );

  # Magic number is magic
  my $scale = ( .842 * ( $len / $freq ) ) / 4;

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $grid->[$x]->[$y] =
        sin( ( $x / $scale ) * ( $y / $scale ) / 180 * pi ) * $args{bias};
    }
  }

  $grid = tile( $grid, %args );

  $grid = glow( $grid, %args );

  return $grid;
}

sub textile {
  my %args = defaultArgs(@_);

  my $grid = moire(
    %args,
    freq => ( ( 1024 + rand(1024) ) * 2 ) + 1,
    square => 1,
  );

  return smooth( $grid, %args );
}

sub sparkle {
  my %args = @_;

  $args{len} ||= $defaultLen;
  $args{freq} = $args{len} if !defined $args{freq};

  my $stars = stars(%args);
  $stars = lsmooth( $stars, %args );

  my $stars0 = stars( %args, amp => .25 );

  %args = defaultArgs(%args);

  my $clouds = sgel( %args, freq => 8, bias => 0, amp => .025, stars => 1 );

  my $shadow = emboss( $clouds, %args );
  my $dust = sgel( %args, freq => 16, amp => .5, stars => 1 );
  $dust = densemap($dust);

  my $out = grid(%args);

  my $len = $args{len};

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $cv = $clouds->[$x]->[$y] + $stars0->[$x]->[$y];
      my $dv = $dust->[$x]->[$y] + $shadow->[$x]->[$y];
      my $fv = lerp( 0, $cv, $dv / $maxColor );
      my $sv = $stars->[$x]->[$y];

      $out->[$x]->[$y] = $sv + $fv;
    }
  }

  return glow( $out, %args );
}

sub delta {
  my %args = @_;

  my $generator = __generator( $args{ltype} );

  my $p1 = &$generator(%args);
  my $p2 = &$generator(%args);

  %args = defaultArgs(%args);

  my $len  = $args{len};
  my $grid = grid(%args);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $grid->[$x]->[$y] = abs( $p1->[$x]->[$y] - $p2->[$x]->[$y] );
    }
  }

  return $grid;
}

sub chiral {
  my %args = defaultArgs(@_);

  my $generator = __generator( $args{ltype} );

  my $p1 = &$generator(%args);
  my $p2 = &$generator(%args);

  my $len  = $args{len};
  my $grid = grid(%args);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $c1 = $p1->[$x]->[$y];
      my $c2 = $p1->[$x]->[$y];

      if ( $c1 > $c2 ) {
        $grid->[$x]->[$y] = $c1;
      } else {
        $grid->[$x]->[$y] = $c2;
      }
    }
  }

  return $grid;
}

sub stereo {
  my %args = @_;

  my $len = $args{len} || $defaultLen;

  my $sqrt = sqrt($len);

  my $generator = __generator( $args{ltype} );
  my $left      = &$generator(%args);

  %args = defaultArgs(%args);

  my $map = densemap( $left, %args );
  my $out = grid(%args);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    $out->[ $x / 2 ] ||= [];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $offset = ( $map->[$x]->[$y] / $maxColor ) * 16;

      $out->[ $x / 2 ]->[$y] += noise( $left, $x - $offset, $y ) / 2;
      $out->[ ( $x + $len ) / 2 ]->[$y] += noise( $left, $x + $offset, $y ) / 2;
    }
  }

  return glow( $out, %args );
}

sub _test {
  my %args = defaultArgs(@_);

  my $grid = grid(%args);

  my $len = $args{len};

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {

    }
  }

  return $grid;
}

# our @chars = ( " ", ".", "-", "+", "=", "/", ">", "X", "#", "@" );
our @chars = ( " ", ".", ".", ":", ":", "-", "-", "+", "+", "=", "=", "#" );

sub printRow {
  return if $QUIET;

  my $row = shift;

  my $len = scalar( @{$row} );

  for my $i ( 0 .. 79 ) {
    my $pct  = $i / 80;
    my $rowI = $pct * ($len);
    my $val  = $row->[$rowI];

    my $valPct = clamp($val) / $maxColor;
    my $char = $chars[ $valPct * ( @chars - 1 ) ];

    print $char;
  }

  print "\n";
}

sub spamConsole {
  my %args = @_;

  my $fmtstr = '%-10s %-10s %-10s %-10s %-4s %-4s %-4s %-4s %-4s';

  printf( $fmtstr, qw| type lbase ltype stype bias amp freq oct len | );
  print "\n";

  my $type = $args{type};

  if ( $type eq 'complex' ) {
    printf( $fmtstr,
      "complex",    $args{lbase},   $args{ltype},
      $args{stype}, $args{bias},    $args{amp},
      $args{freq},  $args{octaves}, $args{len},
    );
  } elsif (
    grep {
      $_ eq $type
    } @PERLIN_TYPES
    )
  {
    printf( $fmtstr,
      $type,        "n/a",          "n/a",
      $args{stype}, $args{bias},    $args{amp},
      $args{freq},  $args{octaves}, $args{len},
    );
  } else {
    printf( $fmtstr,
      $type,      "n/a",       "n/a", "n/a", $args{bias},
      $args{amp}, $args{freq}, "n/a", $args{len}, );
  }

  print "\n";
}

1;
__END__

=pod

=head1 NAME

Math::Fractal::Noisemaker - Visual noise generator

=head1 VERSION

This document is for version 0.013 of Math::Fractal::Noisemaker.

=head1 SYNOPSIS

  use Math::Fractal::Noisemaker qw| :all |;

  #
  # use defaults
  #
  make();

  #
  # override defaults
  #
  make(type => 'gel',
    # ...
  );

A wrapper script, C<make-noise>, is included with this distribution.

  #
  # use defaults
  #
  make-noise

  #
  # override defaults
  #
  make-noise -type gel

  #
  # usage
  #
  make-noise --help

  make-noise --help types

Noise sets are just 2D arrays, which may be generated directly using
named functions.

  use Math::Fractal::Noisemaker qw| :flavors |;

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

Math::Fractal::Noisemaker provides a simple functional interface
for generating 2D tiles from various flavors of fractal (and
non-fractal) inputs.

As long as the specified side length is a power of the noise's
frequency, this module will produce seamless tiles (with the exception
of a few noise types).  For example, a base frequency of 4 would
work fine for an image with a side length of 256 (256x256).

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

=head2 MAKE ARGS

In addition to any argument appropriate to the type of noise being
generated, C<make> accepts the following args in hash key form:

=over 4

=item * type => $noiseType

The type of noise to generate, defaults to Perlin. Specify any type.

  make(type => 'gel');

=item * sphere => $bool

Generate a pseudo-spheremap from the resulting noise.

When specifying C<sphere>, the output image will be 50% of the
C<len> you asked for. This is done to avoid aliasing. Multiply the
supplied C<len> argument by 2 to work around this.

See C<spheremap>.

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

0: Hypotenuse lookup (corner to corner, so it doesn't matter if the
input table is oriented horizontally or vertically). This is the
default. Best for seamless tiling.

1: Vertical lookup, good for generating maps which have ice caps at
the poles and tropical looking colors at the equator. Output will
have color seams at the poles unless viewed on a spheroid. This
lookup method produces output which resembles a reflection map, if
a photograph is used for the C<clut>.

2: Fractal lookup, uses the same methodology as C<refract>. Also
good for seamless tiling.

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

=item * shadow => $float

Amount of self-shadowing to apply, between 0 and 1.

=item * emboss => <0|1>

Render lightmap only

=back

=head1 NOISE TYPES

=head2 SIMPLE NOISE

Simple noise types may be specified as Perlin slice types (C<stype>)

=over 4

=item * white(%args)

Each non-smoothed pixel contains a pseudo-random value

=item * wavelet(%args)

Basis function for sharper Perlin slices

=item * square(%args)

Diamond-Square

=item * gel(%args)

Self-displaced white noise; see GEL TYPES

=item * sgel(%args)

Self-displaced Diamond-Square noise; see GEL TYPES

=item * dla(%args)

Diffusion-limited aggregation, seeded from multiple random points.

=item * mandel(%args)

Fractal type - Mandelbrot. Included as a demo.

=item * dmandel(%args)

Fractal type - Deep Mandelbrot. Picks a random "interesting" location
in the set (some point with a value which neither hovers near 0 nor
flies off into infinity), zooms in a random amount, and embellishes
the palette.

=item * buddha(%args)

Fractal type - "Buddhabrot" Mandelbrot variant. Work in progress.

=item * fflame(%args)

IFS type - "Fractal Flame". Work in progress. Neat.

=item * fern(%args)

IFS type - Barnsley's fern. Included as a demo.

=item * gasket(%args)

IFS type - Sierpinski's triangle/gasket. Included as a demo.

=item * stars(%args)

White noise generated with extreme gappiness and smoothed

=item * spirals(%args)

Tiny logarithmic spirals

=item * voronoi(%args)

Ridged Voronoi cells.

=item * moire(%args)

Interference pattern with blended image seams.

Appearance of output is heavily influenced by the C<freq> arg.

=item * textile(%args)

Moire noise with a randomized and large C<freq> arg.

=item * infile(%args)

Import the brightness values from the file specified by the "in"
or "-in" arg.

  my $grid = infile(
    in => "dirt.bmp"
  );

=item * intile(%args)

Calls C<infile>, and makes a seamless repeating tile from the image.

  my $grid = intile(
    in => "dirt.bmp"
  );

=item * sparkle

Stylized starfield

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

  make(type => 'mandel', zoom => 2);

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

The default slice type is smoothed C<wavelet> noise.

=over 4

=item * perlin(%args)

Perlin

  make(type => 'perlin', stype => '...');

=item * ridged(%args)

Ridged multifractal - provide C<zshift> arg to specify a post-processing bias.

  make(type => 'ridged', stype => '...', zshift => .5 );

=item * block(%args)

Unsmoothed Perlin

  make(type => 'block', stype => ...);

=item * pgel(%args)

Self-displaced Perlin noise; see GEL TYPES

  make(type => 'pgel', stype => ...);

=item * fur(%args)

Fur-lin noise; traced paths of worms with Perlin input.

=item * tesla(%args)

Long, fiberous worm paths with random skew.

=item * delta(%args)

Difference noise; output contains absolute values of subtracting
two noise sets.

  make( type => "delta" );

Use C<ltype> to specify any simple or perlin layer type.

  make(
    type => "delta",
    ltype => "gel"
  );

=item * chiral(%args)

Twin noise; output contains the lightest values of two noise sets.

  make( type => "chiral" );

Use C<ltype> to specify any simple or perlin layer type.

  make(
    type => "chiral",
    ltype => "tesla"
  );

=item * stereo(%args)

Stereoscopic depth map.

Use C<ltype> to specify any simple or perlin layer type.

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

Perlin slice type, defaults to C<wavelet>. Any simple type may be
specified.

  my $grid = make(stype => 'gel');

=back

=head2 COMPLEX NOISE

=over 4

=item * complex

Complex layered noise

  make(type => "complex");

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

The simple and Perlin "gel" types (C<gel>, C<sgel>, C<pgel>)
accept the following additional arguments:

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

Math::Fractal::Noisemaker diverges from most Perlin implementations
in that its noise function simply utilizes a lookup table. The
lookup table contains pre-populated random values. Turns out, this
works fine.

=item * lerp($a, $b, $x)

Linear interpolate from $a to $b, by $x percent. $x is between 0
and 1.

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

=item * displace($grid,%args)

Use the received grid as its own displacement map; returns a new grid.

The amount of displacement is controlled by the C<displace> arg.

See GEL TYPES

=back

=head1 SEE ALSO

L<Imager>, L<Math::Trig>

Math::Fractal::Noisemaker is on GitHub: http://github.com/aayars/noisemaker

Noisemaker borrows inspiration and/or pseudocode from these notable
sources.

  - http://freespace.virgin.net/hugo.elias/models/m_perlin.htm
    Perlin

  - http://gameprogrammer.com/fractal.html
    Diamond-Square

  - http://graphics.pixar.com/library/WaveletNoise/paper.pdf
    Wavelet (Pixar)

  - http://www.complang.tuwien.ac.at/schani/mathmap/stills.html
    Moire (MathMap)

  - http://libnoise.sourceforge.net/
    Libnoise is pro

  - http://flam3.com/flame.pdf
    Fractal Flame

... and a host of others.

=head1 AUTHOR

  Alex Ayars <pause@nodekit.org>

=head1 COPYRIGHT

  File: Fractal/Noisemaker.pm
 
  Copyright (c) 2009 Alex Ayars
 
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Common Public License v1.0
  which accompanies this distribution, and is available at
  http://opensource.org/licenses/cpl1.0.txt

=cut
