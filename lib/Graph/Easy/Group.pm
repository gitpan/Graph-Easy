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
$VERSION = '0.06';

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{name} = 'Group #'. $self->{id};
  $self->{label} = '';
  $self->{class} = 'group';
  $self->{cells} = {};

  # XXX TODO check arguments
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

=head2 add_node()

	$group->add_node($node);

Add the specified node to this group.

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

Returns a list of all nodes that belong to this group.

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
