#############################################################################
# Path and cell management for Graph::Easy.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Layout::Path;

use vars qw/$VERSION/;

$VERSION = '0.03';

#############################################################################
#############################################################################

package Graph::Easy::Node;

use Graph::Easy::Edge::Cell qw/
  EDGE_HOR EDGE_VER EDGE_CROSS
  EDGE_START_E EDGE_START_N EDGE_START_S EDGE_START_W
  EDGE_END_E EDGE_END_N EDGE_END_S EDGE_END_W
  EDGE_TYPE_MASK
 /;

sub _near_places
  {
  # Take a node and return a list of possible placements around it and
  # prune out already occupied cells. $d is the distance from the node
  # border and defaults to two (for placements). Set it to one for
  # adjacent cells. 

  # If $type is 'start', it will also plus EDGE_START_x for each place.
  # If it is "stop", the flags will be EDGE_END_x.

  my ($n, $cells, $d, $type) = @_;

  my $cx = $n->{cx} || 1;
  my $cy = $n->{cy} || 1;
  
  $d = 2 unless defined $d;		# default is distance = 2

  my $idx = 0; $idx = 4 if defined $type && $type ne 'start';
  my @flags = (
    EDGE_START_W, # right
    EDGE_START_N, # down
    EDGE_START_E, # left
    EDGE_START_S, # up
    EDGE_END_W,   # right
    EDGE_END_N,   # down
    EDGE_END_E,   # left
    EDGE_END_S,   # up
  );

  my @places = ();

  if ($cx + $cy == 2)
    {
    my @tries  = (
  	$n->{x} + $d, $n->{y}, $flags[$idx],   # right
	$n->{x}, $n->{y} + $d, $flags[$idx+1], # down
	$n->{x} - $d, $n->{y}, $flags[$idx+2], # left
	$n->{x}, $n->{y} - $d, $flags[$idx+3], # up
      );

    while (@tries > 0)
      {
      my $x = shift @tries;
      my $y = shift @tries;
      my $t = shift @tries;

      # This quick check does not take node clusters or multi-celled nodes
      # into account. These are handled in $node->place() later.
      next if exists $cells->{"$x,$y"};
      push @places, $x, $y;
      push @places, $t if defined $type;
      }
    return @places;
    }

  # Handle a multi-celled node. For a 3x2 node:
  #      A   B   C
  #   J [00][10][20] D
  #   I [10][11][21] E
  #      H   G   F
  # we have 10 (3 * 2 + 2 * 2) places to consider

  my $nx = $n->{x};
  my $ny = $n->{y};
  my ($px,$py);

  $cy--; $cx--;
  my $t = $flags[$idx];
  # right
  $px = $nx + $cx + $d;
  for my $y (0 .. $cy)
    {
    $py = $y + $ny;
    push @places, $px, $py unless exists $cells->{"$px,$py"};
    push @places, $t if defined $type && !exists $cells->{"$px,$py"};
    }

  # below
  $py = $ny + $cy + $d;
  $t = $flags[$idx+1];
  for my $x (0 .. $cx)
    {
    $px = $x + $nx;
    push @places, $px, $py unless exists $cells->{"$px,$py"};
    push @places, $t if defined $type && !exists $cells->{"$px,$py"};
    }

  # left
  $px = $nx - $d;
  $t = $flags[$idx+2];
  for my $y (0 .. $cy)
    {
    $py = $y + $ny;
    push @places, $px, $py unless exists $cells->{"$px,$py"};
    push @places, $t if defined $type && !exists $cells->{"$px,$py"};
    }

  # top
  $py = $ny - $d;
  $t = $flags[$idx+3];
  for my $x (0 .. $cx)
    {
    $px = $x + $nx;
    push @places, $px, $py unless exists $cells->{"$px,$py"};
    push @places, $t if defined $type && !exists $cells->{"$px,$py"};
    }

  @places;
  }

package Graph::Easy;

use strict;
use Graph::Easy::Node::Cell;

