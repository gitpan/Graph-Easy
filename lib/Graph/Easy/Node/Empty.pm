#############################################################################
# (c) by Tels 2004 - 2005. An empty, borderless cell. Part of Graph::Easy.
#
#############################################################################

package Graph::Easy::Node::Empty;

use Graph::Easy::Node;

@ISA = qw/Graph::Easy::Node/;
$VERSION = '0.03';

use strict;

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;

  $self->SUPER::_init($args);
  
  $self->{w} = 3;
  $self->{h} = 3;

  $self->{class} = 'node.empty';

  $self->{no_border_left} = 1;
  $self->{no_border_top} = 1;

  $self;
  }

sub _correct_size
  {
  my $self = shift;

  # find out whether the cell above/left of us is a node (w/ border)
  my $cells = $self->{graph}->{cells};
  my $x = $self->{x}; my $y = $self->{y};

  my $top = $cells->{"$x," . ($y-1)};
  my $left = $cells->{($x-1) . ",$y"};

  my $bottom = $cells->{"$x," . ($y+1)};
  my $right = $cells->{($x+1) . ",$y"};
  my $bottomright = $cells->{($x+1) . "," . ($y+1)};

  my $check = qr/^Graph::Easy::Node/;

  # count the number of cells below and right of us (0..3)
  $self->{rightbelow_count} = 0;

  $self->{rightbelow_count}++ if ref($bottom) =~ $check;
  $self->{rightbelow_count}++ if ref($right) =~ $check;
  $self->{rightbelow_count}++ if ref($bottomright) =~ $check;

  $self->{have_below} = 1 if ref($bottom) =~ $check;
#  $self->{have_above} = 1 if ref($top) =~ $check;
#  $self->{have_left} = 1 if ref($left) =~ $check;
  $self->{have_right} = 1 if ref($right) =~ $check;

  $self->{border_collapse_bottom} = 1 if ref($bottom) =~ $check;
  $self->{border_collapse_right} = 1 if ref($right) =~ $check;

  # either not there, or not empty
  $self->{no_border_right} = 1 if ref($right) !~ /::Node\z/;
  $self->{no_border_bottom} = 1 if ref($bottom) !~ /::Node\z/;

  return if !exists $self->{autosplit_xy};

  # nodes not in first row/column are smaller
  my ($asx, $asy) = split /,/, $self->{autosplit_xy};

  # nodes not in first row/column are smaller
  $self->{w}-- if $asx != 0;
  $self->{h}-- if $asy != 0;

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
