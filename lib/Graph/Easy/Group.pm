#############################################################################
# A group of nodes. Part of Graph::Easy.
#
#############################################################################

package Graph::Easy::Group;

use Graph::Easy::Group::Cell;
use Graph::Easy;
use Scalar::Util qw/weaken/;

@ISA = qw/Graph::Easy::Node Graph::Easy/;
$VERSION = '0.18';

use strict;

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{name} = 'Group #'. $self->{id};
  $self->{class} = 'group';
  $self->{_cells} = {};				# the Group::Cell objects
  $self->{cx} = 1;
  $self->{cy} = 1;

  foreach my $k (keys %$args)
    {
    if ($k !~ /^(graph|name)\z/)
      {
      require Carp;
      Carp::confess ("Invalid argument '$k' passed to Graph::Easy::Group->new()");
      }
    $self->{$k} = $args->{$k};
    }
  
  $self->{nodes} = {};
  $self->{groups} = {};
  $self->{att} = {};

  $self;
  }

#############################################################################
# accessor methods

sub nodes
  {
  my $self = shift;

  wantarray ? ( values %{$self->{nodes}} ) : scalar keys %{$self->{nodes}};
  }

sub edges
  {
  my $self = shift;

  wantarray ? ( values %{$self->{edges}} ) : scalar keys %{$self->{edges}};
  }

#############################################################################

sub set_attribute
  {
  my ($self, $name, $val, $class) = @_;

  $self->SUPER::set_attribute($name, $val, $class);

  # if defined attribute "nodeclass", put our nodes into that class
  if ($name eq 'nodeclass')
    {
    my $class = $self->{att}->{nodeclass};
    for my $node (values %{ $self->{nodes} } )
      {
      $node->sub_class($class);
      }
    }
  $self;
  }

sub shape
  {
  '';
  }

#############################################################################
# node handling

sub add_node
  {
  # add a node to this group
  my ($self,$n) = @_;

  if (!ref($n) || !$n->isa("Graph::Easy::Node"))
    {
    require Carp;
    Carp::confess("Cannot add non node-object $n to group '$self->{name}'");
    }
  $self->{nodes}->{ $n->{name} } = $n;

  # if defined attribute "nodeclass", put our nodes into that class
  $n->sub_class($self->{att}->{nodeclass}) if exists $self->{att}->{nodeclass};

  # register ourselves with the member
  $n->{group} = $self;

  $self;
  }

sub add_member
  {
  # add an edge or node to this group
  my ($self,$n) = @_;
 
  if (!ref($n) || !$n->isa("Graph::Easy::Node"))
    {
    require Carp;
    Carp::confess("Cannot add non node-object $n to group '$self->{name}'");
    }

  return $self->add_group($n) if $n->isa('Graph::Easy::Group');

  my $class = 'nodes'; my $key = 'name';
  if ($n->isa('Graph::Easy::Edge'))
    {
    $class = 'edges'; $key = 'id';
    }
  $self->{$class}->{ $n->{$key} } = $n;

  # nodes => nodeclass, edges => edgeclass
  $class =~ s/s\z/class/;

  # if defined attribute "nodeclass", put our nodes into that class
  my $cl = $self->attribute($class) || '';
  $n->sub_class($cl) if $cl ne '';

  # register ourselves with the member
  $n->{group} = $self;

  $self;
  }

sub del_member
  {
  # delete an edge or node from this group
  my ($self,$n) = @_;

  my $class = 'nodes'; my $key = 'name';
  if ($n->isa('Graph::Easy::Edge'))
    {
    $class = 'edges'; $key = 'id';
    }
  delete $self->{$class}->{ $n->{$key} };
  delete $n->{group};			# unregister us

  if ($n->isa('Graph::Easy::Node'))
    {
    # find all edges that mention this node and drop them from the group
    my $edges = $self->{edges};
    for my $e (values %$edges)
      {
      delete $edges->{ $e->{id} } if $e->{from} == $n || $e->{to} == $n;
      }
    }

  $self;
  }

sub del_node
  {
  # delete a node from this group
  my ($self,$n) = @_;

  delete $self->{nodes}->{ $n->{name} };
  delete $n->{group};			# unregister us

  # find all edges that mention this node and drop them from the group
  my $edges = $self->{edges};
  for my $e (values %$edges)
    {
    delete $edges->{ $e->{id} } if $e->{from} == $n || $e->{to} == $n;
    }

  $self;
  }

