#############################################################################
# (c) by Tels 2004 - 2005. Part of Graph::Easy
#
#############################################################################

package Graph::Easy::Edge::Cell;

use 5.006001;
use strict;
use Graph::Easy::Edge;
require Exporter;

use vars qw/$VERSION @EXPORT_OK @ISA/;
@ISA = qw/Exporter Graph::Easy::Edge/;

$VERSION = '0.08';

#############################################################################

# The different cell types:
sub EDGE_CROSS		() { 1; }		# +	crossing lines
sub EDGE_HOR		() { 2; }		# --	horizontal line
sub EDGE_VER		() { 3; }		# |	vertical line

sub EDGE_N_E		() { 4; }		# |_	corner (N to E)
sub EDGE_N_W		() { 5; }		# _|	corner (N to W)
sub EDGE_S_E		() { 6; }		# ,-	corner (S to E)
sub EDGE_S_W		() { 7; }		# -,	corner (S to W)

# Joints:
sub EDGE_S_E_W		() { 8; }		# -,-	three-sided corner (S to W/E)
sub EDGE_N_E_W		() { 9; }		# -'-	three-sided corner (N to W/E)
sub EDGE_E_N_S		() { 10; }		#  |-   three-sided corner (E to S/N)
sub EDGE_W_N_S		() { 11; }		# -|	three-sided corner (W to S/N)

sub EDGE_MAX_TYPE () { 11; }			# last valid type

# Flags:
sub EDGE_START_E	() { 0x0100; }		# start from East	(sorted ESWN)
sub EDGE_START_S	() { 0x0200; }		# start from South
sub EDGE_START_W	() { 0x0400; }		# start from West
sub EDGE_START_N	() { 0x0800; }		# start from North

sub EDGE_END_W		() { 0x0010; }		# end points to West	(sorted WNES)
sub EDGE_END_N		() { 0x0020; }		# end points to North
sub EDGE_END_E		() { 0x0040; }		# end points to East
sub EDGE_END_S		() { 0x0080; }		# end points to South

sub EDGE_LABEL_CELL	() { 0x1000; }		# this cell carries the label

sub EDGE_ARROW_MASK	() { 0x0FF0; }		# mask out the end/start type
sub EDGE_START_MASK	() { 0x0F00; }		# mask out the start type
sub EDGE_END_MASK	() { 0x00F0; }		# mask out the end type
sub EDGE_TYPE_MASK	() { 0x000F; }		# mask out the basic cell type
sub EDGE_FLAG_MASK	() { 0xFFF0; }		# mask out the flags
sub EDGE_MISC_MASK	() { 0xF000; }		# mask out the misc. flags

# shortcuts to not need to write EDGE_HOR + EDGE_START_W + EDGE_END_E
sub EDGE_SHORT_E	() { EDGE_HOR + EDGE_END_E + EDGE_START_W; }  # |-> start/end at this cell
sub EDGE_SHORT_S	() { EDGE_VER + EDGE_END_S + EDGE_START_N; }  # v   start/end at this cell
sub EDGE_SHORT_W	() { EDGE_HOR + EDGE_END_W + EDGE_START_E; }  # <-| start/end at this cell
sub EDGE_SHORT_N	() { EDGE_VER + EDGE_END_N + EDGE_START_S; }  # ^   start/end at this cell

sub EDGE_SHORT_EW	() { EDGE_HOR + EDGE_END_E + EDGE_END_W; }  # <-> start/end at this cell
sub EDGE_SHORT_NS	() { EDGE_VER + EDGE_END_S + EDGE_END_N; }  # ^
								    # | start/end at this cell
								    # v

#############################################################################

@EXPORT_OK = qw/
  EDGE_START_E
  EDGE_START_W
  EDGE_START_N
  EDGE_START_S

  EDGE_END_E
  EDGE_END_W	
  EDGE_END_N
  EDGE_END_S

  EDGE_SHORT_E
  EDGE_SHORT_W	
  EDGE_SHORT_N
  EDGE_SHORT_S

  EDGE_SHORT_EW
  EDGE_SHORT_NS

  EDGE_HOR
  EDGE_VER
  EDGE_CROSS

  EDGE_N_E
  EDGE_N_W
  EDGE_S_E
  EDGE_S_W

  EDGE_S_E_W
  EDGE_N_E_W
  EDGE_E_N_S
  EDGE_W_N_S	

  EDGE_TYPE_MASK
  EDGE_FLAG_MASK
  EDGE_ARROW_MASK
  
  EDGE_START_MASK
  EDGE_END_MASK
  EDGE_MISC_MASK

  EDGE_LABEL_CELL
  /;

my $edge_types = {
  EDGE_HOR() => 'horizontal',
  EDGE_VER() => 'vertical',

  EDGE_CROSS() => 'crossing',

  EDGE_N_E() => 'north/east corner',
  EDGE_N_W() => 'north/west corner',
  EDGE_S_E() => 'south/east corner',
  EDGE_S_W() => 'south/west corner',

  EDGE_S_E_W() => 'joint south to east/west',
  EDGE_N_E_W() => 'joint north to east/west',
  EDGE_E_N_S() => 'joint east to north/south',
  EDGE_W_N_S() => 'joint west to north/south',	

  };

my $flag_types = {
  EDGE_LABEL_CELL() => 'labeled',

  EDGE_START_E() => 'starting east',
  EDGE_START_W() => 'starting west',
  EDGE_START_N() => 'starting north',
  EDGE_START_S() => 'starting south',

  EDGE_END_E() => 'ending east',
  EDGE_END_W() => 'ending west',
  EDGE_END_N() => 'ending north',
  EDGE_END_S() => 'ending south',

  };

sub edge_type
  {
  # convert edge type number to some descriptive text
  my $type = shift;

  my $flags = $type & EDGE_FLAG_MASK;
  $type &= EDGE_TYPE_MASK;

  my $t = $edge_types->{$type} || ('unknown edge type #' . $type);

  $flags &= EDGE_FLAG_MASK;

  my $mask = 0x0010;
  while ($mask < 0xFFFF)
    {
    my $tf = $flags & $mask; $mask <<= 1;
    $t .= ", $flag_types->{$tf}" if $tf != 0;
    }
 
  $t;
  }

my $edge_styles = 
  {
  # style            hor, ver,   cross,	corner
  solid 	 => [ '--',  "|", '+', '+' ],	# simple line
  double	 => [ '==',  "H", "#", '#' ],	# double line
  'double-dash'	 => [ '= ',  '"', "#", '#' ],	# double dashed line
  dotted	 => [ '..',  ":", ':', '.' ],	# dotted
  dashed	 => [ '- ',  "'", '+', '+' ],	# dashed
  'dot-dash'	 => [ '.-',  "!", '+', '+' ],	# dot-dash
  'dot-dot-dash' => [ '..-', "!", '+', '+' ],	# dot-dot-dash
  'wave' 	 => [ '~~',  "}", '+', '*' ],	# wave
  'bold' 	 => [ '##',  "#", '#', '#' ],	# bold
  };

# for as_html
# XXX TODO: should really draw like as_ascii() (re-use this!)
my $edge_content = {
  # "^", "v", "--" and "|\n|" are replaced by the different styles from above

  EDGE_SHORT_E() => '------>',
  EDGE_SHORT_S() => "|\n|\nv",
  EDGE_SHORT_W() => '<------',
  EDGE_SHORT_N() => "^\n|\n|",

  EDGE_START_E() + EDGE_HOR() => '------',
  EDGE_START_S() + EDGE_VER() => "\n|\n|\n|\n|",
  EDGE_START_W() + EDGE_HOR() => '------',
  EDGE_START_N() + EDGE_VER() => "|\n|\n|\n|\n",

  EDGE_END_W() + EDGE_HOR() => '<------',
  EDGE_END_N() + EDGE_VER() => "^\n|\n|",
  EDGE_END_E() + EDGE_HOR() => '------>',
  EDGE_END_S() + EDGE_VER() => "|\n|\nv",

  EDGE_HOR() => '------',
  EDGE_VER() => "|\n|\n|\n|\n|",
  EDGE_CROSS() => "|\n--*--\n|",

  # XXX TODO
  # these with end/start points are missing here 
 
  EDGE_N_E() => "   |\n  *--",
  EDGE_N_W() => "   |\n--*",
  EDGE_S_E() => "\n  *--\n   |",
  EDGE_S_W() => "\n--*\n   |",

  EDGE_SHORT_EW() => "<----->",
  EDGE_SHORT_NS() => "^\n|\n|\nv",

  };

