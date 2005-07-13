#############################################################################
# Path and cell management for Graph::Easy.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Layout::Path;

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

package Graph::Easy::Node;

sub _near_places
  {
  # Take a node and return a list of possible placements around it
  # prunes out already occupied cells.
  my ($n, $cells) = @_;

  my $cx = $n->{cx} || 1;
  my $cy = $n->{cy} || 1;
  
  my @places = ();

  if ($cx + $cy == 2)
    {
    my @tries  = (
  	$n->{x} + 2, $n->{y},		# right
	$n->{x}, $n->{y} + 2,		# down
	$n->{x} - 2, $n->{y},		# left
	$n->{x}, $n->{y} - 2,		# up
      );

    while (@tries > 0)
      {
      my $x = shift @tries;
      my $y = shift @tries;
      # This quick check does not take node clusters or multi-celled nodes
      # into account. These are handled in $node->place() later.
      next if exists $cells->{"$x,$y"};
      push @places, $x, $y;
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

  # right
  for my $y (0 .. $cy-1)
    {
    $py = $y + $ny;
    $px = $nx + $cx + 1;
    push @places, $px, $py unless exists $cells->{"$px,$py"};
    }

  # below
  for my $x (0 .. $cx-1)
    {
    $px = $x + $nx;
    $py = $ny + $cy + 1;
    push @places, $px, $py unless exists $cells->{"$px,$py"};
    }

  # left
  for my $y (0 .. $cy-1)
    {
    $py = $y + $ny;
    $px = $nx - 1;
    push @places, $px, $py unless exists $cells->{"$px,$py"};
    }

  # top
  for my $x (0 .. $cx-1)
    {
    $px = $x + $nx;
    $py = $ny - 1;
    push @places, $px, $py unless exists $cells->{"$px,$py"};
    }

  @places;
  }

package Graph::Easy;

sub _find_node_place
  {
  # Try to place a node (or node cluster). Return score (usually 0).
  my ($self, $cells, $node) = @_;

  print STDERR "# Finding place for $node->{name}\n" if $self->{debug};

  # try to place node at upper left corner
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
	  @tries = ( $pre[0]->{x}, $pre[0]->{y} + $dy / 2 );
          }
        else
          {
	  @tries = ( $pre[0]->{x} + $dx / 2, $pre[0]->{y} );
          }
        }
      # In addition, we can also try to place the node around the
      # different nodes:
      foreach $node (@pre)
        {
        push @tries, $node->_near_places($cells);
        }
      }
    }
  elsif (@pre == 0)
    {
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

  # no try to place node (or node cluster)
  $y +=2 while (! $node->place($col,$y,$cells));

  0;							# success, score 0 
  }

sub _trace_path
  {
  # find a free way from $src to $dst (both need to be placed)
  my ($self, $src, $dst, $edge) = @_;

  my $cells = $self->{cells};
  my $mod = 0;

  print STDERR "# Finding path from $src->{name} to $dst->{name}\n" if $self->{debug};

  print STDERR "# src: $src->{x}, $src->{y} dst: $dst->{x}, $dst->{y}\n" if $self->{debug};

  #my ($dx,$dy,@coords) = $self->_find_path ($src, $dst);
  my @coords = $self->_find_path ($src, $dst);

  # fond a path, so compute a score
  if (@coords != 0)
    {
    $mod = 1;				# for straight paths: score +1
    $mod++ if @coords == 1;		# for short paths: score +1

    if ($src->{x} == $dst->{x}-2 && $src->{y} == $dst->{y})
      {
      $mod += 2;			# +2 if right
      }
   elsif ($src->{x} == $dst->{x} && $src->{y} == $dst->{y} - 2)
      {
      $mod += 1;			# +1 if down
      }

#   my $edge = $self->edge($src,$dst);

   # Create all cells like "start" cell, "end" cell and intermidiate pieces
   foreach my $coord (@coords)
     {
     $self->_create_cell($edge,$coord);
     }
    }
  else
    {
    # XXX TODO
    print STDERR "# Unable to find path from $src->{name} ($src->{x},$src->{y}) to $dst->{name} ($dst->{x},$dst->{y})\n";
    sleep(1);
    return undef;
    }
  $mod;
  }

sub _create_cell
  {
  my ($self,$edge,$coord) = @_;

  my ($x,$y,$type) = split /,/, $coord;

  # XXX TODO: set the label of the cell_
  if ($type & EDGE_LABEL_CELL != 0)
    {
    }
  $type &= ~EDGE_LABEL_CELL;

  my $path = Graph::Easy::Edge::Cell->new( type => $type, edge => $edge, x => $x, y => $y );
  $path->{graph} = $self;		# register path elements with ourself
  $self->{cells}->{"$x,$y"} = $path;	# store in cells
  }

sub _remove_path
  {
  # Take an edge, and remove all the cells it covers from the cells area
  my ($self, $edge) = @_;

  my $cells = $self->{cells};
  my $covered = $edge->cells();

  for my $key (keys %$covered)
    {
    # XXX TODO: handle crossed edges here differently (from CROSS => HOR
    # or VER)
    # free in our cells area
    delete $cells->{$key};
    }
  $edge->clear_cells();
  }

sub _path_is_clear
  {
  # For all points (x,y pairs) in the path, check that the cell is still free
  # $path points to a list of [ [x,y,type], [x,y,type], ...]
  my ($self,$path) = @_;

  my $cells = $self->{cells};
  foreach my $elem (@$path)
    {
    my ($x,$y,$type);

    ($x,$y,$type) = split(/,/,$elem) if ref($elem) ne 'ARRAY';
    ($x,$y,$type) = @$elem if ref($elem) eq 'ARRAY';

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
