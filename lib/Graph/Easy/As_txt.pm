#############################################################################
# output the graph as textual description
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::As_txt;

use vars qw/$VERSION/;

$VERSION = '0.02';

#############################################################################
#############################################################################

package Graph::Easy;

use strict;

sub _as_txt
  {
  my ($self) = @_;

  # convert the graph to a textual representation
  # does not need a layout() before hand!

  $self->_assign_ranks();

  # generate the class attributes first
  my $txt = '';
  my $att =  $self->{att};
  for my $class (sort keys %$att)
    {

    my $out = $self->_remap_attributes( $class, $att->{$class}, {}, 'noquote');

    my $att = '';
    for my $atr (sort keys %$out)
      {
      # border is handled special below
      next if $atr =~ /^border/;
      $att .= "  $atr: $out->{$atr};\n";
      }

    my $border = $self->border_attribute($class) || '';
    $border = '' if defined $self->{def_att}->{$class}->{border} &&
              $border eq $self->{def_att}->{$class}->{border};
    $att .= "  border: $border;\n" if $border ne '';

    if ($att ne '')
      {
      # the following makes short, single definitions to fit on one line
      if ($att !~ /\n.*\n/ && length($att) < 40)
        {
        $att =~ s/\n/ /; $att =~ s/^  / /;
        }
      else
        {
        $att = "\n$att";
        }
      $txt .= "$class {$att}\n";
      }
    }

  $txt .= "\n" if $txt ne '';		# insert newline

  my @nodes = $self->sorted_nodes('name');

  my $count = 0;
  # output nodes with attributes first, sorted by their name
  foreach my $n (@nodes)
    {
    $n->{_p} = undef;			# mark as not yet processed
    my $att = $n->attributes_as_txt();
    if ($att ne '')
      {
      $n->{_p} = 1;			# mark as processed
      $count++;
      $txt .= $n->as_pure_txt() . $att . "\n"; 
      }
    }
 
  $txt .= "\n" if $count > 0;		# insert a newline

  # output groups first, with their nodes
  foreach my $gn (sort keys %{$self->{groups}})
    {
    my $group = $self->{groups}->{$gn};
    $txt .= $group->as_txt();		# marks nodes as processed if nec.
    $count++;
    }

  # XXX TODO:
  # Output all nodes with rank=0 first, and also follow their successors
  # What is left will then be done next, with rank=1 etc.
  # This output order let's us output node chains in compact form as:
  # [A]->[B]->[C]->[D]
  # [B]->[E]
  # instead of having:
  # [A]->[B]
  # [B]->[E]
  # [B]->[C] etc
 
  @nodes = $self->sorted_nodes('rank','name');
  foreach my $n (@nodes)
    {
    my @out = $n->sorted_successors();
    my $first = $n->as_pure_txt();
    if ((@out == 0) && ( (scalar $n->predecessors() || 0) == 0))
      {
      # single node without any connections (unless already output)
      $txt .= $first . "\n" unless defined $n->{_p};
      }

    # for all outgoing connections
    foreach my $other (@out)
      {
      # in case there exists more than one edge from $n --> $other
      my @edges = $n->edges_to($other);
      for my $edge (@edges)
        {
        $txt .= $first . $edge->as_txt() . $other->as_pure_txt() . "\n";
        }
      }
    }

  $txt;
  }
 
1;
__END__
=head1 NAME

Graph::Easy::As_txt - Generate textual description from graph object

=head1 SYNOPSIS

	use Graph::Easy;
	
	my $graph = Graph::Easy->new();

	my $bonn = Graph::Easy::Node->new(
		name => 'Bonn',
	);
	my $berlin = Graph::Easy::Node->new(
		name => 'Berlin',
	);

	$graph->add_edge ($bonn, $berlin);

	print $graph->as_txt();

	# prints something like:

	# [ Bonn ] -> [ Berlin ]

=head1 DESCRIPTION

C<Graph::Easy::As_txt> contains just the code for converting a
L<Graph::Easy|Graph::Easy> object to a human-readable textual description.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut

