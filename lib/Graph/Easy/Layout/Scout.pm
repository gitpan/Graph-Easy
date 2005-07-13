#############################################################################
# Find path from node to node in a Manhattan-style grid.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Layout::Scout;

use vars qw/$VERSION/;

$VERSION = '0.01';

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

  EDGE_HOR EDGE_VER EDGE_CROSS

  EDGE_LABEL_CELL
 /;


#############################################################################

sub _find_path
  {
  # Traces a straight path (no bend) or at maximum one bend. If this is not
  # possible, delegate to _find_path_hard(). Returns a list of cells.
  my ($self, $src, $dst) = @_;

  # XXX TODO:
  # This code assumes each starting/end point is one cell.
  # It should really get all the starting possibilities via
  # $src->_near_places() and then the possibilities from $dst->_near_places()
  # and the try each @start with each @stop

  my @start = $src->_near_places();
  my @stop = $dst->_near_places();

  # one node pointing back to itself?
  return $self->_find_path_loop($src) if $src == $dst;
 
  my ($x0, $y0) = ($src->{x}, $src->{y});
  my ($x1, $y1) = ($dst->{x}, $dst->{y});
  my $dx = ($x1 - $x0) <=> 0;
  my $dy = ($y1 - $y0) <=> 0;
    
  # if ($dx == 0 && $dy == 0) then we have only a short edge

  my $cells = $self->{cells};
  my @coords;
  my ($x,$y) = ($x0,$y0);			# starting pos

  print STDERR "# dx,dy: $dx,$dy\n" if $self->{debug};

  # the type of the edge at the bend depends on $dx and $dy
  my $type_bend = EDGE_CROSS;

#  $type_bend = EDGE_N_E if $dx == -1 && $dy == -1;
#  $type_bend = EDGE_N_W if $dx == +1 && $dy == -1;
#  $type_bend = EDGE_S_E if $dx == -1 && $dy == +1;
#  $type_bend = EDGE_S_W if $dx == +1 && $dy == +1;
 
  if ($dx != 0 && $dy != 0)
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
      push @coords, "$x,$y," . $type;		# good one, is free
      $x += $dx;				# next field
      };

    if ($done == 0)
      {
      push @coords, "$x,$y," . $type_bend;		# put in bend
      print STDERR "# at $x,$y\n" if $self->{debug};
      $y += $dy;
      $type = EDGE_VER;
      while ($y != $y1)
        {
        $done++, last if exists $cells->{"$x,$y"};	# cell already full
	print STDERR "# at $x,$y\n" if $self->{debug};
        push @coords, "$x,$y," . $type;		# good one, is free
        $y += $dy;
        } 
      }

    if ($done != 0)
      {
      $done = 0;
      # try ver => hor
      print STDERR "# hm, now trying first vertical, then horizontal\n" if $self->{debug};
      $type = EDGE_VER;

      ($x,$y) = ($x0, $y0 + $dy);		# starting pos
      while ($y != $y1)
        {
        $done++, last if exists $cells->{"$x,$y"};	# cell already full
        print STDERR "# at $x,$y\n" if $self->{debug};
        push @coords, "$x,$y," . $type;		# good one, is free
        $y += $dy;				# next field
        };

      if ($done == 0)
        {
        push @coords, "$x,$y," . $type_bend;	# put in bend
        print STDERR "# at $x,$y\n" if $self->{debug};
        $x += $dx;
        $type = EDGE_HOR;
        while ($x != $x1)
          {
          $done++, last if exists $cells->{"$x,$y"};	# cell already full
	  print STDERR "# at $x,$y\n" if $self->{debug};
	  push @coords, "$x,$y," . $type;		# good one, is free
	  $x += $dx;
          } 
        }
      }

    # modify last field of path to be the correct endpoint:
    if ($done == 0)
      {
      print STDERR "# success for ", scalar @coords, " steps in path\n" if $self->{debug};
      my $type_last;
      $type_last = EDGE_END_E if $type == EDGE_HOR && $dx == 1;
      $type_last = EDGE_END_W if $type == EDGE_HOR && $dx == -1;
      $type_last = EDGE_END_S if $type == EDGE_VER && $dy == 1;
      $type_last = EDGE_END_N if $type == EDGE_VER && $dy == -1;

      my @last = split /,/, $coords[-1];
      $last[-1] = $type_last;
      $coords[-1] = join(",", @last);
 
      return @coords;			# return all fields of path
      }
    print STDERR "# no success\n" if $self->{debug};

    } # end path with $dx and $dy
  else
    {
    # try straight path to target:
 
    print "$src->{x},$src->{y} => $dst->{x},$dst->{y} - trying short path\n" if $self->{debug};

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
        $type |= EDGE_LABEL_CELL;

        return ("$x,$y,$type");				# return a short EDGE
        }
      }

    my $type = EDGE_HOR; $type = EDGE_VER if $dx == 0;	# - or |
    my $done = 0;
    my $label_done = 0;
    while (3 < 5)
      {
      # XXX TODO handle here crossing paths
      $done = 1, last if exists $cells->{"$x,$y"};	# cell already full

      # the first cell gets the label
      my $t = $type; $t += EDGE_LABEL_CELL if $label_done++ == 0;

      push @coords, "$x,$y," . $t;			# good one, is free
      $x += $dx;					# next field
      $y += $dy;
      last if ($x == $x1) && ($y == $y1);
      }

    # modify type of last cell to be endpoint

    return @coords if $done == 0;			# return all fields of path
    } # end else straight path try

  # first try to find a path that is U-shaped:
  my @rc = $self->_find_path_u_shaped($src,$dst); return @rc if @rc;

  $self->_find_path_hard($src, $dst);		# try generic approach as last hope
  }

sub _find_path_hard
  {
  # try a generic approach to finding a path
  my ($self, $src, $dst) = @_;

  my ($x0, $y0) = ($src->{x}, $src->{y});
  my ($x1, $y1) = ($dst->{x}, $dst->{y});

  my $dx = ($x1 - $x0) <=> 0;
  my $dy = ($y1 - $y0) <=> 0;

  my @rc;				# XXX TODO A* not implemented yet

  @rc;					# return result
  }

sub _find_path_u_shaped
  {
  # try to find a path that is U-shaped:
  my ($self, $src, $dst) = @_;

  # [ ]        [ ] 	            [ ]
  #  |          ^	 [ ]         ^
  #  +----------+	  |          |
  #                       +----------+

  # [ ] --+       [ ] -----+
  #       |                |
  # [ ] <-+          [ ] <-+

  # Both variants can be upwards/downwards or left/right, giving us
  # four combinations in total. However, the horizontal U is
  # impossible when $dx == 0, and likewise the vertical is not
  # possible when $dy == 0.
  
  my ($x0, $y0) = ($src->{x}, $src->{y});
  my ($x1, $y1) = ($dst->{x}, $dst->{y});

  my $dx = ($x1 - $x0) <=> 0;
  my $dy = ($y1 - $y0) <=> 0;
  my $cells = $self->{cells};

  my @variants = ();

  # going down/up
  push @variants, 
    [ 0, +1, EDGE_VER, EDGE_HOR, EDGE_END_N, EDGE_N_E, EDGE_N_W ], 
    [ 0, -1, EDGE_VER, EDGE_HOR, EDGE_END_S, EDGE_S_E, EDGE_S_W ] if $dx != 0;
  # going left/right
  push @variants, 
    [ +1, 0, EDGE_HOR, EDGE_VER, EDGE_END_W, EDGE_S_W, EDGE_N_W ],
    [ -1, 0, EDGE_HOR, EDGE_VER, EDGE_END_E, EDGE_S_E, EDGE_N_E ] if $dy != 0;

  print "$src->{x},$src->{y} => $dst->{x},$dst->{y} - trying U-shaped path\n" if $self->{debug};

  foreach my $variant (@variants)
    {
    my ($dx0, $dy0, @edges) = @$variant;

    # going up/down, but src is right of dst, so swap last two edges
    # likewise, if going left/right, and src lower than dst
    if (($dx0 == 0 && $dx < 0) || ($dy0 == 0 && $dy > 0))
      {
      ($edges[-2], $edges[-1]) = ($edges[-1], $edges[-2]);
      }

    # We do not need to try the extending if the first or last cell of the
    # path is blocked. So we should test this beforehand.

    # check the first field of the path, if it is blocked, forget this try
    my $x = $src->{x} + $dx0; my $y = $src->{y} + $dy0;
    next if exists $cells->{"$x,$y"};

    # check the last field of the path, if it is blocked, forget this try
    $x = $dst->{x} + $dx0; $y = $dst->{y} + $dy0;
    next if exists $cells->{"$x,$y"};

    # try to extend the U shape for 1..5 units in the primary direction
    for (my $len = 1; $len < 5; $len++)
      {
      # construct the path      

      print STDERR "# try $len\n" if $self->{debug};

      my @path = ();     
      my $x = $src->{x}; my $y = $src->{y};
      $x += $dx0; $y += $dy0;
      my $edge = $edges[0];

#      print "extending " . scalar @path . "\n";

      # extending
      for (my $i = 0; $i < $len; $i++)
        {
	push @path, "$x,$y,$edge";
	$x += $dx0; $y += $dy0;
        }

      print STDERR "# bend " . scalar @path . "\n" if $self->{debug};
      # first bend
      $edge = $edges[-2];
      push @path, "$x,$y,$edge";
      $x += $dx; $y += $dy;

#      print "towards " . scalar @path . "\n";

      # go towards dst
      $edge = $edges[1];
      while (! (($x == $dst->{x}) || ($y == $dst->{y})))
	{
        print STDERR "# at $x $y\n" if $self->{debug};
	push @path, "$x,$y,$edge";
	$x += $dx; $y += $dy;
	}

#      print "bend 2 " . scalar @path . "\n";
      # second bend
      $edge = $edges[-1];
      push @path, "$x,$y,$edge";
#      print "at $x,$y ($dx0 $dy0)\n";
      $x -= $dx0; $y -= $dy0;

#      print "backwards " . scalar @path . "\n";
      $edge = $edges[0];
      # going back towards dst
      print STDERR "# at $x $y\n" if $self->{debug};
#      sleep(1);
      while (($x != $dst->{x}) || ($y != $dst->{y}))
	{
        print STDERR "# at $x $y ($dx0 $dy0)\n" if $self->{debug};
#        sleep(1);
	push @path, "$x,$y,$edge";
	$x -= $dx0; $y -= $dy0;
	}
      # modify last type to be the endpoint

      my @last = split /,/, $path[-1];
      $last[-1] = $edges[2];
      $path[-1] = join(",", @last);

      print STDERR "# checking path with ", scalar @path, " steps\n" if $self->{debug};
      return @path if $self->_path_is_clear(\@path);
      }
    }

  ();
  }

