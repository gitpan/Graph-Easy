#############################################################################
# (c) by Tels 2004 - 2006. Part of Graph::Easy
#
#############################################################################

package Graph::Easy::Edge;

use Graph::Easy::Node;
@ISA = qw/Graph::Easy::Node/;		# an edge is just a special node
$VERSION = '0.22';

use strict;

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{class} = 'edge';

  # leave this unitialized until we need it
  # $self->{cells} = [ ];

  foreach my $k (keys %$args)
    {
    if ($k !~ /^(label|name|style)\z/)
      {
      require Carp;
      Carp::confess ("Invalid argument '$k' passed to Graph::Easy::Node->new()");
      }
    $self->{$k} = $args->{$k};
    }

  $self->{att}->{label} = $self->{name} unless defined $self->{att}->{label};
  $self->{att}->{label} = $self->{label} unless defined $self->{att}->{label};
  delete $self->{label};

  $self->{name} = '' unless defined $self->{name};

  # not defined => no label, thus inherit from class  
  delete $self->{att}->{label} unless defined $self->{att}->{label};

  $self->{att}->{'border-style'} = 'none';
  $self->{att}->{style} = $self->{style} if $self->{style};
  delete $self->{style};
 
  $self;
  }

my $styles = {
  solid => '--',
  dotted => '..',
  double => '==',
  'double-dash' => '= ',
  dashed => '- ',
  'dot-dash' => '.-',
  'dot-dot-dash' => '..-',
  wave => '~~',
  };

sub as_txt
  {
  my $self = shift;

  # '- Name ' or ''
  my $n = $self->{att}->{label}; $n = '' unless defined $n;

  my $left = ' '; $left = ' <' if $self->{bidirectional};
  my $right = '> '; $right = ' ' if $self->{undirected};
  
  my $s = $self->style() || 'solid';

  my $style = '--';

  # suppress border on edges
  my $suppress = { all => { label => undef } };
  if ($s =~ /^(bold|bold-dash|broad|wide|invisible)\z/)
    {
    # output "--> { style: XXX; }"
    $style = '--';
    }
  else
    {
    # output "-->" or "..>" etc
    $suppress->{all}->{style} = undef;

    $style = $styles->{ $s };
    if (!defined $style)
      {
      require Carp;
      Carp::confess ("Unknown edge style '$s'\n");
      }
    }
 
  $n = $style . " $n " if $n ne '';

  # make " -  " into " - -  "
  $style = $style . $style if $self->{undirected} && substr($style,1,1) eq ' ';

  # ' - Name -->' or ' --> ' or ' -- '
  my $a = $self->attributes_as_txt($suppress) . ' '; $a =~ s/^\s//;
  $left . $n . $style . $right . $a;
  }

#############################################################################
# accessor methods

sub bidirectional
  {
  my $self = shift;

  $self->{bidirectional} = $_[0] ? 1 : 0 if @_ > 0;

  $self->{bidirectional};
  }

sub undirected
  {
  my $self = shift;

  $self->{undirected} = $_[0] ? 1 : 0 if @_ > 0;

  $self->{undirected};
  }

sub has_ports
  {
  my $self = shift;

  my $s_port = $self->{att}->{start} || $self->attribute('start');

  return 1 if defined $s_port;

  my $e_port = $self->{att}->{end} || $self->attribute('end');

  return 1 if defined $e_port;

  0;
  }

sub start_port
  {
  # return the side and portnumber if the edge has a shared source port
  # undef for none
  my $self = shift;

  my $s = $self->{att}->{start} || $self->attribute('start');
  return undef if !defined $s || $s !~ /,/;	# "south, 0" => ok, "south" => no

  return (split /\s*,\s*/, $s) if wantarray;

  $s =~ s/\s+//g;		# remove spaces to normalize "south, 0" to "south,0"
  $s;
  }

sub end_port
  {
  # return the side and portnumber if the edge has a shared source port
  # undef for none
  my $self = shift;

  my $s = $self->{att}->{end} || $self->attribute('end');
  return undef if !defined $s || $s !~ /,/;	# "south, 0" => ok, "south" => no

  return split /\s*,\s*/, $s if wantarray;

  $s =~ s/\s+//g;		# remove spaces to normalize "south, 0" to "south,0"
  $s;
  }

sub style
  {
  my $self = shift;

  $self->{att}->{style} || $self->attribute('style') || 'solid';
  }

#############################################################################
# cell management

sub cells
  {
  # return all the cells this edge currently occupies
  my $self = shift;

  $self->{cells} = [] unless defined $self->{cells};

  @{$self->{cells}};
  }

sub clear_cells
  { 
  # remove all belonging cells
  my $self = shift;

  $self->{cells} = [];

  $self;
  }

sub _unplace
  {
  # Take an edge, and remove all the cells it covers from the cells area
  my ($self, $cells) = @_;

  print STDERR "# clearing path from $self->{from}->{name} to $self->{to}->{name}\n" if $self->{debug};

  for my $key (@{$self->{cells}})
    {
    # XXX TODO: handle crossed edges differently (from CROSS => HOR or VER)
    # free in our cells area
    delete $cells->{$key};
    }

  $self->clear_cells();

  $self;
  }

