#############################################################################
# Layout directed graphs on a flat plane. Part of Graph::Easy.
#
# Code to repair spliced layouts (after group cells have been inserted).
#
# (c) by Tels 2004-2006.
#############################################################################

package Graph::Easy::Layout::Repair;

use vars qw/$VERSION/;

$VERSION = '0.01';

#############################################################################
#############################################################################
# for layouts with groups:

package Graph::Easy;

use strict;

sub _edges_into_groups
  {
  my $self = shift;

  # Put all edges between two nodes with the same group in the group as well
  for my $edge (values %{$self->{edges}})
    {
    my $gf = $edge->{from}->group();
    my $gt = $edge->{to}->group();

    $edge->add_to_group($gf) if defined $gf && defined $gt && $gf == $gt;
    }

  $self;
  }

sub _splice_nodes
  {
  # Splicing the rows/columns to add filler cells will have torn holes into
  # multi-edges nodes, so we insert additional filler cells.
  my ($self) = @_;
  my $cells = $self->{cells};

  # We might get away with not inserting filler cells if we just mark the
  # cells as used (e.g. use only one global filler cell) since filler cells
  # aren't actually rendered, anyway.

  for my $cell (values %$cells)
    {
    next unless $cell->isa('Graph::Easy::Node::Cell');

    # we have "[ empty  ] [ filler ]" (unless cell is on the same column as node)
    if ($cell->{x} > $cell->{node}->{x})
      {
      my $x = $cell->{x} - 1; my $y = $cell->{y}; 

#      print STDERR "# inserting filler at $x,$y for $cell->{node}->{name}\n";
      my $filler = Graph::Easy::Node::Cell->new( 
	    node => $cell->{node}, x => $x, y => $y );
      $cells->{"$x,$y"} = $filler;
      }

    # we have " [ empty ]  "
    #         " [ filler ] " (unless cell is on the same row as node)
    if ($cell->{y} > $cell->{node}->{y})
      {
      my $x = $cell->{x}; my $y = $cell->{y} - 1;

#      print STDERR "# inserting filler at $x,$y for $cell->{node}->{name}\n";
      my $filler = Graph::Easy::Node::Cell->new( 
	    node => $cell->{node}, x => $x, y => $y );
      $cells->{"$x,$y"} = $filler;
      }
    }
  }

sub _splice_edges
  {
  # Splicing the rows/columns to add filler cells might have torn holes into
  # edges, so we splice these together again.
  my ($self) = @_;

  my $cells = $self->{cells};

  # go over the old layout, because the new cells were inserted into odd
  # rows/columns and we do not care for these:
  for my $cell (sort { $a->{x} <=> $b->{x} || $a->{y} <=> $b->{y} } values %$cells)
    {
    next unless $cell->isa('Graph::Easy::Edge::Cell');

    #########################################################################
    # check for "[ --- ] [ empty  ] [ ---> ]"

    my $x = $cell->{x} + 2; my $y = $cell->{y}; 

    if (exists $cells->{"$x,$y"})
      {
      my $right = $cells->{"$x,$y"};

      # check that both cells belong to the same edge
      if ($right->isa('Graph::Easy::Edge::Cell') && $cell->{edge} == $right->{edge})
	{
        $x = $cell->{x} + 1;
  
        my $filler = 
	  Graph::Easy::Edge::Cell->new( 
	    type => EDGE_HOR(), 
	    edge => $cell->{edge}, x => $x, y => $y, after => $cell );
	$cells->{"$x,$y"} = $filler;
	}
      }
    
    
    #########################################################################
    # check for [ | ]
    #		[ empty ]
    #		[ | ]
    $x = $cell->{x}; $y = $cell->{y}+2; 

    next unless exists $cells->{"$x,$y"};

    my $below = $cells->{"$x,$y"};
    # check that both cells belong to the same edge
    next unless $below->isa('Graph::Easy::Edge::Cell') && $cell->{edge} == $below->{edge};

    $y = $cell->{y} + 1;

    my $filler = 
      Graph::Easy::Edge::Cell->new( 
	type => EDGE_VER(), 
	edge => $cell->{edge}, x => $x, y => $y, after => $cell );
    $cells->{"$x,$y"} = $filler;
    }

  }

