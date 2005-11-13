#############################################################################
# Path and cell management for Graph::Easy.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Layout::Path;

use vars qw/$VERSION/;

$VERSION = '0.07';

#############################################################################
#############################################################################

package Graph::Easy::Node;

use Graph::Easy::Edge::Cell qw/
 EDGE_END_E EDGE_END_N EDGE_END_S EDGE_END_W
/;

sub _shuffle_dir
  {
  # take a list with four entries and shuffle them around according to $dir
  my ($self, $e, $dir) = @_;

  # $dir: 0 => north, 90 => east, 180 => south, 270 => west

  $dir = 90 unless defined $dir;		# default is east

  return [ @$e ] if $dir == 90;			# default is no shuffling

  my @shuffle = (0,1,2,3);			# the default
  @shuffle = (1,2,0,3) if $dir == 180;		# south
  @shuffle = (2,3,1,0) if $dir == 270;		# west
  @shuffle = (3,0,2,1) if $dir == 0;		# north

  [
    $e->[ $shuffle[0] ],
    $e->[ $shuffle[1] ],
    $e->[ $shuffle[2] ],
    $e->[ $shuffle[3] ],
  ];
  }

sub _shift
  {
  # get a direction shifted by X° to $dir
  my ($self, $turn) = @_;

  $dir = $self->attribute('flow') || 90;

  $dir += $turn;
  $dir += 360 if $dir < 0;
  $dir -= 360 if $dir > 360;
  $dir;
  }

