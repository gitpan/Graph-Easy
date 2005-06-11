#############################################################################
# (c) by Tels 2004 - 2005. Part of Graph::Easy
#
#############################################################################

package Graph::Easy::Node::Cell;

use 5.006001;
use strict;
use Graph::Easy::Node;

use vars qw/$VERSION @ISA/;

@ISA = qw/Graph::Easy::Node/;

$VERSION = '0.01';

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{class} = '';
  $self->{name} = '';
  
  $self->{x} = 0;
  $self->{y} = 0;
  $self->{w} = 0;
  $self->{h} = 0;

  # XXX TODO check arguments
  foreach my $k (keys %$args)
    {
    $self->{$k} = $args->{$k};
    }
 
  $self->{error} = '';

  $self;
  }

1;
__END__

=head1 NAME

Graph::Easy::Node::Cell - An empty filler cell

=head1 SYNOPSIS

        use Graph::Easy::Path;
        use Graph::Easy::Edge;

	my $ssl = Graph::Easy::Edge->new(
		label => 'encrypted connection',
		style => '-->',
		color => 'red',
	);
	my $path = Graph::Easy::Path->new(
		type => EDGE_SHORT_E,
	);
	$ssl->add_cell ($path);

	my $src = Graph::Easy::Node->new(
		name => 'source',
	);

	my $dst = Graph::Easy::Node->new(
		name => 'destination',
	);

	$graph = Graph::Easy->new();

	$graph->add_edge($src, $dst, $ssl);

	print $graph->as_ascii();

=head1 DESCRIPTION

A C<Graph::Easy::Group::Cell> represents an edge between two (or more) nodes in a
simple graph.

Each edge has a direction (from source to destination, or back and forth),
plus a style (line width and style), colors etc. It can also have a name,
e.g. a text associated with it.

=head1 METHODS

=head2 error()

	$last_error = $edge->error();

	$cvt->error($error);			# set new messags
	$cvt->error('');			# clear error

Returns the last error message, or '' for no error.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
