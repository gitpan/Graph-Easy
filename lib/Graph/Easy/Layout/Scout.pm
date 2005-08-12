#############################################################################
# Find paths from node to node in a Manhattan-style grid.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Layout::Scout;

use vars qw/$VERSION/;

$VERSION = '0.03';

#############################################################################
#############################################################################

package Graph::Easy;

use strict;
use Graph::Easy::Node::Cell;
use Graph::Easy::Edge::Cell qw/
  EDGE_SHORT_E EDGE_SHORT_W EDGE_SHORT_N EDGE_SHORT_S

  EDGE_START_E EDGE_START_W EDGE_START_N EDGE_START_S

  EDGE_END_E EDGE_END_W EDGE_END_N EDGE_END_S

  EDGE_N_E EDGE_N_W EDGE_S_E EDGE_S_W

  EDGE_HOR EDGE_VER

  EDGE_LABEL_CELL
  EDGE_TYPE_MASK
  EDGE_FLAG_MASK
 /;

# for A* pathfinding:
use Heap;
use Heap::Fibonacci;

#############################################################################

sub _find_path
  {
  # Try to find a path between two nodes. $options contains direction
  # preferences. Returns a list of cells like:
  # [ $x,$y,$type, $x1,$y1,$type1, ...]
  my ($self, $src, $dst, $options) = @_;

  # one node pointing back to itself?
  if ($src == $dst)
    {
    my $rc = $self->_find_path_loop($src,$options);
    return $rc unless scalar @$rc == 0;
    }

  # If one of the two nodes is bigger than 1 cell, use _find_path_astar(),
  # because it automatically handles all the possibilities:
  return $self->_find_path_astar($src, $dst, $options)
    if ($src->is_multicelled() || $dst->is_multicelled());
  
  my ($x0, $y0) = ($src->{x}, $src->{y});
  my ($x1, $y1) = ($dst->{x}, $dst->{y});
  my $dx = ($x1 - $x0) <=> 0;
  my $dy = ($y1 - $y0) <=> 0;
    
  my $cells = $self->{cells};
  my @coords;
  my ($x,$y) = ($x0,$y0);			# starting pos

  print STDERR "# dx,dy: $dx,$dy\n" if $self->{debug};

  if ($dx == 0 || $dy == 0)
    {
    # try straight path to target:
 
    print STDERR "# $src->{x},$src->{y} => $dst->{x},$dst->{y} - trying short path\n" if $self->{debug};

    # distance to node:
    my $dx1 = ($x1 - $x0);
    my $dy1 = ($y1 - $y0);
    ($x,$y) = ($x0+$dx,$y0+$dy);			# starting pos

    if ((abs($dx1) == 2) || (abs($dy1) == 2))
      {
      if (!exists ($cells->{"$x,$y"}))
        {
        # a single step for this edge:
        my $type;
        # short path
        $type = EDGE_SHORT_E if ($dx ==  1 && $dy ==  0);
        $type = EDGE_SHORT_S if ($dx ==  0 && $dy ==  1);
        $type = EDGE_SHORT_W if ($dx == -1 && $dy ==  0);
        $type = EDGE_SHORT_N if ($dx ==  0 && $dy == -1);
        $type += EDGE_LABEL_CELL;

        return [ $x, $y, $type ];			# return a short EDGE
        }
      }

    my $type = EDGE_HOR; $type = EDGE_VER if $dx == 0;	# - or |
    my $done = 0;
    my $label_done = 0;
    while (3 < 5)		# endless loop
      {
      # Since we do not handle crossings here, A* will be tried if we hit an
      # edge in this test.
      $done = 1, last if exists $cells->{"$x,$y"};	# cell already full

      # the first cell gets the label
      my $t = $type; $t += EDGE_LABEL_CELL if $label_done++ == 0;

      push @coords, $x, $y, $t;				# good one, is free
      $x += $dx; $y += $dy;				# next field
      last if ($x == $x1) && ($y == $y1);
      }

    # modify type of last cell to be endpoint

    return \@coords if $done == 0;			# return all fields of path
    } # end else straight path try

  # ($dx != 0 && $dy != 0) => path with one bend
  # XXX TODO:
  # This could be handled by A*, too, but it would be probably a bit slower.
  else
    {
    # straight path not possible, since x0 != x1 AND y0 != y1

    #           "  |"                        "|   "
    # try first "--+" (aka hor => ver), then "+---" (aka ver => hor)
    my $done = 0;

    print STDERR "# bend path from $x,$y\n" if $self->{debug};

    # try hor => ver
    my $type = EDGE_HOR;

    $x += $dx;
    while ($x != $x1)
      {
      $done++, last if exists $cells->{"$x,$y"};	# cell already full
      print STDERR "# at $x,$y\n" if $self->{debug};
      push @coords, $x, $y, $type;			# good one, is free
      $x += $dx;					# next field
      };

    if ($done == 0)
      {
      my $type_bend = _astar_edge_type ($x-$dx,$y, $x,$y, $x,$y+$dy);
 
      push @coords, $x, $y, $type_bend;			# put in bend
      print STDERR "# at $x,$y\n" if $self->{debug};
      $y += $dy;
      $type = EDGE_VER;
      while ($y != $y1)
        {
        $done++, last if exists $cells->{"$x,$y"};	# cell already full
	print STDERR "# at $x,$y\n" if $self->{debug};
        push @coords, $x, $y, $type;			# good one, is free
        $y += $dy;
        } 
      }

    if ($done != 0)
      {
      $done = 0;
      # try ver => hor
      print STDERR "# hm, now trying first vertical, then horizontal\n" if $self->{debug};
      $type = EDGE_VER;

      ($x,$y) = ($x0, $y0 + $dy);			# starting pos
      while ($y != $y1)
        {
        $done++, last if exists $cells->{"$x,$y"};	# cell already full
        print STDERR "# at $x,$y\n" if $self->{debug};
        push @coords, $x, $y, $type;			# good one, is free
        $y += $dy;					# next field
        };

      if ($done == 0)
        {
        my $type_bend = _astar_edge_type ($x,$y-$dy, $x,$y, $x+$dx,$y);

        push @coords, $x, $y, $type_bend;		# put in bend
        print STDERR "# at $x,$y\n" if $self->{debug};
        $x += $dx;
        $type = EDGE_HOR;
        while ($x != $x1)
          {
          $done++, last if exists $cells->{"$x,$y"};	# cell already full
	  print STDERR "# at $x,$y\n" if $self->{debug};
	  push @coords, $x, $y, $type;			# good one, is free
	  $x += $dx;
          } 
        }
      }

    # modify last field of path to be the correct endpoint and first field
    # to be the correct startpoint:
    if ($done == 0)
      {
      print STDERR "# success for ", scalar @coords, " steps in path\n" if $self->{debug};
      my $type_last = 0;
      $type_last = EDGE_END_E if $type == EDGE_HOR && $dx == 1;
      $type_last = EDGE_END_W if $type == EDGE_HOR && $dx == -1;
      $type_last = EDGE_END_S if $type == EDGE_VER && $dy == 1;
      $type_last = EDGE_END_N if $type == EDGE_VER && $dy == -1;
      $coords[-1] |= $type_last;
 
      $type = $coords[2];
      $type_last = 0;
      $type_last = EDGE_START_W if $type == EDGE_HOR && $dx == 1;
      $type_last = EDGE_START_E if $type == EDGE_HOR && $dx == -1;
      $type_last = EDGE_START_N if $type == EDGE_VER && $dy == 1;
      $type_last = EDGE_START_S if $type == EDGE_VER && $dy == -1;
      $coords[2] |= $type_last;
 
      return \@coords;			# return all fields of path
      }

    print STDERR "# no success\n" if $self->{debug};

    } # end path with $dx and $dy

  $self->_find_path_astar($src, $dst, $options);	# try generic approach as last hope
  }

sub _find_path_loop
  {
  # find a path from one node back to itself
  my ($self, $src, $options) = @_;

  print STDERR "# Finding looping path from $src->{name} to $src->{name}\n" if $self->{debug};

  # There are four possible path loops with 5 edge pieces:
  #  +- -- -+      +- -- -+
  #  |0  1 2|      |      |
  #
  #     4  3|      |   
  # [ ]<-- -+      +- -->[ ]

  # Likewise: 
  # [ ]<-+      +->[ ]
  #  |   |      |   |
  #  +---+      +---+

  # We define them here relative to (0,0):    
  my @loops = (
     [
       [ 0,-1, EDGE_S_E + EDGE_START_S],
       [ 1,-1, EDGE_HOR + EDGE_LABEL_CELL],
       [ 2,-1, EDGE_S_W],
       [ 2, 0, EDGE_N_W],
       [ 1, 0, EDGE_END_W + EDGE_HOR],
     ],
     [
       [ 0, 1, EDGE_N_W + EDGE_START_S],
       [-1, 1, EDGE_HOR + EDGE_LABEL_CELL],
       [-2, 1, EDGE_N_E],
       [-2, 0, EDGE_S_E],
       [-1, 0, EDGE_END_E + EDGE_HOR],
     ],
     [
       [ 0, 1, EDGE_N_E + EDGE_START_N ],
       [ 1, 1, EDGE_HOR + EDGE_LABEL_CELL],
       [ 2, 1, EDGE_N_W],
       [ 2, 0, EDGE_S_W],
       [ 1, 0, EDGE_END_W + EDGE_HOR],
     ],
     [
       [ 0,-1, EDGE_S_W + EDGE_START_N ],
       [-1,-1, EDGE_HOR + EDGE_LABEL_CELL],
       [-2,-1, EDGE_S_E],
       [-2, 0, EDGE_N_E],
       [-1, 0, EDGE_END_E + EDGE_HOR],
     ],
   );
  # where does the final edge point to?
  my @dx = ( -1, 1, -1, 1);

  my @rc; my $i = -1;
  foreach my $path (@loops)
    {
    $i++;
    my $x = $src->{x}; my $y = $src->{y};

    # clear list of cells we are going to return
    @rc = ();
    foreach my $elem (@$path)
      {
      my $xi = $x + $elem->[0];
      my $yi = $y + $elem->[1];

      push @rc, $xi, $yi, $elem->[2];
      }
    next unless $self->_path_is_clear(\@rc);
    print STDERR "# Found looping path $i\n" if $self->{debug};
    return \@rc;
    }

  [];		# no path found
  }

