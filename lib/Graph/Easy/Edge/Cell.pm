#############################################################################
# (c) by Tels 2004 - 2005. Part of Graph::Easy
#
#############################################################################

package Graph::Easy::Edge::Cell;

use strict;
use Graph::Easy::Edge;
require Exporter;

use vars qw/$VERSION @EXPORT_OK @ISA/;
@ISA = qw/Exporter Graph::Easy::Edge/;

$VERSION = '0.15';

use Scalar::Util qw/weaken/;

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

# these loop types must come last
sub EDGE_N_W_S		() { 12; }		# v--+  loop, northwards
sub EDGE_S_W_N		() { 13; }		# ^--+  loop, southwards
sub EDGE_E_S_W		() { 14; }		# [_    loop, westwards
sub EDGE_W_S_E		() { 15; }		# _]    loop, eastwards

sub EDGE_MAX_TYPE () { 15; }			# last valid type
sub EDGE_LOOP_TYPE () { 12; }			# first LOOP type

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
sub EDGE_NO_M_MASK	() { 0x0FFF; }		# anything except the misc. flags

# shortcuts to not need to write EDGE_HOR + EDGE_START_W + EDGE_END_E
sub EDGE_SHORT_E 	() { EDGE_HOR + EDGE_END_E + EDGE_START_W; }  # |-> start/end at this cell
sub EDGE_SHORT_S	() { EDGE_VER + EDGE_END_S + EDGE_START_N; }  # v   start/end at this cell
sub EDGE_SHORT_W	() { EDGE_HOR + EDGE_END_W + EDGE_START_E; }  # <-| start/end at this cell
sub EDGE_SHORT_N	() { EDGE_VER + EDGE_END_N + EDGE_START_S; }  # ^   start/end at this cell

sub EDGE_SHORT_BD_EW	() { EDGE_HOR + EDGE_END_E + EDGE_END_W; }  # <-> start/end at this cell
sub EDGE_SHORT_BD_NS	() { EDGE_VER + EDGE_END_S + EDGE_END_N; }  # ^
								    # | start/end at this cell
								    # v
	
sub EDGE_SHORT_UN_EW	() { EDGE_HOR + EDGE_START_E + EDGE_START_W; }  # --
sub EDGE_SHORT_UN_NS	() { EDGE_VER + EDGE_START_S + EDGE_START_N; }  # |

sub EDGE_LOOP_NORTH	() { EDGE_N_W_S + EDGE_END_S + EDGE_START_N + EDGE_LABEL_CELL; }
sub EDGE_LOOP_SOUTH	() { EDGE_S_W_N + EDGE_END_N + EDGE_START_S + EDGE_LABEL_CELL; }
sub EDGE_LOOP_WEST	() { EDGE_W_S_E + EDGE_END_E + EDGE_START_W + EDGE_LABEL_CELL; }
sub EDGE_LOOP_EAST	() { EDGE_E_S_W + EDGE_END_W + EDGE_START_E + EDGE_LABEL_CELL; }

