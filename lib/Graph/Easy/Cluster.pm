#############################################################################
# (c) by Tels 2004-2005. A cluster of relativ positioned nodes.
# Part of Graph::Easy.
#
#############################################################################

package Graph::Easy::Cluster;

use 5.006001;
use strict;

use vars qw/$VERSION @ISA/;
use Graph::Easy::Node;

@ISA = qw/Graph::Easy::Node/;
$VERSION = '0.05';

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
 
  $self->{name} = 'Cluster #' . $self->{id};

  # XXX TODO check arguments
  foreach my $k (keys %$args)
    {
    $self->{$k} = $args->{$k};
    }
  
  # list of nodes that belong to that cluster
  $self->{nodes} = {};
  $self->{error} = '';
  $self->{graph} = undef;

  $self;
  }

#############################################################################
# accessor methods

sub nodes
  {
  # return all nodes in cluster
  my $self = shift;

  ( values %{$self->{nodes}} );
  }

#############################################################################
# node handling

sub add_node
  {
  my ($self,$n) = @_;
 
  if (ref($n) !~ /^Graph::Easy::Node/)
    {
    require Carp;
    Carp::croak("Cannot add non-node $n to cluster");
    }
  $self->{nodes}->{ $n->{name} } = $n;

  $n->_add_to_cluster($self);

  $self;
  }

sub add_nodes
  {
  # add one or more nodes to the cluster
  my $self = shift;

  foreach my $n (@_)
    {
    if (ref($n) !~ /^Graph::Easy::Node/)
      {
      require Carp;
      Carp::croak("Cannot add non-node $n to cluster");
      }
    $self->{nodes}->{ $n->{name} } = $n;
    $n->_add_to_cluster($self);
    }
  $self;
  }

sub center_node
  {
  # set the passed node as the center of the cluster
  my ($self) = shift;

  if ($_[0])
    {
    # add the node to ourself (in case it wasn't already)
    my $node = shift;
    $self->add_node($node) unless exists $self->{nodes}->{ $node->{name} };
    $self->{center_node} = $node; 
    }
  $self->{center_node}; 
  }

1;
__END__

=head1 NAME

Graph::Easy::Cluster - Nodes positioned relatively to each other

=head1 SYNOPSIS

        use Graph::Easy::Cluster;

	my $bonn = Graph::Easy::Node->new(
		name => 'Bonn',
		border => 'solid 1px black',
		pos => '0,0',
	);
	my $berlin = Graph::Easy::Node->new(
		name => 'Berlin',
		pos => '1,0',
	);
	my $cities = Graph::Easy::Cluster->new();

	$cities->add_node ($bonn);
	# $bonn will be ONCE in the group
	$cities->add_nodes ($bonn, $berlin);
	$cities->set_center($bonn);

=head1 DESCRIPTION

A C<Graph::Easy::Cluster> represents a group of nodes that are all
positioned relatively to each other.

=head1 METHODS

=head2 new()

	my $cluster = Graph::Easy::Group->new( $options );

Create a new, empty cluster. C<$options> are the possible options, see
L<Graph::Easy::Node> for a list. At least an unique C<name> should be passed
as option.

=head2 error()

	$last_error = $group->error();

	$group->error($error);			# set new messags
	$group->error('');			# clear error

Returns the last error message, or '' for no error.

=head2 name()

	my $name = $cluster->name();

Return the name of the cluster.

=head2 nodes()

	my @nodes = $cluster->nodes();

Return all nodes in the cluster.

=head2 center_node()

	my $center = $cluster->center_node();
	$cluster->center_node($new_center);

Get or set the center node. All other nodes will be positioned relatively
to the position of the center node.

=head2 add_node()

	$cluster->add_node( $node );

Add one node to the cluster.

Note: You need to call C<$node->add_to_cluster($cluster)> afterwards, too.

=head2 add_nodes()

	$cluster->add_nodes( @nodes );

Add one or more nodes to the cluster.

Note: You need to call C<$node->add_to_cluster($cluster)> for each node, too.

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for more details.

=cut
