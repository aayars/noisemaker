package Math::Fractal::Noisemaker;

our $VERSION = '0.105';

use strict;
use warnings;

use Imager;
use Math::Trig qw| :radial deg2rad tan pi |;
use Tie::CArray;

use base qw| Exporter |;

our $COLUMN_CLASS = "Tie::CDoubleArray";

our @SIMPLE_TYPES = qw|
  white wavelet gradient square gel sgel stars spirals dla worley wgel
  fflame mandel dmandel buddha fern gasket julia djulia newton
  infile intile moire textile sparkle canvas simplex simplex2
  |;

our @PERLIN_TYPES = qw|
  multires ridged block pgel fur tesla lumber wormhole flux
  |;

our @NOISE_TYPES = ( @SIMPLE_TYPES, @PERLIN_TYPES, qw| terra | );

our @EXPORT_OK = "make";

# there used to be more stuff here, but i'll leave the :all tag
our %EXPORT_TAGS = (
  'all' => \@EXPORT_OK,
);

our $DEFAULT_FORMAT = "bmp";
our $DEFAULT_AMP = .5;
our $DEFAULT_BIAS = .5;
our $DEFAULT_LEN = 256;
our $DEFAULT_TYPE = 'multires';
our $DEFAULT_SLICE_TYPE = 'white';
our $DEFAULT_TERRAIN_BASE = 'multires';
our $DEFAULT_TERRAIN_SLICE = 'ridged';
our $DEFAULT_GAP = 0;
our $DEFAULT_FREQ = 4;
our $DEFAULT_OCTAVES = 8;
our $DEFAULT_PERSIST = .5;
our $DEFAULT_DISPLACEMENT  = 1;
our $DEFAULT_INTERP = 1;
our $DEFAULT_RHO = 1;

our $QUIET;

my $MAX_COLOR = 255;

my $INTERP_FN;
my $GROW_FN;

#
# Persistent gradient values
#
my @NUMS = ( -255 .. 255 );
do {
  my @r;
  while (@NUMS) {
    my $i = rand(@NUMS);
    push @r, $NUMS[$i];
    splice( @NUMS, $i, 1 );
  }
  @NUMS = @r;
};

sub showVersion {
  print "Math::Fractal::Noisemaker $VERSION\n";
}

sub showTypes {
  showVersion();

  print "\n";
  print "All noise types have optional args, see -h.\n";
  print "\n";
  print "Noise Types:\n";
  print "\n";
  print "  * white           ## pseudo-random values\n";
  print "  * wavelet         ## band-limited ortho\n";
  print "  * gradient        ## persistent gradient noise\n";
  print "  * simplex         ## continuous gradient noise\n";
  print "  * simplex2        ## interpolated simplex\n";
  print "  * square          ## diamond-square algorithm\n";
  print "  * gel             ## self-displaced smooth\n";
  print "  * sgel            ## self-displaced diamond-square\n";
  print "  * dmandel         ## \"deep\" mandelbrot\n";
  print "  * djulia          ## \"deep\" julia\n";
  print "  * dla             ## diffusion-limited aggregation\n";
  print "  * worley          ## voronoi cell noise\n";
  print "  * wgel            ## self-displaced cell noise\n";
  print "\n";
  print "  ! multires        ## multi-resolution\n";
  print "  ! ridged          ## ridged multifractal\n";
  print "  ! block           ## unsmoothed multi-res\n";
  print "  ! pgel            ## self-displaced multi-res\n";
  print "  ! fur             ## inspired by \"Perlin Worms\"\n";
  print "  ! tesla           ## worms/fur variant\n";
  print "\n";
  print "Legend:";
  print "\n";
  print "  * single-res type\n";
  print "  !  multi-res type - use 'stype' arg to change basis func\n";
  print "\n";
  print "For even more types(!), see:\n";
  print "  $0 -h moretypes\n";
  print "\n";
  print "perldoc Math::Fractal::Noisemaker for more help, or see:\n";
  print
"  http://search.cpan.org/~aayars/Math-Fractal-Noisemaker/lib/Math/Fractal/Noisemaker.pm\n";
  print "\n";

  exit 1;
}

sub showMoreTypes {
  showVersion();
  print "\n";
  print "Additional types:\n";
  print "\n";

  print "  * mandel          ## Mandelbrot (demo)\n";
  print "  * buddha          ## buddhabrot\n";
  print "  * julia           ## Julia set\n";
  print "  * newton          ## Newton fractal (demo)\n";
  print "  * fflame          ## IFS fractal flame\n";
  print "  * fern            ## IFS fern (demo)\n";
  print "  * gasket          ## IFS gasket (demo)\n";
  print "  * stars           ## starfield\n";
  print "  * spirals         ## tiny logspirals\n";
  print "  * moire           ## interference patterns\n";
  print "  * textile         ## random high-freq moire\n";
  print "  * infile          ## image file named by 'in' arg\n";
  print "  * intile          ## infile + blend seams\n";
  print "  * sparkle         ## stylized stars\n";
  print "  * canvas          ## like an old map\n";
  print "\n";
  print "  ! lumber          ## vaguely woodlike\n";
  print "  ! wormhole        ## field flow\n";
  print "  ! flux            ## extruded contours\n";
  print "  ! terra           ## terrain recipe (see -h more)\n";
  print "\n";

  exit 1;
}

sub usage {
  showVersion();

  print "\n";
  print "All command line args are optional.\n";
  print "\n";
  print "Usage:\n";
  print "$0 \\\n";
  print "  [-type <noisetype>] \\ ## noise type\n";
  print "  [-stype <single-res type>]\\ ## multi-res slice type\n";
  print "  [-amp <num>] \\       ## base amplitude (eg .5)\n";
  print "  [-freq <num>] \\      ## base frequency (eg 2)\n";
  print "  [-len <int>] \\       ## side length (eg 256)\n";
  print "  [-bias <num>] \\      ## value bias (0..1)\n";
  print "  [-qual <0|1|2|3>]* \\ ## quality (draft|linear|cosine|gaussian)\n";
  print "  [-octaves <int>] \\   ## multi-res octaves (eg 4)\n";
  print "  [-refract <0|1>] \\   ## refractive grayscale palette\n";
  print "  [-sphere <0|1>] \\    ## fake spheremap\n";
  print "  [-displace <num>] \\  ## self-displacement (eg .25)\n";
  print "  [-clut <filename>] \\ ## color lookup table (ex.bmp)\n";
  print "  [-clutdir 0|1|2] \\   ## clut direction diagonal|vertical|fractal\n";
  print "  [-in <filename>] \\   ## input filename for infile (infile.bmp)\n";
  print "  [-shadow <0..1>] \\   ## false shadow/highlight amount (rec. .5)\n";
  print "  [-nth <n>] \\         ## worley: Nth closest neighbor (0-index)\n";
  print "  [-dist <0|1|2|3>] \\  ## worley: euclid|manhat|cheby|? (0|1|2|3)\n";
  print "  [-cell <0|1>] \\      ## worley: render as distance|cell (0|1)\n";
  print "  [-tile 0|1|2|3] \\    ## force tiling (off|both|horiz|vert)\n";
  print "  [-format <type>] \\   ## file type (default bmp)\n";
  print "  [-outdir <dir>] \\    ## output dir (eg \"mynoise/\")\n";
  print "  [-quiet <0|1>] \\     ## no STDOUT spam\n";
  print "  [-out <filename>]    ## Output file (foo.bmp)\n";
  print "\n";
  print "* Add a plus (+) to quality arg to use non-upsampled noise, eg:\n";
  print "  make-noise -quality 1+\n";
  print "\n";
  print "For more options, see:\n";
  print "  $0 -h more\n";
  print "\n";
  print "For a list of available noise types, see:\n";
  print "  $0 -h types\n";
  print "\n";
  print "perldoc Math::Fractal::Noisemaker for more help.\n";
  print "\n";

  my $warning = shift;
  print "$warning\n" if $warning;

  exit 1;
}

sub moreUsage {
  showVersion();

  print "\n";
  print "Additional options:\n";
  print "$0 \\\n";
  print "  [-persist <num>] \\   ## multi-res persistence (eg .5)\n";
  print "  [-gap <num>] \\       ## stars: gappiness (0..1)\n";
  print "  [-smooth <0|1>] \\    ## resampling off|on (default: on)\n";
  print "  [-interp <0|1>] \\    ## interp fn linear|cosine\n";
  print "  [-grow <0|1>] \\      ## growth fn interp|gaussian\n";
  print "  [-limit 0|1] \\       ## scale|clip pixel values\n";
  print "  [-zoom <num>] \\      ## fractals: scale magnitude\n";
  print "  [-maxiter <num>] \\   ## fractals: iteration limit\n";
  print "  [-emboss <0|1>] \\    ## output shadow only (no|yes)\n";
  print "  [-zshift <-1..1>] \\  ## final z offset for ridged\n";
  print "  [-delta 0|1] \\       ## output as difference noise\n";
  print "  [-chiral 0|1] \\      ## output as additive noise\n";
  print "  [-stereo 0|1] \\      ## output as stereogram\n";
  print "\n";
  print "'terra' options:\n";
  print "\n";
  print "  [-lbase <any type but terra>] \\ ## terra continent shape\n";
  print "  [-ltype <any type but terra>] \\ ## terra multi-res type\n";
  print "  [-feather <num>] \\   ## terra feather amt (0..255)\n";
  print "  [-layers <int>] \\    ## terra layers (eg 3)\n";
  print "\n";

  my $warning = shift;
  print "$warning\n" if $warning;

  exit 1;
}