use Graph::Easy::Edge::Cell qw/
  EDGE_HOR EDGE_VER EDGE_CROSS
  EDGE_TYPE_MASK
 /;

sub _clear_tries
  {
  # Take a list of potential positions for a node, and then remove the
  # ones that are immidiately near the given other node (successor).
  # Returns a list of "good" positions.  
  my ($self, $cells, $suc, @tries) = @_;

  my @near = $suc->_near_places($cells, 1);
  my @good;
  my $i = 0;
  while ($i < @tries)
    {
    my $j = 0;
    my $g = 0;
    while ($j < @near)
      {
      $g ++ and last if ($near[$j] == $tries[$i] && $near[$j+1] == $tries[$i+1]);
      $j += 2;
      }
    push @good, $tries[$i], $tries[$i+1] if $g == 0;
    $i += 2;
    }
  @good;
  }

sub _find_node_place
  {
  # Try to place a node (or node cluster). Return score (usually 0).
  my ($self, $cells, $node) = @_;

  print STDERR "# Finding place for $node->{name}\n" if $self->{debug};

  # Try to place node at upper left corner (the very first node to be
  # placed will usually end up there).
  return 0 if $node->place(0,0,$cells);

  # try to place node near the predecessor(s)
  my @pre_all = $node->predecessors();

  print STDERR "# Predecessors of $node->{name} " . scalar @pre_all . "\n" if $self->{debug};

  # find all already placed predecessors
  my @pre;
  for my $p (@pre_all)
    {
    push @pre, $p if defined $p->{x};
    }

  print STDERR "# Placed predecessors of $node->{name}: " . scalar @pre . "\n" if $self->{debug};

  my @tries;
  if (@pre <= 2 && @pre > 0)
    {

    if (@pre == 1)
      {
      # only one placed predecessor, so place $node near it
      print STDERR "# placing $node->{name} near predecessor\n" if $self->{debug};
      @tries = $pre[0]->_near_places($cells); 
      }
    else
      {
      # two placed predecessors, so place at crossing point of both of them
      # compute difference between the two nodes

      my $dx = ($pre[0]->{x} - $pre[1]->{x});
      my $dy = ($pre[0]->{y} - $pre[1]->{y});

      # are both nodes NOT on a straight line?
      if ($dx != 0 && $dy != 0)
        {
        # ok, so try to place at the crossing point
	@tries = ( 
	  $pre[0]->{x}, $pre[1]->{y},
	  $pre[0]->{y}, $pre[1]->{x},
	);
        }
      else
        {
        # two nodes on a line, try to place node in the middle
        if ($dx == 0)
          {
	  @tries = ( $pre[1]->{x}, $pre[1]->{y} + $dy / 2 );
          }
        else
          {
	  @tries = ( $pre[1]->{x} + $dx / 2, $pre[1]->{y} );
          }
        }
      # XXX TODO BUG: shouldnt we also try this if we have more than 2 placed
      # predecessors?

      # In addition, we can also try to place the node around the
      # different nodes:
      foreach my $n (@pre)
        {
        push @tries, $n->_near_places($cells);
        }
      }
    }

  my @suc_all = $node->successors();

  # find all already placed successors
  my @suc;
  for my $s (@suc_all)
    {
    push @suc, $s if defined $s->{x};
    }
  foreach my $s (@suc)
    {
    # for each successors (especially if there is only one), try to place near
    push @tries, $s->_near_places($cells); 
    }

  foreach my $s (@suc)
    {
    # for each successors weed out too close positions
    @tries = $self->_clear_tries($cells, $s, @tries);
    }

  print STDERR "# Trying simple placement of $node->{name}\n" if $self->{debug};
  while (@tries > 0)
    {
    my $x = shift @tries;
    my $y = shift @tries;

    print STDERR "# Trying to place $node->{name} at $x,$y\n" if $self->{debug};
    return 0 if $node->place($x,$y,$cells);

    } # for all trial positions

  # all simple possibilities exhausted, try generic approach

  # if no predecessors/incoming edges, try to place in column 0, otherwise in column 2
  my $col = 0; $col = 2 if @pre > 0;

  # find the first free row
  my $y = 0;
  $y +=2 while (exists $cells->{"$col,$y"});
  $y += 1 if exists $cells->{"$col," . ($y-1)};		# leave one cell spacing

  # now try to place node (or node cluster)
  $y +=2 while (! $node->place($col,$y,$cells));

  0;							# success, score 0 
  }