# for as_html
# the last entry is '*' and '', to replace the '*' with '+', because '*' ne ''
my @replace_qr = ( qr/\-\-/, qr/\|/, qr/>/, qr/</, qr/\^/, qr/v/, qr/\+/, qr/\*/, );
my @replace    = ( '--', '|', '>', '<', '^', 'v', '+', '' );

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{type} = EDGE_SHORT_E;		# -->
  $self->{style} = 'solid';
  
  $self->{x} = 0;
  $self->{y} = 0;
  $self->{w} = undef;
  $self->{h} = 3;

  # XXX TODO check arguments
  foreach my $k (keys %$args)
    {
    $self->{$k} = $args->{$k};
    }

  # XXX TODO: if no edge present, create one, then use edge
  # attributes directly instead of copying them, that saves
  # four hash entries per edge-cell!
 
  if (defined $self->{edge})
    {
    # register ourselves at this edge
    $self->{edge}->add_cell ($self);
    # take over settings from edge
    $self->{style} = $self->{edge}->{att}->{style};
    $self->{class} = $self->{edge}->{class};
    $self->{graph} = $self->{edge}->{graph};
    $self->{att} = $self->{edge}->{att};
    }
  else
    {
    require Carp;
    Carp::confess ("Creating edge cell without a parent edge object");
    } 
  $self->{error} = '';

  $self;
  }

sub _make_cross
  {
  # Upgrade us to a cross-section.
  my ($self, $edge) = @_;
  
  my $type = $self->{type};

  # return undef if (($type != EDGE_HOR) && ($type != EDGE_VER));

  $self->{style_ver} = $edge->{att}->{style};
  $self->{cross} = $edge;

  # if we are the VER piece, switch styles around
  ($self->{style_ver}, $self->{style}) = ($self->{style},$self->{style_ver})
    if $type == EDGE_VER;
 
  $edge->add_cell($self);

  $self->{type} = EDGE_CROSS;

  $self;
  }

#############################################################################
# conversion to ASCII or HTML

sub _content
  {
  # generate the content of the cell, aka the edge (like: '---', '-->' etc)
  my ($self) = @_;

  my $type = $self->{type} & ~EDGE_MISC_MASK;
  my $name = $edge_content->{$type};

  my $style = $edge_styles->{ $self->{style} };

  # XXX TODO: this code will not work in case it needs to replace two lines like:
  # dot-dot-dash:
  # |     |
  # | --> :

#  my $i = 0;
#  for my $repl (@$style)
#    {
#    my $q = $replace_qr[$i];
#    $name =~ s/$q/$repl/g if $replace[$i] ne $repl;
#    $i++;
#    }

  $name;
  }

sub _draw_hor
  {
  # draw a HOR edge piece
  my ($self, $fb) = @_;

  my $style = $edge_styles->{ $self->{style} };
  
  my $w = $self->{w};
  # '-' => '-----', '.-' => '.-.-.-'
  # "(2 + ... )" to get space for the offset
  my $len = length($style->[0]); 
  my $line = $style->[0] x (2 + $w / $len); 

  # '.-.-.-' => '-.-.-' if $x % $ofs == 1 (e.g. on odd positions)
  my $ofs = $self->{rx} % $len;
  my $type = ($self->{type} & (~EDGE_MISC_MASK));
  substr($line,0,$ofs) = '' if $ofs != 0
    && ($type != EDGE_SHORT_E && $type != EDGE_SHORT_W);

  $line = substr($line, 0, $w) if length($line) > $w;

  # handle start/end point

  my $flags = $self->{type} & EDGE_FLAG_MASK; my $x = 0;

  if (($flags & EDGE_START_W) != 0)
    {
    $x++; chop($line);			# ' ---'
    }
  if (($flags & EDGE_START_E) != 0)
    {
    chop($line);			# '--- '
    }
  if (($flags & EDGE_END_E) != 0)
    {
    chop($line);
    substr($line,-1,1) = '>';		# '--> '
    }
  if (($flags & EDGE_END_W) != 0)
    {
    substr($line,0,2) = ' <';		# ' <--'
    }

  $self->_printfb ($fb, $x, $self->{h} - 2, $line);

  if ($self->{type} & EDGE_LABEL_CELL)
    {
    # include our label
    my @pieces = $self->_formatted_label();
    $self->_printfb ($fb, 2, $self->{h} - 3, @pieces) if @pieces > 0;
    }

  }

