#############################################################################
# (c) by Tels 2004. A group of nodes. Part of Graph::Easy
#
#############################################################################

package Graph::Easy::Group;

use strict;
use vars qw/$VERSION @ISA/;
use Graph::Easy::Group::Cell;
use Graph::Easy::Node;

@ISA = qw/Graph::Easy::Node/;
$VERSION = '0.07';

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{name} = 'Group #'. $self->{id};
  $self->{label} = '';
  $self->{class} = 'group';
  $self->{cells} = {};

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

  $self;
  }

sub as_txt
  {
  my $self = shift;

  require Graph::Easy::As_txt;

  my $n = $self->{name};
  # quote special chars in name
  $n =~ s/([\[\]\(\)\{\}\#])/\\$1/g;

  my $txt = "( $n\n";
  
  $n = $self->{nodes};
    
  for my $name ( sort keys %$n )
    {
    $n->{$name}->{_p} = 1;				# mark as processed
    $txt .= '  ' . $n->{$name}->as_pure_txt() . "\n";
    }
  $txt .= ")" . $self->attributes_as_txt() . "\n\n";
  }

#############################################################################
# accessor methods

sub name
  {
  my $self = shift;

  $self->{name};
  }

sub nodes
  {
  my $self = shift;

  ( values %{$self->{nodes}} );
  }

sub edges
  {
  my $self = shift;

  ( values %{$self->{edges}} );
  }

#############################################################################

sub set_attribute
  {
  my ($self, $atr, $v, $class) = @_;

  $self->SUPER::set_attribute($atr,$v, $class);

  # if defined attribute "nodeclass", put our nodes into that class
  if ($atr eq 'nodeclass')
    {
    my $class = $self->{att}->{nodeclass};
    for my $node (values %{ $self->{nodes} } )
      {
      $node->sub_class($class);
      }
    }
  $self;
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

  my $class = 'nodes'; $class = 'edges' if $n->isa('Graph::Easy::Edge');
  $self->{$class}->{ $n->{name} } = $n;

  # nodes => nodeclass, edges => edgeclass
  $class =~ s/s\z/class/;

  # if defined attribute "nodeclass", put our nodes into that class
  $n->sub_class($self->{att}->{$class}) if exists $self->{att}->{$class};

  # register ourselves with the member
  $n->{group} = $self;

  $self;
  }

sub del_member
  {
  # delete an edge or node from this group
  my ($self,$n) = @_;

  my $class = 'nodes'; $class = 'edges' if $n->isa('Graph::Easy::Edge');

  delete $self->{$class}->{ $n->{name} };

  $self;
  }

sub del_node
  {
  # delete a node from this group
  my ($self,$n) = @_;

  delete $self->{nodes}->{ $n->{name} };

  $self;
  }

sub del_edge
  {
  # delete an edge from this group
  my ($self,$n) = @_;

  delete $self->{edges}->{ $n->{name} };

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

sub add_nodes
  {
  my $self = shift;

  foreach my $n (@_)
    {
    if (!ref($n) || ref($n) =~ /Graph::Easy::Group/)
      {
      require Carp;
      Carp::confess("Cannot add non-object or group $n as node to group '$self->{name}'");
      }
    $self->{nodes}->{ $n->{name} } = $n;
    }
  $self;
  }

sub cells
  {
  # return all the cells this group currently occupies
  my $self = shift;

  $self->{cells};
  }

sub clear_cells
  {
  # remove all belonging cells
  my $self = shift;

  $self->{cells} = {};

  $self;
  }

sub add_cell
  {
  # add a cell to the list of cells this group covers
  my ($self,$cell) = @_;

  $self->{cells}->{"$cell->{x},$cell->{y}"} = $cell;
  }

1;
__END__

=head1 NAME

Graph::Easy::Group - Represents a group of nodes in a simple graph

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

A C<Graph::Easy::Node> represents a node in a simple graph. Each
node has contents (a text, an image or another graph), and dimension plus
an origin. The origin is typically determined by a graph layouter module
like L<Graph::Easy>.

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

Add the specified node or edge to this group.

=head2 add_node()

	$group->add_node($node);

Add the specified node to this group.

=head2 add_edge()

	$group->add_edge($edge);

Add the specified edge to this group.

=head2 del_member()

	$group->del_member($node);
	$group->del_member($edge);

Delete the specified node or edge from this group.

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

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for more details.

=cut
