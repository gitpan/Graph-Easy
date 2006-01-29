#############################################################################
# Find paths from node to node in a Manhattan-style grid.
#
# (c) by Tels 2004-2006.
#############################################################################

package Graph::Easy::Layout::Scout;

$VERSION = '0.14';

#############################################################################
#############################################################################

package Graph::Easy;

use strict;
use Graph::Easy::Node::Cell;
use Graph::Easy::Edge::Cell qw/
  EDGE_SHORT_E EDGE_SHORT_W EDGE_SHORT_N EDGE_SHORT_S

  EDGE_SHORT_BD_EW EDGE_SHORT_BD_NS
  EDGE_SHORT_UN_EW EDGE_SHORT_UN_NS

  EDGE_START_E EDGE_START_W EDGE_START_N EDGE_START_S

  EDGE_END_E EDGE_END_W EDGE_END_N EDGE_END_S

  EDGE_N_E EDGE_N_W EDGE_S_E EDGE_S_W

  EDGE_N_W_S EDGE_S_W_N EDGE_E_S_W EDGE_W_S_E

  EDGE_LOOP_NORTH EDGE_LOOP_SOUTH EDGE_LOOP_WEST EDGE_LOOP_EAST

  EDGE_HOR EDGE_VER

  EDGE_S_E_W EDGE_N_E_W EDGE_E_N_S EDGE_W_N_S

  EDGE_LABEL_CELL
  EDGE_TYPE_MASK
  EDGE_ARROW_MASK
  EDGE_FLAG_MASK
  EDGE_START_MASK
  EDGE_END_MASK
  EDGE_NO_M_MASK
 /;

# for A* pathfinding:
use Heap::Binary;		# Binary is faster than Fibonacci

#############################################################################

# mapping edge type (HOR, VER, NW etc) and dx/dy to startpoint flag
my $start_points = {
#               [ dx == 1, 	dx == -1,     dy == 1,      dy == -1 ,
#                 dx == 1, 	dx == -1,     dy == 1,      dy == -1 ]
  EDGE_HOR() => [ EDGE_START_W, EDGE_START_E, 0,	    0 			,
		  EDGE_END_E,   EDGE_END_W,   0,	    0,			],
  EDGE_VER() => [ 0,		0, 	      EDGE_START_N, EDGE_START_S 	,
		  0,		0,	      EDGE_END_S,   EDGE_END_N,		],
  EDGE_N_E() => [ 0,		EDGE_START_E, EDGE_START_N, 0		 	,
		  EDGE_END_E,	0,	      0, 	    EDGE_END_N, 	],
  EDGE_N_W() => [ EDGE_START_W,	0, 	      EDGE_START_N, 0			,
		  0,	        EDGE_END_W,   0,	    EDGE_END_N,		],
  EDGE_S_E() => [ 0,		EDGE_START_E, 0,	    EDGE_START_S 	,
		  EDGE_END_E,   0,            EDGE_END_S,   0,			],
  EDGE_S_W() => [ EDGE_START_W,	0, 	      0,	    EDGE_START_S	,
		  0,		EDGE_END_W,   EDGE_END_S,   0,			],
  };

my $start_to_end = {
  EDGE_START_W() => EDGE_END_W(),
  EDGE_START_E() => EDGE_END_E(),
  EDGE_START_S() => EDGE_END_S(),
  EDGE_START_N() => EDGE_END_N(),
  };

sub _end_points
  {
  # modify last field of path to be the correct endpoint; and the first field
  # to be the correct startpoint:
  my ($self, $edge, $coords, $dx, $dy) = @_;
  
  return $coords if $edge->undirected();

  # there are two cases (for each dx and dy)
  my $i = 0;					# index 0,1
  my $co = 2;
  my $case;

  for my $d ($dx,$dy,$dx,$dy)
    {
    next if $d == 0;

    my $type = $coords->[$co] & EDGE_TYPE_MASK;

    $case = 0; $case = 1 if $d == -1;

    # modify first/last cell
    my $t = $start_points->{ $type }->[ $case + $i ];
    # on bidirectional edges, turn START_X into END_X
    $t = $start_to_end->{$t} || $t if $edge->{bidirectional};

    $coords->[$co] += $t;

    } continue {
    $i += 2; 					# index 2,3, 4,5 etc
    $co = -1 if $i == 4;			# modify now last cell
    }
  $coords;
  }