#############################################################################
#############################################################################

# This package represents one element in a Heap object:

package Graph::Easy::Astar::Node;

sub new
  {
  my $class = shift; $class = ref($class) || $class;

  # 0 for Heap, 1: value, 2,3 are x,y, 4,5 are parent's x,y, 6 is type
  bless [ undef, @_ ], $class;
  }

sub val
  {
  # get or set value slot
  my $self = shift;
  @_ ? ($self->[1] = shift) : $self->[1];
  }

sub heap
  {
  # get or set heap slot
  my $self = shift;
  @_ ? ($self->[0] = shift) : $self->[0];
  }

sub pos
  {
  # return the stored ptr
  my $self = shift;
  $self->[2], $self->[3];
  }

sub type
  {
  # return the stored type
  my $self = shift;
  $self->[6];
  }

sub parent
  {
  # return the stored parent pos
  my $self = shift;
  $self->[4], $self->[5];
  }

sub fields
  {
  my $self = shift;

  my @a = @$self;
  shift @a;			# throw away heap
  @a;
  }

sub cmp
  {
  # compare two elements
  $_[0]->[1] <=> $_[1]->[1];
  }

package Graph::Easy;

#############################################################################
#############################################################################

# Generic pathfinding via the A* algorithm:
# See http://bloodgate.com/perl/graph/astar.html for some background.

