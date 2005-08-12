#############################################################################
# (c) by Tels 2004. A group of nodes. Part of Graph::Easy
#
#############################################################################

package Graph::Easy::Group;

use 5.006001;
use strict;

use vars qw/$VERSION @ISA/;
use Graph::Easy::Group::Cell;
use Graph::Easy::Node;

@ISA = qw/Graph::Easy::Node/;
$VERSION = '0.05';

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{border} = 'solid';
  $self->{name} = 'Group #'. $self->{id};
  $self->{label} = '';
  $self->{class} = 'group';
  $self->{cells} = {};

  # XXX TODO check arguments
  foreach my $k (keys %$args)
    {
    $self->{$k} = $args->{$k};
    }
  
  $self->{nodes} = {};
  $self->{error} = '';

  $self;
  }

sub as_txt
  {
  my $self = shift;

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

#############################################################################

sub set_attribute
  {
  my ($self, $atr, $v) = @_;

  $self->SUPER::set_attribute($atr,$v);

  # if defined attribute "nodeclass", put our nodes into that class
  if ($atr eq 'nodeclass')
    {
    for my $n (keys %{ $self->{nodes} } )
      {
      my $node = $self->{nodes}->{$n};
      $node->sub_class($self->{att}->{nodeclass});
      }
    }
  $self;
  }

#############################################################################
# node handling

sub add_node
  {
  my ($self,$n) = @_;
 
  if (!ref($n) || ref($n) =~ /Graph::Easy::Group/)
    {
    require Carp;
    Carp::croak("Cannot add non-object or group $n as node to group '$self->{name}'");
    }
  $self->{nodes}->{ $n->{name} } = $n;

  # if defined attribute "nodeclass", put our nodes into that class
  if (exists $self->{att}->{nodeclass})
    {
    $n->sub_class($self->{att}->{nodeclass});
    }
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
      Carp::croak("Cannot add non-object or group $n as node to group '$self->{name}'");
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

        use Graph::Easy::Group;

	my $bonn = Graph::Easy::Node->new(
		name => 'Bonn',
		border => 'solid 1px black',
	);
	my $berlin = Graph::Easy::Node->new(
		name => 'Berlin',
	);
	my $cities = Graph::Easy::Group->new(
		name => 'Cities',
	);

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

=head2 contents()

	my $contents = $node->contents();

For nested nodes, returns the contents of the node.

=head2 width()

	my $width = $node->width();

Returns the width of the node. This is a unitless number.

=head2 height()

	my $height = $node->height();

Returns the height of the node. This is a unitless number.

=head2 pos()

	my ($x,$y) = $node->pos();

Returns the position of the node. Initially, this is undef, and will be
set from C<Graph::Easy::layout>.

=head2 x()

	my $x = $node->x();

Returns the X position of the node. Initially, this is undef, and will be
set from C<Graph::Easy::layout>.

=head2 y()

	my $y = $node->y();

Returns the Y position of the node. Initially, this is undef, and will be
set from C<Graph::Easy::layout>.

=head2 id()

	my $id = $node->id();

Returns the node's unique ID number.

=head2 predecessors()

	my @pre = $node->predecessors();

Returns all nodes (as objects) that link to us.

=head2 successors()

	my @suc = $node->successors();

Returns all nodes (as objects) that we are linking to.

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for more details.

=cut