sub make {
  my %args;

  while ( my $arg = shift ) {
    if ( $arg =~ /(-h$|help)/ ) {
      if ( $_[0] && lc( $_[0] ) eq 'types' ) {
        showTypes();
      } elsif ( $_[0] && lc( $_[0] ) eq 'moretypes' ) {
        showMoreTypes();
      } elsif ( $_[0] && lc( $_[0] ) eq 'more' ) {
        moreUsage();
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
    elsif ( $arg =~ /persist/ )   { $args{persist}  = shift; }
    elsif ( $arg =~ /qual/ )      { $args{quality}  = shift; }
    elsif ( $arg =~ /interp$/ )   { $args{interp}   = shift; }
    elsif ( $arg =~ /grow$/ )     { $args{grow}     = shift; }
    elsif ( $arg =~ /gap/ )       { $args{gap}      = shift; }
    elsif ( $arg =~ /feather/ )   { $args{feather}  = shift; }
    elsif ( $arg =~ /layers/ )    { $args{layers}   = shift; }
    elsif ( $arg =~ /smooth/ )    { $args{smooth}   = shift; }
    elsif ( $arg =~ /(^|-)out$/ ) { $args{out}      = shift; }
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
    elsif ( $arg =~ /nth/ )       { $args{nth}      = shift; }
    elsif ( $arg =~ /cell/ )      { $args{cell}     = shift; }
    elsif ( $arg =~ /dist/ )      { $args{dist}     = shift; }
    elsif ( $arg =~ /delta/ )     { $args{delta}    = shift; }
    elsif ( $arg =~ /chiral/ )    { $args{chiral}   = shift; }
    elsif ( $arg =~ /stereo/ )    { $args{stereo}   = shift; }
    elsif ( $arg =~ /tile/ )      { $args{tile}     = shift; }
    elsif ( $arg =~ /xscale/ )    { $args{xscale}   = shift; }
    elsif ( $arg =~ /yscale/ )    { $args{yscale}   = shift; }
    elsif ( $arg =~ /quiet/ )     { $QUIET          = shift; }
    elsif ( $arg =~ /format/ )    { $args{format}   = shift; }
    elsif ( $arg =~ /outdir/ )    { $args{outdir}   = shift; }
    else                          { usage("Unknown argument: $arg") }
  }

  usage("Specified CLUT file not found") if $args{clut} && !-e $args{clut};

  my $q = $args{quality};
  $args{upsample} = 1;

  if ( defined $q ) {
    $args{upsample} = 0 if $q =~ s/\+$//;

    if ( $q == 0 ) {
      $args{smooth} = 0 if !defined $args{smooth};
      $args{interp} = 0 if !defined $args{interp};
      $args{grow}   = 0 if !defined $args{grow};
    } elsif ( $q == 1 ) {
      $args{smooth} = 1 if !defined $args{smooth};
      $args{interp} = 0 if !defined $args{interp};
      $args{grow}   = 0 if !defined $args{grow};
    } elsif ( $q == 2 ) {
      $args{smooth} = 1 if !defined $args{smooth};
      $args{interp} = 1 if !defined $args{interp};
      $args{grow}   = 0 if !defined $args{grow};
    } elsif ( $q == 3 ) {
      $args{smooth} = 1 if !defined $args{smooth};
      $args{interp} = 1 if !defined $args{interp};
      $args{grow}   = 1 if !defined $args{grow};
    }
  }

  #
  #
  #
  $args{type}  ||= $DEFAULT_TYPE;
  $args{stype} ||= $DEFAULT_SLICE_TYPE;
  $args{lbase} ||= $DEFAULT_TERRAIN_BASE;
  $args{ltype} ||= $DEFAULT_TERRAIN_SLICE;

  #
  #
  #
  if ( !defined $args{interp} ) {
    $args{interp} = $DEFAULT_INTERP;
  }

  $INTERP_FN = $args{interp} ? \&cosine_interp : \&lerp;

  if ( $args{grow} ) {
    $GROW_FN = \&grow_gaussian;
  } else {
    $GROW_FN = \&grow_interp;
  }

  if ( !defined $args{smooth} ) {
    $args{smooth} = 1;
  }

  #
  #
  #
  if ( $args{shadow} && $args{emboss} ) {
    delete $args{shadow};
  }

  if (
    ( $args{type} eq 'terra' )
    && ( ( $args{lbase} =~ /[prs]gel/ )
      || ( $args{ltype} =~ /[prs]gel/ )
      || $args{stype} =~ /[prs]gel/ )
    )
  {
    $args{freq}     ||= 2;
    $args{displace} ||= .125;
  } elsif (
    ( $args{type} eq 'terra' )
    && ( ( $args{lbase} eq 'gel' )
      || ( $args{ltype} eq 'gel' )
      || $args{stype} eq 'gel' )
    )
  {
    $args{freq}     ||= 4;
    $args{displace} ||= .5;
  }

  my $format = $args{format} || $DEFAULT_FORMAT;

  if ( !$Imager::formats{$format} ) {
    my $formats = join( ",", sort keys %Imager::formats );

    usage("Unsupported format: $format (choose: $formats)");
  }

  $args{out} ||= join(".", $args{type}, $format);

  if ( $args{outdir} ) {
    usage("outdir does not exist") if !-e $args{outdir};

    $args{out} = join( "/", $args{outdir}, $args{out} );
  }

  if ( $args{upsample} ) {
    $args{len} ||= $DEFAULT_LEN;
    $args{len} /= 2;
  }

  my $grid;

  for my $type (@NOISE_TYPES) {
    if ( $args{type} eq $type ) {
      my $sub;

      do {
        no strict 'refs';
        $sub = \&{"Math::Fractal::Noisemaker::$type"};
      };

      $grid = &$sub(%args);
      last;
    }
  }

  if ( !$grid ) {
    usage("Unknown noise type '$args{type}' specified");
  }

  if ( $args{refract} ) {
    $grid = refract( $grid, %args );
  }

  if ( defined($args{xscale}) || defined($args{yscale}) ) {
    $grid = stretch($grid, %args);
  }

  if ( $args{sphere} ) {
    %args = defaultArgs(%args);

    $grid = spheremap( $grid, %args );
  }

  if ( $args{delta} || $args{chiral} ) {
    my $grid2;

    for my $type (@NOISE_TYPES) {
      if ( $args{type} eq $type ) {
        my $sub;

        do {
          no strict 'refs';
          $sub = \&{"Math::Fractal::Noisemaker::$type"};
        };

        $grid2 = &$sub(%args);
        last;
      }
    }

    if ( $args{delta} ) {
      $grid = delta( $grid, $grid2, %args );
    } else {
      $grid = chiral( $grid, $grid2, %args );
    }
  }

  if ( $args{stereo} ) {
    $grid = stereo( $grid, %args );
  }

  if ( $args{upsample} ) {
    $args{len} *= 2;
    $grid = grow($grid, %args);
  }

  my $img;

  $img = img( $grid, %args);

  $img->write( file => $args{out} ) || die $img->errstr;

  print "Saved file to $args{out}\n" if !$QUIET;

  return($img, $args{out});
}

sub defaultArgs {
  my %args = @_;

  $args{bias}   = $DEFAULT_BIAS if !defined $args{bias};

  $args{gap}     ||= $DEFAULT_GAP;
  $args{type}    ||= $DEFAULT_TYPE;
  $args{stype}   ||= $DEFAULT_SLICE_TYPE;
  $args{lbase}   ||= $DEFAULT_TERRAIN_BASE;
  $args{ltype}   ||= $DEFAULT_TERRAIN_SLICE;
  $args{freq}    ||= $DEFAULT_FREQ;
  $args{len}     ||= $DEFAULT_LEN;
  $args{octaves} ||= $DEFAULT_OCTAVES;
  $args{persist} ||= $DEFAULT_PERSIST;

  $args{auto} = 1 if !defined( $args{auto} ) && $args{type} ne 'fern';

  $args{amp} = $DEFAULT_AMP if !defined $args{amp};

  return %args;
}

sub img {
  my $grid = shift;
  my %args = defaultArgs(@_);

  print "Generating image...\n" if !$QUIET;

  my $len = scalar( @{$grid} );

  my $stretch = $args{sphere} ? 2 : 1;

  ###
  ### Save the image
  ###
  my %imagerArgs = (
    xsize => $len*$stretch,
    ysize => $len,
  );

  $imagerArgs{channels} = 1 if !$args{clut};

  my $img = Imager->new(%imagerArgs);

  ###
  ### Scale pixel values to sane levels
  ###
  my ( $min, $max, $range );

  if ( $args{auto} ) {
    for ( my $x = 0 ; $x < $len ; $x++ ) {
      my $column = $grid->[$x];

      for ( my $y = 0 ; $y < $len ; $y++ ) {
        my $gray = $column->get($y);

        $min = $gray if !defined $min;
        $max = $gray if !defined $max;

        $min = $gray if $gray < $min;
        $max = $gray if $gray > $max;
      }
    }

    $range = $max - $min;
  }

  my $scaledGrid = [];

  for ( my $x = 0 ; $x < $len*$stretch ; $x++ ) {
    my $scaledColumn = $COLUMN_CLASS->new($len);

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      # my $gray = $column->get($y);
      my $gray = noise($grid,$x/$stretch,$y);

      my $scaled;

      if ( $args{auto} ) {
        $scaled = $range ? ( ( $gray - $min ) / $range ) * $MAX_COLOR : 0;
      } else {
        $scaled = clamp($gray);
      }

      $scaledColumn->set( $y, $scaled );
    }

    $scaledGrid->[$x] = $scaledColumn;
  }

  if ( $args{clut} && $args{clutdir} ) {
    $img = vertclut( $scaledGrid, %args );
  } elsif ( $args{clut} ) {
    $img = hypoclut( $scaledGrid, %args );
  } else {
    if ( $args{emboss} && !$args{shadow} ) {
      $scaledGrid = emboss( $scaledGrid, %args );
      $scaledGrid = smooth( $scaledGrid, %args );
      # $scaledGrid = glow( $scaledGrid, %args );
      $scaledGrid = densemap( $scaledGrid );
    }

    for ( my $x = 0 ; $x < $len*$stretch; $x++ ) {
      my $column = $scaledGrid->[$x];

      for ( my $y = 0 ; $y < $len ; $y++ ) {
        my $gray = $column->get($y);
        $img->setpixel(
          x     => $x,
          y     => $y,
          color => [ $gray, $gray, $gray ],
        );
      }
      printRow($column);
    }
  }

  if ( $args{shadow} && !$args{emboss} ) {
    my $embossed = emboss( $scaledGrid, %args );

    # $embossed = smooth( $embossed, %args );
    # $embossed = glow( $embossed, %args );
    $embossed = densemap( $embossed );

    my $shadow = $args{shadow};

    for ( my $x = 0 ; $x < $len*$stretch ; $x++ ) {
      for ( my $y = 0 ; $y < $len ; $y++ ) {
        my $color = $img->getpixel( x => $x, y => $y );
        my ( $r, $g, $b ) = $color->rgba;

        my $embColor = noise($embossed,$x/$stretch,$y/$stretch) / $MAX_COLOR;

        if ( $embColor < .65 ) {
          my $amt = ( 1 - ( $embColor / .65 ) ) * $shadow;

          $r = interp( $r, 0, $amt );
          $g = interp( $g, 0, $amt );
          $b = interp( $b, 0, $amt );
        } else {
          my $amt = ( ( ( $embColor - .65 ) / .65 ) ) * $shadow;

          $r = interp( $r, $MAX_COLOR, $amt );
          $g = interp( $g, $MAX_COLOR, $amt );
          $b = interp( $b, $MAX_COLOR, $amt );
        }

        $img->setpixel(
          x     => $x,
          y     => $y,
          color => [ $r, $g, $b ]
        );
      }
      printRow( $embossed->[$x/2] ) if $x % 2 == 0;
    }
  }

  return $img;
}

sub grow {
  $GROW_FN ||= \&grow_interp;

  &$GROW_FN(@_);
}

#
# Artificially stretch noise along either axis
#
sub stretch {
  my $noise = shift;
  my %args  = defaultArgs(@_);

  my $len = $args{len};

  my $grid = grid(%args);

  my $xscale = $args{xscale} || 1;
  my $yscale = $args{yscale} || 1;

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $thisX = $x * $xscale;
      my $thisY = $y * $yscale;

      $column->set( $y, noise( $noise, $thisX, $thisY ) );
    }
  }

  return $grid;
}

#
# Grow the image using the interpolation function
#
sub grow_interp {
  my $noise = shift;
  my %args  = @_;

  my $wantLength = $args{len};
  my $haveLength = scalar( @{$noise} );

  my $scale = $wantLength / $haveLength;

  my $grid = grid(%args);

  my $smooth = $args{smooth};

  for ( my $x = 0 ; $x < $wantLength ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $wantLength ; $y++ ) {
      my $thisX = $x / $scale;
      my $thisY = $y / $scale;

      if ( !$smooth ) {
        $thisX = int($thisX);
        $thisY = int($thisY);
      }

      $column->set( $y, noise( $noise, $thisX, $thisY ) );
    }
  }

  return $grid;
}

#
# Grow the image by resampling neighborhood pixels
#
sub grow_gaussian {
  my $noise = shift;
  my %args  = @_;

  my $grid = $noise;

  my $wantLength = $args{len};
  my $haveLength = scalar( @{$noise} );

  until ( $haveLength >= $wantLength ) {
    my $grown = [];

    for ( my $x = 0 ; $x < $haveLength * 2 ; $x++ ) {
      my $column      = $grid->[ $x / 2 ];
      my $grownColumn = $COLUMN_CLASS->new( $haveLength * 2 );

      for ( my $y = 0 ; $y < $haveLength * 2 ; $y++ ) {
        $grownColumn->set( $y, $column->get( $y / 2 ) );
      }

      $grown->[$x] = $grownColumn;
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
  my $haveXLen = scalar @$noise;
  my $haveYLen = $noise->[0]->len();

  until ( $haveXLen <= $wantLength ) {
    my $shrunk = [];

    for ( my $x = 0 ; $x < $haveXLen / 2 ; $x++ ) {
      my $shrunkColumn = $COLUMN_CLASS->new( $haveYLen / 2 );

      for ( my $y = 0 ; $y < $haveYLen / 2 ; $y++ ) {
        my $value = noise($grid, $x*2, $y*2);
        $value += noise($grid, ($x*2)+1, $y*2);
        $value += noise($grid, $x*2, ($y*2)+1);
        $value += noise($grid, ($x*2)+1, ($y*2)+1);

        $shrunkColumn->set( $y, $value / 4 );
      }

      $shrunk->[$x] = $shrunkColumn;
    }

    $haveXLen /= 2;

    $grid = $shrunk;
  }

  return $grid;
}

sub grid {
  my %args = defaultArgs(@_);

  my $grid = [];

  my $len = $args{len};

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my @row;

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $row[$y] = ( $args{bias} / 1 ) * $MAX_COLOR;
    }

    $grid->[$x] = $COLUMN_CLASS->new( $len, \@row );
  }

  return $grid;
}

sub infile {
  my %args = defaultArgs(@_);

  print "Loading image...\n" if !$QUIET;

  my $len = $args{len};

  my $img = Imager->new;

  $img->read( file => $args{in} ) || die $img->errstr();

  my $width  = $img->getwidth();
  my $height = $img->getheight();

  my $tempSize = ( $width > $height ) ? $width : $height;
  my $tempGrid = grid(%args, len => $tempSize);

  for ( my $x = 0 ; $x < $tempSize ; $x++ ) {
    my $column = $tempGrid->[$x];

    for ( my $y = 0 ; $y < $tempSize ; $y++ ) {
      my $color = $img->getpixel(
        x => ( $x / ( $tempSize / 1 ) ) * ( $width - 1 ),
        y => ( $y / ( $tempSize - 1 ) ) * ( $height - 1 )
      );

      my ( $r, $g, $b ) = $color->rgba;

      $column->set( $y, ( $r + $g + $b ) / 3 );
    }
  }

  return grow($tempGrid, %args);
}

sub intile {
  my $grid = infile(@_);

  return tile( $grid, @_ );
}

sub gradient {
  my %args = @_;

  print "Generating gradient noise...\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $freq = $args{freq};

  my $grid = grid( %args, len => $freq );

  $args{amp} = $DEFAULT_AMP if !defined $args{amp};

  my $ampVal  = $args{amp} * $MAX_COLOR;
  my $biasVal = $args{bias} * $MAX_COLOR;

  spamConsole(%args) if !$QUIET;

  my $amp = $args{amp};

  for ( my $x = 0 ; $x < $freq ; $x++ ) {
    my $column = $grid->[$x];

    my $thisX = $x / $freq;

    for ( my $y = 0 ; $y < $freq ; $y++ ) {

      # my $randAmp = rand($ampVal);

      my $thisY = $y / $freq;

      my $xval = $NUMS[ $thisX * 256 ] + $NUMS[ $thisY * 256 ];
      my $yval = $NUMS[ $thisY * 256 ] + $NUMS[ $xval % 256 ];
      $xval = ( $NUMS[ $xval % 256 ] / 255 ) * $amp;
      $yval = ( $NUMS[ $yval % 256 ] / 255 ) * $amp;

      my $randAmp = interp( $xval, $yval, .5 );

      $column->set( $y, $randAmp + $biasVal );
    }

    printRow($column);
  }

  return grow( $grid, %args );
}