sub _distance
  {
  # estimate the distance from SRC to DST node
  my ($self) = @_;

  my $src = $self->{from};
  my $dst = $self->{to};

  # one of them not yet placed?
  return 100000 unless defined $src->{x} && defined $dst->{x};

  my $cells = $self->{graph}->{cells};

  # get all the starting positions
  # distance = 1: slots, generate starting types, the direction is shifted
  # by 90° counter-clockwise

  my @start = $src->_near_places($cells, 1, undef, undef, $src->_shift(-90) );

  # potential stop positions
  my @stop = $dst->_near_places($cells, 1);		# distance = 1: slots

  my ($s_p,@ss_p) = $self->port('start');
  my ($e_p,@ee_p) = $self->port('end');

  # the edge has a port description, limiting the start places
  @start = $src->_allowed_places( \@start, $src->_allow( $s_p, @ss_p ), 3)
    if defined $s_p;

  # the edge has a port description, limiting the stop places
  @stop = $dst->_allowed_places( \@stop, $dst->_allow( $e_p, @ee_p ), 3)
    if defined $e_p;

  my $stop = scalar @stop;

  return 0 unless @stop > 0 && @start > 0;	# no free slots on one node?

  my $lowest;

  my $i = 0;
  while ($i < scalar @start)
    {
    my $sx = $start[$i]; my $sy = $start[$i+1]; $i += 2;

    # for each start point, calculate the distance to each stop point, then use
    # the smallest as value

    for (my $u = 0; $u < $stop; $u += 2)
      {
      my $dist = Graph::Easy::_astar_distance($sx,$sy, $stop[$u], $stop[$u+1]);
      $lowest = $dist if !defined $lowest || $dist < $lowest;
      }
    }

  $lowest;
  }

sub add_cell
  {
  # add a cell to the list of cells this edge covers. If $after is a ref
  # to a cell, then the new cell will be inserted right after this cell.
  # if after is defined, but not a ref, the new cell will be inserted
  # at the specified position.
  my ($self, $cell, $after) = @_;
 
  $self->{cells} = [] unless defined $self->{cells};
  my $cells = $self->{cells};

  if (defined $after)
    {
    # insert the new cell right after $after
    my $ofs = 0;
    # $after == 0 => ofs is 0 (insert at front)
    if (ref($after))
      {
      for my $cell (@$cells)
        {
        last if $cell == $after;
        $ofs++; 
        }
      }
    else { $ofs = $after; }
    splice (@$cells, $ofs, 0, $cell);
    } 
  else
    {
    # insert new cell at the end
    push @$cells, $cell;
    }

  $self;
  }

#############################################################################

sub from
  {
  my $self = shift;

  $self->{from};
  }

sub to
  {
  my $self = shift;

  $self->{to};
  }

sub start_at
  {
  # move the edge's start point from the current node to the given node
  my ($self, $node) = @_;

  # if not a node yet, or not part of this graph, make into one proper node
  $node = $self->{graph}->add_node($node);

  $self->_croak("start_at() needs a node object, but got $node")
    unless ref($node) && $node->isa('Graph::Easy::Node');

  # A => A => nothing to do
  return $node if $self->{from} == $node;

  # delete self at A
  delete $self->{from}->{edges}->{ $self->{id} };

  # set from to B
  $self->{from} = $node;

  # add to B
  $self->{from}->{edges}->{ $self->{id} } = $self;

  $node;
  }

sub flow
  {
  # return the flow at this edge
  my ($self) = @_;

# print STDERR "# flow from $self->{from}->{name} to $self->{to}->{name}\n";

  # our flow comes from ourselves
  my $flow = $self->{att}->{flow};

  # if the edge doesn't have a flwow, maybe the node has a default out flow
  $flow = $self->{from}->{att}->{flow} if !defined $flow;

  # if that didn't work out either, use the parents flows
  $flow = $self->parent()->attribute('flow') if !defined $flow; 
  # or finally, the default "east":
  $flow = 90 if !defined $flow;

  # absolute flow does not depend on the in-flow, so can return early
  return $flow if $flow =~ /^(0|90|180|270)\z/;

  # in-flow comes from our "from" node
  my $in = $self->{from}->flow();

#  print STDERR "in $in out $flow\n";

  my $out = $self->{graph}->_flow_as_direction($in,$flow);
  $out;
  }

sub port
  {
  my ($self, $which) = @_;

  $self->_croak("'$which' must be one of 'start' or 'end' in port()") unless $which =~ /^(start|end)/;

  # our flow comes from ourselves
  my $sp = $self->attribute($which); 

  return (undef,undef) unless defined $sp;

  my ($side, $port) = split /\s*,\s*/, $sp;

  # if absolut direction, return as is
  my $s = Graph::Easy->_direction_as_side($side);

  if (defined $s)
    {
    my @rc = ($s); push @rc, $port if defined $port;
    return @rc;
    }

  # in_flow comes from our "from" node
  my $in = 90; $in = $self->{from}->flow() if ref($self->{from});

  # turn left in "south" etc:
  $s = Graph::Easy->_flow_as_side($in,$side);

  my @rc = ($s); push @rc, $port if defined $port;
  @rc;
  }

