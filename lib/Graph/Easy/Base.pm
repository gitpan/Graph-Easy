#############################################################################
# A baseclass for Graph::Easy objects like nodes, edges etc.
#
# (c) by Tels 2004-2006. Part of Graph::Easy
#############################################################################

package Graph::Easy::Base;

$VERSION = '0.05';

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

sub self
  {
  my $self = shift;
  
  $self;
  }  

#############################################################################

sub no_fatal_errors
  {
  my $self = shift;

  $self->{no_fatal_errors} = $_[1] ? 0 : 1 if @_ > 0;

  $self->{no_fatal_errors} || 0;
  }

sub error
  {
  my $self = shift;

  if (defined $_[0])
    {
    $self->{error} = $_[0];
    $self->_croak($self->{error}, 2)
      unless $self->{no_fatal_errors} || $self->{error} eq '';
    }
  $self->{error} || '';
  }

sub warn
  {
  my ($self, $msg) = @_;

  require Carp;
  Carp::carp($msg);
  }

#############################################################################
# class management

sub sub_class
  {
  # get/set the subclass
  my $self = shift;

  if (defined $_[0])
    {
    $self->{class} =~ s/\..*//;		# nix subclass
    $self->{class} .= '.' . $_[0];	# append new one
    }
  $self->{class} =~ /\.(.*)/;
  $1;
  }

sub class
  {
  # return our full class name like "node.subclass" or "node"
  my $self = shift;

  $self->{class};
  }

sub main_class
  {
  my $self = shift;

  $self->{class} =~ /^(.+)(\.|\z)/;	# extract first part

  $1;
  }

sub _croak
  {
  my ($self, $msg, $level) = @_;
  $level = 1 unless defined $level;
  
  require Carp;
  $Carp::CarpLevel = $level;			# don't report Base itself
  Carp::confess($msg);
  }
 
1;
__END__

=head1 NAME

Graph::Easy::Base - Baseclass for Graph::Easy objects like nodes, edges etc

=head1 SYNOPSIS

        # Used automatically by Graph::Easy - should not be used directly

=head1 DESCRIPTION

Used automatically by Graph::Easy - should not used directly.

=head1 METHODS

=head2 new()

	my $object = Graph::Easy::Base->new();

Create a new object, and call C<_init()> on it.

=head2 error()

	$last_error = $object->error();

	$object->error($error);			# set new messags
	$object->error('');			# clear the error

Returns the last error message, or '' for no error.

When setting a new error message, 
C<$self->_croak($error)> will be called unless C<$object->no_fatal_errors()>
is true.

=head2 warn()

	$object->warn('Warning!');

Warn on STDERR with the given message.

=head2 no_fatal_errors()

	$fatal = $object->no_fatal_errors();
	$object->no_fatal_errors(1);

Set/get the flag that determines whether setting an error message
via C<error()> is fatal, e.g. results in a call to C<_croak()>.

=head2 self()

	my $self = $object->self();

Returns the object itself.

=head2 class()

	my $class = $object->class();

Returns the full class name like C<node.cities>. See also C<sub_class>.

=head2 sub_class()

	my $sub_class = $object->sub_class();

Returns the sub class name like C<cities>. See also C<class>.

=head2 main_class()

	my $main_class = $object->main_class();

Returns the main class name like C<node>. See also C<sub_class>.

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

X<tels>
X<bloodgate>
X<license>
X<gpl>

=cut