sub worley {
  my %args = @_;
  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = 32 if !defined $args{freq};

  %args = defaultArgs(%args);

  my $freq     = $args{freq};
  my $len      = $args{len};
  my $amp      = $args{amp};
  my $nth      = $args{nth};
  my $cell     = $args{cell};
  my $distType = $args{dist} || 0;

  my $grid = grid(%args);

  my @points;
  if ( $args{points} ) {
    @points = @{$args{points}};
  } else {
    for ( my $i = 0 ; $i < $freq ; $i++ ) {
      my $x = rand($len);
      my $y = rand($len);
      my $white = $NUMS[$i];

      push @points, [ $x, $y, $white ];
    }
  }

  if ( !defined $nth ) {
    $nth = sqrt(scalar @points);
  }

  # render as shaded distance or solid cells? normalize the index:
  $cell = $cell ? 1 : 0;

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my @thisDist;
      for my $point (@points) {
        if ( $distType == 0 || $distType == 3 ) {
          my $xdist = abs( $x - $point->[0] );
          my $ydist = abs( $y - $point->[1] );
          push @thisDist, [ sqrt( $xdist**2 + $ydist**2 ), $point->[2] ];
        }
        if ( $distType == 1 ) {
          push @thisDist, [
            abs( $x - $point->[0] ) + abs( $y - $point->[1] ),
            $point->[2]
          ];
        }
        if ( $distType == 2 ) {
          my $xdist = abs( $x - $point->[0] );
          my $ydist = abs( $y - $point->[1] );
          my $thisDist = ( $xdist > $ydist ) ? $xdist : $ydist;
          push @thisDist, [ $thisDist, $point->[2] ];
        }
      }
      if ( $distType == 3 ) {
        my @foo;
        my $i = 0;
        for (@thisDist) {
          $i++;
          push @foo, [
            abs( $_->[0] - ( $NUMS[$i] / $MAX_COLOR ) * $len ), $_->[1]
          ];
        }

        # push @thisDist, @foo;
        @thisDist = sort { $a->[0] <=> $b->[0] } @foo;
      } else {
        @thisDist = sort { $a->[0] <=> $b->[0] } @thisDist;
      }

      my $val = $thisDist[$nth]->[$cell];
      $column->set( $y, $val);
    }
  }

  $grid = densemap($grid, $args{invert});

  return tile( $grid, %args );
}

sub white {
  my %args = @_;

  print "Generating white noise...\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $freq = $args{freq};
  my $gap  = $args{gap};

  my $grid = grid( %args, len => $freq );

  $args{amp} = $DEFAULT_AMP if !defined $args{amp};

  my $ampVal  = $args{amp} * $MAX_COLOR;
  my $biasVal = $args{bias} * $MAX_COLOR;

  spamConsole(%args) if !$QUIET;

  my $stars = $args{stars};

  # my $offX = rand($freq);
  # my $offY = rand($freq);
  my $offX = 0;
  my $offY = 0;

  for ( my $x = 0 ; $x < $freq ; $x++ ) {
    my $thisX  = ( $x + $offX ) % $freq;
    my $column = $grid->[$thisX];

    for ( my $y = 0 ; $y < $freq ; $y++ ) {
      my $thisY = ( $y + $offY ) % $freq;

      if ( rand() < $gap ) {
        $column->set( $thisY, 0 );
        next;
      }

      my $randAmp = rand($ampVal);

      if ( !$stars ) {
        $randAmp *= -1 if rand(1) >= .5;
      }

      $column->set( $thisY, $randAmp + $biasVal );
    }

    printRow($column);
  }

  return grow( $grid, %args );
}

sub stars {
  my %args = @_;

  print "Generating stars...\n" if !$QUIET;

  $args{bias} = 0;
  $args{amp} ||= $DEFAULT_AMP;
  $args{gap} ||= .995;

  my $grid = white( %args, stars => 1 );

  %args = defaultArgs(%args);

  return $args{smooth} ? smooth( $grid, %args ) : $grid;
}

sub gel {
  my %args = @_;

  print "Generating gel noise...\n" if !$QUIET;

  $args{displace} = $DEFAULT_DISPLACEMENT if !defined $args{displace};

  %args = defaultArgs(%args);

  my $grid = white(%args);

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
    ( $displace / 1 ) * ( $length / $DEFAULT_LEN )
    ;    # Same visual offset for diff size imgs

  $grid = smooth( $grid, %args );

  for ( my $x = 0 ; $x < $length ; $x++ ) {
    my $column = $COLUMN_CLASS->new($length);

    for ( my $y = 0 ; $y < $length ; $y++ ) {
      my $tmpX = noise($grid, $x + $length/2, $y + $length/2);
      my $displaceX = noise($grid, $tmpX, $y) * $displace;

      my $tmpY = noise($grid, $x, $y);
      my $displaceY = noise($grid, $x, $tmpY) * $displace;

      $column->set( $y, noise( $grid, $displaceX, $displaceY ) );
    }

    $out->[$x] = $column;
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
  my $persist = $args{persist};

  $amp = $DEFAULT_AMP if !defined $amp;

  my $grid = $args{grid} || white( %args, len => $freq * 2 );
  my $haveLength = scalar @$grid;
  my $baseOffset = $MAX_COLOR * $amp;
  $baseOffset = sqrt($baseOffset) if $args{grid};

  spamConsole(%args) if !$QUIET;

  until ( $haveLength >= $length ) {
    my $grown = [];

    for ( my $x = 0 ; $x < $haveLength * 2 ; $x++ ) {
      $grown->[$x] = $COLUMN_CLASS->new( $haveLength * 2 );
    }

    for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
      my $thisX       = $x * 2;
      my $column      = $grid->[$x];
      my $grownColumn = $grown->[$thisX];

      for ( my $y = 0 ; $y < $haveLength ; $y++ ) {
        my $thisY = $y * 2;

        my $offset = rand($baseOffset);
        $offset *= -1 if ( rand(1) >= .5 );

        $grownColumn->set( $thisY, $column->get($y) + $offset );
      }

      $grown->[$thisX] = $grownColumn;
    }

    for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
      my $thisX = $x * 2;
      $thisX += 1;

      my $grownColumn = $grown->[$thisX];

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
        $grownColumn->set( $thisY, $corners + $offset );
      }
    }

    $haveLength *= 2;

    $baseOffset *= $persist;

    for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
      my $base = ( $x + 1 ) % 2;

      my $grownColumn = $grown->[$x];

      for ( my $y = $base ; $y < $haveLength ; $y += 2 ) {
        my $sides =
          ( noise( $grown, $x - 1, $y ) +
            noise( $grown, $x + 1, $y ) +
            noise( $grown, $x,     $y - 1 ) +
            noise( $grown, $x,     $y + 1 ) ) / 4;

        my $offset = rand($baseOffset);
        $offset *= -1 if ( rand(1) >= .5 );
        $grownColumn->set( $y, $sides + $offset );
      }
    }

    $grid = $args{smooth} ? smooth( $grown, %args ) : $grown;
  }

  return $grid;
}

sub sgel {
  my %args = defaultArgs(@_);

  $args{displace} = $DEFAULT_DISPLACEMENT if !defined $args{displace};

  print "Generating square gel noise...\n" if !$QUIET;

  my $grid = square(%args);

  return displace( $grid, %args );
}

sub multires {
  my %args = @_;

  print "Generating multi-res noise...\n" if !$QUIET;

  $args{amp} = $DEFAULT_AMP if !defined $args{amp};

  %args = defaultArgs(%args);

  $args{amp} *= $args{octaves};

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

    $amp  *= $args{persist};
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
    $zshift = $args{zshift} * $MAX_COLOR;
  }

  for ( my $x = 0 ; $x < $length ; $x++ ) {

    my $combinedColumn = $COLUMN_CLASS->new($length);

    for ( my $y = 0 ; $y < $length ; $y++ ) {
      my $n;
      my $t;

      for ( my $z = 0 ; $z < @layers ; $z++ ) {
        $n++;

        my $gray = $layers[$z][$x]->get($y);

        if ( $args{ridged} ) {
          $t += abs($gray);
        } else {
          $t += $gray;
        }
      }

      if ( $n && $args{ridged} ) {
        $combinedColumn->set( $y,
          ( $bias * $MAX_COLOR ) + $zshift - ( $t / $n ) );
      } elsif ($n) {
        $combinedColumn->set( $y, $t / $n );
      } else {
        $combinedColumn->set( $y, 0 );
      }
    }

    $combined->[$x] = $combinedColumn;

    printRow($combinedColumn);
  }

  return $combined;
}

sub block {
  my %args = @_;

  print "Generating block noise...\n" if !$QUIET;

  $args{smooth} = 0;

  return multires(%args);
}

sub pgel {
  my %args = @_;

  print "Generating multi-res gel noise...\n" if !$QUIET;

  my $grid = multires(%args);

  $args{displace} = $DEFAULT_DISPLACEMENT if !defined $args{displace};

  %args = defaultArgs(%args);

  return displace( $grid, %args );
}

sub wgel {
  my %args = @_;

  print "Generating worley gel noise...\n" if !$QUIET;

  my $dist     = defined $args{dist}     ? $args{dist}     : 3;
  my $freq     = defined $args{freq}     ? $args{freq}     : 8;
  my $displace = defined $args{displace} ? $args{displace} : 4;

  %args = defaultArgs(
    %args,
    dist     => $dist,
    freq     => $freq,
    displace => $displace,
  );

  my $grid = worley(%args);

  return displace( $grid, %args );
}

sub ridged {
  my %args = @_;

  print "Generating ridged multifractal noise...\n" if !$QUIET;

  $args{bias} = 0 if !defined $args{bias};
  $args{amp}  = 1 if !defined $args{amp};

  return multires( %args, ridged => 1 );
}

sub refract {
  my $grid = shift;
  my %args = @_;

  print "Applying fractal Z displacement...\n" if !$QUIET;

  my $haveLength = scalar( @{$grid} );

  my $out = [];

  for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
    $out->[$x] = [];

    my $inColumn  = $grid->[$x];
    my $outColumn = $COLUMN_CLASS->new($haveLength);

    for ( my $y = 0 ; $y < $haveLength ; $y++ ) {
      my $color = $inColumn->get($y) || 0;
      my $srcY = ( $color / $MAX_COLOR ) * $haveLength;

      $outColumn->set( $y, $inColumn->get($srcY % $haveLength) );
    }

    $out->[$x] = $outColumn;
  }

  return $out;
}

sub lsmooth {
  my $grid = shift;
  my %args = @_;

  my $len = scalar( @{$grid} );

  my $smooth = grid(%args, len => $args{len}/2);

  my $dirs  = $args{dirs}  || 6;
  my $angle = $args{angle} || rand(360);
  my $rad   = $args{rad}   || 6;

  my $dirAngle = 360 / $dirs;
  my $angle360 = 360 + $angle;

  for ( my $x = 0 ; $x < $len/2 ; $x++ ) {
    my $smoothColumn = $smooth->[$x];
    my $column       = $grid->[$x*2];

    for ( my $y = 0 ; $y < $len/2 ; $y++ ) {
      $smoothColumn->set( $y,
        $smoothColumn->get($y) + $column->get($y*2) / $dirs );

      for ( my $a = $angle ; $a < $angle360 ; $a += $dirAngle ) {
        for ( my $d = 1 ; $d <= $rad ; $d++ ) {    # distance
          my ( $tx, $ty ) = translate( $x, $y, $a, $d );
          $tx = ($tx*2) % $len;
          $ty = ($ty*2) % $len;

          $smoothColumn->set( $y,
            $smoothColumn->get($y) +
              $grid->[$tx]->get($ty) * ( 1 - ( $d / $rad ) ) / $rad );
        }
      }
    }

    $smooth->[$x] = $smoothColumn;
  }

  return grow($smooth,%args);
}

sub smooth {
  my $grid = shift;
  my %args = @_;

  my $haveLength = scalar( @{$grid} );

  my $smooth = [];

  my $amt = $args{smooth};

  for ( my $x = 0 ; $x < $haveLength ; $x++ ) {
    my $smoothColumn = $COLUMN_CLASS->new($haveLength);

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

      my $pixel = noise( $grid, $x, $y );

      my $center = $pixel / 4;

      my $blended = $corners + $sides + $center;

      my $final = interp( $pixel, $blended, $amt );

      $smoothColumn->set( $y, $final );
    }

    $smooth->[$x] = $smoothColumn;
  }

  return $smooth;
}

sub terra {
  my %args = @_;

  print "Generating terra noise...\n" if !$QUIET;

  $args{amp}     = .5 if !defined $args{amp};
  $args{feather} = 48 if !defined $args{feather};
  $args{layers} ||= 4;

  %args = defaultArgs(%args);

  my $refGenerator = __generator( $args{lbase} );

  my $reference = &$refGenerator(
    %args,
    bias => .4,
    amp  => .6,
    freq => $args{freq},
  );

  my @layers;

  do {
    my $biasOffset = .5;
    my $bias       = .25;
    my $amp        = .125;
    my $freq       = $args{freq};

    my $generator = __generator( $args{ltype} );

    for ( my $i = 0 ; $i < $args{layers} ; $i++ ) {
      print "---------------------------------------\n" if !$QUIET;
      print "Complex layer $i ...\n"                    if !$QUIET;

      my %xargs;

      if ( $args{ltype} eq 'ridged' ) {
        $xargs{zshift} = $bias;
        $xargs{bias}   = 0;
      } else {
        $xargs{bias} = $bias;
      }

      push @layers,
        &$generator(
        %args,
        %xargs,
        freq => $freq,
        amp  => $amp,
        );

      $bias += $biasOffset;
      $biasOffset *= .5;

      $freq *= 2;

      # $amp *= $args{persist};
    }
  };

  my $out = grid(%args);

  my $feather = $args{feather};
  my $length  = $args{len};

  for ( my $x = 0 ; $x < $length ; $x++ ) {
    my $referenceColumn = $reference->[$x];
    my $outColumn       = $COLUMN_CLASS->new($length);

    for ( my $y = 0 ; $y < $length ; $y++ ) {
      my $value = $referenceColumn->get($y);

      my $level       = 128;
      my $levelOffset = 64;

      $outColumn->set( $y, $layers[0][$x]->get($y) );

      for ( my $z = 1 ; $z < $args{layers} ; $z++ ) {
        my $diff = $level - $value;

        if ( $value >= $level ) {
          ##
          ## Reference pixel value is greater than current level,
          ## so use the current level's pixel value
          ##
          $outColumn->set( $y, $layers[$z][$x]->get($y) );

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
            interp( $layers[$z][$x]->get($y), $outColumn->get($y), $fadeAmt );

          $outColumn->set( $y, $color );
        }

        $level += $levelOffset;
        $levelOffset /= 2;
      }

      $outColumn->set( $y, interp( $outColumn->get($y), $value, .25 ) );
    }

    $out->[$x] = $outColumn;
    printRow($outColumn);
  }

  return $out;

  # return $args{smooth} ? smooth($out, %args) : $out;
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
  my $max = shift || $MAX_COLOR;

  $val = 0    if $val < 0;
  $val = $max if $val > $max;

  return $val;
}

sub noise {
  my $noise = shift;
  my $x     = shift;
  my $y     = shift;

  my $length = shift;
  my $xlen = $length || scalar @$noise;
  my $ylen = $length || $noise->[0]->len();

  my $thisX = int($x);
  my $thisY = int($y);

  #
  # No need to interpolate
  #
  if ( ( $thisX == $x ) && ( $thisY == $y ) ) {
    return $noise->[ $x % $xlen ]->get( $y % $ylen );
  }

  $x = ( ( $x * 1000 ) % ( $xlen * 1000 ) ) / 1000;
  $y = ( ( $y * 1000 ) % ( $ylen * 1000 ) ) / 1000;

  my $fractX = $x - $thisX;
  my $nextX  = ( $x + 1 ) % $xlen;

  my $fractY = $y - $thisY;
  my $nextY  = ( $y + 1 ) % $ylen;

  $thisX = $thisX % $xlen;
  $thisY = $thisY % $ylen;

  my $thisColumn = $noise->[$thisX];
  my $nextColumn = $noise->[$nextX];

  my $v1 = $thisColumn->get($thisY) || 0;
  my $v2 = $nextColumn->get($thisY) || 0;
  my $v3 = $thisColumn->get($nextY) || 0;
  my $v4 = $nextColumn->get($nextY) || 0;

  my $i1 = interp( $v1, $v2, $fractX );
  my $i2 = interp( $v3, $v4, $fractX );

  return interp( $i1, $i2, $fractY );
}

sub interp {
  die "No interp function defined" if !$INTERP_FN;

  &$INTERP_FN(@_);
}

sub lerp {
  my $a = shift || 0;
  my $b = shift || 0;
  my $x = shift || 0;

  if ( $x < 0 ) {
    $x = 0;
  } elsif ( $x > 1 ) {
    $x = 1;
  }

  return ( $a * ( 1 - $x ) + $b * $x );
}

sub cosine_interp {
  my $a = shift || 0;
  my $b = shift || 0;
  my $x = shift || 0;

  my $ft = ( $x * pi );
  my $f  = ( 1 - cos($ft) ) * .5;

  return ( $a * ( 1 - $f ) + $b * $f );
}

sub wavelet {
  my %args = @_;

  print "Generating wavelet noise...\n" if !$QUIET;

  $args{amp} = $DEFAULT_AMP if !defined $args{amp};
  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $source = $args{grid} || white( %args, len => $args{freq} );

  my $down = shrink( $source, %args, len => $args{freq} / 2 );
  my $up   = grow( $down, %args, len => $args{freq} );

  my $out = [];

  my $freq = $args{freq};

  for ( my $x = 0 ; $x < $freq ; $x++ ) {
    my $column       = $COLUMN_CLASS->new($freq);
    my $sourceColumn = $source->[$x];
    my $upColumn     = $up->[$x];

    for ( my $y = 0 ; $y < $freq ; $y++ ) {
      $column->set( $y,
        ( $args{bias} * $MAX_COLOR ) +
          $sourceColumn->get($y) -
          $upColumn->get($y) );
    }

    $out->[$x] = $column;
    printRow($column);
  }

  return grow( $out, %args );
}

sub gasket {
  my %args = @_;

  print "Generating gasket...\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};
  $args{amp} ||= 1;

  my $freq = $args{freq};
  my $amp  = $args{amp} * $MAX_COLOR;

  %args = defaultArgs(%args);

  my $grid = grid( %args, len => $args{freq} );

  for ( my $x = 0 ; $x < $freq ; $x++ ) {
    $grid->[$x] = $COLUMN_CLASS->new($freq);
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
      $grid->[$thisX]->set( $thisY, $MAX_COLOR );
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
sub _fflinear { return @_ }

sub _ffsinusoidal {
  my ( $x, $y ) = @_;
  return sin($x) * 3, sin($y) * 3;
}

sub _ffsphere {
  my ( $x, $y ) = @_;
  my $n = 1 / ( ( $x * $x ) + ( $y + $y ) );
  return $x * $n, $y * $n;
}

sub _ffswirl {
  my ( $x, $y ) = @_;
  my $rsqrd = ( ( $x * $x ) + ( $y + $y ) );
  return (
    ( $x * sin($rsqrd) ) - ( $y * cos($rsqrd) ),
    ( $x * cos($rsqrd) ) + ( $y * sin($rsqrd) )
  );
}

sub _ffhorseshoe {
  my ( $x, $y ) = @_;
  my $r = sqrt( ( $x * $x ) + ( $y * $y ) );
  my $rf = 1 / ( $r * $r );
  return ( $rf * ( $x - $y ) * ( $x + $y ), $rf * 2 * $x * $y );
}

sub _ffpopcorn {
  my ( $x, $y, $c, $f ) = @_;
  return ( $x + ( $c * sin( tan( 3 * $y ) ) ),
    $y + ( $f * sin( tan( 3 * $x ) ) ), );
}

my @flameFns;

do {
  push @flameFns, \&_fflinear;
  push @flameFns, \&_ffsinusoidal;
  push @flameFns, \&_ffsphere;
  push @flameFns, \&_ffswirl;
  push @flameFns, \&_ffhorseshoe;
  push @flameFns, \&_ffpopcorn;
};

sub fflame {
  my %args = @_;

  my @fns;

  for ( my $i = 0 ; $i < @flameFns * 2 ; $i++ ) {
    push @fns, $flameFns[ rand(@flameFns) ];
  }

  print "Generating fractal flame!\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};
  $args{amp} ||= 1;

  my $freq = $args{freq};
  my $amp  = $args{amp} * $MAX_COLOR;

  %args = defaultArgs(%args);

  my $grid = grid( %args, len => $freq );

  my $steps = $args{maxiter} || $freq * $freq * 100;

  my $A = rand(.125) + .25;
  my $B = rand(.125) + .25;
  my $c = rand(.125) + .25;
  my $d = rand(.125) + .25;
  my $e = rand(.125) + .25;
  my $f = rand(.125) + .25;

  my $scale = $args{zoom} || 1;

  my $x = 0;
  my $y = 0;

  my $finalX = rand($freq);
  my $finalY = rand($freq);

  for ( my $n = 0 ; $n < $steps ; $n++ ) {
    do {
      my $gx = ( ( $x * $scale * $freq ) + $finalX ) % $freq;
      my $gy = ( ( $y * $scale * $freq ) + $finalY ) % $freq;

      my $column = $grid->[$gx];

      $column->set( $gy, $column->get($gy) + 1 );

      if ( $n >= 20 ) {
        $column->set( $gy, $column->get($gy) + 1 );
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

  $grid = glow( $grid, %args );

  return grow( $grid, %args );
}

sub densemap {
  my $grid = shift;
  my $invert = shift;

  my $xlen = scalar @$grid;
  my $ylen = $grid->[0]->len();

  my $colors = {};

  for ( my $x = 0 ; $x < $xlen ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $ylen ; $y++ ) {
      $colors->{ $column->get($y) }++;
    }
  }

  my @colors = keys %{$colors};

  my $i = 0;
  for ( sort { $a <=> $b } @colors ) {
    if ( $invert ) {
      $colors->{$_} = $MAX_COLOR - ( $i / @colors ) * $MAX_COLOR;
    } else {
      $colors->{$_} = ( $i / @colors ) * $MAX_COLOR;
    }

    $i++;
  }

  my $out = [];

  for ( my $x = 0 ; $x < $xlen ; $x++ ) {
    my $outColumn = $COLUMN_CLASS->new($ylen);
    my $column    = $grid->[$x];
    for ( my $y = 0 ; $y < $ylen ; $y++ ) {
      $outColumn->set( $y, $colors->{ $column->get($y) } );
    }
    $out->[$x] = $outColumn;
  }

  return $out;
}

sub fern {
  my %args = @_;

  print "Generating fern...\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};
  $args{amp} ||= 1;

  my $freq = $args{freq};
  my $amp  = $args{amp} * $MAX_COLOR;

  %args = defaultArgs(%args);

  my $grid = grid( %args, len => $freq );

  my $steps = $freq * $freq * 10;

  my $x = 0;
  my $y = 0;

  my $scale = $args{zoom} || 1;

  for ( my $n = 0 ; $n < $steps ; $n++ ) {
    my $gx =
      ( $freq - ( ( ( $x * $scale ) + 2.1818 ) / 4.8374 * $freq ) ) % $freq;
    my $gy = ( $freq - ( ( ( $y * $scale ) / 9.95851 ) * $freq ) ) % $freq;

    my $column = $grid->[$gx];

    $column->set( $gy, $column->get($gy) + sqrt( rand() * $amp ) );

    my $rand = rand();

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

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $freq = $args{freq};

  my $iters = $args{maxiter} || $freq;

  my $scale = $args{zoom} || 1;

  $freq *= 2;

  my $grid = grid( %args, len => $freq );

  for ( my $x = 0 ; $x < $freq ; $x += 1 ) {
    my $cx = ( $x / $freq ) * 2 - 1;
    $cx -= .5;
    $cx /= $scale;

    my $column = $grid->[$x];

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

      $column->set( $y, $MAX_COLOR - ( ( $n / $iters ) * $MAX_COLOR ) );
      $column->set( $freq - 1 - $y,
        $MAX_COLOR - ( ( $n / $iters ) * $MAX_COLOR ) );
    }

    printRow($column);
  }

  $grid = shrink( $grid, %args );

  $grid = grow( $grid, %args );

  return $grid;
}

sub dmandel {
  my %args = @_;

  print "Generating Mandelbrot...\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $freq = $args{freq};
  my $iters = $args{maxiter} || $MAX_COLOR;

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

  my $scale = $args{zoom} || 5120 + rand(128);

  $freq *= 2;

  my $grid = grid( %args, len => $freq );

  for ( my $x = 0 ; $x < $freq ; $x += 1 ) {
    my $cx = ( $x / $freq ) * 2 - 1;
    $cx += $tuple->[0] * $scale;
    $cx /= $scale;

    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $freq ; $y += 1 ) {
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

      my $color = $MAX_COLOR - ( ( $n / ( $iters - 1 ) ) * $MAX_COLOR );

      # $color = 0 if $color >= $MAX_COLOR;

      $column->set( $y, $color );
    }

    printRow($column);
  }

  $grid = shrink( $grid, %args );

  $grid = grow( $grid, %args );

  return tile($grid,%args);
}

sub buddha {
  my %args = @_;

  print "Generating Buddhabrot (this will take a while)...\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
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

        $grid->[$thisY]->set( $thisX, $grid->[$thisY]->get($thisX) + 25 );
        $grid->[ $freq - 1 - $thisY ]
          ->set( $thisX, $grid->[ $freq - 1 - $thisY ]->get($thisX) + 25 );
      }
    }
    printRow( $grid->[$x] );
  }

  $grid = densemap( $grid );

  $grid = grow( $grid, %args );

  return $grid;
}

# Re-maps pixel values along the north and south edges of the source
# image using polar coordinates, slowly blending back into original
# pixel values towards the middle.
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
    my $column = $COLUMN_CLASS->new($len);

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my ( $cartX, $cartY, $cartZ ) = cartCoords( $x, $y, $len, $scale );

      ### North Pole
      $column->set( $y / 2,
        noise( $grid, $xOffset + ( ( $srclen - $cartX ) / 2 ), $cartY / 2 ) );

      ### South Pole
      $column->set(
        $len - 1 - ( $y / 2 ),
        noise(
          $grid,
          $xOffset + ( $cartX / 2 ),
          ( $offset * $scale ) + ( $cartY / 2 )
        )
      );
    }

    $out->[$x] = $column;
  }

  $grid = grow( $grid, %args, len => $len * 2 );

  #
  # Equator (cover up the unsightly seam left by the above pass)
  #
  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $out->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $diff = abs( $offset - $y );
      my $pct  = ( $diff / $offset );

      my $srcY = $scale * $y * 2;
      $srcY += ( $offset / 2 ) * $scale;

      my $source = noise( $grid, $scale * $x * 2, $srcY / 2 );

      my $target = $column->get($y) || 0;

      $column->set( $y, interp( $source, $target, $pct ) );
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

  $x = ( $x * $scale ) % $thisLen;
  $y = ( $y * $scale ) % $thisLen;

  my $theta = deg2rad( ( $x / $thisLen ) * 360 );
  my $phi   = deg2rad( ( $y / $thisLen ) * 90 );

  my ( $cartX, $cartY, $cartZ ) =
    spherical_to_cartesian( $DEFAULT_RHO, $theta, $phi );

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

  my $xlen = scalar @$grid;
  my $ylen = $grid->[0]->len();

  my $out = Imager->new(
    xsize => $xlen,
    ysize => $ylen,
  );

  for ( my $x = 0 ; $x < $xlen ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $ylen ; $y++ ) {
      my $gray = $column->get($y);

      my $srcY = $y / $ylen;

      $out->setpixel(
        x     => $x,
        y     => $y,
        color => $palette->getpixel(
          x =>
            clamp( ( $gray / $MAX_COLOR ) * ( $srcWidth - 1 ), $srcWidth - 1 ),
          y => clamp( $srcY * ( $srcHeight - 1 ), $srcHeight - 1 ),
        )
      );
    }
  }

  return $out;
}