sub _draw_ver
  {
  # draw a VER edge piece
  my ($self, $fb) = @_;

  my $style = $edge_styles->{ $self->{style} };
  
  my $h = $self->{h};
  # '|' => '|||||', '{}' => '{}{}{}'
  my $line = $style->[1] x (1 + $h / length($style->[1])); 
  $line = substr($line, 0, $h) if length($line) > $h;

  my $flags = $self->{type} & EDGE_FLAG_MASK;
  # XXX TODO: handle here start points
  # we get away with not handling them because in VER edges
  # starting points are currently invisible.

  substr($line,0,1) = '^' if (($flags & EDGE_END_N) != 0);
  substr($line,-1,1) = 'v' if (($flags & EDGE_END_S) != 0);

  my @pices = split //, $line;
  $self->_printfb ($fb, 2, 0, @pices);
  }

sub _draw_cross
  {
  # draw a CROSS sections
  my ($self, $fb) = @_;
  
  # vertical piece
  my $style = $edge_styles->{ $self->{style_ver} };
  
  my $h = $self->{h};
  # '|' => '|||||', '{}' => '{}{}{}'
  my $line = $style->[1] x (2 + $h / length($style->[1])); 
  $line = substr($line, 0, $h) if length($line) > $h;

  my @pices = split //, $line;
  $self->_printfb ($fb, 2, 0, @pices);

  # horizontal piece
  $style = $edge_styles->{ $self->{style} };
  
  my $w = $self->{w};
  # '-' => '-----', '.-' => '.-.-.-'
  my $len = length($style->[0]); 
  $line = $style->[0] x (2 + $w / $len); 
  
  # '.-.-.-' => '-.-.-' if $x % $ofs == 1 (e.g. on odd positions)
  my $ofs = $self->{rx} % $len;
  substr($line,0,$ofs) = '' if $ofs != 0;

  $line = substr($line, 0, $w) if length($line) > $w;
  
  my $y = $self->{h} - 2;

  $self->_printfb ($fb, 0, $y, $line);

  # the crossing character
  my $cross = $style->[2];
  $cross = '#' if $self->{style_ver} ne $self->{style};
 
  $self->_printfb ($fb, 2, $y, $cross);

  # done
  }

sub _draw_corner
  {
  # draw a corner (N_E, S_E etc)
  my ($self, $fb) = @_;

  my $type = $self->{type} & EDGE_TYPE_MASK;
  my $flags = $self->{type} & EDGE_FLAG_MASK;

  ############
  #   ........
  # 0 :      :
  # 1 :      :    label would appear here
  # 2 :  +---:    (w-3) = 3 chars wide
  # 3 :  |   :    always 1 char high
  #   .......:
  #    012345 

  # draw the vertical piece
 
  # get the style
  my $style = $edge_styles->{ $self->{style} };
 
  my $h = 1; my $y = $self->{h} -1; 
  if ($type == EDGE_N_E || $type == EDGE_N_W)
    {
    $h = $self->{h} - 2; $y = 0; 
    }
  # '|' => '|||||', '{}' => '{}{}{}'
  my $line = $style->[1] x (1 + $h / length($style->[1])); 
  $line = substr($line, 0, $h) if length($line) > $h;

  substr($line,0,1) = '^' if (($flags & EDGE_END_N) != 0);
  substr($line,-1,1) = 'v' if (($flags & EDGE_END_S) != 0);

  my @pieces = split //, $line;
  $self->_printfb ($fb, 2, $y, @pieces);

  # horizontal piece
  my $w = $self->{w} - 3; $y = $self->{h} - 2; my $x = 3;
  if ($type == EDGE_N_W || $type == EDGE_S_W)
    {
    $w = 2; $x = 0; 
    }

  # '-' => '-----', '.-' => '.-.-.-'
  my $len = length($style->[0]); 
  $line = $style->[0] x (2 + $w / $len); 
  
  # '.-.-.-' => '-.-.-' if $x % $ofs == 1 (e.g. on odd positions)
  my $ofs = ($x + $self->{rx}) % $len;
  substr($line,0,$ofs) = '' if $ofs != 0;

  $line = substr($line, 0, $w) if length($line) > $w;
  
  substr($line,-1,2) = '>' if (($flags & EDGE_END_E) != 0);
  substr($line,0,2) = ' <' if (($flags & EDGE_END_W) != 0);

  $self->_printfb ($fb, $x, $y, $line);

  # insert the corner character
  $self->_printfb ($fb, 2, $y, $style->[3]);

  # done
  }