sub _new_edge_cell
  {
  # create a new edge cell to be spliced into the layout for repairs
  my ($self, $cells, $group, $edge, $x, $y, $after, $type) = @_;

  my $e_cell = Graph::Easy::Edge::Cell->new( 
	  type => $type + EDGE_SHORT_CELL(), 
          edge => $edge, x => $x, y => $y, after => $after);
  $group->del_cell($e_cell);
  $cells->{"$x,$y"} = $e_cell;
  }

sub _new_edge_no_group_cell
  {
  # create a new edge cell to be spliced into the layout for repairs
  my ($self, $cells, $edge, $x, $y, $after, $type) = @_;

  my $e_cell = Graph::Easy::Edge::Cell->new( 
	  type => $type, edge => $edge, x => $x, y => $y, after => $after);
  $cells->{"$x,$y"} = $e_cell;
  }

sub _repair_group_edge
  {
  my ($self, $cell, $rows, $cols, $group) = @_;

  my $cells = $self->{cells};
  my ($x,$y,$doit);

  # repair an edge inside a group

  #########################################################################
  # check for " [ empty ] [ |---> ]"
  $x = $cell->{x} - 1; $y = $cell->{y};

  # go over all cells in the "empty" col and check whether there are group
  # fillers in it that are not "gt" or "gb"
  $doit = 0;
  for my $r (values %{$cols->{$x}})
    {
    $doit = 1, last if exists $r->{cell_class} && $r->{cell_class} =~ /g. g/;	# "gt gr" etc
    }

  # has start flag and is hor edge piece
  if ( $doit &&
	(($cell->{type} & EDGE_START_MASK) == EDGE_START_W))
    {
    # delete the start flag on the edge pice
    $cell->{type} &= ~ EDGE_START_MASK;

    $self->_new_edge_cell($cells, $group, $cell->{edge}, $x, $y, 0, 
	EDGE_HOR() + EDGE_START_W() ); 
    }

  #########################################################################
  # check for " [ --> ] [ empty ]"
  $x = $cell->{x} + 1;

  # go over all cells in the "empty" col and check whether there are group
  # fillers in it that are not "gt" or "gb"
  $doit = 0;
  for my $r (values %{$cols->{$x}})
    {
    $doit = 1, last if exists $r->{cell_class} && $r->{cell_class} =~ /g. g/;	# "gt gr" etc
    }

  # has end flag and is hor edge piece
  if ( $doit &&
	(($cell->{type} & EDGE_END_MASK) == EDGE_END_E))
    {
    # delete the end flag on the edge pice
    $cell->{type} &= ~ EDGE_END_MASK;

    $self->_new_edge_cell($cells, $group, $cell->{edge}, $x, $y, -1, 
	EDGE_HOR() + EDGE_END_E() ); 
    }

  #########################################################################
  # check for [empty] 
  #           [ |\n|\n ]
  $x = $cell->{x}; $y = $cell->{y} - 1;

  # go over all cells in the "empty" row and check whether there are group
  # fillers in it that are not "gt" or "gb"
  $doit = 0;
  for my $r (values %{$rows->{$y}})
    {
    $doit = 1, last if exists $r->{cell_class} && $r->{cell_class} =~ /g. g/;	# "gt gr" etc
    }

  # has start flag and is ver edge piece
  if ( $doit &&
	(($cell->{type} & EDGE_START_MASK) == EDGE_START_N))
    {
    # delete the start flag on the edge pice
    $cell->{type} &= ~ EDGE_START_MASK;

    $self->_new_edge_cell($cells, $group, $cell->{edge}, $x, $y, 0, 
	EDGE_VER() + EDGE_START_N() );
    }

  #########################################################################
  # check for [ |\n|\nv ]
  #           [empty] 
  $x = $cell->{x}; $y = $cell->{y} + 1;

  # go over all cells in the "empty" row and check whether there are group
  # fillers in it that are not "gt" or "gb"
  $doit = 0;
  for my $r (values %{$rows->{$y}})
    {
    $doit = 1, last if exists $r->{cell_class} && $r->{cell_class} =~ /g. g/;	# "gt gr" etc
    }

  # has end flag and is hor edge piece
  if ( $doit &&
	(($cell->{type} & EDGE_END_MASK) == EDGE_END_S))
    {
    # delete the start flag on the edge pice
    $cell->{type} &= ~ EDGE_END_MASK;

    $self->_new_edge_cell($cells, $group, $cell->{edge}, $x, $y, -1, 
	EDGE_VER() + EDGE_END_S() ); 
    }

  }