##
## Look up color values from bottom left corner to top right corner
##
sub hypoclut {
  my $grid = shift;
  my %args = @_;

  print "Applying corner-to-corner CLUT...\n" if !$QUIET;

  my $palette = Imager->new;
  $palette->read( file => $args{clut} ) || die $palette->errstr;

  my $srcHeight = $palette->getheight();
  my $srcWidth  = $palette->getwidth();

  my $xlen = scalar @$grid;
  my $ylen = $grid->[0]->len();

  my $out = Imager->new(
    xsize => $xlen,
    ysize => $ylen,
  );

  for ( my $x = 0 ; $x < $xlen ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $ylen ; $y++ ) {
      my $gray = $column->get($y);

      my $color = $palette->getpixel(
        x => ( clamp($gray) / $MAX_COLOR * ( $srcWidth - 1 ) ),
        y => $srcHeight - 1 - ( clamp($gray) / $MAX_COLOR * ( $srcHeight - 1 ) ),
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

sub spirals {
  my %args = @_;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  my $voronoi = $args{voronoi};

  %args = defaultArgs(%args);

  my $len = $args{freq};

  my $grid = grid( %args, len => $len, bias => 0 );

  my $half   = $len / 2;
  my $radius = $half;
  my $rand   = sub { ( rand() >= .5 ) ? 1 : -1 };

  $args{amp} = $DEFAULT_AMP if !defined $args{amp};

  my $bias = $args{bias} * $MAX_COLOR;
  my $amp  = $args{amp} * $MAX_COLOR;

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

        my $column = $grid->[$x];
        my $color = $MAX_COLOR - ( ( ( $i - 1 ) / ( $steps - 1 ) ) * $MAX_COLOR );

        if ( $column->get($y) < $color ) {
          $column->set( $y, $color );
        }
      }
    }

    $grid->[$centerX]->set( $centerY, $MAX_COLOR );
  }

  if ($voronoi) {
    $grid = densemap($grid);

    for ( my $x = 0 ; $x < $len ; $x++ ) {
      my $column = $grid->[$x];

      for ( my $y = 0 ; $y < $len ; $y++ ) {
        $column->set( $y,
          $MAX_COLOR - ( ( $column->get($y) / $MAX_COLOR ) * $MAX_COLOR ) );
      }
    }
  } else {
    $grid = glow( $grid, %args );
  }

  return grow( $grid, %args );
}

sub dla {
  my %args = @_;

  $args{bias} ||= $DEFAULT_BIAS;
  $args{amp}  ||= $DEFAULT_AMP;
  $args{len}  ||= $DEFAULT_LEN;
  $args{freq} ||= $DEFAULT_FREQ;

  %args = defaultArgs(%args);

  my $amp = $args{amp};
  my $len = $args{len};
  my $freq = $args{freq};

  my $grid;

  if ( $args{in} ) {
    $grid = infile( %args, len => $len );
  } else {
    $grid = grid( %args, bias => 0 );

    if ( $args{points} ) {
      for ( @{$args{points}} ) {
        $grid->[ $_->[0] % $len ]->set($_->[1] % $len, $amp);
      }
    } else {
      for ( my $i = 0 ; $i <= $freq; $i++ ) {
        $grid->[ rand($len) ]->set(rand($len), $amp);
      }
    }
  }

  my @points;

  my $branches = $len * $len / 4;

  for ( my $i = 0 ; $i < $branches ; $i++ ) {
    push @points, [ rand($len), rand($len) ];
  }

  my $prev = 0;

  my $buf = $|;
  $| = 1;

  while (@points) {
    my $color = ( @points / $branches ) * $MAX_COLOR;

    print scalar(@points) . " " if !$QUIET && ( $prev != @points );

    $prev = scalar(@points);

    my @newPoints;

    for ( my $i = 0 ; $i < @points ; $i++ ) {
      my $x = $points[$i]->[0] % $len;
      my $y = $points[$i]->[1] % $len;

      my $column = $grid->[$x];

      if ( ( $column->get($y) )
        || ( $grid->[ ( $x + 1 ) % $len ]->get($y) )
        || ( $grid->[ ( $x - 1 ) % $len ]->get($y) )
        || ( $column->get( ( $y + 1 ) % $len ) )
        || ( $column->get( ( $y - 1 ) % $len ) )
        || ( $grid->[ ( $x + 1 ) % $len ]->get( ( $y + 1 ) % $len ) )
        || ( $grid->[ ( $x + 1 ) % $len ]->get( ( $y - 1 ) % $len ) )
        || ( $grid->[ ( $x - 1 ) % $len ]->get( ( $y - 1 ) % $len ) )
        || ( $grid->[ ( $x - 1 ) % $len ]->get( ( $y + 1 ) % $len ) ) )
      {
        $column->set( $y, $color );
      } else {
        push @newPoints, [ $x, $y ];
      }
    }

    @points = @newPoints;

    last if !@points;

    for ( my $i = 0 ; $i < @points ; $i++ ) {
      my $x = $points[$i]->[0] % $len;
      my $y = $points[$i]->[1] % $len;

      my $offset = rand(6) - 3;
      $points[$i]->[0] = $x + $offset % $len;

      $offset = rand(6) - 3;
      $points[$i]->[1] = $y + $offset % $len;
    }
  }

  $| = $buf;

  return grow($grid, %args);
}


sub glow {
  my $grid = shift;
  my %args = @_;

  my $len = $args{len} || $DEFAULT_LEN;

  my $down = shrink($grid, len => $len/2);
  $down = smooth($down, len => $len/2);
  my $smoothed = grow($down, len => $len);

  for ( my $x = 0; $x < $len; $x++ ) {
    my $column         = $grid->[$x];
    my $smoothedColumn = $smoothed->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $smoothedColumn->set( $y, $smoothedColumn->get($y) + $column->get($y) );
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

  my $multires = multires( %args, amp => 1, bias => 0 );
  my $grid = grid(%args);

  my $len = $args{len} || $DEFAULT_LEN;

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

      my $multiresColumn = $multires->[$x];
      my $column         = $grid->[$x];

      my $heading = ( $multiresColumn->get($y) / $MAX_COLOR ) * 360;

      if ( $args{tesla} ) {
        ### kink it up
        $heading += ( $w / $numWorms ) * 45;
      }

      $column->set( $y,
        $column->get($y) + 1 -
          ( abs( $i - ( $threadLen / 2 ) ) / ( $threadLen / 2 ) ) );

      ( $x, $y ) = translate( $x, $y, $heading, 1 );
      $x = ( $x * 100 ) % ( $len * 100 );
      $y = ( $y * 100 ) % ( $len * 100 );
      $worm->[0] = $x / 100;
      $worm->[1] = $y / 100;

      $w++;
    }
  }

  $grid = densemap( $grid );

  if ( $args{tesla} ) {
    $grid = glow( $grid, %args );
  }

  return $grid;
}

sub emboss {
  my $grid = shift;
  my %args = @_;

  my $xlen = scalar @$grid;
  my $ylen = $grid->[0]->len();

  print "Generating light map\n" if !$QUIET;

  my $lightmap = [];

  my $angle = rand(360);

  for ( my $x = 0 ; $x < $xlen ; $x += 1 ) {
    $lightmap->[$x] = [];

    my $lightmapColumn = $COLUMN_CLASS->new($ylen);
    my $column         = $grid->[$x];

    for ( my $y = 0 ; $y < $ylen; $y += 1 ) {
      my $value;

      my ( $neighborX, $neighborY ) = translate( $x, $y, $angle, 1.5 );

      my $neighbor = noise( $grid, $neighborX, $neighborY );

      my $diff = $column->get($y) - $neighbor;

      $lightmapColumn->set( $y, $MAX_COLOR - $diff );
    }

    $lightmap->[$x] = $lightmapColumn;
  }

  return grow($lightmap,%args);
}

#
# Make a seamless tile from non-seamless input, such as an infile
#
sub tile {
  my $grid = shift;
  my %args = @_;

  my $dirs = defined $args{tile} ? $args{tile} : 1;
  return $grid if !$dirs;

  my $len = scalar( @{$grid} );

  my $out = grid( %args, len => $len );

  my $border = $len / 2;

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $outColumn = $out->[$x];
    my $column    = $grid->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $outColumn->set( $y, $column->get($y) );
    }
  }

  if ( $dirs == 1 || $dirs == 2 ) {
    for ( my $x = 0 ; $x < $len ; $x++ ) {
      my $outColumn = $out->[$x];

      for ( my $y = 0 ; $y < $len ; $y++ ) {
        my $thisX = ( $x - ( $len / 2 ) ) % $len;

        my $blend = 1;
        if ( $x < $border ) {
          $blend = 1 - ( ( $border - $x ) / $border );
        } elsif ( ( $len - $x ) < $border ) {
          $blend = ( $len - $x ) / $border;
        }

        $outColumn->set( $y,
          interp( $out->[$thisX]->get($y), $outColumn->get($y), $blend ) );
      }
    }

    for ( my $x = 0 ; $x < $len ; $x++ ) {
      my $outColumn = $grid->[$x];
      my $column    = $out->[$x];

      for ( my $y = 0 ; $y < $len ; $y++ ) {
        $outColumn->set( $y, $column->get($y) );
      }
    }
  }

  if ( $dirs == 1 || $dirs == 3 ) {
    for ( my $x = 0 ; $x < $len ; $x++ ) {
      my $outColumn = $out->[$x];

      for ( my $y = 0 ; $y < $len ; $y++ ) {
        my $thisX = $x;
        my $thisY = ( $y - ( $len / 2 ) ) % $len;

        my $blend = 1;
        if ( $y < $border ) {
          $blend = 1 - ( ( $border - $y ) / $border );
        } elsif ( ( $len - $y ) < $border ) {
          $blend = ( $len - $y ) / $border;
        }

        $outColumn->set( $y,
          interp( $out->[$thisX]->get($thisY), $outColumn->get($y), $blend ) );
      }
    }
  }

  return $out;
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

  $args{len} ||= $DEFAULT_LEN;
  my $len = $args{len};

  $args{freq} ||= 64;
  my $freq = $args{freq};

  %args = defaultArgs(%args);

  my $grid = grid( %args, len => $len );

  # Magic number is magic
  my $scale = ( .842 * ( $len / $freq ) ) / 4;

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $column->set( $y,
        sin( ( $x / $scale ) * ( $y / $scale ) / 180 * pi ) * $args{bias} );
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

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  my $stars = stars(%args);
  $stars = lsmooth( $stars, %args );

  my $stars0 = stars( %args, amp => .25 );

  %args = defaultArgs(%args);

  my $out = grid(%args);

  my $len = $args{len};

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $col0      = $stars0->[$x];
    my $col1      = $stars->[$x];
    my $outColumn = $out->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $cv = $col0->get($y);
      my $sv = $col1->get($y);

      $outColumn->set( $y, $sv + $cv );
    }
  }

  return glow( $out, %args );
}

sub delta {
  my $noise1 = shift;
  my $noise2 = shift;

  my %args = defaultArgs(@_);

  $noise1 = grow($noise1, %args);
  $noise2 = grow($noise2, %args);

  my $len  = $args{len};
  my $grid = grid(%args);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $grid->[$x];
    my $n1col  = $noise1->[$x];
    my $n2col  = $noise2->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $column->set( $y, abs( $n1col->get($y) - $n2col->get($y) ) );
    }
  }

  return $grid;
}

sub chiral {
  my $noise1 = shift;
  my $noise2 = shift;

  my %args = defaultArgs(@_);

  $noise1 = grow($noise1, %args);
  $noise2 = grow($noise2, %args);

  my $len  = $args{len};
  my $grid = grid(%args);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $grid->[$x];
    my $n1col  = $noise1->[$x];
    my $n2col  = $noise2->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      if ( $n1col->get($y) > $n2col->get($y) ) {
        $column->set( $y, $n1col->get($y) );
      } else {
        $column->set( $y, $n2col->get($y) );
      }
    }
  }

  return $grid;
}

sub add {
  my $noise1 = shift;
  my $noise2 = shift;

  my %args = defaultArgs(@_);

  $noise1 = grow($noise1, %args);
  $noise2 = grow($noise2, %args);

  my $len  = $args{len};
  my $grid = grid(%args);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $grid->[$x];
    my $n1col  = $noise1->[$x];
    my $n2col  = $noise2->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $column->set( $y, $n1col->get($y) + $n2col->get($y) );
    }
  }

  return $grid;
}

sub avg {
  my $noise1 = shift;
  my $noise2 = shift;

  my %args = defaultArgs(@_);

  $noise1 = grow($noise1, %args);
  $noise2 = grow($noise2, %args);

  my $len  = $args{len};
  my $grid = grid(%args);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $grid->[$x];
    my $n1col  = $noise1->[$x];
    my $n2col  = $noise2->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      $column->set( $y, lerp($n1col->get($y), $n2col->get($y), .5) );
    }
  }

  return $grid;
}