sub _draw_label
  {
  # This routine is cunningly named _draw_label, because it actually
  # draws the edge line(s). The label text will be drawn by the individual
  # routines called below.
  my ($self, $fb, $x, $y) = @_;

  my $type = $self->{type} & EDGE_TYPE_MASK;

  # store the coordinates of our upper-left corner (for seamless rendering)
  $self->{rx} = $x || 0; $self->{ry} = $y || 0;

  $self->_draw_hor($fb) if $type == EDGE_HOR;
  $self->_draw_ver($fb) if $type == EDGE_VER;
  $self->_draw_cross($fb) if $type == EDGE_CROSS;
  $self->_draw_corner($fb) if 
     $type == EDGE_S_E || 
     $type == EDGE_S_W ||
     $type == EDGE_N_E ||
     $type == EDGE_N_W;

  delete $self->{rx}; delete $self->{ry};	# no longer needed

  # XXX TODO: joints (E to N/S etc)
  # $self->_printfb ($fb, 0,0, 'unsupported edge type ' . $type);
  }

sub as_html
  {
  my ($self) = shift;
  
  $self->{name} = $self->_content();

  my $id = $self->{graph}->{id};

  my $noquote = 0;
  my $label = $self->{att}->{label};
  $label = '' unless defined $label;

  $label =~ s/\\n/<br>/g;

  # XXX TODO: find out real size (aka length) of label

  my $style = $edge_styles->{ $self->{style} };

  # if we have a label, and are a EDGE_SHORT_E/EDGE_SHORT_W
  my $type = $self->{type};
  if ($label ne '')
    {
    if(($type == EDGE_SHORT_E) ||
       ($type == EDGE_SHORT_W))
      {
      my $left = '';
      my $right = '';
      $left = '&lt;' if $type == EDGE_SHORT_W;
      $right = '&gt;' if $type == EDGE_SHORT_E;
      # twice the length of the label is about right, due to 0.7 * 0.8
      # (letter-spacing * font-size) being about 1.8 plus some spacing left/right
      my $length = int(2 + 0.90 * length($label));
      
      $self->{name} = 
      "<span class='label'>$label</span><br>" .
      "<span class='line'>$left" . ($style->[0] x $length) . "$right</span>\n";
      $noquote = 1;
      $self->{class} = 'edgel';
      } 
    elsif (($type == EDGE_SHORT_N) ||
          ($type == EDGE_SHORT_S))
      {
      my $name = $self->{name}; 
      $name =~ s/&/&amp;/g;
      $name =~ s/</&lt;/g;
      $name =~ s/</&gt;/g;
      $name =~ s/\n/<br>/g;
 
      $self->{name} = 
      "$name<span class='labelv'>$label</span>\n";
      $noquote = 1;
      $self->{class} = 'edgev';
      }
    } # end of label handling code 

  # let Graph::Easy::Edge (aka Node) handle the output: 
  $self->SUPER::as_html($_[0], $_[1], $noquote);
  }

#############################################################################
# accessor methods

sub type
  {
  # get/set type of this path element
  # type - EDGE_START, EDGE_END, EDGE_HOR, EDGE_VER, etc
  my ($self,$type) = @_;

  if (defined $type)
    {
    if (defined $type && $type < 0 || $type > EDGE_MAX_TYPE)
      {
      require Carp;
      Carp::croak ("Cell type $type for cell $self->{x},$self->{y} is not valid.");
      }
    $self->{type} = $type;
    }

  $self->{type};
  }