sub _find_path
  {
  # Try to find a path between two nodes. $options contains direction
  # preferences. Returns a list of cells like:
  # [ $x,$y,$type, $x1,$y1,$type1, ...]
  my ($self, $src, $dst, $edge) = @_;

  # one node pointing back to itself?
  if ($src == $dst)
    {
    my $rc = $self->_find_path_loop($src,$edge);
    return $rc unless scalar @$rc == 0;
    }

  # If one of the two nodes is bigger than 1 cell, use _find_path_astar(),
  # because it automatically handles all the possibilities:
  return $self->_find_path_astar($edge)
    if ($src->is_multicelled() || $dst->is_multicelled() || $edge->has_ports());
  
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
        my $type = EDGE_LABEL_CELL;
        # short path
        if ($edge->bidirectional())
	  {
          $type += EDGE_SHORT_BD_EW if $dy == 0;
          $type += EDGE_SHORT_BD_NS if $dx == 0;
          }
        elsif ($edge->undirected())
          {
          $type += EDGE_SHORT_UN_EW if $dy == 0;
          $type += EDGE_SHORT_UN_NS if $dx == 0;
          }
        else
          {
          $type += EDGE_SHORT_E if ($dx ==  1 && $dy ==  0);
          $type += EDGE_SHORT_S if ($dx ==  0 && $dy ==  1);
          $type += EDGE_SHORT_W if ($dx == -1 && $dy ==  0);
          $type += EDGE_SHORT_N if ($dx ==  0 && $dy == -1);
          }

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

    if ($done == 0)
      {
      print STDERR "# success for ", scalar @coords / 3, " steps in path\n" if $self->{debug};
      # return all fields of path
      return $self->_end_points($edge, \@coords, $dx, $dy);
      }

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

    my $label = 0;						# attach label?
    $label = 1 if ref($edge) && ($edge->label()||'') eq '';	# no label?
    $x += $dx;
    while ($x != $x1)
      {
      $done++, last if exists $cells->{"$x,$y"};	# cell already full
      print STDERR "# at $x,$y\n" if $self->{debug};
      my $t = $type; $t += EDGE_LABEL_CELL if $label++ == 0;
      push @coords, $x, $y, $t;				# good one, is free
      $x += $dx;					# next field
      };

    # check the bend itself     
    $done++ if exists $cells->{"$x,$y"};	# cell already full

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

      @coords = ();					# drop old version
      ($x,$y) = ($x0, $y0 + $dy);			# starting pos
      while ($y != $y1)
        {
        $done++, last if exists $cells->{"$x,$y"};	# cell already full
        print STDERR "# at $x,$y\n" if $self->{debug};
        push @coords, $x, $y, $type;			# good one, is free
        $y += $dy;					# next field
        };

      # check the bend itself     
      $done++ if exists $cells->{"$x,$y"};		# cell already full

      if ($done == 0)
        {
        my $type_bend = _astar_edge_type ($x,$y-$dy, $x,$y, $x+$dx,$y);

        push @coords, $x, $y, $type_bend;		# put in bend
        print STDERR "# at $x,$y\n" if $self->{debug};
        $x += $dx;
        my $label = 0;					# attach label?
        $label = 1 if $edge->label() eq '';		# no label?
        $type = EDGE_HOR;
        while ($x != $x1)
          {
          $done++, last if exists $cells->{"$x,$y"};	# cell already full
	  print STDERR "# at $x,$y\n" if $self->{debug};
          my $t = $type; $t += EDGE_LABEL_CELL if $label++ == 0;
          push @coords, $x, $y, $t;			# good one, is free
	  $x += $dx;
          } 
        }
      }

    if ($done == 0)
      {
      print STDERR "# success for ", scalar @coords / 3, " steps in path\n" if $self->{debug};
      # return all fields of path
      return $self->_end_points($edge, \@coords, $dx, $dy);
      }

    print STDERR "# no success\n" if $self->{debug};

    } # end path with $dx and $dy

  $self->_find_path_astar($edge);		# try generic approach as last hope
  }

