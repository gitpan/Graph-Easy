#############################################################################
# (c) by Tels 2004 - 2005. Part of Graph::Easy
#
#############################################################################

package Graph::Easy::Edge;

use 5.006001;
use strict;
use Graph::Easy::Node;

use vars qw/$VERSION @ISA/;

@ISA = qw/Graph::Easy::Node/;		# an edge is a special node

$VERSION = '0.15';

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{class} = 'edge';

  # leave this unitialized until we need it
  # $self->{cells} = { };

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

  $self->{att}->{'border-style'} = 'none';
  $self->{att}->{style} = $self->{style} || 'solid';
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
  bold => '##',
  };

sub as_txt
  {
  my $self = shift;

  # '- Name ' or ''
  my $n = $self->{att}->{label}; $n = '' unless defined $n;

  my $left = ' '; $left = ' <' if $self->{bidirectional};
  my $right = '> '; $right = ' <' if $self->{undirected};

  my $style = $styles->{$self->{att}->{style}};
  if (!defined $style)
    {
    require Carp;
    Carp::croak ("Unknown edge style $self->{att}->{style}\n");
    }

  # suppress border on edges
  my $suppress = { all => { label => undef } };
  if ($self->{att}->{style} eq 'bold')
    {
    # output "--> { style: bold; }"
    $style = '--';
    }
  else
    {
    # output "-->" or "..>" etc
    $suppress->{all}->{style} = undef;
    }
 
  $n = $style . " $n " if $n ne '';

  # make " -  " into " - -  "
  $style = $style . $style if $self->{undirected} && substr($style,1,1) eq ' ';

  # ' - Name -->' or ' --> ' or ' -- '
  my $a = $self->attributes_as_txt($suppress) . ' '; $a =~ s/^\s//;
  $left . $n . $style . $right . $a;
  }

sub _formatted_label
  {
  my $self = shift;

  my $name = $self->label() || '';
  # insert real newlines and remove spacing
  $name =~ s/\s*\\n\s*/\n/g;		# insert real newlines

  # split into lines
  my @lines = split /\n/, $name;
  @lines;
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

sub style
  {
  my $self = shift;

  $self->{att}->{style};
  }

sub cells
  {
  # return all the cells this edge currently occupies
  my $self = shift;

  $self->{cells} = {} unless defined $self->{cells};
  $self->{cells};
  }

sub clear_cells
  { 
  # remove all belonging cells
  my $self = shift;

  $self->{cells} = {};

  $self;
  }

sub _unplace
  {
  # Take an edge, and remove all the cells it covers from the cells area
  my ($self, $cells) = @_;

  my $covered = $self->cells();

  print STDERR "# clearing path from $self->{from}->{name} to $self->{to}->{name}\n" if $self->{debug};

  for my $key (keys %$covered)
    {
    # XXX TODO: handle crossed edges differently (from CROSS => HOR or VER)
    # free in our cells area
    delete $cells->{$key};
    }
  # clear cells
  $self->{cells} = {};
  $self;
  }

sub add_cell
  {
  # add a cell to the list of cells this edge covers
  my ($self,$cell) = @_;
  
  $self->{cells}->{"$cell->{x},$cell->{y}"} = $cell;
  }

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

	$edge->add_cell( $cell );

Add a new cell to the edge. C<$cell> should be an
L<Graph::Easy::Path|Graph::Easy::Path> object.

=head2 clear_cells()

	$edge->clear_cells();

Removes all belonging cells.

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

=head2 from()

	my $from = $edge->from();

Returns the node that this edge starts at. See also C<to()>.

=head2 to()

	my $to = $edge->to();

Returns the node that this edge leads to. See also C<from()>.

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

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
