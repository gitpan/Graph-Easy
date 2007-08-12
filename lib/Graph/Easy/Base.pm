#############################################################################
# A baseclass for Graph::Easy objects like nodes, edges etc.
#
#############################################################################

package Graph::Easy::Base;

$VERSION = '0.10';

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

  $self->{fatal_errors} = ($_[1] ? 1 : 0) if @_ > 0;

  $self->{fatal_errors} || 0;
  }

sub fatal_errors
  {
  my $self = shift;

  $self->{fatal_errors} = ($_[1] ? 0 : 1) if @_ > 0;

  $self->{fatal_errors} || 0;
  }

sub error
  {
  my $self = shift;

  # If we switched to a temp. Graphviz parser, then set the error on the
  # original parser object instead:
  return $self->{_old_self}->error(@_) if ref($self->{_old_self});

  # if called on a member on a graph, call error() on the graph itself:
  return $self->{graph}->error(@_) if ref($self->{graph});

  if (defined $_[0])
    {
    $self->{error} = $_[0];
    $self->_croak($self->{error}, 2)
      if ($self->{fatal_errors}) && $self->{error} ne '';
    }
  $self->{error} || '';
  }

sub error_as_html
  {
  # return error() properly escaped
  my $self = shift;

  my $msg = $self->{error};

  $msg =~ s/&/&amp;/g;
  $msg =~ s/</&lt;/g;
  $msg =~ s/>/&gt;/g;
  $msg =~ s/"/&quot;/g;

  $msg; 
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
    delete $self->{cache};
    $self->{cache}->{subclass} = $_[0];
    $self->{cache}->{class} = $self->{class};
    return;
    }
  $self->{class} =~ /\.(.*)/;

  return $1 if defined $1;

  return $self->{cache}->{subclass} if defined $self->{cache}->{subclass}; 

  # Subclass not defined, so check our base class for a possible set class
  # attribute and return this:

  # take a shortcut
  my $g = $self->{graph};
  if (defined $g)
    {
    my $subclass = $g->{att}->{$self->{class}}->{class};
    $subclass = '' unless defined $subclass;
    $self->{cache}->{subclass} = $subclass;
    $self->{cache}->{class} = $self->{class};
    return $subclass;
    }

  # not part of a graph?
  $self->{cache}->{subclass} = $self->attribute('class');
  }

sub class
  {
  # return our full class name like "node.subclass" or "node"
  my $self = shift;

  $self->{class} =~ /\.(.*)/;

  return $self->{class} if defined $1;

  return $self->{cache}->{class} if defined $self->{cache}->{class};

  # Subclass not defined, so check our base class for a possible set class
  # attribute and return this:

  my $subclass;
  # take a shortcut:
  my $g = $self->{graph};
  if (defined $g)
    {
    $subclass = $g->{att}->{$self->{class}}->{class};
    $subclass = '' unless defined $subclass;
    }

  $subclass = $self->{att}->{class} unless defined $subclass;
  $subclass = '' unless defined $subclass;
  $self->{cache}->{subclass} = $subclass;
  $subclass = '.' . $subclass if $subclass ne '';

  $self->{cache}->{class} = $self->{class} . $subclass;
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
  if (ref($self) && $self->{debug})
    {
    $Carp::CarpLevel = $level;			# don't report Base itself
    Carp::confess($msg);
    }
  else
    {
    Carp::croak($msg);
    }
  }
 
1;
__END__

=head1 NAME

Graph::Easy::Base - base class for Graph::Easy objects like nodes, edges etc

=head1 SYNOPSIS

	package Graph::Easy::My::Node;
	use Graph::Easy::Base;
	@ISA = qw/Graph::Easy::Base/;

=head1 DESCRIPTION

Used automatically and internally by L<Graph::Easy> - should not be used
directly.

=head1 METHODS

=head2 new()

	my $object = Graph::Easy::Base->new();

Create a new object, and call C<_init()> on it.

=head2 error()

	$last_error = $object->error();

	$object->error($error);			# set new messags
	$object->error('');			# clear the error

Returns the last error message, or '' for no error.

When setting a new error message, C<$self->_croak($error)> will be called
unless C<$object->no_fatal_errors()> is true.

=head2 error_as_html()

	my $error = $object->error_as_html();

Returns the same error message as L<error()>, but properly escaped
as HTML so it is safe to output to the client.

=head2 warn()

	$object->warn('Warning!');

Warn on STDERR with the given message.

=head2 no_fatal_errors()

	$object->no_fatal_errors(1);

Set the flag that determines whether setting an error message
via C<error()> is fatal, e.g. results in a call to C<_croak()>.

A true value will make errors non-fatal. See also L<fatal_errors>.

=head2 fatal_errors()

	$fatal = $object->fatal_errors();
	$object->fatal_errors(0);		# turn off
	$object->fatal_errors(1);		# turn on

Set/get the flag that determines whether setting an error message
via C<error()> is fatal, e.g. results in a call to C<_croak()>.

A true value makes errors fatal.

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

Copyright (C) 2004 - 2007 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

X<tels>
X<bloodgate>
X<license>
X<gpl>

=cut