sub _find_path_loop
  {
  # find a path from one node back to itself
  my ($self, $src, $edge) = @_;

  print STDERR "# Finding looping path from $src->{name} to $src->{name}\n" if $self->{debug};

  my ($n, $cells, $d, $type, $loose) = @_;

  # get a list of all places

  my @places = $src->_near_places( 
    $self->{cells}, 1, [
      EDGE_LOOP_EAST,
      EDGE_LOOP_SOUTH,
      EDGE_LOOP_WEST,
      EDGE_LOOP_NORTH,
    ]);
  
  my @tries = (
    EDGE_LOOP_NORTH,
    EDGE_LOOP_SOUTH,
    EDGE_LOOP_WEST,
    EDGE_LOOP_EAST,
   );
  my $index = $src->_shuffle_dir( \@tries, $src->flow());

  for my $this_try (@$index)
    {
    my $idx = 0;
    while ($idx < @places)
      {
      next unless $places[$idx+2] == $this_try;
      
      # build a path from the returned piece
      my @rc = ($places[$idx], $places[$idx+1], $places[$idx+2]);

      next unless $self->_path_is_clear(\@rc);

      print STDERR "# Found looping path\n" if $self->{debug};
      return \@rc;
      } continue { $idx += 3; } 
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

sub pos
  {
  # return the stored ptr
  my $self = shift;
  $self->[2], $self->[3];
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

sub cmp
  {
  # compare two elements
  $_[0]->[1] <=> $_[1]->[1];
  }

#############################################################################
#############################################################################

package Graph::Easy;

# Generic pathfinding via the A* algorithm:
# See http://bloodgate.com/perl/graph/astar.html for some background.

sub _astar_modifier
  {
  my ($x1,$y1,$x,$y,$px,$py, $cells) = @_;

  my $add = 1;

  if (defined $x1)
    {
    my $xy = "$x1,$y1";
    # add a harsh penalty for crossing an edge, meaning we can travel many
    # fields to go around.
    $add += 30 if ref($cells->{$xy}) && $cells->{$xy}->isa('Graph::Easy::Edge');
    }
 
  if (defined $px)
    {
    # see whether the new position $x1,$y1 is a continuation from $px,$py => $x,$y
    # e.g. if from we go down from $px,$py to $x,$y, then anything else then $x,$y+1 will
    # get a penalty
    my $dx1 = ($px-$x) <=> 0;
    my $dy1 = ($py-$y) <=> 0;
    my $dx2 = ($x-$x1) <=> 0;
    my $dy2 = ($y-$y1) <=> 0;
    $add += 6 unless $dx1 == $dx2 || $dy1 == $dy2;
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

    # loops (left-right-left etc)
    '0,-1,0,1' => EDGE_N_W_S,
    '0,1,0,-1' => EDGE_S_W_N,
    '1,0,-1,0' => EDGE_E_S_W,
    '-1,0,1,0' => EDGE_W_S_E,
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
  # return possible next nodes from $nx,$ny
  my ($nx, $ny, $cells, $open, $closed, $min_x, $min_y, $max_x, $max_y) = @_;

  my @places = ();

  my @tries  = (	# ordered E,S,W,N:
    $nx + 1, $ny, 	# right
    $nx, $ny + 1,	# down
    $nx - 1, $ny,	# left
    $nx, $ny - 1,	# up
    );

  # on crossings, only allow one direction (NS or EW)
  my $type = EDGE_CROSS;
  # including flags, because only flagless edges may be crossed
  $type = $cells->{"$nx,$ny"}->{type} if exists $cells->{"$nx,$ny"};
  if ($type == EDGE_HOR)
    {
    @tries  = (
      $nx, $ny + 1,	# down
      $nx, $ny - 1,	# up
    );
    }
  elsif ($type == EDGE_VER)
    {
    @tries  = (
      $nx + 1, $ny, 	# right
      $nx - 1, $ny,	# left
    );
    }

  my $i = 0;
  while ($i < @tries)
    {
    my ($x,$y) = ($tries[$i], $tries[$i+1]);

    # drop cells outside our working space:
    next if $x < $min_x || $x > $max_x || $y < $min_y || $y > $max_y;

    my $p = "$x,$y";
    next if exists $closed->{$p};

    # XXX TODO:
    # If it is in open, but we reached it with a lower g(), then lower
    # the existing value.
    # already open?
    next if exists $open->{$p};

    if (exists $cells->{$p} && ref($cells->{$p}) && $cells->{$p}->isa('Graph::Easy::Edge'))
      {
      # if the existing cell is an VER/HOR edge, then we may cross it
      my $type = $cells->{$p}->{type};	# including flags, because only flagless edges
					# may be crossed
      push @places, $x, $y if ($type == EDGE_HOR) || ($type == EDGE_VER);
      next;
      }
    next if exists $cells->{$p};	# uncrossable cell

    push @places, $x, $y;

    } continue { $i += 2; }
 
  @places;
  }

sub _astar_boundaries
  {
  # Calculate boundaries for area that A* should not leave.
  my $self = shift;

  my ($min_x, $min_y, $max_x, $max_y);

  my $cells = $self->{cells};

  for my $c (keys %$cells)
    {
    my ($x,$y) = split /,/, $c;
    $min_x = $x if !defined $min_x || $x < $min_x;
    $min_y = $y if !defined $min_y || $y < $min_y;
    $max_x = $x if !defined $max_x || $x > $max_x;
    $max_y = $y if !defined $max_y || $y > $max_y;
    }

  # make the area one bigger in each direction
  $min_x --; $min_y --; $max_x ++; $max_y ++;

  print STDERR "# A* working space boundaries: $min_x, $min_y, $max_x, $max_y\n" if $self->{debug};

  ($min_x, $min_y, $max_x, $max_y);
  }

# on edge pieces, select start fields (left/right of a VER, above/below of a HOR etc)
# contains also for each starting position the joint-type
my $next_fields =
  {
  EDGE_VER() => [ -1,0, EDGE_W_N_S, +1,0, EDGE_E_N_S ],
  EDGE_HOR() => [ 0,-1, EDGE_N_E_W, 0,+1, EDGE_S_E_W ],
  EDGE_N_E() => [ 0,+1, EDGE_E_N_S, -1,0, EDGE_N_E_W ],		# |_
  EDGE_N_W() => [ 0,+1, EDGE_W_N_S, +1,0, EDGE_N_E_W ],		# _|
  EDGE_S_E() => [ 0,-1, EDGE_E_N_S, -1,0, EDGE_S_E_W ],
  EDGE_S_W() => [ 0,-1, EDGE_W_N_S, +1,0, EDGE_S_E_W ],
  };

# on edge pieces, select end fields (left/right of a VER, above/below of a HOR etc)
# contains also for each end position the joint-type
my $prev_fields =
  {
  EDGE_VER() => [ -1,0, EDGE_W_N_S, +1,0, EDGE_E_N_S ],
  EDGE_HOR() => [ 0,-1, EDGE_N_E_W, 0,+1, EDGE_S_E_W ],
  EDGE_N_E() => [ 0,+1, EDGE_E_N_S, -1,0, EDGE_N_E_W ],		# |_
  EDGE_N_W() => [ 0,+1, EDGE_W_N_S, +1,0, EDGE_N_E_W ],		# _|
  EDGE_S_E() => [ 0,-1, EDGE_E_N_S, -1,0, EDGE_S_E_W ],
  EDGE_S_W() => [ 0,-1, EDGE_W_N_S, +1,0, EDGE_S_E_W ],
  };

sub _get_joints
  { 
  # from a list of shared, already placed edges, get possible start/end fields
  my ($self, $shared, $mask, $types, $cells, $next_fields) = @_;

  # take each cell from all edges shared, already placed edges as start-point
  for my $e (@$shared)
    {
    for my $c (@{$e->{cells}})
      {
      my $type = $c->{type} & EDGE_TYPE_MASK;

      next unless exists $next_fields->{ $type };

      # don't consider end/start (depending on $mask) cells
      next if $c->{type} & $mask;

      my $fields = $next_fields->{$type};

      my ($px,$py) = ($c->{x},$c->{y});
      my $i = 0;
      while ($i < @$fields)
	{
	my ($sx,$sy, $jt) = ($fields->[$i], $fields->[$i+1], $fields->[$i+2]);
	$sx += $px; $sy += $py; $i += 3;
        # don't add the field twice
	next if exists $cells->{"$sx,$sy"};
	$cells->{"$sx,$sy"} = [ $sx, $sy, undef, $px, $py ];
	$types->{"$sx,$sy"} = $jt;
	} 
      }
    }
 
  my @R;
  # convert hash to array
  for my $s (values %{$cells})
    {
    push @R, @$s;
    }
  @R;
  }

sub _find_path_astar
  {
  my ($self,$edge) = @_;

  my $cells = $self->{cells};
  my $src = $edge->{from};
  my $dst = $edge->{to};

  print STDERR "# A* from $src->{x},$src->{y} to $dst->{x},$dst->{y}\n" if $self->{debug};

  my $start_flags = [
    EDGE_START_W,
    EDGE_START_N,
    EDGE_START_E,
    EDGE_START_S,
  ]; 

  my $end_flags = [
    EDGE_END_W,
    EDGE_END_N,
    EDGE_END_E,
    EDGE_END_S,
  ]; 

  my ($s_p,@ss_p) = $edge->port('start');
  my ($e_p,@ee_p) = $edge->port('end');
  my (@A, @B);
  my @shared_start;

  # has a starting point restriction
  @shared_start = $edge->{from}->edges_at_port('start', $s_p, $ss_p[0]) if defined $s_p && @ss_p == 1;

  my @shared;
  # filter out all non-placed edges (this will also filter out $edge)
  for my $s (@shared_start)
    {
    push @shared, $s if @{$s->{cells}} > 0;
    }

  my $joint_type = {};
  my $joint_type_end = {};

  my $start_cells = {};
  my $end_cells = {};

  if (@shared > 0)
    {
    # more than one edge share the same start port, and one of the others was
    # already placed

    print STDERR "# edge from $edge->{from} to $edge->{to} shares port with ",
	scalar @shared, " other edge(s)\n" if $self->{debug};

    @A = $self->_get_joints(\@shared, EDGE_END_MASK, $joint_type, $start_cells, $next_fields);
    }
  else
    {
    # from SRC to DST

    # get all the starting positions
    # distance = 1: slots, generate starting types, the direction is shifted
    # by 90° counter-clockwise

    my $s = $start_flags; $s = $end_flags if $edge->{bidirectional};
    my @start = $src->_near_places($cells, 1, $s, 1, $src->_shift(-90) );

    # the edge has a port description, limiting the start places
    @start = $src->_allowed_places( \@start, $src->_allow( $s_p, @ss_p ), 3)
      if defined $s_p;

    return unless @start > 0;			# no free slots on start node?

    my $i = 0;
    while ($i < scalar @start)
      {
      my $sx = $start[$i]; my $sy = $start[$i+1]; my $type = $start[$i+2]; $i += 3;

      # compute the field inside the node from where $sx,$sy is reached:
      my $px = $sx; my $py = $sy;
      if ($sy < $src->{y} || $sy >= $src->{y} + $src->{cy})
        {
        $py = $sy + 1 if $sy < $src->{y};		# above
        $py = $sy - 1 if $sy > $src->{y};		# below
        }
      else
        {
        $px = $sx + 1 if $sx < $src->{x};		# right
        $px = $sx - 1 if $sx > $src->{x};		# left
        }

      push @A, ($sx, $sy, $type, $px, $py);
      }
    }

  my @shared_end;

  # has a end point restriction
  @shared_end = $edge->{to}->edges_at_port('end', $e_p, $ee_p[0]) if defined $e_p && @ee_p == 1;

  @shared = ();
  # filter out all non-placed edges (this will also filter out $edge)
  for my $s (@shared_end)
    {
    push @shared, $s if @{$s->{cells}} > 0;
    }

  my $per_field = 5;			# for shared: x,y,undef, px,py
  if (@shared > 0)
    {
    # more than one edge share the same end port, and one of the others was
    # already placed

    print STDERR "# edge from $edge->{from} to $edge->{to} shares port with ",
	scalar @shared, " other edge(s)\n" if $self->{debug};

    @B = $self->_get_joints(\@shared, EDGE_START_MASK, $joint_type_end, $end_cells, $prev_fields, 3);
    }
  else
    {
    # potential stop positions
    @B = $dst->_near_places($cells, 1, $end_flags, 1);	# distance = 1: slots

    # the edge has a port description, limiting the end places
    @B = $dst->_allowed_places( \@B, $dst->_allow( $e_p, @ee_p ), 3)
      if defined $e_p;

    $per_field = 3;			# x,y,type
    }

  return unless scalar @B > 0;			# no free slots on target node?

  my $path = $self->_astar(\@A,\@B,$edge, $per_field);

  if (@$path > 0 && keys %$start_cells > 0)
    {
    # convert the edge piece of the starting edge-cell to a join
    my ($x, $y) = ($path->[0],$path->[1]);
    my $xy = "$x,$y";
    my ($sx,$sy,$t,$px,$py) = @{$start_cells->{$xy}};

    my $jt = $joint_type->{"$sx,$sy"};
    $cells->{"$px,$py"}->_make_joint($edge,$jt);
    }

  if (@$path > 0 && keys %$end_cells > 0)
    {
    # convert the edge piece of the starting edge-cell to a join
    my ($x, $y) = ($path->[-3],$path->[-2]);
    my $xy = "$x,$y";
    my ($sx,$sy,$t,$px,$py) = @{$end_cells->{$xy}};

    my $jt = $joint_type_end->{"$sx,$sy"};
    $cells->{"$px,$py"}->_make_joint($edge,$jt);
    }

  $path;
  }

sub _astar
  {
  my ($self, $A, $B, $edge, $per_field) = @_;

  my @start = @$A;
  my @stop = @$B;
  my $stop = scalar @stop;
 
  my $src = $edge->{from};
  my $dst = $edge->{to};
  my $cells = $self->{cells};

  my $open = Heap::Binary->new();	# to find smallest elem fast
  my $open_by_pos = {};			# to find node by pos
  my $closed = {};			# a hash, indexed by "$x,$y" to find nodes by pos

  my $elem;

  # The boundaries of objects in $cell, e.g. the area that the algorithm shall
  # never leave.
  my ($min_x, $min_y, $max_x, $max_y) = $self->_astar_boundaries();

  # Max. steps to prevent endless searching in case of bugs like endless loops.
  my $tries = 0; my $max_tries = 50000;

  # count how many times we did A*
  $self->{stats}->{astar}++;

  ###########################################################################
  ###########################################################################
  # put the start positions into OPEN

  my $i = 0; my $bias = 0;
  while ($i < scalar @start)
    {
    my ($sx,$sy,$type,$px,$py) = 
     ($start[$i],$start[$i+1],$start[$i+2],$start[$i+3],$start[$i+4]);
    $i += 5;

    my $cell = $cells->{"$sx,$sy"}; my $rcell = ref($cell);
    next if $rcell && $rcell !~ /::Edge/;

    my $t = 0; $t = $cell->{type} & EDGE_NO_M_MASK if $rcell =~ /::Edge/;
    next if $t != 0 && $t != EDGE_HOR && $t != EDGE_VER;

    # for each start point, calculate the distance to each stop point, then use
    # the smallest as value

    my $lowest = _astar_distance($sx,$sy, $stop[0], $stop[1]);
    for (my $u = $per_field; $u < $stop; $u += $per_field)
      {
      my $dist = _astar_distance($sx,$sy, $stop[$u], $stop[$u+1]);
      $lowest = $dist if $dist < $lowest;
      }

    # add a penalty for crossings
    my $malus = 0; $malus = 30 if $t != 0;
    $malus += _astar_modifier($px,$py, $sx, $sy, $sx, $sy);
    $open->add( Graph::Easy::Astar::Node->new( $lowest, $sx, $sy, $px, $py, $type, 1 ));

    my $o = $malus + $bias + $lowest;
    print STDERR "# adding open pos $sx,$sy ($o)\n" if $self->{debug};

    # The cost to reach the starting node is obviously 0. That means that there is
    # a tie between going down/up if both possibilities are equal likely. We insert
    # a small bias here that makes the prefered order east/south/west/north. Instead
    # the algorithmn exploring both way and terminating arbitrarily on the one that
    # first hits the target, it will explore only one.
    $open_by_pos->{"$sx,$sy"} = $o;

    $bias += $self->{_astar_bias} || 0;
    } 

  ###########################################################################
  ###########################################################################
  # main A* loop

  my $stats = $self->{stats};

  STEP:
  while( defined( $elem = $open->extract_top ) )
    {
    $stats->{astar_steps}++ if $self->{debug};

    # hard limit on number of steps todo
    return if $tries++ > $max_tries;

    print STDERR "# Smallest elem is weight ", $elem->val, " at ", join(",", $elem->pos()),"\n" if $self->{debug};
    my (undef, $val, $x,$y, $px,$py, $type, $do_stop) = @$elem;

    my $key = "$x,$y";
    # move node into CLOSE and remove from OPEN
    my $g = $open_by_pos->{$key} || 0;
    $closed->{$key} = [ $px, $py, $val - $g, $g, $type, $do_stop ];
    delete $open_by_pos->{$key};

    # we are done when we hit one of the potential stop positions
    for (my $i = 0; $i < $stop; $i += $per_field)
      {
      # reached one stop position?
      if ($x == $stop[$i] && $y == $stop[$i+1])
        {
        $closed->{$key}->[4] += $stop[$i+2] if defined $stop[$i+2];
        print STDERR "# Reached stop position $x,$y\n" if $self->{debug};
        last STEP;
        }
      } # end test for stop postion(s)

    if (!defined $x || !defined $y)
      {
      require Carp;
      Carp::confess("On of '$x,$y' is not defined");
      }
    # get list of potential positions we need to explore from the current one
    my @p = _astar_near_nodes($x,$y, $cells, $open_by_pos, $closed, $min_x, $min_y, $max_x, $max_y);
    my $n = 0;
    while ($n < scalar @p)
      {
      my $nx = $p[$n]; my $ny = $p[$n+1]; $n += 2;

      if (!defined $nx || !defined $ny)
        {
        require Carp;
        Carp::confess("On of '$nx,$ny' is not defined");
        }
      my $lg = $g;
      $lg += _astar_modifier($px,$py,$x,$y,$nx,$ny,$cells) if defined $px && defined $py;

      # calculate distance to each possible stop position, and
      # use the lowest one
      my $lowest_distance = _astar_distance($nx, $ny, $stop[0], $stop[1]);
      for (my $i = $per_field; $i < $stop; $i += $per_field)
        {
        my $d = _astar_distance($nx, $ny, $stop[$i], $stop[$i+1]);
        $lowest_distance = $d if $d < $lowest_distance; 
        }

    print STDERR "# opening pos $x,$y ($lowest_distance + $lg)\n" if $self->{debug};

      # open new position into OPEN
      $open->add( Graph::Easy::Astar::Node->new(
        $lowest_distance + $lg,
         $nx, $ny, $x, $y, undef ));
      $open_by_pos->{"$nx,$ny"} = $lg;
      }
    }

  # count how many steps we did in A*
  $self->{stats}->{astar_steps} += $tries;

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
	# We can figure it out from the flag of the position of cx,cy
	#        ................
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
      print STDERR 
       "# Warning: A* detected loop in path-backtracking at $px,$py, $cx,$cy, $lx,$ly\n"
       if $self->{debug};
      last;
      }

    $type = EDGE_HOR if ($type & EDGE_TYPE_MASK) == 0;		# last resort

    # if this is the first hor edge, attach the label to it
    # XXX TODO: This clearly is not optimal. Look for left-most HOR CELL
    my $t = $type & EDGE_TYPE_MASK;
    if ($label_cell == 0 && ($t == EDGE_HOR || $t == EDGE_VER))
      {
      $label_cell++;
      $type += EDGE_LABEL_CELL;
      }

    unshift @$path, $cx, $cy, $type;		# unshift to reverse the path

    last if $closed->{"$cx,$cy"}->[ 5 ];	# stop here?

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

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>.

See the LICENSE file for information.

=cut