sub add_nodes
  {
  my $self = shift;

  foreach my $n (@_)
    {
    if (!ref($n) || $n->isa('Graph::Easy::Group'))
      {
      require Carp;
      Carp::confess("Cannot add non-object or group $n as node to group '$self->{name}'");
      }
    $self->{nodes}->{ $n->{name} } = $n;
    }
  $self;
  }

#############################################################################

sub del_edge
  {
  # delete an edge from this group
  my ($self,$e) = @_;

  delete $self->{edges}->{ $e->{id} };
  delete $e->{group};			# unregister us

  $self;
  }

sub add_edge
  {
  # add an edge to this group
  my ($self,$e) = @_;

  if (!ref($e) || !$e->isa("Graph::Easy::Edge"))
    {
    require Carp;
    Carp::confess("Cannot add non edge-object $e to group '$self->{name}'");
    }
  $self->{edges}->{ $e->{id} } = $e;

  # if defined attribute "edgeclass", put our edges into that class
  $e->sub_class($self->{att}->{edgeclass}) if exists $self->{att}->{edgeclass};
 
  $self;
  }

#############################################################################

sub add_group
  {
  # add a group to us
  my ($self,$group) = @_;

  my $uc = $self->{use_class};

  # group with that name already exists?
  my $name = $group;
  $group = $self->{groups}->{ $group } unless ref $group;

  # group with that name doesn't exist, so create new one
  $group = $uc->{group}->new( name => $name ) unless ref $group;

  # index under the group name for easier lookup
  $self->{groups}->{ $group->{name} } = $group;

  # make attribute->('group') work
  $group->{att}->{group} = $self->{name};

  # register group with the graph and ourself
  $group->{graph} = $self->{graph};
  $group->{group} = $self;
  {
    no warnings; # dont warn on already weak references
    weaken($group->{graph});
    weaken($group->{group});
  }
  $self->{graph}->{score} = undef;		# invalidate last layout

  $group;
  }

sub cells
  {
  # return all the cells this group currently occupies
  my $self = shift;

  $self->{_cells};
  }

sub clear_cells
  {
  # remove all belonging cells
  my $self = shift;

  $self->{_cells} = {};

  $self;
  }

sub add_cell
  {
  # add a cell to the list of cells this group covers
  my ($self,$cell) = @_;

  $cell->_update_boundaries();
  $self->{_cells}->{"$cell->{x},$cell->{y}"} = $cell;
  $cell;
  }

sub del_cell
  {
  # delete a cell from the list of cells this group covers
  my ($self,$cell) = @_;

  delete $self->{_cells}->{"$cell->{x},$cell->{y}"};
  delete $cell->{group};

  $self;
  }

sub _find_label_cell
  {
  # go through all cells of this group and find one where to attach the label
  my $self = shift;

  my $g = $self->{graph};

  my $align = $self->attribute('align') || 'left';

  my $lc;						# the label cell

  for my $c (values %{$self->{_cells}})
    {
    # find a cell where to put the label
    next unless $c->{cell_class} =~ /^\s*gt\s*\z/;

    if (defined $lc)
      {
      if ($align eq 'left')
	{
	# find top-most, left-most cell
	next if $lc->{x} < $c->{x} || $lc->{y} < $c->{y};
	}
      elsif ($align eq 'center')
	{
	# just find any top-most cell
	next if $lc->{y} < $c->{y};
	}
      elsif ($align eq 'right')
	{
	# find top-most, right-most cell
	next if $lc->{x} > $c->{x} || $lc->{y} < $c->{y};
	}
      }  
    $lc = $c;
    }

  # find the cell mostly near the center in the found top-row
  if (ref($lc) && $align eq 'center')
    {
    my ($left, $right);
    # find left/right most coordinates
    for my $c (values %{$self->{_cells}})
      {
      next if $c->{y} != $lc->{y};
      $left = $c->{x} if !defined $left || $left > $c->{x};  
      $right = $c->{x} if !defined $right || $right < $c->{x};
      }
    my $center = int(($right - $left) / 2 + $left);
    my $min_dist;
    # find the cell mostly near the center in the found top-row
    for my $c (values %{$self->{_cells}})
      {
      next if $c->{y} != $lc->{y};
      # squared to get rid of sign
      my $dist = ($center - $c->{x}); $dist *= $dist;
      next if defined $min_dist && $dist > $min_dist;
      $min_dist = $dist; $lc = $c;
      }
    }

  print STDERR "# Setting label for group '$self->{name}' at $lc->{x},$lc->{y}\n"
	if $self->{debug};

  $lc->_set_label() if ref($lc);
  }

sub layout
  {
  my $self = shift;

  $self->_croak('Cannot call layout() on a Graph::Easy::Group directly.');
  }