sub flip
  {
  # swap from and to for this edge
  my ($self) = @_;

  ($self->{from}, $self->{to}) = ($self->{to}, $self->{from});

  $self;
  }

1;
__END__

=head1 NAME

Graph::Easy::Edge - An edge (a path from one node to another)

=head1 SYNOPSIS

        use Graph::Easy;

	my $ssl = Graph::Easy::Edge->new(
		label => 'encrypted connection',
		style => 'solid',
	);
	$ssl->set_attribute('color', 'red');

	my $src = Graph::Easy::Node->new('source');

	my $dst = Graph::Easy::Node->new('destination');

	$graph = Graph::Easy->new();

	$graph->add_edge($src, $dst, $ssl);

	print $graph->as_ascii();

=head1 DESCRIPTION

A C<Graph::Easy::Edge> represents an edge between two (or more) nodes in a
simple graph.

Each edge has a direction (from source to destination, or back and forth),
plus a style (line width and style), colors etc. It can also have a label,
e.g. a text associated with it.

Each edge also contains a list of path-elements (also called cells), which
make up the path from source to destination.

=head1 METHODS

=head2 error()

	$last_error = $edge->error();

	$cvt->error($error);			# set new messags
	$cvt->error('');			# clear error

Returns the last error message, or '' for no error.

=head2 as_ascii()

	my $ascii = $edge->as_ascii();

Returns the edge as a little ascii representation.

=head2 as_txt()

	my $txt = $edge->as_txt();

Returns the edge as a little Graph::Easy textual representation.

=head2 label()

	my $label = $edge->label();

Returns the label (also known as 'name') of the edge.

=head2 style()

	my $style = $edge->style();

Returns the style of the edge, like 'solid', 'dotted', 'double', etc.

=head2 to_nodes()

	my @nodes = $edge->to_nodes();

Return the nodes this edge connects to, as objects.

=head2 from_nodes()

	my @nodes = $edge->from_nodes();

Return the nodes (that connections come from) as objects.

=head2 nodes()

	my @nodes = $edge->nodes();

Return all the nodes connected (in either direction) by this edge
as objects.

=head2 add_cell()

	$edge->add_cell( $cell, $after );

Add a new cell to the edge. C<$cell> must be an
C<Graph::Easy::Edge::Cell> object.

If the optional argument C<$after> is a ref to a cell, then the new cell will
be inserted right after this cell. If it is defined, but not a ref, the new cell
will be inserted at the specified position.

=head2 clear_cells()

	$edge->clear_cells();

Removes all cells belonging to this edge.

=head2 cells()

	my $cells = $edge->cells();

Returns a hash containing all the cells this edge currently occupies. Keys
on the hash are of the form of C<$x,$y> e.g. C<5,3> denoting cell at X = 5 and
Y = 3. The values of the hash are the cell objects.

=head2 bidirectional()

	$edge->bidirectional(1);
	if ($edge->bidirectional())
	  {
	  }

Returns true if the edge is bidirectional, aka has arrow heads on both ends.
An optional parameter will set the bidirectional status of the edge.

=head2 undirected()

	$edge->undirected(1);
	if ($edge->undirected())
	  {
	  }

Returns true if the edge is undirected, aka has now arrow at all.
An optional parameter will set the undirected status of the edge.

=head2 has_ports()

	if ($edge->has_ports())
	  {
	  ...
	  }

Return true if the edge has restriction on the starting or ending
port, e.g. either the C<start> or C<end> attribute is set on
this edge. 

=head2 start_port()

	my $port = $edge->start_port();

Return undef if the edge does not have a fixed start port, otherwise
returns the port as "side, number", for example "south, 0".

=head2 end_port()

	my $port = $edge->end_port();

Return undef if the edge does not have a fixed end port, otherwise
returns the port as "side, number", for example "south, 0".

=head2 from()

	my $from = $edge->from();

Returns the node that this edge starts at. See also C<to()>.

=head2 to()

	my $to = $edge->to();

Returns the node that this edge leads to. See also C<from()>.

=head2 start_at()

	$edge->start_at($other);
	my $other = $edge->start_at('some node');

Set the edge's start point to the given node. If given a node name,
will add that node to the graph first.

Returns the new edge start point node.

=head2 flip()

	$edge->flip();

Swaps the C<start> and C<end> nodes on this edge, e.g. reverses the direction
of it.

=head2 flow()

	my $flow = $edge->flow();

Returns the flow for this edge, or undef if it has none.

=head2 port()

	my ($side, $number) = $edge->port('start');
	my ($side, $number) = $edge->port('end');

Return the side and port number where this edge starts or ends.

Returns undef for $side if the edge has no port restriction. The
returned side will be one absolute direction of C<east>, C<west>,
C<north> or C<south>, depending on the port restriction and
flow at that edge.

=head1 EXPORT

None by default.

=head1 TODO

=over 2

=item joints

Edges that join another edge.

=back

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