sub ARROW_RIGHT () { 0; };
sub ARROW_LEFT () { 1; };
sub ARROW_UP () { 2; };
sub ARROW_DOWN () { 3; };

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

  EDGE_SHORT_BD_EW
  EDGE_SHORT_BD_NS

  EDGE_SHORT_UN_EW
  EDGE_SHORT_UN_NS

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

  EDGE_LOOP_NORTH
  EDGE_LOOP_SOUTH
  EDGE_LOOP_EAST
  EDGE_LOOP_WEST

  EDGE_N_W_S
  EDGE_S_W_N
  EDGE_E_S_W
  EDGE_W_S_E

  EDGE_TYPE_MASK
  EDGE_FLAG_MASK
  EDGE_ARROW_MASK
  
  EDGE_START_MASK
  EDGE_END_MASK
  EDGE_MISC_MASK

  EDGE_LABEL_CELL
  EDGE_NO_M_MASK

  ARROW_RIGHT
  ARROW_LEFT
  ARROW_UP
  ARROW_DOWN
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

  EDGE_N_W_S() => 'selfloop, northwards',
  EDGE_S_W_N() => 'selfloop, southwards',
  EDGE_E_S_W() => 'selfloop, eastwards',
  EDGE_W_S_E() => 'selfloop, westwards',
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

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{type} = EDGE_SHORT_E();	# -->
  $self->{style} = 'solid';
  
  $self->{x} = 0;
  $self->{y} = 0;
  $self->{w} = undef;
  $self->{h} = 3;

  # XXX TODO check arguments
  foreach my $k (keys %$args)
    {
    next unless $k =~ /^(graph|edge|x|y|type)\z/;
    $self->{$k} = $args->{$k};
    }

  if (defined $self->{edge})
    {
    # register ourselves at this edge
    $self->{edge}->add_cell ($self, $args->{after});
    # take over settings from edge
    $self->{style} = $self->{edge}->style();
    $self->{class} = $self->{edge}->{class};
    $self->{graph} = $self->{edge}->{graph};
    weaken($self->{graph});
    $self->{att} = $self->{edge}->{att};
    }
  else
    {
    require Carp;
    Carp::confess ("Creating edge cell without a parent edge object");
    } 

  $self;
  }

sub arrow_count
  {
  # return 0, 1 or 2, depending on the number of end points
  my $self = shift;

  my $count = 0;
  my $type = $self->{type};
  $count ++ if ($type & EDGE_END_N) != 0;
  $count ++ if ($type & EDGE_END_S) != 0;
  $count ++ if ($type & EDGE_END_W) != 0;
  $count ++ if ($type & EDGE_END_E) != 0;
  $count;
  }

sub _make_cross
  {
  # Upgrade us to a cross-section.
  my ($self, $edge, $flags) = @_;
  
  my $type = $self->{type} & EDGE_TYPE_MASK;
    
#  print STDERR "# edge ($edge->{id}: $edge->{from}->{name} to $edge->{to}->{name}) will cross\n";
#  my $e = $self->{edge};
#  print STDERR "# ($e->{id}: $e->{from}->{name} to $e->{to}->{name})\n";

  return undef if (($type != EDGE_HOR) && ($type != EDGE_VER));

  $self->{color} = $self->attribute('color');
  $self->{style_ver} = $edge->style();
  $self->{color_ver} = $edge->attribute('color');
  $self->{cross} = $edge;

  # if we are the VER piece, switch styles around

  if ($type == EDGE_VER)
    {
    ($self->{style_ver}, $self->{style}) = ($self->{style},$self->{style_ver});
    ($self->{color_ver}, $self->{color}) = ($self->{color},$self->{color});
    }

  $edge->add_cell($self);

  $self->{type} = EDGE_CROSS + ($flags || 0);

  $self;
  }

#############################################################################
# conversion to HTML