sub _near_places
  {
  # Take a node and return a list of possible placements around it and
  # prune out already occupied cells. $d is the distance from the node
  # border and defaults to two (for placements). Set it to one for
  # adjacent cells. 

  # If defined, $type contains four flags for each direction. If undef,
  # two entries (x,y) will be returned for each pos, instead of (x,y,type).

  # If $loose is true, no checkingg wether the returned fields are free
  # is done.

  my ($n, $cells, $d, $type, $loose, $dir) = @_;

  my $cx = $n->{cx} || 1;
  my $cy = $n->{cy} || 1;
  
  $d = 2 unless defined $d;		# default is distance = 2

  my $flags = $type;

  if (ref($flags) ne 'ARRAY')
    {
    $flags = [
      EDGE_END_W,
      EDGE_END_N,
      EDGE_END_E,
      EDGE_END_S,
     ];
    }
  $dir = $n->attribute('flow') unless defined $dir;

  my $index = $n->_shuffle_dir( [ 0,3,6,9], $dir);

  my @places = ();

  # single-celled node
  if ($cx + $cy == 2)
    {
    my @tries  = (
  	$n->{x} + $d, $n->{y}, $flags->[0],   # right
	$n->{x}, $n->{y} + $d, $flags->[1], # down
	$n->{x} - $d, $n->{y}, $flags->[2], # left
	$n->{x}, $n->{y} - $d, $flags->[3], # up
      );

    for my $i (0..3)
      {
      my $idx = $index->[$i];
      my ($x,$y,$t) = ($tries[$idx], $tries[$idx+1], $tries[$idx+2]);

      # This quick check does not take node clusters or multi-celled nodes
      # into account. These are handled in $node->place() later.
      next if !$loose && exists $cells->{"$x,$y"};
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

  my $idx = 0;
  my @results = ( [], [], [], [] );
 
  $cy--; $cx--;
  my $t = $flags->[$idx++];
  # right
  $px = $nx + $cx + $d;
  for my $y (0 .. $cy)
    {
    $py = $y + $ny;
    next if exists $cells->{"$px,$py"} && !$loose;
    push @{$results[0]}, $px, $py;
    push @{$results[0]}, $t if defined $type;
    }

  # below
  $py = $ny + $cy + $d;
  $t = $flags->[$idx++];
  for my $x (0 .. $cx)
    {
    $px = $x + $nx;
    next if exists $cells->{"$px,$py"} && !$loose;
    push @{$results[1]}, $px, $py;
    push @{$results[1]}, $t if defined $type;
    }

  # left
  $px = $nx - $d;
  $t = $flags->[$idx++];
  for my $y (0 .. $cy)
    {
    $py = $y + $ny;
    next if exists $cells->{"$px,$py"} && !$loose;
    push @{$results[2]}, $px, $py;
    push @{$results[2]}, $t if defined $type;
    }

  # top
  $py = $ny - $d;
  $t = $flags->[$idx];
  for my $x (0 .. $cx)
    {
    $px = $x + $nx;
    next if exists $cells->{"$px,$py"} && !$loose;
    push @{$results[3]}, $px, $py;
    push @{$results[3]}, $t if defined $type;
    }

  # accumulate the results in the requested, shuffled order
  for my $i (0..3)
    {
    my $idx = $index->[$i] / 3;
    push @places, @{$results[$idx]};
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
  # ones that are immidiately near any other node.
  # Returns a list of "good" positions. Afterwards $node->{x} is undef.
  my ($self, $node, $cells, $tries) = @_;

  my $src = 0; my @new;

  print STDERR "# clearing ", scalar @$tries / 2, " tries for $node->{name}\n" if $self->{debug};

  my $node_grandpa = $node->find_grandparent();

  while ($src < scalar @$tries)
    {
    # check the current position

    # temporary place node here
    my $x = $tries->[$src];
    my $y = $tries->[$src+1];

    print STDERR "# checking $x,$y\n" if $self->{debug};

    $node->{x} = $x;
    $node->{y} = $y;

    my @near = $node->_near_places($cells, 1, undef, 1);

    # push also the four corner cells to avoid placing nodes corner-to-corner
    push @near, $x-1, $y-1,					# upperleft corner
                $x-1, $y+($node->{cy}||1),			# lowerleft corner
                $x+($node->{cx}||1), $y+($node->{cy}||1),	# lowerright corner
                $x+($node->{cx}||1), $y-1;			# upperright corner
    
    # check all near places to be free from nodes (except our children)
    my $j = 0; my $g = 0;
    while ($j < @near)
      {
      my $xy = $near[$j]. ',' . $near[$j+1];

      print STDERR "# checking near-place: $xy: " . ref($cells->{$xy}) . "\n" if $self->{debug};
      
      my $cell = $cells->{$xy};

      # skip, unless we are a children of node, or the cell is our children
      next unless ref($cell) && $cell->isa('Graph::Easy::Node');

      my $grandpa = $cell->find_grandparent();

      #       this cell is our children
      #                            this cell is our grandpa
      #                                                      has the same grandpa as node
      next if $grandpa == $node || $cell == $node_grandpa || $grandpa == $node_grandpa;

      $g++; last;

      } continue { $j += 2; }

    if ($g == 0)
      {
      push @new, $tries->[$src], $tries->[$src+1];
      }
    $src += 2;
    }

  $node->{x} = undef;

  @new;
  }

sub _find_node_place
  {
  # Try to place a node (or node cluster). Return score (usually 0).
  my ($self, $cells, $node, $try, $parent) = @_;

  $try ||= 0;

  print STDERR "# Finding place for $node->{name}, try #$try\n" if $self->{debug};
  print STDERR "# Parent node is '$parent->{name}'\n" if $self->{debug} && ref $parent;

  my @tries;
  if (ref($parent) && defined $parent->{x})
    {
    @tries = $parent->_near_places($cells); 
  
    print STDERR "# Trying chained placement of $node->{name}\n" if $self->{debug};

    # weed out positions that are unsuitable
    @tries = $self->_clear_tries($node, $cells, \@tries);

    print STDERR "# Left with " . scalar @tries . " for node $node->{name}\n" if $self->{debug};

    splice (@tries,0,$try) if $try > 0;	# remove the first N tries

    while (@tries > 0)
      {
      my $x = shift @tries;
      my $y = shift @tries;

      print STDERR "# Trying to place $node->{name} at $x,$y\n" if $self->{debug};
      return 0 if $node->place($x,$y,$cells);
      } # for all trial positions
    }

  print STDERR "# Trying to place $node->{name} at 0,0\n" if $try == 0 && $self->{debug};
  # Try to place node at upper left corner (the very first node to be
  # placed will usually end up there).
  return 0 if $try == 0 && $node->place(0,0,$cells);

  # try to place node near the predecessor(s)
  my @pre_all = $node->predecessors();

  print STDERR "# Predecessors of $node->{name} " . scalar @pre_all . "\n" if $self->{debug};

  # find all already placed predecessors
  my @pre;
  for my $p (@pre_all)
    {
    push @pre, $p if defined $p->{x};
    print STDERR "# Placed predecessors of $node->{name}: $p->{name} at $p->{x},$p->{y}\n" if $self->{debug} && defined $p->{x};
    }

  # sort predecessors on their rank (to try first the higher ranking ones on placement)
  @pre = sort { $b->{rank} <=> $a->{rank} } @pre;

  print STDERR "# Number of placed predecessors of $node->{name}: " . scalar @pre . "\n" if $self->{debug};

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
	  @tries = ( $pre[1]->{x}, $pre[1]->{y} + int($dy / 2) );
          }
        else
          {
	  @tries = ( $pre[1]->{x} + int($dx / 2), $pre[1]->{y} );
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

  # weed out positions that are unsuitable
  @tries = $self->_clear_tries($node, $cells, \@tries);

  print STDERR "# Left with " . scalar @tries . " for node $node->{name}\n" if $self->{debug};

  splice (@tries,0,$try) if $try > 0;	# remove the first N tries
  
  while (@tries > 0)
    {
    my $x = shift @tries;
    my $y = shift @tries;

    print STDERR "# Trying to place $node->{name} at $x,$y\n" if $self->{debug};
    return 0 if $node->place($x,$y,$cells);

    } # for all trial positions

  ##############################################################################
  # all simple possibilities exhausted, try a generic approach

  print STDERR "# No more simple possibilities for node $node->{name}\n" if $self->{debug};

  # If no predecessors/incoming edges, try to place in column 0, otherwise 
  # considered the node's rank, too

  my $col = 0; $col = $node->{rank} * 2 if @pre > 0;

  $col = $pre[0]->{x} if @pre > 0;
  
  # find the first free row
  my $y = 0;
  $y +=2 while (exists $cells->{"$col,$y"});
  $y += 1 if exists $cells->{"$col," . ($y-1)};		# leave one cell spacing

  # now try to place node (or node cluster)
  $y +=2 while (
   !$node->place($col,$y,$cells) ||
   ($self->_clear_tries($node, $cells, [ $col,$y ]) == 0));

  $node->{x} = $col; #$node->{y} = $y;

  0;							# success, score 0 
  }

sub _trace_path
  {
  # find a free way from $src to $dst (both need to be placed beforehand)
  my ($self, $src, $dst, $edge) = @_;

  print STDERR "# Finding path from $src->{name} to $dst->{name}\n" if $self->{debug};
  print STDERR "# src: $src->{x}, $src->{y} dst: $dst->{x}, $dst->{y}\n" if $self->{debug};

  my $coords = $self->_find_path ($src, $dst, $edge);

  # found no path?
  if (!defined $coords || scalar @$coords == 0)
    {
    print STDERR "# Unable to find path from $src->{name} ($src->{x},$src->{y}) to $dst->{name} ($dst->{x},$dst->{y})\n" if $self->{debug};
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
  
  return $cells->{$xy}->_make_cross($edge,$type & EDGE_FLAG_MASK)
    if ref($cells->{$xy}) && $cells->{$xy}->isa('Graph::Easy::Edge');

  my $path = Graph::Easy::Edge::Cell->new( type => $type, edge => $edge, x => $x, y => $y );
  $cells->{$xy} = $path;	# store in cells
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