sub _repair_edge
  {
  # repair a edge outside a group
  my ($self, $cell, $rows, $cols) = @_;

  my $cells = $self->{cells};
  my ($x,$y,$doit);

  #########################################################################
  # check for [ |\n|\nv ]
  #	        [empty]	... [non-empty]
  #	        [node]

  $x = $cell->{x}; $y = $cell->{y} + 1;

  my $below = $cells->{"$x,$y"}; 		# must be empty

  if  (!ref($below) && (($cell->{type} & EDGE_END_MASK) == EDGE_END_S))
    {
    # go over all cells in the "empty" row and check whether there are any
    # cells in it
    $doit = 0;
    for my $r (values %{$rows->{$y}})
      {
      $doit = 1, last if exists $r->{cell_class} && $r->{cell_class} =~ /g. g/;	# "gt gr" etc
      }

    # has end flag and is ver edge piece
    if ($doit)
      {
      # delete the start flag on the edge pice
      $cell->{type} &= ~ EDGE_END_MASK;

      $self->_new_edge_no_group_cell($cells, $cell->{edge}, $x, $y, -1, 
          EDGE_VER() + EDGE_END_S() );
      }
    }
  # XXX TODO: do the other ends (END_N, END_W, END_E), too

  }

sub _repair_edges
  {
  # fix edge end/start cells to be closer to the node cell they point at
  my ($self, $rows, $cols) = @_;

  my $cells = $self->{cells};

  # go over all existing cells
  for my $cell (sort { $a->{x} <=> $b->{x} || $a->{y} <=> $b->{y} } values %$cells)
    {
    next unless $cell->isa('Graph::Easy::Edge::Cell');

    my $group = $cell->group();

    $self->_repair_edge($cell,$rows,$cols) unless $group;
    $self->_repair_group_edge($cell,$rows,$cols,$group) if $group;

    } # end for all cells
  }