sub _trace_path
  {
  # find a free way from $src to $dst (both need to be placed beforehand)
  my ($self, $src, $dst, $edge) = @_;

  print STDERR "# Finding path from $src->{name} to $dst->{name}\n" if $self->{debug};
  print STDERR "# src: $src->{x}, $src->{y} dst: $dst->{x}, $dst->{y}\n" if $self->{debug};

  my $coords = $self->_find_path ($src, $dst, { direction => [ 90, 180, 270, 0 ] } );

  # found no path?
  if (!defined $coords || scalar @$coords == 0)
    {
    # XXX TODO
    print STDERR "# Unable to find path from $src->{name} ($src->{x},$src->{y}) to $dst->{name} ($dst->{x},$dst->{y})\n";
    sleep(1);
    return undef;
    }

  # Create all cells from the returned list and score path (lower score: better)
  my $i = 0;
  my $score = 0;
  while ($i < scalar @$coords)
    {
    my $type = $coords->[$i+2];
    $self->_create_cell($edge,$coords->[$i],$coords->[$i+1],$type);
    $score ++;					# each element: one point
    $type &= EDGE_TYPE_MASK;			# mask flags
    # edge bend or cross: one point extra
    $score ++ if $type != EDGE_HOR && $type != EDGE_VER;
    $score += 3 if $type == EDGE_CROSS;		# crossings are doubleplusungood
    $i += 3;
    }

  $score;
  }

sub _create_cell
  {
  my ($self,$edge,$x,$y,$type) = @_;

  my $cells = $self->{cells}; my $xy = "$x,$y";
  if (exists $cells->{$xy})
    {
    $cells->{$xy}->_cross($edge);
    return;
    }

  my $path = Graph::Easy::Edge::Cell->new( type => $type, edge => $edge, x => $x, y => $y );
  $path->{graph} = $self;	# register path elements with ourself
  $cells->{$xy} = $path;	# store in cells
  }

sub _remove_path
  {
  # Take an edge, and remove all the cells it covers from the cells area
  my ($self, $edge) = @_;

  my $cells = $self->{cells};
  my $covered = $edge->cells();

  for my $key (keys %$covered)
    {
    # XXX TODO: handle crossed edges differently (from CROSS => HOR or VER)
    # free in our cells area
    delete $cells->{$key};
    }
  $edge->clear_cells();
  }

sub _path_is_clear
  {
  # For all points (x,y pairs) in the path, check that the cell is still free
  # $path points to a list of [ x,y,type, x,y,type, ...]
  my ($self,$path) = @_;

  my $cells = $self->{cells};
  my $i = 0;
  while ($i < scalar @$path)
    {
    my $x = $path->[$i];
    my $y = $path->[$i+1];
    # my $t = $path->[$i+2];
    $i += 3;

    return 0 if exists $cells->{"$x,$y"};	# obstacle hit
    } 
  1;						# path is clear
  }

1;
__END__
=head1 NAME

Graph::Easy::Layout::Path - Path management for Manhattan-style grids

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

C<Graph::Easy::Layout::Scout> contains just the actual path-managing code for
L<Graph::Easy|Graph::Easy>, e.g. to create/destroy/maintain paths, node
placement etc.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 METHODS

This module injects the following methods into Graph::Easy:

=head2 _path_is_clear

	$graph->_path_is_clear($path);

For all points (x,y pairs) in the path, check that the cell is still free.
C<$path> points to a list x,y,type pairs as in C<< [ [x,y,type], [x,y,type], ...] >>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for information.

=cut