sub stereo {
  my $noise = shift;
  my %args  = @_;

  my $len = $args{len} || $DEFAULT_LEN;

  %args = defaultArgs(%args);

  my $map = densemap( $noise );
  my $out = grid(%args);

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $outcol  = $out->[ $x / 2 ];
    my $outcol2 = $out->[ ( $x + $len ) / 2 ];
    my $mapcol  = $map->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $offset = ( $mapcol->get($y) / $MAX_COLOR ) * 16;

      $outcol->set( $y,
        $outcol->get($y) + noise( $noise, $x - $offset, $y ) / 2 );
      $outcol2->set( $y,
        $outcol2->get($y) + noise( $noise, $x + $offset, $y ) / 2 );
    }
  }

  return $out;
}

#
# Julia distance
#
sub jdist {
  my $Zx       = shift;
  my $Zy       = shift;
  my $Cx       = shift;
  my $Cy       = shift;
  my $iter_max = shift;

  my $x   = $Zx;
  my $y   = $Zy;
  my $xp  = 1;
  my $yp  = 0;
  my $nz  = 0;
  my $nzp = 0;

  for ( my $i = 0 ; $i < $iter_max ; $i++ ) {
    $nz = 2 * ( $x * $xp - $y * $yp ) + 1;
    $yp = 2 * ( $x * $yp + $y * $xp );
    $xp = $nz;

    $nz = $x * $x - $y * $y + $Cx;
    $y  = 2 * $x * $y + $Cy;
    $x  = $nz;

    $nz  = $x * $x + $y * $y;
    $nzp = $xp * $xp + $yp * $yp;
    last if $nzp > 1e60;
  }

  my $a = sqrt($nz);

  return 2 * $a * log($a) / sqrt($nzp);
}

sub djulia {
  my %args = @_;

  my $xstart = rand(.05) - .05;
  my $ystart = rand(.05) - .05;

  my $flen = .0125 + rand(.0125);

  $args{maxiter} ||= 4096;

  return tile( julia(
    %args,
    ZxMin => $xstart,
    ZyMin => $ystart,
    ZxMax => $xstart + $flen,
    ZyMax => $ystart + $flen,
  ), %args );
}

sub julia {
  my %args = @_;

  local $COLUMN_CLASS = "Tie::CDoubleArray";

  print "Generating Julia...\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $len = $args{freq};

  my $grid = grid( %args, len => $len );

  my @c = (
    [ -.74543, .11301 ],

    # [ .285,  .01 ],
    # [ -.8,   .156 ],
  );

  my $c = $c[ rand(@c) ];

  my $Cx = $c->[0];
  my $Cy = $c->[1];

  # my $Cx = -0.74543;
  # my $Cy = 0.11301;

  my $iX = 0;
  my $iY = 0;

  my $ZxMin = $args{ZxMin};
  my $ZxMax = $args{ZxMax};
  my $ZyMin = $args{ZyMin};
  my $ZyMax = $args{ZyMax};

  $ZxMin = -2 if !defined $ZxMin;
  $ZxMax = 2  if !defined $ZxMax;
  $ZyMin = -2 if !defined $ZyMin;
  $ZyMax = 2  if !defined $ZyMax;

  # This is really low because this function is really slow
  my $iters = $args{maxiter} || ( $MAX_COLOR * .75 );

  # $len *= 2;

  my $pixelWidth  = ( $ZxMax - $ZxMin ) / $len;
  my $pixelHeight = ( $ZyMax - $ZyMin ) / $len;

  my $Zx  = 0;
  my $Zy  = 0;
  my $Z0x = 0;
  my $Z0y = 0;
  my $Zx2 = 0;
  my $Zy2 = 0;

  my $escapeRadius = 400;
  my $ER2          = $escapeRadius * $escapeRadius;

  my $distanceMax = $pixelWidth / 15;

  my $i;

  for ( $iY = 0 ; $iY < $len ; $iY++ ) {
    $Z0y = $ZyMax - $iY * $pixelHeight;
    if ( abs($Z0y) < $pixelHeight / 2 ) {
      $Z0y = 0;
    }
    for ( $iX = 0 ; $iX < $len ; $iX++ ) {
      $Z0x = $ZxMin + $iX * $pixelWidth;
      $Zx  = $Z0x;
      $Zy  = $Z0y;
      $Zx2 = $Zx * $Zx;
      $Zy2 = $Zy * $Zy;

      for ( $i = 1 ; $i <= $iters && ( $Zx2 + $Zy2 ) < $ER2 ; $i++ ) {
        $Zy  = 2 * $Zx * $Zy + $Cy;
        $Zx  = $Zx2 - $Zy2 + $Cx;
        $Zx2 = $Zx * $Zx;
        $Zy2 = $Zy * $Zy;
      }

      my $color;

      if ( $i == $iters ) {
        $color = 0;
      } else {
        my $distance = jdist( $Z0x, $Z0y, $Cx, $Cy, $iters );
        if ( $distance < $distanceMax ) {
          $color = $distanceMax - $distance;
        } else {
          $color = 0;
        }
      }

      my $column = $grid->[$iX];
      $column->set( $iY, $column->get($iY) + $color );
    }
  }

  $grid = densemap( $grid );

  return grow( $grid, %args );
}

my @roots = ( [ 1, 0 ], [ -.5, sqrt(3) / 2 ], [ -.5, sqrt(3) / 2 * -1 ], );

sub nclass {
  my $x       = shift;
  my $y       = shift;
  my $maxiter = shift;

  my $numRoots = scalar(@roots);

  my $z = cplx( $x, $y );

  my $prev = cplx( 0, 0 );

  my $t_numerator     = cplx( 0, 0 );
  my $t_denominator   = cplx( 0, 0 );
  my $t_rootDist      = cplx( 0, 0 );
  my $t_prevRrootDist = cplx( 0, 0 );

  my $dist;

  for ( my $i = 0 ; $i < $maxiter ; $i++ ) {
    for ( my $r = 0 ; $r < $numRoots ; $r++ ) {
      $t_rootDist->_set_cartesian( $roots[$r] );
      $t_rootDist -= $z;

      $dist = abs($t_rootDist);
      last if $dist == 0;

      if ( $dist <= .25 ) {
        $t_prevRrootDist->_set_cartesian( $roots[$r] );
        $t_rootDist -= $prev;

        my $lnPrevRrootDist = log( abs($t_prevRrootDist) );

        my $coded =
          ( log(.25) - $lnPrevRrootDist ) / ( log($dist) - $lnPrevRrootDist );

        $coded = $coded - int($coded);
        $coded = $r + $coded;

        # return $coded;
        return $i / $maxiter + $coded;
      }
    }

    if ( $z == $prev ) {
      return -1;
    }

    $t_numerator = $z;
    $t_numerator**= 3;
    $t_numerator *= 2;
    $t_numerator += 1;

    $t_denominator = $z;
    $t_denominator**= 2;
    $t_denominator *= 3;

    $prev = $z;

    $z = $t_numerator / $t_denominator;
  }

  return -1;
}

sub newton {
  my %args = @_;

  eval {
    use Math::Complex;
  };

  print "Generating Newton...\n" if !$QUIET;

  $args{len} ||= $DEFAULT_LEN;
  $args{freq} = $args{len} if !defined $args{freq};

  %args = defaultArgs(%args);

  my $len = $args{freq};

  my $ZxMin = $args{ZxMin};
  my $ZxMax = $args{ZxMax};
  my $ZyMin = $args{ZyMin};
  my $ZyMax = $args{ZyMax};

  $ZxMin = -2 if !defined $ZxMin;
  $ZxMax = 2  if !defined $ZxMax;
  $ZyMin = -2 if !defined $ZyMin;
  $ZyMax = 2  if !defined $ZyMax;

  my $iters = $args{maxiter} || 10;

  my $grid = grid( %args, len => $len );

  my $pixelWidth  = ( $ZxMax - $ZxMin ) / $len;
  my $pixelHeight = ( $ZyMax - $ZyMin ) / $len;

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $zx = $ZxMin + $x * $pixelWidth;

    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $zy = $ZyMin + $y * $pixelHeight;

      my $result = nclass( $zx, $zy, $iters );

      $column->set( $y, $result * $MAX_COLOR / 2 );
    }

    printRow( $grid->[$x] );
  }

  $grid = grow( $grid, %args );

  return $grid;
}

sub lumber {
  my %args = defaultArgs(@_);

  my $multires = multires( %args, octaves => 3, freq => 2, amp => 4 );
  my $grid = grid(%args);

  my $len = $args{len};

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column         = $grid->[$x];
    my $multiresColumn = $multires->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $gray = noise( $multires, $x, 0 ) / 4;

      $column->set( $y,
        ( noise( $multires, $gray, $y ) + $multiresColumn->get($y) )
          % $MAX_COLOR );
    }
  }

  return glow($grid, %args);
}

#
# I heartily endorse this event or product
#
sub wormhole {
  my %args = @_;

  $args{octaves} = 3 if !$args{octaves};
  $args{freq}    = 2 if !$args{freq};
  $args{amp}     = 4 if !$args{amp};

  %args = defaultArgs(%args);

  my $len  = $args{len} * 2;
  my $dist = sqrt($len);

  my $grid = grid( %args, bias => 0, len => $len );
  my $multires = multires( %args, len => $len );

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $amp = noise( $multires, $x, $y, $len ) / $MAX_COLOR;

      do {
        my ( $thisX, $thisY ) = translate( $x, $y, $amp * 360, $amp * $dist, );

        $grid->[ $thisX % $len ]->set( $thisY % $len, abs($amp) );
      };
    }
  }

  $grid = shrink( $grid, %args );

  $grid = glow( $grid, %args );

  $grid = densemap( $grid );

  return $grid;
}

sub flux {
  my %args = @_;

  $args{len}     = $DEFAULT_LEN if !$args{len};
  $args{octaves} = 3           if !$args{octaves};
  $args{freq}    = 2           if !$args{freq};

  my $len = $args{len} * 2;

  $args{amp} = sqrt($len) * 2 if !$args{amp};
  $args{bias} = 0 if !$args{bias};

  my $dist = sqrt($len);

  %args = defaultArgs(%args);

  my $grid = grid( %args, bias => 0, len => $len );

  my $multires = multires( %args, freq => 2, len => $len );

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $amp = noise( $multires, $x, $y, $len ) / $MAX_COLOR;

      do {
        my $xAngle = xAngle( $multires, $x, $y );
        my $yAngle = yAngle( $multires, $x, $y );

        my $angle = sqrt( ( $xAngle**2 ) + ( $yAngle**2 ) );

        my ( $thisX, $thisY ) =
          translate( $x, $y, $angle, ( $amp / $dist ) * $dist, );

        $thisX %= $len;
        $thisY %= $len;

        my $column = $grid->[$thisX];

        $column->set( $thisY, $column->get($thisY) + abs($amp) );
      };
    }
  }

  $grid = shrink( $grid, %args );

  $grid = glow( $grid, %args );

  $grid = densemap( $grid );

  for ( my $x = 0 ; $x < $len / 2 ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $len / 2 ; $y++ ) {
      $column->set( $y, $MAX_COLOR - $column->get($y) );
    }
  }

  return $grid;
}

sub xAngle {
  my $multires = shift;
  my $x        = shift;
  my $y        = shift;

  my $left  = noise( $multires, $x - 1, $y );
  my $this  = noise( $multires, $x,     $y );
  my $right = noise( $multires, $x + 1, $y );

  my $delta = ( $left - $right ) / $MAX_COLOR;

  return ( $delta * 360 );
}

sub yAngle {
  my $multires = shift;
  my $x        = shift;
  my $y        = shift;

  my $up   = noise( $multires, $x, $y - 1 );
  my $this = noise( $multires, $x, $y );
  my $down = noise( $multires, $x, $y + 1 );

  my $delta = ( $up - $down ) / $MAX_COLOR;

  return ( $delta * 360 );
}

sub canvas {
  my %args = defaultArgs(@_);

  my $square = square( %args, smooth => 0 );

  $square =
    lsmooth( $square, %args, dirs => 4, angle => 90, rad => $args{len} / 16 );

  return $square;
}

#
# Simplex gradient function
#
sub _sgrad {
  my $hash = shift;
  my $x    = shift;
  my $y    = shift;

  my $h = $hash & 7;

  my $u = $h < 4 ? $x : $y;
  my $v = $h < 4 ? $y : $x;

  return ( ( $h & 1 ) ? $u * -1 : $u ) + ( ( $h & 2 ) ? $v * -1 : $v );
}

my $F2 = 0.366025403;
my $G2 = 0.211324865;