my $edge_html = {

  # The &nbsp; in empty table cells with borders are here to make IE display
  # the border. I so hate browser bugs :-(

  EDGE_S_E() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>',
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    '',
   ],

  EDGE_S_E() + EDGE_START_E() + EDGE_END_S() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td rowspan=4 class="##class## ve"></td>',
    '',
    ' <td colspan=2 class="##class## eb"></td>'. "\n" .
    ' <td class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=4 class="##class## v"##edgecolor##>&nbsp;v</td>',
   ],

  EDGE_S_E() + EDGE_START_E() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td rowspan=4 class="##class## ve"></td>',
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    '',
   ],

  EDGE_S_E() + EDGE_END_E() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td rowspan=4 class="##class## ha"##edgecolor##>&gt;</td>',
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>'. "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    '',
   ],

  EDGE_S_E() + EDGE_START_S() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>',
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>' . "\n",
    ' <td colspan=4 class="##class## eb"></td>',
   ],

  EDGE_S_E() + EDGE_START_S() + EDGE_END_E() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>'.
    ' <td rowspan=4 class="##class## ha"##edgecolor##>&gt;</td>',
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>'. "\n" .
    ' <td class="##class## eb" style="border-left: ##border##;">&nbsp;</td>' . "\n",
    ' <td colspan=1 class="##class## eb"></td>',
   ],

  EDGE_S_E() + EDGE_END_S() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>',
    '',
    ' <td colspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>' . "\n",
    ' <td colspan=4 class="##class## v"##edgecolor##>&nbsp;v</td>',
   ],

  EDGE_S_E() + EDGE_END_S() + EDGE_END_E() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td rowspan=4 class="##class## ha"##edgecolor##>&gt;</td>',
    '',
    ' <td colspan=2 class="##class## eb"></td>'. "\n" .
    ' <td class="##class## eb" style="border-left: ##border##;">&nbsp;</td>' . "\n",
    ' <td colspan=3 class="##class## v"##edgecolor##>&nbsp;v</td>',
   ],

  ###########################################################################
  ###########################################################################
  # S_W

  EDGE_S_W() => [
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    '',
   ],

  EDGE_S_W() + EDGE_START_W() => [
    ' <td rowspan=2 class="##class## ve"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    '',
   ],

  EDGE_S_W() + EDGE_END_W() => [
    ' <td rowspan=2 class="##class## va"##edgecolor##>&lt;</td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    '',
   ],

  EDGE_S_W() + EDGE_START_S() => [
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
    ' <td colspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=4 class="##class## eb"></td>',
   ],

  EDGE_S_W() + EDGE_END_S() => [
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
    ' <td colspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=4 class="##class## v"##edgecolor##>&nbsp;v</td>',
   ],

  EDGE_S_W() + EDGE_START_W() + EDGE_END_S() => [
    ' <td rowspan=2 class="##class## ve"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
    ' <td colspan=2 class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=4 class="##class## v"##edgecolor##>&nbsp;v</td>',
   ],

  EDGE_S_W() + EDGE_START_S() + EDGE_END_W() => [
    ' <td rowspan=3 class="##class## va"##edgecolor##>&lt;</td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
    ' <td class="##class## eb"></td>'. "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=4 class="##class## eb"></td>',
   ],

  ###########################################################################
  ###########################################################################
  # N_W

  EDGE_N_W() => [
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    '',
    ' <td colspan=4 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_W() + EDGE_START_N() => [
    ' <td colspan=4 class="##class## eb"></td>' . "\n",
    ' <td colspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=4 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_W() + EDGE_END_N() => [
    ' <td colspan=4 class="##class## hat"##edgecolor##>&nbsp;^</td>' . "\n",
    ' <td colspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=4 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_W() + EDGE_END_N() + EDGE_START_W() => [
    ' <td colspan=4 class="##class## hat"##edgecolor##>&nbsp;^</td>' . "\n",
    ' <td rowspan=3 class="##class## eb"></td>'.
    ' <td class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=4 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_W() + EDGE_START_W() => [
    ' <td rowspan=2 class="##class## ve"></td>' . "\n" . 
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>' . "\n",
    '',
    ' <td colspan=4 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_W() + EDGE_END_W() => [
    ' <td rowspan=2 class="##class## va"##edgecolor##>&lt;</td>' . "\n" . 
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##;">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-left: ##border##;">&nbsp;</td>' . "\n",
    '',
    ' <td colspan=4 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  ###########################################################################
  ###########################################################################
  # N_E

  EDGE_N_E() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb" style="border-bottom: ##border##; border-left: ##border##;">&nbsp;</td>',
    '',
    ' <td colspan=4 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_E() + EDGE_START_E() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##; border-left: ##border##;">&nbsp;</td>' . "\n" .
    ' <td rowspan=4 class="##class## ve"></td>',
    '',
    ' <td colspan=3 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_E() + EDGE_END_E() => [
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="border-bottom: ##border##; border-left: ##border##;">&nbsp;</td>' . "\n" .
    ' <td rowspan=4 class="##class## va"##edgecolor##>&gt;</td>',
    '',
    ' <td colspan=3 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_E() + EDGE_END_E() + EDGE_START_N() => [
    ' <td colspan=4 class="##class## eb"></td>' . "\n",
    ' <td colspan=2 class="##class## eb"></td>' . "\n" .
    ' <td class="##class## eb" style="border-bottom: ##border##; border-left: ##border##;">&nbsp;</td>' . "\n" .
    ' <td rowspan=3 class="##class## va"##edgecolor##>&gt;</td>',
    ' <td colspan=3 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_E() + EDGE_START_E() + EDGE_END_N() => [
    ' <td colspan=4 class="##class## hat"##edgecolor##>&nbsp;^</td>' . "\n",
    ' <td colspan=2 class="##class## eb"></td>' . "\n" .
    ' <td class="##class## eb" style="border-bottom: ##border##; border-left: ##border##;">&nbsp;</td>' . "\n" .
    ' <td rowspan=3 class="##class## eb">&nbsp;</td>',
    ' <td colspan=3 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_E() + EDGE_START_N() => [
    ' <td colspan=4 class="##class## eb"></td>' . "\n",
    ' <td colspan=2 rowspan=3 class="##class## eb"></td>' . "\n" .
    ' <td colspan=2 class="##class## eb" style="border-bottom: ##border##; border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  EDGE_N_E() + EDGE_END_N() => [
    ' <td colspan=4 class="##class## hat"##edgecolor##>&nbsp;^</td>' . "\n",
    ' <td colspan=2 rowspan=3 class="##class## eb"></td>' . "\n" .
    ' <td colspan=2 class="##class## eb" style="border-bottom: ##border##; border-left: ##border##;">&nbsp;</td>',
    ' <td colspan=2 rowspan=2 class="##class## eb"></td>',
    '',
   ],

  ###########################################################################
  ###########################################################################
  # self loops

  EDGE_LOOP_NORTH() - EDGE_LABEL_CELL() => [
    '<td rowspan=2 class="##class## eb" style="##bg##">&nbsp;</td>' . "\n".
    ' <td colspan=2 rowspan=2 class="##class## lh" style="border-bottom: ##border##;##lc####bg##">##label##</td>' . "\n" .
    ' <td rowspan=2 class="##class## eb" style="##bg##">&nbsp;</td>',
    '',
    '<td class="##class## eb" style="##bg##">&nbsp;</td>' . "\n".
    ' <td colspan=2 class="##class## eb" style="border-left: ##border##;##bg##">&nbsp;</td>'."\n".
    ' <td colspan=1 class="##class## eb" style="border-left: ##border##;##bg##">&nbsp;</td>',

    '<td colspan=2 class="##class## v" style="##bg##"##edgecolor##>&nbsp;v</td>' . "\n" .
    ' <td colspan=2 class="##class## eb" style="##bg##">&nbsp;</td>',

   ],

  EDGE_LOOP_SOUTH() - EDGE_LABEL_CELL() => [
    '<td colspan=2 class="##class## v" style="##bg##"##edgecolor##>&nbsp;^</td>' . "\n" . 
    ' <td colspan=2 class="##class## eb" style="##bg##">&nbsp;</td>',

    '<td rowspan=2 class="##class## eb" style="##bg##">&nbsp;</td>' . "\n".
    ' <td colspan=2 rowspan=2 class="##class## lh" style="border-left: ##border##; border-bottom: ##border##;##lc####bg##">##label##</td>'."\n".
    ' <td colspan=1 rowspan=2 class="##class## eb" style="border-left: ##border##;##bg##">&nbsp;</td>',

    '',

    '<td colspan=4 class="##class## eb" style="##bg##">&nbsp;</td>',

   ],

  EDGE_LOOP_WEST() - EDGE_LABEL_CELL() => [
    '<td rowspan=4 class="##class## eb" style="##bg##">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## lh" style="border-bottom: ##border##;##lc####bg##">##label##</td>'."\n".
    ' <td rowspan=2 class="##class## eb" style="##bg##">&nbsp;</td>',

    '',

    '<td colspan=2 class="##class## eb" style="border-left: ##border##; border-bottom: ##border##;##bg##">&nbsp;</td>' . "\n".
    ' <td rowspan=2 class="##class## va" style="##bg##"##edgecolor##>&gt;</td>',
    
    '<td colspan=2 class="##class## eb" style="##bg##">&nbsp;</td>',
   ],

  EDGE_LOOP_EAST() - EDGE_LABEL_CELL() => [

    '<td rowspan=2 class="##class## eb " style="##bg##">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## lh" style="border-bottom: ##border##;##lc####bg##">##label##</td>' ."\n".
    ' <td rowspan=2 class="##class## eb" style="##bg##>&nbsp;</td>',

    '',

    '<td rowspan=2 class="##class## va" style="##bg##"##edgecolor##>&lt;</td>' ."\n".
    ' <td colspan=2 class="##class## eb" style="border-bottom: ##border##;##bg##">&nbsp;</td>'."\n".
    ' <td class="##class## eb" style="border-left: ##border##;##bg##">&nbsp;</td>',
    
    '<td colspan=3 class="##class## eb" style="##bg##">&nbsp;</td>',
   ],

  };