sub _fill_group_cells
  {
  # after doing a layout(), we need to add the group to each cell based on
  # what group the nearest node is in.
  my ($self, $cells_layout) = @_;

  print STDERR "\n# Padding with fill cells, have ", 
    scalar $self->groups(), " groups.\n" if $self->{debug};

  # take a shortcut if we do not have groups
  return $self if $self->groups == 0;

  $self->_edges_into_groups();

  $self->{padding_cells} = 1;		# set to true

  # We need to insert "filler" cells around each node/edge/cell:

  # To "insert" the filler cells, we simple multiply each X and Y by 2, this
  # is O(N) where N is the number of actually existing cells. Otherwise we
  # would have to create the full table-layout, and then insert rows/columns.
  my $cells = {};
  for my $key (keys %$cells_layout)
    {
    my ($x,$y) = split /,/, $key;
    my $cell = $cells_layout->{$key};

    $x *= 2;
    $y *= 2;
    $cell->{x} = $x;
    $cell->{y} = $y;

    $cells->{"$x,$y"} = $cell; 
    }

  $self->{cells} = $cells;		# override with new cell layout

  $self->_splice_edges();		# repair edges
  $self->_splice_nodes();		# repair multi-celled nodes

  my $c = 'Graph::Easy::Group::Cell';
  for my $cell (values %{$self->{cells}})
    {
    # DO NOT MODIFY $cell IN THE LOOP BODY!

    my ($x,$y) = ($cell->{x},$cell->{y});

    # find the primary node for node cells, for group check
    my $group = $cell->group();

    # not part of group, so no group-cells nec.
    next unless $group;

    # now insert up to 8 filler cells around this cell
    my $ofs = [ -1, 0,
		0, -1,
		+1, 0,
		+1, 0,
		0, +1,
		0, +1,
		-1, 0,
		-1, 0,  ];
    while (@$ofs > 0)
      {
      $x += shift @$ofs;
      $y += shift @$ofs;

      $cells->{"$x,$y"} = $c->new ( graph => $self, group => $group, x => $x, y => $y )
        unless exists $cells->{"$x,$y"};
      }
    }

  # Nodes positioned two cols/rows apart (f.i. y == 0 and y == 2) will be
  # three cells apart (y == 0 and y == 4) after the splicing, the step above
  # will not be able to close that hole - it will create fillers at y == 1 and
  # y == 3. So we close these holes now with an extra step.
  for my $cell (values %{$self->{cells}})
    {
    # only for filler cells
    next unless $cell->isa('Graph::Easy::Group::Cell');

    my ($sx,$sy) = ($cell->{x},$cell->{y});
    my $group = $cell->{group};

    my $x = $sx; my $y2 = $sy + 2; my $y = $sy + 1;
    # look for:
    # [ group ]
    # [ empty ]
    # [ group ]
    if (exists $cells->{"$x,$y2"} && !exists $cells->{"$x,$y"})
      {
      my $down = $cells->{"$x,$y2"};
      if ($down->isa('Graph::Easy::Group::Cell') && $down->{group} == $group)
        {
	$cells->{"$x,$y"} = $c->new ( graph => $self, group => $group, x => $x, y => $y );
        }
      }
    $x = $sx+1; my $x2 = $sx + 2; $y = $sy;
    # look for:
    # [ group ]  [ empty ]  [ group ]
    if (exists $cells->{"$x2,$y"} && !exists $cells->{"$x,$y"})
      {
      my $right = $cells->{"$x2,$y"};
      if ($right->isa('Graph::Easy::Group::Cell') && $right->{group} == $group)
        {
	$cells->{"$x,$y"} = $c->new ( graph => $self, group => $group, x => $x, y => $y );
        }
      }
    }

  # XXX TODO
  # we should "grow" the group area to close holes

  # for all group cells, set their right type (for border) depending on
  # neighbour cells
  for my $cell (values %$cells)
    {
    $cell->_set_type($cells) if $cell->isa('Graph::Easy::Group::Cell');
    }

  # create a mapping for each row/column so that we can repair edge starts/ends
  my $rows = {};
  my $cols = {};
  for my $cell (values %$cells)
    {
    $rows->{$cell->{y}}->{$cell->{x}} = $cell;
    $cols->{$cell->{x}}->{$cell->{y}} = $cell;
    }
  $self->_repair_edges($rows,$cols);	# insert short edge cells on group
					# border rows/columns

  # for all groups, set the cell carrying the label (top-left-most cell)
  for my $group (values %{$self->{groups}})
    {
    $group->_find_label_cell();
    }

# DEBUG:
# for my $cell (values %$cells)
#   { 
#   $cell->_correct_size();
#   }
#
# my $y = 0;
# for my $cell (sort { $a->{y} <=> $b->{y} || $a->{x} <=> $b->{x} } values %$cells)
#   {
#  print STDERR "\n" if $y != $cell->{y};
#  print STDERR "$cell->{x},$cell->{y}, $cell->{w},$cell->{h}, ", $cell->{group}->{name} || 'none', "\t";
#   $y = $cell->{y};
#  }
# print STDERR "\n";

  $self;
  }

1;
__END__

=head1 NAME

Graph::Easy::Layout::Repair - Repair spliced layout with group cells

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

C<Graph::Easy::Layout::Repair> contains code that can splice in
group cells into a layout, as well as repair the layout after that step.

It is part of L<Graph::Easy|Graph::Easy> and used automatically.

=head1 METHODS

C<Graph::Easy::Layout> injects the following methods into the C<Graph::Easy>
namespace:

=head2 _edges_into_groups()

Put the edges into the appropriate group and class.

=head2 _assign_ranks()

	$graph->_assign_ranks();

=head2 _splice_nodes()

Splicing the rows/columns to add filler cells will have torn holes into
multi-edges nodes, so we insert additional filler cells to repair this.

=head2 _splice_edges()

Splicing the rows/columns to add filler cells might have torn holes into
multi-celled edges, so we splice these together again.

=head2 _repair_edges()


Splicing the rows/columns to add filler cells might have put "holes"
between an edge start/end and the node cell it points to. This
routine fixes this problem by extending the edge by one cell if
necessary.

=head2 _fill_group_cells()

After doing a C<layout()>, we need to add the group to each cell based on
what group the nearest node is in.

This routine will also find the label cell for each group, and repair
edge/node damage done by the splicing.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