sub _astar_modifier
  {
  my ($x1,$y1,$x,$y,$px,$py, $cells) = @_;

  my $add = 1;

  my $xy = "$x1,$y1";
  # add a harsh penalty for crossing an edge
  # 50 means we could travel 50 fields to go around the crossing
  $add += 50 if ref($cells->{$xy}) =~ /^Graph::Easy::Edge/;
 
  if (defined $px)
    {
    # see whether the new position $x1,$y1 is a continuation from $px,$py => $x,$y
    # e.g. if from we go down from $px,$py to $x,$y, then anything else then $x,$y+1 will
    # get a penalty
    my $dx1 = ($px-$x) <=> 0;
    my $dy1 = ($py-$y) <=> 0;
    #print STDERR "# dx1 $dx1 dy1 $dy1 ";
    my $dx2 = ($x-$x1) <=> 0;
    my $dy2 = ($y-$y1) <=> 0;
    #print STDERR " dx2 $dx2 dy2 $dy2 ";
    $add += 1 unless $dx1 == $dx2 || $dy1 == $dy2;
    }
  $add;
  }

sub _astar_distance
  {
  my ($x1,$y1,$x2,$y2) = @_;

  my $dx = abs($x2 - $x1);
  my $dy = abs($y2 - $y1);

  # plus 1 because we need to go around one corner if $dx != $dy
  my $add = 1; $add = 0 if $dx == 0 || $dy == 0;

  $dx + $dy + $add; 
  }

my $edge_type = {
    '0,1,-1,0' => EDGE_N_W,
    '0,1,0,1' => EDGE_VER,
    '0,1,1,0' => EDGE_N_E,

    '-1,0,0,-1' => EDGE_N_E,
    '-1,0,-1,0' => EDGE_HOR,
    '-1,0,0,1' => EDGE_S_E,

    '0,-1,-1,0' => EDGE_S_W,
    '0,-1,0,-1' => EDGE_VER,
    '0,-1,1,0' => EDGE_S_E,

    '1,0,0,-1' => EDGE_N_W,
    '1,0,1,0' => EDGE_HOR,
    '1,0,0,1' => EDGE_S_W,
  };

sub _astar_edge_type
  {
  # from three consecutive positions calculate the edge type (VER, HOR, N_W etc)
  my ($x,$y, $x1,$y1, $x2, $y2) = @_;

  my $dx1 = ($x1 - $x) <=> 0;
  my $dy1 = ($y1 - $y) <=> 0;
  
  my $dx2 = ($x2 - $x1) <=> 0;
  my $dy2 = ($y2 - $y1) <=> 0;
  
  # return correct type depending on differences
  $edge_type->{"$dx1,$dy1,$dx2,$dy2"} || EDGE_HOR;
  }

sub _astar_near_nodes
  {
  # return possible next nodes from $x,$y
  my ($nx, $ny, $cells, $open, $closed) = @_;

  my @places = ();

  my @tries  = (	# ordered E,S,W,N:
    $nx + 1, $ny, 	# right
    $nx, $ny + 1,	# down
    $nx - 1, $ny,	# left
    $nx, $ny - 1,	# up
    );

  my $i = 0;
  while ($i < @tries)
    {
    my ($x,$y) = ($tries[$i], $tries[$i+1]);
    my $p = "$x,$y";

    if (ref($cells->{$p}) =~ /^Graph::Easy::Edge/)
      {
      # if the existing cell is an VER/HOR edge, then we may cross it
      my $type = $cells->{$p}->{type} & EDGE_TYPE_MASK;
      push @places, $x, $y if ($type == EDGE_HOR) || ($type == EDGE_VER);
      next;
      }
    next if exists $cells->{$p};	# uncrossable cell

    # XXX TODO:
    # If it is in open, but we reached it with a lower g(), then lower
    # the existing value.
    next if exists $closed->{$p};
    next if exists $open->{$p};
    push @places, $x, $y;

    } continue { $i += 2; }
 
  @places;
  }