sub _html_edge_hor
  {
  # Return HTML code for a horizontal edge (with all start/end combinations)
  # as [], with code for each table row.
  my ($self) = @_;

  my $s_flags = $self->{type} & EDGE_START_MASK;
  my $e_flags = $self->{type} & EDGE_END_MASK;

  my $rc = [
    ' <td colspan=##mod## rowspan=2 class="##class## lh" style="border-bottom: ##border##;##lc####bg##">##label##</td>' . "\n",
    '',
    '<td colspan=##mod## rowspan=2 class="##class## eb" style="##bg##">&nbsp;</td>' . "\n", 
    '',
    ];

  # The code below assumes that only 2 end/start flags are set at the same
  # time.

  my $mod = 4;							# modifier
  if ($s_flags & EDGE_START_W)
    {
    $mod--;
    $rc->[0] = '<td rowspan=4 class="##class## ve" style="##bg##"></td>' . "\n" . $rc->[0];
    };
  if ($s_flags & EDGE_START_E)
    {
    $mod--;
    $rc->[0] .= "\n " . '<td rowspan=4 class="##class## ve" style="##bg##"></td>';
    };
  if ($e_flags & EDGE_END_W)
    {
    $mod--;
    $rc->[0] = '<td rowspan=4 class="##class## va" style="##ec####bg##">&lt;</td>' . "\n" . $rc->[0];
    }
  if ($e_flags & EDGE_END_E)
    { 
    $mod--;
    $rc->[0] .= "\n " . '<td rowspan=4 class="##class## va" style="##ec####bg##">&gt;</td>';
    };

  for my $e (@$rc)
    {
    $e =~ s/##mod##/$mod/g;
    }

  $rc;
  }