#
# Simplex noise lookup
#
sub _snoise {
  my $x   = shift;
  my $y   = shift;
  my $len = shift || $DEFAULT_LEN;

  $x = ( ( $x * 1000 ) % ( $len * 1000 ) ) / 1000;
  $y = ( ( $y * 1000 ) % ( $len * 1000 ) ) / 1000;

  my ( $n0, $n1, $n2 );

  my $s  = ( $x + $y ) * $F2;
  my $xs = $x + $s;
  my $ys = $y + $s;

  my $i = abs( int($xs) );
  my $j = abs( int($ys) );

  my $t  = ( $i + $j ) * $G2;
  my $X0 = $i - $t;
  my $Y0 = $j - $t;
  my $x0 = $x - $X0;
  my $y0 = $y - $Y0;

  my ( $i1, $j1 );

  if   ( $x0 > $y0 ) { $i1 = 1; $j1 = 0; }
  else               { $i1 = 0; $j1 = 1; }

  my $x1 = $x0 - $i1 + $G2;
  my $y1 = $y0 - $j1 + $G2;
  my $x2 = $x0 - 1 + 2 * $G2;
  my $y2 = $y0 - 1 + 2 * $G2;

  my $ii = $i % 256;
  my $jj = $j % 256;

  my $t0 = .5 - $x0 * $x0 - $y0 * $y0;

  if ( $t0 < 0 ) { $n0 = 0; }
  else {
    $t0 *= $t0;
    $n0 = $t0 * $t0 * _sgrad( $NUMS[ ( $ii + $NUMS[$jj] ) % 256 ], $x0, $y0 );
  }

  my $t1 = .5 - $x1 * $x1 - $y1 * $y1;

  if ( $t1 < 0 ) { $n1 = 0; }
  else {
    $t1 *= $t1;
    $n1 =
      $t1 * $t1 *
      _sgrad( $NUMS[ ( $ii + $i1 + $NUMS[ ( $jj + $j1 ) % 256 ] ) % 256 ],
      $x1, $y1 );
  }

  my $t2 = .5 - $x2 * $x2 - $y2 * $y2;

  if ( $t2 < 0 ) { $n2 = 0; }
  else {
    $t2 *= $t2;
    $n2 =
      $t2 * $t2 *
      _sgrad( $NUMS[ ( $ii + 1 + $NUMS[ ( $jj + 1 ) % 256 ] ) % 256 ],
      $x2, $y2 );
  }

  return ( $n0 + $n1 + $n2 );
}

sub simplex {
  my %args = defaultArgs(@_);

  my $freq = $args{freq};
  my $len  = $args{len};
  my $amp  = $args{amp};

  my $grid = grid( %args, len => $len );

  for ( my $x = 0 ; $x < $len ; $x++ ) {
    my $column = $grid->[$x];

    for ( my $y = 0 ; $y < $len ; $y++ ) {
      my $thisX = ( $x / $len ) * $freq;
      my $thisY = ( $y / $len ) * $freq;

      $column->set( $y, _snoise( $thisX, $thisY, $len ) * $amp );
    }
  }

  return tile( $grid, %args );
}