sub _layout
  {
  my $self = shift;

  ###########################################################################
  # set local {debug} for groups
  local $self->{debug} = $self->{graph}->{debug};

  $self->SUPER::_layout();
  }

sub _set_cell_types
  {
  my ($self, $cells) = @_;

  # Set the right cell class for all of our cells:
  for my $cell (values %{$self->{_cells}})
    {
    $cell->_set_type($cells);
    }
 
  $self;
  }

1;
__END__

=head1 NAME

Graph::Easy::Group - A group of nodes (aka subgraph) in Graph::Easy

=head1 SYNOPSIS

        use Graph::Easy;

        my $bonn = Graph::Easy::Node->new('Bonn');

        $bonn->set_attribute('border', 'solid 1px black');

        my $berlin = Graph::Easy::Node->new( name => 'Berlin' );

	my $cities = Graph::Easy::Group->new(
		name => 'Cities',
	);
        $cities->set_attribute('border', 'dashed 1px blue');

	$cities->add_nodes ($bonn);
	# $bonn will be ONCE in the group
	$cities->add_nodes ($bonn, $berlin);


=head1 DESCRIPTION

A C<Graph::Easy::Group> represents a group of nodes in an C<Graph::Easy>
object. These nodes are grouped together on output.

=head1 METHODS

=head2 new()

	my $group = Graph::Easy::Group->new( $options );

Create a new, empty group. C<$options> are the possible options, see
L<Graph::Easy::Node> for a list.

=head2 error()

	$last_error = $group->error();

	$group->error($error);			# set new messags
	$group->error('');			# clear error

Returns the last error message, or '' for no error.

=head2 as_ascii()

	my $ascii = $group->as_ascii();

Return the group as a little box drawn in ASCII art as a string.

=head2 name()

	my $name = $group->name();

Return the name of the group.

=head2 id()

	my $id = $group->id();

Returns the group's unique ID number.

=head2 set_attribute()

        $group->set_attribute('border-style', 'none');

Sets the specified attribute of this (and only this!) group to the
specified value.

=head2 add_member()

	$group->add_member($node);
	$group->add_member($edge);
	$group->add_member($group);

Add the specified object to this group.

Note that each object can only be a member of one group at a time.

=head2 add_node()

	$group->add_node($node);

Add the specified node to this group.

Note that each object can only be a member of one group at a time.

=head2 add_edge()

	$group->add_edge($edge);

Add the specified edge to this group.

Note that each object can only be a member of one group at a time.

=head2 add_group()

	my $inner = $group->add_group('Group name');
	my $nested = $group->add_group($group);

Add a group as subgroup to this group.

=head2 del_member()

	$group->del_member($node);
	$group->del_member($edge);
	$group->del_member($group);

Delete the specified object from this group.

=head2 del_node()

	$group->del_node($node);

Delete the specified node from this group.

=head2 del_edge()

	$group->del_edge($edge);

Delete the specified edge from this group.

=head2 add_nodes()

	$group->add_nodes($node, $node2, ... );

Add all the specified nodes to this group.

=head2 add_cell()

	$group->add_cell($cell);

Add a cell to the list of cells this group covers.

=head2 del_cell()

	$group->del_cell($cell);

Delete a cell from the list of cells this group covers.

=head2 cells()

	my @cells = $group->cells();

Returns a list of all cells that belong to this group.

=head2 nodes()

	my @nodes = $group->nodes();

Returns a list of all node objects that belong to this group.

=head2 edges()

	my @edges = $group->edges();

Returns a list of all edge objects that belong to this group.

=head2 clear_cells()

	$group->clear_cells();

Clears the cells associated with this group.

=head2 as_txt()

	my $txt = $group->as_txt();

Returns the group as Graph::Easy textual description.

=head2 _find_label_cell()

	$group->_find_label_cell();

Called by the layouter once for each group. Goes through all cells of this
group and finds one where to attach the label to. Internal usage only.

=head2 attribute related methods

You can call all the various attribute related methods like C<set_attribute()>,
C<get_attribute()>, etc. on a group, too. For example:

	$group->set_attribute('label', 'by train');
	my $attr = $group->get_attributes();

=head2 layout()

This routine should not be called on groups, it only works on the graph
itself.

=head2 shape()

	my $shape = $group->shape();

Returns the shape of the group as string.

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>, L<Graph::Easy::Node>, L<Graph::Easy::Manual>.

=head1 AUTHOR

Copyright (C) 2004 - 2007 by Tels L<http://bloodgate.com>

See the LICENSE file for more details.

=cut
