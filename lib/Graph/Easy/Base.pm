#############################################################################
# A baseclass for Graph::Easy objects like nodes, edges etc.
#
# (c) by Tels 2004-2005. Part of Graph::Easy
#############################################################################

package Graph::Easy::Base;

$VERSION = '0.01';

use strict;

#############################################################################

{
  # protected vars
  my $id = 0;
  sub _new_id { $id++; }
  sub _reset_id { $id = 0; }
}

#############################################################################

sub new
  {
  # Create a new object. This is a generic routine that is inherited
  # by many other things like Edge, Cell etc.
  my $class = shift;

  my $args = $_[0];
  $args = { name => $_[0] } if ref($args) ne 'HASH' && @_ == 1;
  $args = { @_ } if ref($args) ne 'HASH' && @_ > 1;
  
  my $self = bless {}, $class;

  $self->{id} = _new_id();

  $self->_init($args);
  }

sub _init
  {
  # Generic init routine, to be overriden in subclasses.
  my ($self,$args) = @_;
  
  $self;
  }

#############################################################################

sub error
  {
  my $self = shift;

  $self->{error} = $_[0] if defined $_[0];
  $self->{error} || '';
  }

1;
__END__

=head1 NAME

Graph::Easy::Base - Baseclass for Graph::Easy objects like nodes, edges etc

=head1 SYNOPSIS

        # Used automatically by Graph::Easy - should not used directly

=head1 DESCRIPTION

Used automatically by Graph::Easy - should not used directly.

=head1 METHODS

=head2 new()

Create a new object, and call C<_init()> on it.

=head2 error()

	$last_error = $node->error();

	$node->error($error);			# set new messags
	$node->error('');			# clear error

Returns the last error message, or '' for no error.

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