sub _find_path_astar
  {
  my ($self,$src,$dst) = @_;

  my $cells = $self->{cells};

  my $open = Heap::Fibonacci->new();	# to find smallest elem fast
  my $open_by_pos = {};			# to find node by pos
  my $closed = {};			# a hash, indexed by "$x,$y" to find nodes by pos

  my $dx = $dst->{x}; my $dy = $dst->{y};
  
  print STDERR "# A* from $src->{x},$src->{y} to $dx,$dy\n" if $self->{debug};

  # get all the starting positions and add them to OPEN:
  # distance = 1: slots, generate starting types
  my @start = $src->_near_places($cells, 1, 'start');

  my $i = 0; my $bias = $self->{_astar_bias} || 0;
  while ($i < scalar @start)
    {
    my $sx = $start[$i]; my $sy = $start[$i+1]; my $type = $start[$i+2]; $i += 3;

    $open->add( Graph::Easy::Astar::Node->new(
      _astar_distance($sx,$sy, $dst->{x}, $dst->{y}),
      $sx, $sy, undef, undef, $type ));

    # The cost to reach the starting node is obviously 0. That means that there is
    # a tie between going down/up if both possibilities are equal likely. We insert
    # a small bias here that makes the prefered order east/south/west/north. Instead
    # the algorithmn exploring both way and terminating arbitrarily on the one that
    # first hits the target, it will explore only one.
    $open_by_pos->{"$sx,$sy"} = $bias; $bias += $self->{_astar_bias} || 0;
    }

  # potential stop positions
  my @stop = $dst->_near_places($cells, 1, 'stop');	# distance = 1: slots
  my $stop = scalar @stop;

  return unless $stop > 0;			# no free slots on target node?
 
  my $elem;
  # max. 10000 steps to prevent endless searching in case no path can be found
  my $tries = 0; my $max_tries = 10000;
  STEP:
  while( defined( $elem = $open->extract_top ) )
    {
    last STEP if $tries++ > $max_tries;
    #sleep(1);
    print STDERR "# Smallest elem is weight ", $elem->val, " at ", join(",", $elem->pos()),"\n" if $self->{debug};

    my ($val, $x,$y, $px,$py, $type) = $elem->fields();

    my $key = "$x,$y";
    # move node into CLOSE and remove from OPEN
    my $g = $open_by_pos->{$key} || 0;
    $closed->{$key} = [ $px, $py, $val - $g, $g, $type ];
    delete $open_by_pos->{$key};

    # Do not test for stop position(s) when we just did one step, otherwise
    # the algorithm terminates at the same field it started from. This happens
    # f.i. if you trace a self-loop ala ($src,$src,$edge).
   
#    if (defined $px)
      {
      # we are done when we hit one of the potential stop positions
      for (my $i = 0; $i < $stop; $i += 3)
        {
        # reached on stop position
        if ($x == $stop[$i] && $y == $stop[$i+1])
          {
          $closed->{$key}->[4] = $stop[$i+2];
          print STDERR "# Reached stop position $x,$y\n" if $self->{debug};
          last STEP;
          }
        }
      } # end test for stop postion(s)

    if (!defined $x || !defined $y)
      {
      require Carp;
      Carp::confess("On of '$x,$y' is not defined");
      }
    # get list of potential positions we need to explore from the current one
    my @p = _astar_near_nodes($x,$y, $cells, $open_by_pos, $closed);
    my $n = 0;
    while ($n < scalar @p)
      {
      my $nx = $p[$n]; my $ny = $p[$n+1]; $n += 2;

      if (!defined $nx || !defined $ny)
        {
        require Carp;
        Carp::confess("On of '$nx,$ny' is not defined");
        }
      my $lg = $g + _astar_modifier($nx,$ny,$x,$y,$px,$py,$cells);

      # calculate distance to each possible stop position, and
      # use the lowest one
      my $lowest_distance = _astar_distance($nx, $ny, $stop[0], $stop[1]);
      for (my $i = 3; $i < $stop; $i += 3)
        {
        my $d = _astar_distance($nx, $ny, $stop[$i], $stop[$i+1]);
        $lowest_distance = $d if $d < $lowest_distance; 
        }

      # open new position into OPEN
      $open->add( Graph::Easy::Astar::Node->new(
        $lowest_distance + $lg,
         $nx, $ny, $x, $y, undef ));
      $open_by_pos->{"$nx,$ny"} = $lg;
      }
    }

  # no more nodes to follow, so we couldn't find a path
  return [] unless defined $elem;

  my $path = [];
  my ($cx,$cy) = $elem->pos();
  my ($lx,$ly);
  my $type;

  my $label_cell = 0;		# found a cell to attach the label to?

  # follow $elem back to the source to find the path
  while (defined $cx)
    {
    last unless exists $closed->{"$cx,$cy"};

    $type = $closed->{"$cx,$cy"}->[ 4 ];

    my ($px,$py) = @{ $closed->{"$cx,$cy"} };	# get X,Y of parent cell

    my $edge_type = ($type||0) & EDGE_TYPE_MASK;
    if ($edge_type == 0)
      {
      my $edge_flags = ($type||0) & EDGE_FLAG_MASK;
      # either a start or a stop cell
      if (!defined $px)
        {
        # We can figure out from the flag of the position of cx,cy
        #         ................
        #         : EDGE_START_S :
        # .......................................
        # START_E :    px,py     : EDGE_START_W :
        # .......................................
        #         : EDGE_START_N :
        #         ................
        ($px,$py) = ($cx, $cy);		# start with same cell
        $py ++ if ($edge_flags & EDGE_START_S) != 0; 
        $py -- if ($edge_flags & EDGE_START_N) != 0; 

        $px ++ if ($edge_flags & EDGE_START_E) != 0; 
        $px -- if ($edge_flags & EDGE_START_W) != 0; 
        }
      if (!defined $lx)
        {
        # We can figure out from the flag of the position of cx,cy
        #       ..............
        #       : EDGE_END_S :
        # .................................
        # END_E :    lx,ly   : EDGE_END_W :
        # .................................
        #       : EDGE_END_N :
        #       ..............
        ($lx,$ly) = ($cx, $cy);		# start with same cell

        $ly ++ if ($edge_flags & EDGE_END_S) != 0; 
        $ly -- if ($edge_flags & EDGE_END_N) != 0; 

        $lx ++ if ($edge_flags & EDGE_END_E) != 0; 
        $lx -- if ($edge_flags & EDGE_END_W) != 0; 
        }
      # now figure out correct type for this cell from positions of
      # parent/following cell
      $type += _astar_edge_type($px, $py, $cx, $cy, $lx,$ly);
      }

    print STDERR "# Following back from $lx,$ly to $cx,$cy to $px,$py\n" if $self->{debug};

    if ($px == $lx && $py == $ly && ($cx != $lx || $cy != $ly))
      {
      print "Detected loop in path-backtracking at $px,$py, $cx,$cy, $lx,$ly\n";
      last;
      }

    $type = EDGE_HOR if ($type & EDGE_TYPE_MASK) == 0;		# last resort

    # if this is the first hor edge, attach the label to it
    # XXX TODO: This clearly is not optimal.
    $type += EDGE_LABEL_CELL if
     ($label_cell++ == 0) &&
     ($type & EDGE_TYPE_MASK) == EDGE_HOR;

    unshift @$path, $cx, $cy, $type;		# unshift to reverse the path
    ($lx,$ly) = ($cx,$cy);
    ($cx,$cy) = @{ $closed->{"$cx,$cy"} };	# get X,Y of parent cell
    }

  return ($path,$closed,$open_by_pos) if wantarray;
  $path;
  }