sub simplex2 {
  my %args = defaultArgs(@_);

  my $grid = simplex( %args, len => $args{freq}, tile => 0 );

  return grow( $grid, %args );
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

our @chars = split( //, '     . .. .....:.::.:::::H:HH:HHHH#H##H#######');

sub printRow {
  return if $QUIET;

  my $row = shift;
  my $len = $row->len();

  my $rows = 80;
  for my $i ( 0 .. $rows - 1 ) {
    my $pct  = $i / $rows - 1;
    my $rowI = int( $pct * $len );
    my $val  = $row->get( $rowI % $len );

    my $valPct = clamp($val) / $MAX_COLOR;
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

  if ( $type eq 'terra' ) {
    printf( $fmtstr,
      "terra",      $args{lbase},   $args{ltype},
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

This document is for version 0.105 of Math::Fractal::Noisemaker.

=head1 SYNOPSIS

  use Math::Fractal::Noisemaker;

  Math::Fractal::Noisemaker::make();

See MAKE ARGS.

A command-line utility, C<make-noise>, is included with this distribution.
C<make-noise> is a complete wrapper to this module.

  make-noise -h
  make-noise -h types

=head1 DESCRIPTION

Math::Fractal::Noisemaker provides a simple functional interface
for generating several types of two-dimensional grayscale noise,
which may be combined in interesting and novel ways.

This module isn't fast, but it can output production-quality noise
for use in games or other media, and also serve as an educational
toy.


=head1 FUNCTION

=over 4


=item * make(%ARGS)

Generate a new noise set, and save the resulting image to disk.

Returns an L<Imager> instance containing final noise values, and
filename which was used.

All args are optional. This function accepts many arguments; see
MAKE ARGS, in this document.

  make();

  # my ($img, $filename) = make(
    #
    # Any MAKE ARGS or noise args here!
    #
  # );

Noisemaker's typical usage is via this function's command-line
wrapper, C<make-noise>.

  make-noise -h

  make-noise -type worley    # does make(type => "worley")

=back

=head1 NOISE TYPES

To specify a noise type, use the C<type> arg, for example:

  make-noise -type gradient

If generating multi-res noise, any single-res noise type may be
specified as the slice type (C<stype>), for example:

  make-noise -type ridged -stype gradient

=head2 SINGLE-RES NOISE

=over 4

=item * white

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/white.jpeg" width="256" height="256" alt="white noise example" /></p>

=end HTML

Each non-smoothed pixel contains a pseudo-random value.

See SINGLE-RES ARGS for allowed arguments.

  make(type => "white", ...);

  #
  # As a multi-res basis:
  #
  make(stype => "white", ...);


=item * wavelet

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/wavelet.jpeg" width="256" height="256" alt="wavelet noise example" /></p>

=end HTML

Basis function for sharper multi-res slices

See SINGLE-RES ARGS for allowed arguments.

  make(type => "wavelet", ...);

  #
  # As a multi-res basis:
  #
  make(stype => "wavelet", ...);


=item * gradient

Persistent gradient noise.

See SINGLE-RES ARGS for allowed arguments.

  make(type => "gradient", ...);

  #
  # As a multi-res basis:
  #
  make(stype => "gradient", ...);


=item * simplex

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/simplex.jpeg" width="256" height="256" alt="simplex noise example" /></p>

=end HTML

Another gradient noise function described by Ken Perlin. Not much
speed benefit in 2D, but it has a distinct flavor. I like it.

See C<tile> arg to control forced tiling mode.

  make(type => "simplex", ...);

  #
  # As a multi-res basis:
  #
  make(stype => "simplex", ...);


=item * simplex2

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/simplex2.jpeg" width="256" height="256" alt="simplex2 noise example" /></p>

=end HTML

Interpolated simplex noise which naturally tiles.

  make(type => "simplex2", ...);

  #
  # As a multi-res basis:
  #
  make(stype => "simplex2", ...);


=item * square

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/square.jpeg" width="256" height="256" alt="square noise example" /></p>

=end HTML

Diamond-Square

See SINGLE-RES ARGS for allowed arguments.

C<persist> arg is also permitted.

  make(type => "square", ...);


=item * gel

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/gel.jpeg" width="256" height="256" alt="gel noise example" /></p>

=end HTML

Self-displaced white noise.

See SINGLE-RES ARGS and GEL TYPE ARGS for allowed arguments.

  make(type => "gel", ...);

  #
  # This can be fun
  #
  make(stype => "gel", octaves => 3, ...);


=item * sgel

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/sgel.jpeg" width="256" height="256" alt="square gel noise example" /></p>

=end HTML

Self-displaced Diamond-Square noise.

See SINGLE-RES ARGS and GEL TYPE ARGS for allowed arguments.

C<persist> arg is also permitted.

  make(type => "sgel", ...);


=item * dla

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/dla.jpeg" width="256" height="256" alt="diffusion-limited aggregation noise example" /></p>

=end HTML

Diffusion-limited aggregation, seeded from multiple random points.

See SINGLE-RES ARGS for allowed arguments.

C<freq> arg determines number of seed points.

C<bias> and C<amp> currently have no effect.

  make(type => "dla", ...);


=item * mandel

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/mandel.jpeg" width="256" height="256" alt="mandelbrot fractal example" /></p>

=end HTML

Fractal type - Mandelbrot. Included as a demo.

See SINGLE-RES ARGS and FRACTAL ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect.

Example C<maxiter> value: 256

  make(type => "mandel", ...);


=item * dmandel

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/dmandel.jpeg" width="256" height="256" alt="deep mandelbrot fractal example" /></p>

=end HTML

Fractal type - Deep Mandelbrot. Picks a random "interesting" location
in the set (some point with a value which neither hovers near 0 nor
flies off into infinity), and zooms in a random amount (unless an
explicit C<zoom> arg was provided).

See SINGLE-RES ARGS and FRACTAL ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect.

Example C<maxiter> value: 256

  make(type => "dmandel", ...);


=item * buddha

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/buddha.jpeg" width="256" height="256" alt="buddhabrot fractal example" /></p>

=end HTML

Fractal type - "Buddhabrot" Mandelbrot variant. Shows the paths of
slowly escaping points, density-mapped to escape time.

See SINGLE-RES ARGS and FRACTAL ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect. This type does not
C<zoom> well, due to the diminished sample of escaping points.

Example C<maxiter> value: 4096

  make(type => "buddha", ...);


=item * julia

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/julia.jpeg" width="256" height="256" alt="julia fractal example" /></p>

=end HTML

Fractal type - Julia. Included as demo.

See SINGLE-RES ARGS and FRACTAL ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect.

C<zoom> is not yet implemented for this type.

Example C<maxiter> value: 200

  make(type => "julia", ...);


=item * djulia

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/djulia.jpeg" width="256" height="256" alt="deep julia fractal example" /></p>

=end HTML

Fractal type - Deep Julia. Zoomed in to a random location, which
might not even be in the Julia set at all. Not currently very smart,
but pretty, and pretty slow. C<maxiter> is very low by default.

See SINGLE-RES ARGS and FRACTAL ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect.

C<zoom> is not yet implemented for this type.

Example C<maxiter> value: 200

  make(type => "djulia", ...);


=item * newton

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/newton.jpeg" width="256" height="256" alt="newton fractal example" /></p>

=end HTML

Fractal type - Newton. Included as demo.

Currently, this function is ridiculously slow.

See SINGLE-RES ARGS and FRACTAL ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect.

C<zoom> is not yet implemented for this type.

Example C<maxiter> value: 10

  make(type => "newton", ...);


=item * fflame

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/fflame.jpeg" width="256" height="256" alt="ifs fractal flame example" /></p>

=end HTML

IFS type - "Fractal Flame". Slow but neat.

See SINGLE-RES ARGS and FRACTAL ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect.

Example C<maxiter> value: 6553600

  make(type => "fflame", ...);

=item * fern

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/fern.jpeg" width="256" height="256" alt="fern example" /></p>

=end HTML

IFS type - Barnsley's fern. Included as a demo.

  make(type => "fern", ...);


=item * gasket

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/gasket.jpeg" width="256" height="256" alt="gasket example" /></p>

=end HTML

IFS type - Sierpinski's triangle/gasket. Included as a demo.

  make(type => "gasket", ...);


=item * stars

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/stars.jpeg" width="256" height="256" alt="stars example" /></p>

=end HTML

White noise generated with extreme C<gap>, and smoothed

See SINGLE-RES ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect.

  make(type => "stars", ...);


=item * spirals

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/spirals.jpeg" width="256" height="256" alt="spirals example" /></p>

=end HTML

Tiny logarithmic spirals

See SINGLE-RES ARGS for allowed arguments.

C<bias> and C<amp> currently have no effect.

  make(type => "spirals", ...);


=item * moire

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/moire.jpeg" width="256" height="256" alt="moire example" /></p>

=end HTML

Interference pattern with blended image seams.

Appearance of output is heavily influenced by the C<freq> arg.

C<bias> and C<amp> currently have no effect.

  make(type => "moire", ...);


=item * textile

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/textile.jpeg" width="256" height="256" alt="textile example" /></p>

=end HTML

Moire noise with a randomized and large C<freq> arg.

C<bias> and C<amp> currently have no effect.

  make(type => "textile", ...);


=item * infile

Import the brightness values from the file specified by the "in"
or "-in" arg.

  make(type => "infile", in => "dirt.bmp", ...);

  #
  # also
  #
  my $grid = infile(in => "dirt.bmp", ...);


=item * sparkle

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/sparkle.jpeg" width="256" height="256" alt="sparkle example" /></p>

=end HTML

Stylized starfield

C<bias> and C<amp> currently have no effect.

  make(type => "sparkle", ...);


=item * canvas

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/canvas.jpeg" width="256" height="256" alt="canvas example" /></p>

=end HTML

Unsmoothed square noise with perpenticular linear blur

  make(type => "canvas", ...);


=item * worley

Voronoi cell noise.

Specify Nth closest neighbor with C<nth> arg, or will default to an
C<nth> of the C<freq>'s square root, which tends to produce a neat
3D-looking effect.

Specify an C<nth> of 0 for "traditional" voronoi cells.

Specify a C<cell> argument of "1" to use gray-mapped cells, rather
than distance gradient.

Specify C<dist> function as 0 (Euclidean), 1 (Manhattan), 2 (Chebyshev),
or 3 (Bendy?)

Specify C<tile> to override seam blending (see docs).

C<freq> arg determines number of seed points.

  make(type => "worley", nth => 1, dist => 3, ...);

  #
  # As a multi-res basis:
  #
  make(stype => "worley", nth => 0, octaves => 3);
  

=item * wgel

Self-displaced C<worley> noise. Quite bendy.

See SINGLE-RES ARGS and GEL TYPE ARGS for allowed arguments.

Also accepts "nth" and "dist" worley args.

  make(type => "wgel", ...);

  #
  # As a multi-res basis:
  #
  make(stype => "wgel", octaves => 3, ...);


=back


=head2 MULTI-RES TYPES

Multi-res noise combines the values from multiple 2D slices
(octaves), which are generated using progressively higher frequencies
and lower amplitudes.

The slice type used for generating multi-res noise may be controlled
with the C<stype> argument. Any single-res type may be specified.

The default slice type is smoothed C<white> noise.

=over 4


=item * multires

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/perlin-wavelet.jpeg" width="256" height="256" alt="multires example" /></p>

=end HTML

Multi-resolution noise.

See MULTI-RES ARGS for allowed args.

  make(type => 'multires', stype => '...');


=item * ridged

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/ridged-wavelet.jpeg" width="256" height="256" alt="ridged example" /></p>

=end HTML

Ridged multifractal.

See MULTI-RES ARGS for allowed args.

Provide C<zshift> arg to specify a post-processing bias.

  make(type => 'ridged', stype => '...', zshift => .5 );


=item * block

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/block-wavelet.jpeg" width="256" height="256" alt="block example" /></p>

=end HTML

Unsmoothed multi-resolution.

See MULTI-RES ARGS for allowed args.

  make(type => 'block', stype => ...);


=item * pgel

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/pgel-wavelet.jpeg" width="256" height="256" alt="multires gel example" /></p>

=end HTML

Self-displaced multi-res noise.

See MULTI-RES ARGS and GEL TYPE ARGS for allowed args.

  make(type => 'pgel', stype => ...);


=item * fur

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/fur-wavelet.jpeg" width="256" height="256" alt="fur example" /></p>

=end HTML

Traced "worm paths" from multi-res input.

See MULTI-RES ARGS for allowed args.


=item * tesla

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/tesla-wavelet.jpeg" width="256" height="256" alt="tesla example" /></p>

=end HTML

Long, fiberous worm paths with random skew.

See MULTI-RES ARGS for allowed args.


=item * lumber

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/lumber-wavelet.jpeg" width="256" height="256" alt="lumber example" /></p>

=end HTML

Noise with heavy forced banding.

See MULTI-RES ARGS for allowed args.


=item * wormhole

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/wormhole-wavelet.jpeg" width="256" height="256" alt="wormhole example" /></p>

=end HTML

Noise values displaced according to field flow rules, and plotted.

C<amp> controls displacement amount (eg 8).

See MULTI-RES ARGS for allowed args.


=item * flux

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/flux-wavelet.jpeg" width="256" height="256" alt="flux example" /></p>

=end HTML

Noise values extruded in three dimensions, and plotted.

C<amp> controls extrusion amount (eg 8).

See MULTI-RES ARGS for allowed args.

=back


=head2 BONUS NOISE

=over 4

=item * terra

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/terra.jpeg" width="256" height="256" alt="terra example" /></p>

=end HTML

Multi-layered complex noise. Very slow.

See TERRA ARGS for additional arguments.

Example:

  make(
    type   => "terra",
    lbase  => "multires",   # Layer base = continent shapes
    ltype  => "ridged",   # Layer type = elevation layers
    stype  => "simplex2", # Basis function is any simple type

    clut     => "color.bmp", # color lookup table
    clutdir  => 1,  # vertical "polar" lookup
    shadow   => .5, # false shadow
    grow     => 1,  # gaussian spread
    sphere   => 1,  # false spheremap

  );

=back


=head1 NOISE ARGS

=head2 MAKE ARGS

In addition to any argument appropriate to the type of noise being
generated, C<make> accepts the following args in hash key form:

=over 4


=item * type => $noiseType

The type of noise to generate, defaults to C<multires>. Specify any
type.

  make(type => 'gel');


=item * quality => 0|1|2|3

Sets levels for C<smooth>, C<interp>, and C<grow> in one swoop.
These may also be overridden individually, see docs.

  0: no smoothing, no interpolation, no growth (fastest)
  1: smoothing, linear interpolation, no growth
  2: smoothing, cosine interpolation, no growth
  3: smoothing, cosine interpolation, gaussian growth (slowest)

Add a "+" to the quality argument to disable upsampling. This will
render noise at the image's natural resolution, which is slower but
looks nicer, eg:

  make(quality => "2+");


=item * sphere => $bool

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/post/sphere.jpeg" width="256" height="256" alt="sphere example" /></p>

=end HTML

Generate a false spheremap from the resulting noise. This will output
as a 2:1 rectangular image. 

  make(sphere => 1);


=item * refract => $bool

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/post/refract.jpeg" width="256" height="256" alt="refract example" /></p>

=end HTML

"Refracted" pixel values. Can be used to enhance the fractal
appearance of the resulting noise. Often makes it look dirty.

  make(refract => 1);


=item * clut => $filename

Use an input image as a false color lookup table.

  make(clut => $filename);


=item * clutdir => <0|1|2>

Specify the "direction" of the color lookup table.

0: Corner-to-corner lookup. This is the default clut direction.

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/post/clutdir-0.jpeg" width="256" height="256" alt="clutdir 0 example" /></p>

=end HTML

CLUT arrangement guidance:

- Bottom left corner: Used for dark input values

- Top right corner: Used for bright input values

- Bottom right, top left corners are disregarded.

  make(clut => $filename, clutdir => 0); # mycolors.bmp

1: Vertical lookup. This lookup direction complements noise made
with the C<sphere> arg, and is intended for mapping to a spheroid.

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/post/clutdir-1.jpeg" width="256" height="256" alt="clutdir 1 example" /></p>

=end HTML

CLUT arrangement guidance:

- Left side: Used for dark input values

- Right side: Used for bright input values

- Up/Down: Corresponds to Y position of input values

Blurring the input image in your editing app of choice can reduce
visible banding in the output.

  make(clut => $filename, clutdir => 1, sphere => 1); # mycolors.bmp


2: "Fractal" lookup, uses the same methodology as C<refract>.

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/post/clutdir-2.jpeg" width="256" height="256" alt="clutdir 2 example" /></p>

=end HTML

  make(clut => $filename, clutdir => 2); # mycolors.bmp


=item * limit => <0|1>

0: Scale the pixel values of the noise set to image-friendly levels

1: Clamp pixel values outside of a representable range

  make(limit => 1);


=item * shadow => $float

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/post/shadow.jpeg" width="256" height="256" alt="shadow example" /></p>

=end HTML

Amount of false self-shadowing to apply, between 0 and 1.


=item * emboss => <0|1>

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/post/emboss.jpeg" width="256" height="256" alt="emboss example" /></p>

=end HTML

Render false lightmap only


=item * interp => <0|1>

Use linear (0) or cosine (1) interpolation.

Linear is faster, cosine looks nicer. Default is cosine (1)

  make(type => "gel", interp => 1);


=item * grow => <0|1>

B<This option may dramatically improve noise quality!>

Use interpolation (0) or gaussian neighborhoods (1) when upsampling
pixel grids. Gaussian (1) is best for avoiding directional artifacts,
but is substantially slower. Default is interpolation (0), which
will use the specified C<interp> function.

  make(type => "gel", grow => 1); # spendy goo


=item * delta => 1

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/delta-perlin-wavelet.jpeg" width="256" height="256" alt="delta example" /></p>

=end HTML

Output difference noise

  make(delta => 1);


=item * chiral => 1

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/chiral-perlin-wavelet.jpeg" width="256" height="256" alt="chiral example" /></p>

=end HTML

Output additive noise

  make(chiral => 1);


=item * stereo => 1

=begin HTML

<p><img src="http://github.com.nyud.net/aayars/noisemaker-ex/raw/master/ex/img/stereo-perlin-wavelet.jpeg" width="256" height="256" alt="stereo example" /></p>

=end HTML

Output stereo map

  make(stereo => 1);


=item * tile => <0|1|2|3>

Image seam linear blending mode. Naturally tiling noise types don't
need this argument. For false spheremap blending, see C<sphere>.

  0: no blending
  1: horizontal and vertical
  2: horizontal
  3: vertical

=item * xscale|yscale => $num

Stretch or shrink the final noise values, along either axis. This
does not alter the dimensions of the resulting image.

  make(xscale => .5, yscale => 2);

"Scale" in this context means input scaling. Numbers larger than 1
will shrink noise, repeating values along the specified axis.
Fractional numbers will stretch the noise, using the interpolation
function.

For naturally tiling noise types, providing a non-integer value
here will break tiling. Stick to multiples of 1 for best results.
Artifically tiled noise types do not require this workaround.


=item * quiet => <0|1>

Don't spam console

  make(quiet => 1);


=item * out => $filename

Output image filename. Defaults to the name of the noise type being
generated.

  make(out => "oot.bmp");

=back

=head2 SINGLE-RES ARGS

Single-res noise consumes the following arguments in hash key form:

=over 4


=item * amp => <0..1>

Amplitude, or max variance from the bias value.

For the purposes of this module, amplitude actually means semi-
amplitude (peak-to-peak amp/2).

  make(amp => 1);


=item * freq => $int

Frequency, or "density" of the noise produced.

For the purposes of this module, frequency represents the edge
length of the starting noise grid.

If the specified side length is a product of the noise's frequency,
this module will produce seamless tiles (with the exception of a
few noise types). For example, a base frequency of 4 works for an
image with a side length of 256 (256x256).

  make(freq => 8);


=item * len => $int

Specifies edge length of the output image, in pixels

  make(len => 512);


=item * bias => <0..1>

"Baseline" value for all pixels, .5 = 50%

  make(bias => .25);


=item * smooth => <0..1>

Enable/disable noise smoothing. 1 is default/recommended

  make(smooth => 0);


=item * gap => <0..1>

Increases the probability of black pixels in white noise.

  make(type => "stars", gap => .995);

=back


=head2 MULTI-RES ARGS

In addition to any of the args which may be used for single-res
noise types, Multi-res types consume the following arguments in
hash key form:

=over 4


=item * octaves => $int

e.g. 1..8

Octave (slice) count, increases the complexity of multi-res noise.

  my $blurry = make(octaves => 3);

  my $sharp = make(octaves => 8);


=item * persist => $num

Per-octave amplitude multiplicand (persistence). Traditional and
default value is .5

  my $grid => make(persist => .25);


=item * stype => $simpleType

Multi-res slice type, defaults to C<wavelet>. Any single-res type may be
specified.

  my $grid = make(stype => 'gel');

=back

=head2 GEL TYPE ARGS

The "gel" types (C<gel>, C<sgel>, C<pgel>, C<wgel>) accept the
following additional arguments:

=over 4


=item * displace => $float

Amount of self-displacement to apply to gel noise

  make(type => 'gel', displace => .125);

=back

=head2 FRACTAL ARGS

=over 4


=item * zoom => $num

Magnifaction factor.

  make(type => 'mandel', zoom => 2);


=item * maxiter => $int

Iteration limit for determining infinite boundaries, larger values
take longer but are more accurate/look nicer.

  make(type => 'mandel', maxiter => 2000);

=back


=head2 TERRA ARGS

In addition to all single-res and multi-res args, C<terra> noise consumes
the following args in hash key form:

=over 4

=item * feather => $num

e.g. 0..255

Amount of blending between elevation layers

  make(type => 'terra', feather => 50);

=item * layers => $int

Number of elevation layers to generate

  make(type => 'terra', layers => 4);

=item * lbase => $noiseType

Complex layer base - defaults to "multires". Any type except for
C<terra> may be used.

  make(type => 'terra', lbase => 'gel');

=item * ltype => $noiseType

Complex layer type - defaults to "multires". Any type
except for C<terra> may be used.

  make(type => 'terra', ltype => 'gel');

=back


=head1 BUGS AND LIMITATIONS

Noisemaker was written in Perl as an exploration of the included
algorithms, and is much slower than, say, something written in C
and optimized for speed.

This module only produces single-channel two-dimensional noise--
false colormaps don't count!

Image file types are limited to the types supported by L<Imager>
on your host.

Some noise algorithms might not be implemented "by the book".


=head1 SEE ALSO

L<Imager>, L<Math::Trig>, L<Tie::CArray>

Check out the examples set on Flickr:

L<http://www.flickr.com/photos/aayars/sets/72157622726199318/>

Math::Fractal::Noisemaker is on GitHub: L<http://github.com/aayars/noisemaker>

Inspiration and/or pseudocode borrowed from these notable sources:

=over 4


=item * L<http://freespace.virgin.net/hugo.elias/models/m_perlin.htm>

Hugo Elias's Perlin noise page provided pseudocode for smoothing
and interpolation functions.

Apparently, the above URL really explains something called "value
noise", which is not real Perlin noise. Noisemaker follows its
examples closely, regardless.


=item * L<http://gameprogrammer.com/fractal.html>

Generating Random Fractal Terrain by Paul Martz (Diamond-Square)


=item * L<http://graphics.pixar.com/library/WaveletNoise/paper.pdf>

Pixar - Wavelet noise


=item * L<http://www.complang.tuwien.ac.at/schani/mathmap/stills.html>

Moire recipe inspired by MathMap


=item * L<http://libnoise.sourceforge.net/>

Libnoise, by Jason Bevins, inspired the terrain recipe


=item * L<http://flam3.com/flame.pdf>

The Fractal Flame Algorithm by Scott Draves and Erik Reckase


=item * L<http://en.wikipedia.org/wiki/File:Demj.jpg>

Julia fractal functions ported from "Julia set using DEM/J" by Adam Majewski


=item * L<http://vlab.infotech.monash.edu.au/simulations/fractals/>

Newton functions ported from "Fractals on the Complex Plane", Monash University


=item * L<http://staffwww.itn.liu.se/~stegu/aqsis/aqsis-newnoise/>

Simplex functions ported from simplexnoise1234.cpp by Stefan Gustavson


=back


... and a host of others.

To learn more about the art of making noise, one might start here:

=over 4

=item * L<http://en.wikipedia.org/wiki/Perlin_noise>

=item * L<http://en.wikipedia.org/wiki/Procedural_texture>

=back


=head1 AUTHOR

  Alex Ayars <pause@nodekit.org>

=head1 COPYRIGHT

  File: Math/Fractal/Noisemaker.pm
 
  Copyright (C) 2009, 2010 Alex Ayars <pause@nodekit.org>

  This program is free software; you can redistribute it and/or modify
  it under the same terms as Perl 5.10.0 or later. See:
  http://dev.perl.org/licenses/

=cut