#############################################################################

# For rendering this path element as ASCII, we need to correct our width based
# on whether we have a border or not. But this is only known after parsing is
# complete.

sub _correct_size
  {
  my ($self,$format) = @_;

  if (!defined $self->{w})
    {
    my $border = $self->{edge}->attribute('border-style') || 'none';

    # min-size is this 
    $self->{w} = 5; $self->{h} = 3;

    if ($self->{type} & EDGE_LABEL_CELL)
      {
      my @lines = $self->_formatted_label();

      # find longest line
      my $chars = 0;
      foreach my $line (@lines)
        {
        $chars = length($line) if length($line) > $chars;
        }
      $chars += 5;	# "   label  "
	                # "  ------->"
     
      my $h = scalar @lines;
      if ($border ne 'none')
        {
        $h += 2; $chars += 2;
        }
      $self->{w} = $chars if $chars > $self->{w};
      $self->{h} = $h if $h > $self->{h};
      }
    }
  }

#############################################################################
# attribute handling

sub attribute
  {
  my ($self, $atr) = @_;

  return $self->{att}->{$atr} if exists $self->{att}->{$atr};

  # if not set, path simple uses the attributes from the edge it belongs to
  $self->{edge}->attribute($atr);
  }

1;
__END__

=head1 NAME

Graph::Easy::Edge::Cell - A cell in an edge in Graph::Easy

=head1 SYNOPSIS

        use Graph::Easy;

	my $ssl = Graph::Easy::Edge->new(
		label => 'encrypted connection',
		style => 'solid',
		color => 'red',
	);
	my $src = Graph::Easy::Node->new( 'source' );
	my $dst = Graph::Easy::Node->new( 'destination' );

	$graph = Graph::Easy->new();

	$graph->add_edge($src, $dst, $ssl);

	print $graph->as_ascii();

=head1 DESCRIPTION

A C<Graph::Easy::Edge::Cell> represents an edge between two (or more) nodes
in a simple graph.

Each edge has a direction (from source to destination, or back and forth),
plus a style (line width and style), colors etc. It can also have a name,
e.g. a text label associated with it.

There should be no need to use this package directly.

=head1 METHODS

=head2 error()

	$last_error = $edge->error();

	$cvt->error($error);			# set new messags
	$cvt->error('');			# clear error

Returns the last error message, or '' for no error.

=head2 as_ascii()

	my $ascii = $path->as_ascii();

Returns the path-cell as a little ascii representation.

=head2 as_html()

	my $html = $path->as_html($tag,$id);

Returns the path-cell as HTML code.

=head2 label()

	my $label = $path->label();

Returns the name (also known as 'label') of the path-cell.

=head2 style()

	my $style = $edge->style();

Returns the style of the edge.

=head1 EXPORT

None by default. Can export the following on request:

  EDGE_START_E
  EDGE_START_W
  EDGE_START_N
  EDGE_START_S

  EDGE_END_E
  EDGE_END_W	
  EDGE_END_N
  EDGE_END_S

  EDGE_SHORT_E
  EDGE_SHORT_W	
  EDGE_SHORT_N
  EDGE_SHORT_S

  EDGE_SHORT_EW
  EDGE_SHORT_NS

  EDGE_HOR
  EDGE_VER
  EDGE_CROSS

  EDGE_N_E
  EDGE_N_W
  EDGE_S_E
  EDGE_S_W

  EDGE_S_E_W
  EDGE_N_E_W
  EDGE_E_N_S
  EDGE_W_N_S	

  EDGE_TYPE_MASK
  EDGE_FLAG_MASK
  EDGE_ARROW_MASK
  
  EDGE_START_MASK
  EDGE_END_MASK
  EDGE_MISC_MASK

=head1 TODO

=over 2

=item Different ASCII styles:

   ,-----, 	       +-----+
   | Foo | --,    vs.  | Foo |  --+
   |_____|   |         +-----+    |
	     |	                  |

=item Render the labels

=back

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