sub _html_edge_ver
  {
  # Return HTML code for a vertical edge (with all start/end combinations)
  # as [], with code for each table row.
  my ($self) = @_;

  my $s_flags = $self->{type} & EDGE_START_MASK;
  my $e_flags = $self->{type} & EDGE_END_MASK;

  my $mod = 4; 							# modifier

  # normal vertical edge with no start/end flags
  my $rc = [
    '<td colspan=2 rowspan=##mod## class="##class## el" style="##bg##">&nbsp;</td>' . "\n " . 
    '<td colspan=2 rowspan=##mod## class="##class## lv" style="border-left: ##border##;##lc####bg##">##label##</td>' . "\n",
    '',
    '',
    '',
    ];

  # flag north
  if ($s_flags & EDGE_START_N)
    {
    $mod--;
    unshift @$rc, '<td colspan=4 class="##class## he" style="##bg##"></td>' . "\n";
    delete $rc->[-1];
    }
  elsif ($e_flags & EDGE_END_N)
    {
    $mod--;
    unshift @$rc, '<td colspan=4 class="##class## hat" style="##bg####ec##">&nbsp;^</td>' . "\n";
    delete $rc->[-1];
    }

  # flag south
  if ($s_flags & EDGE_START_S)
    {
    $mod--;
    $rc->[3] = '<td colspan=4 class="##class## he" style="##bg##"></td>' . "\n"
    }

  if ($e_flags & EDGE_END_S)
    {
    $mod--;
    $rc->[3] = '<td colspan=4 class="##class## v" style="##bg####ec##">&nbsp;v</td>' . "\n";
    }

  for my $e (@$rc)
    {
    $e =~ s/##mod##/$mod/g;
    }

  $rc;
  }