sub _map_as_html
  {
  my ($self, $cells, $p, $closed, $open, $w, $h) = @_;

  $w ||= 20;
  $h ||= 20;

  my $html = <<EOF
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
 <head>
 <style type="text/css">
 <!--
 td {
   background: #a0a0a0;
   border: #606060 solid 1px;
   font-size: 0.75em;
 }
 td.b, td.b, td.c {
   background: #404040;
   border: #606060 solid 1px;
   }
 td.c {
   background: #ffffff;
   }
 table.map {
   border-collapse: collapse;
   border: black solid 1px;
 }
 -->
 </style>
</head>
<body>

<h1>A* Map</h1>

<p>
Nodes examined: <b>##closed##</b> <br>
Nodes still to do (open): <b>##open##</b> <br>
Nodes in path: <b>##path##</b>
</p>
EOF
;

  $html =~ s/##closed##/keys %$closed /eg;
  $html =~ s/##open##/keys %$open /eg;
  my $path = {};
  while (@$p)
    {
    my $x = shift @$p;
    my $y = shift @$p;
    my $t = shift @$p;
    $path->{"$x,$y"} = undef;
    }
  $html =~ s/##path##/keys %$path /eg;
  $html .= '<table class="map">' . "\n";

  for my $y (0..$h)
    {
    $html .= " <tr>\n";
    for my $x (0..$w)
      {
      my $xy = "$x,$y";
      my $c = '&nbsp;' x 4;
      $html .= "  <td class='c'>$c</td>\n" and next if
        exists $cells->{$xy} and ref($cells->{$xy}) =~ /Node/;
      $html .= "  <td class='b'>$c</td>\n" and next if
        exists $cells->{$xy} && !exists $path->{$xy};

      $html .= "  <td>$c</td>\n" and next unless
        exists $closed->{$xy} ||
        exists $open->{$xy};

      my $clr = '#a0a0a0';
      if (exists $closed->{$xy})
        {
        $c =  ($closed->{$xy}->[3] || '0') . '+' . ($closed->{$xy}->[2] || '0');
        my $color = 0x10 + 8 * (($closed->{$xy}->[2] || 0));
        my $color2 = 0x10 + 8 * (($closed->{$xy}->[3] || 0));
        $clr = sprintf("%02x%02x",$color,$color2) . 'a0';
        }
      elsif (exists $open->{$xy})
        {
        $c = '&nbsp;' . $open->{$xy} || '0';
        my $color = 0xff - 8 * ($open->{$xy} || 0);
        $clr = 'a0' . sprintf("%02x",$color) . '00';
        }
      my $b = '';
      $b = 'border: 2px white solid;' if exists $path->{$xy};
      $html .= "  <td style='background: #$clr;$b'>$c</td>\n";
      }
    $html .= " </tr>\n";
    }
 
  $html .= "\n</table>\n";

  $html;
  }
 
1;
__END__
=head1 NAME

Graph::Easy::Layout::Scout - Find paths in a Manhattan-style grid

=head1 SYNOPSIS

	use Graph::Easy;
	
	my $graph = Graph::Easy->new();

	my $bonn = Graph::Easy::Node->new(
		name => 'Bonn',
	);
	my $berlin = Graph::Easy::Node->new(
		name => 'Berlin',
	);

	$graph->add_edge ($bonn, $berlin);

	$graph->layout();

	print $graph->as_ascii( );

	# prints:

	# +------+     +--------+
	# | Bonn | --> | Berlin |
	# +------+     +--------+

=head1 DESCRIPTION

C<Graph::Easy::Layout::Scout> contains just the actual pathfinding code for
L<Graph::Easy|Graph::Easy>. It should not be used directly.

=head1 EXPORT

Exports nothing.

=head1 METHODS

This package inserts a few methods into C<Graph::Easy> and
C<Graph::Easy::Node> to enable path-finding for graphs. It should not
be used directly.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for information.

=cut

