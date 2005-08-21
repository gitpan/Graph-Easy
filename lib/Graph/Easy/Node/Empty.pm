#############################################################################
# (c) by Tels 2004 - 2005. An empty, borderless cell. Part of Graph::Easy.
#
#############################################################################

package Graph::Easy::Node::Empty;

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

  $self->SUPER::_init($args);
  
  $self->{w} = 5;
  $self->{h} = 3;

  $self->{att}->{"border-style"} = 'none';

  $self;
  }

1;
__END__

=head1 NAME

Graph::Easy::Node::Empty - An empty, borderless cell in a node cluster

=head1 SYNOPSIS

	my $cell = Graph::Easy::Node::Empty->new();

=head1 DESCRIPTION

A C<Graph::Easy::Node::Empty> represents a borderless, empty cell in
a node cluster.

You should not need to use this class directly.

=head1 METHODS

=head2 error()

	$last_error = $cell->error();

	$cvt->error($error);			# set new messags
	$cvt->error('');			# clear error

Returns the last error message, or '' for no error.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