sub _html_edge_cross
  {
  # Return HTML code for a crossingedge (with all start/end combinations)
  # as [], with code for each table row.
  my ($self, $N, $S, $E, $W) = @_;

#  my $s_flags = $self->{type} & EDGE_START_MASK;
#  my $e_flags = $self->{type} & EDGE_END_MASK;

  my $rc = [
    ' <td colspan=2 rowspan=2 class="##class## eb el" style="border-bottom: ##border##">&nbsp;</td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb el" style="border-left: ##borderv##; border-bottom: ##border##">&nbsp;</td>' . "\n",
    '',
    ' <td colspan=2 rowspan=2 class="##class## eb el"></td>' . "\n" .
    ' <td colspan=2 rowspan=2 class="##class## eb el" style="border-left: ##borderv##">&nbsp;</td>' . "\n",
    '',
    ];

  $rc;
  }

sub as_html
  {
  my ($self) = shift;

  my $type = $self->{type} & EDGE_NO_M_MASK;
  my $style = $self->{style};

  my $code = $edge_html->{$type};

  if (!defined $code)
    {
    my $t = $self->{type} & EDGE_TYPE_MASK;

    $code = $self->_html_edge_hor() if $t == EDGE_HOR;
    $code = $self->_html_edge_ver() if $t == EDGE_VER;
    $code = $self->_html_edge_cross() if $t == EDGE_CROSS;

    if (!defined $code)
      {
      $code = [ ' <td colspan=4 rowspan=4 class="##class##">???</td>' ];
      warn ("as_html: Unimplemented edge type $self->{type} ($type) at $self->{x},$self->{y} " . edge_type($self->{type}));
      }
    }

  my $id = $self->{graph}->{id};

  my $color = $self->attribute('color') || '';
  my $label = '';
  my $label_style = '';

  # only include the label if we are the label cell
  if ($self->{type} & EDGE_LABEL_CELL)
    {
    $label = $self->label(); $label =~ s/\\n/<br \/>/g;

    my $label_color = $self->attribute('label-color') || $color;
    $label_color = '' if $label_color eq 'black';
    $label_style = "color: $label_color;" if $label_color;
  
    $label_style .= $self->text_styles_as_css() unless $label eq '';

    $label_style =~ s/^\s*//;

    my $link = $self->link();
    if ($link ne '')
      {
      # encode critical entities
      $link =~ s/\s/\+/g;			# space
      $link =~ s/'/%27/g;			# single-quote

      # put the style on the link
      $label_style = " style='$label_style'" if $label_style;
      $label = "<a class='l' href='$link'$label_style>$label</a>";
      $label_style = '';
      }

    }
  $label = '&nbsp;' unless $label ne '';

  ###########################################################################
  # get the border styles/colors:

  my $bow = $self->attribute('border-width'); $bow = 2 unless defined $bow;
  my $border = Graph::Easy::_border_attribute_as_html( $self->{style}, $bow, $color);

  my $border_v = $border;

  if (($self->{type} & EDGE_TYPE_MASK) == EDGE_CROSS)
   {
   $border_v = Graph::Easy::_border_attribute_as_html( $self->{style_ver}, $bow, $self->{color_ver});
   }

  ###########################################################################
  my $edge_color = ''; $edge_color = " color: $color;" if $color;
  
  my $bg = $self->background(); $bg = " background: $bg;" if $bg;

  my $title = $self->title();
  $title =~ s/"/&#22;/g;			# replace quotation marks
  $title = " title=\"$title\"" if $title ne '';	# add mouse-over title

  # XXX TODO: replace "&gt;" and "&lt;" with unicode arrow chars for
  # arrow-style: (filled|closed)

  ###########################################################################
  # replace templates

  my @rc;
  for my $a (@$code)
    {
    my $c = $a;					# make a copy
    # insert the title, label, class and border
    $c =~ s/>##label##/$title>$label/;
    my $cl = $self->class(); $cl =~ s/\./-/g;	# group.cities => group-cities
    $c =~ s/##class##/$cl/g;
    # replace borderv with the border for the vertical edge on CROSS sections
    $c =~ s/##border##/$border/g;
    $c =~ s/##borderv##/$border_v/g;
    $c =~ s/##lc##/$label_style/g;
    $c =~ s/##edgecolor##/ style="$edge_color"/g;
    $c =~ s/##ec##/$edge_color/g;
    $c =~ s/##bg##/$bg/g;
    $c =~ s/ style=""//g;		# remove empty styles
    $c .= "\n" unless $c =~ /\n\z/;
    push @rc, " " . $c;
    }
 
  \@rc;
  }

sub class
  {
  my $self = shift;

  my $c = $self->{class} . ($self->{cell_class} || '');
  $c = $self->{edge}->{group}->class() . ' ' . $c if ref($self->{edge}->{group});

  $c;
  }

sub group
  {
  # return the group we belong to as the group of our parent-edge
  my $self = shift;

  $self->{edge}->{group};
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
      Carp::confess ("Cell type $type for cell $self->{x},$self->{y} is not valid.");
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

  return if defined $self->{w};

  my $border = $self->{edge}->attribute('border-style') || 'none';

  # min-size is this 
  $self->{w} = 5; $self->{h} = 3;
    
  my $arrows = ($self->{type} & EDGE_ARROW_MASK);
  my $type = ($self->{type} & EDGE_TYPE_MASK);

  if ($self->{edge}->{bidirectional} && $arrows != 0)
    {
    $self->{w}++ if $type == EDGE_HOR;
    $self->{h}++ if $type == EDGE_VER;
    }

  my $style = $self->{edge}->attribute('style') || 'solid';

  # make the edge to display ' ..-> ' instead of ' ..> ':
  $self->{w}++ if $style eq 'dot-dot-dash';

  if ($type >= EDGE_LOOP_TYPE)
    {
    #  +---+ 
    #  |   V

    #       +
    #  +--> |
    #  |    |
    #  +--- |
    #       +
    $self->{w} = 7;
    $self->{w} = 8 if $type == EDGE_N_W_S || $type == EDGE_S_W_N;
    $self->{h} = 3;
    $self->{h} = 5 if $type != EDGE_N_W_S && $type != EDGE_S_W_N;
    }

  if ($self->{type} == EDGE_HOR)
    {
    $self->{w} = 0;
    }
  elsif ($self->{type} == EDGE_VER)
    {
    $self->{h} = 0;
    }
  elsif ($self->{type} & EDGE_LABEL_CELL)
    {
    my @lines = $self->_formatted_label();

    # find longest line
    my $chars = 0;
    foreach my $line (@lines)
      {
      $chars = length($line) if length($line) > $chars;
      }
    $chars += $self->{w};
     
    my $h = (scalar @lines - 1); $h = 0 if $h < 0;
    $h += $self->{h};
    if ($border ne 'none')
      {
      $h += 2; $chars += 2;
      }
    $self->{w} = $chars;
    $self->{h} = $h;
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

  EDGE_SHORT_BD_EW
  EDGE_SHORT_BD_NS

  EDGE_SHORT_UN_EW
  EDGE_SHORT_UN_NS

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

  EDGE_LOOP_NORTH
  EDGE_LOOP_SOUTH
  EDGE_LOOP_EAST
  EDGE_LOOP_WEST

  EDGE_N_W_S
  EDGE_S_W_N
  EDGE_E_S_W
  EDGE_W_S_E

  EDGE_TYPE_MASK
  EDGE_FLAG_MASK
  EDGE_ARROW_MASK
  
  EDGE_START_MASK
  EDGE_END_MASK
  EDGE_MISC_MASK

  ARROW_RIGHT
  ARROW_LEFT
  ARROW_UP
  ARROW_DOWN

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