sub _find_path_loop
  {
  # find a path from one node back to itself
  my ($self, $src) = @_;

  print STDERR "# Finding path from $src->{name} to $src->{name}\n" if $self->{debug};

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
       [ 0,-1, EDGE_S_E],
       [ 1,-1, EDGE_HOR],
       [ 2,-1, EDGE_S_W],
       [ 2, 0, EDGE_N_W],
       [ 1, 0, EDGE_END_W],
     ],
     [
       [ 0, 1, EDGE_N_W],
       [-1, 1, EDGE_HOR],
       [-2, 1, EDGE_N_E],
       [-2, 0, EDGE_S_E],
       [-1, 0, EDGE_END_E],
     ],
     [
       [ 0, 1, EDGE_N_E],
       [ 1, 1, EDGE_HOR],
       [ 2, 1, EDGE_N_W],
       [ 2, 0, EDGE_S_W],
       [ 1, 0, EDGE_END_W],
     ],
     [
       [ 0,-1, EDGE_S_W],
       [-1,-1, EDGE_HOR],
       [-2,-1, EDGE_S_E],
       [-2, 0, EDGE_N_E],
       [-1, 0, EDGE_END_E],
     ],
   );
  # where does the final edge point to?
  my @dx = ( -1, 1, -1, 1);

  my @rc = (); my $i = -1;
  foreach my $path (@loops)
    {
    $i++;
    my $p = [];
    my $x = $src->{x}; my $y = $src->{y};

    # clear list of cells we are going to return
    @rc = ();
    foreach my $elem (@$path)
      {
      my $xi = $x + $elem->[0];
      my $yi = $y + $elem->[1];

      push @$p, [ $xi, $yi, $elem->[2] ];
      push @rc, "$xi,$yi,$elem->[2]";
      }
    next unless $self->_path_is_clear($p);
    print STDERR "# Found looping path $i\n" if $self->{debug};
    last;
    }

  @rc;					# return findings
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
L<Graph::Easy|Graph::Easy>.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for information.

=cut
