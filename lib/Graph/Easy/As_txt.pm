#############################################################################
# Output an Graph::Easy object as textual description
#
# (c) by Tels 2004-2006.
#############################################################################

package Graph::Easy::As_txt;

use vars qw/$VERSION/;

$VERSION = 0.11;

#############################################################################
#############################################################################

package Graph::Easy;

use strict;

sub _as_txt
  {
  my ($self) = @_;

  # Convert the graph to a textual representation - does not need layout().

  $self->_assign_ranks();

  # generate the class attributes first
  my $txt = '';
  my $att =  $self->{att};
  for my $class (sort keys %$att)
    {

    my $out = $self->_remap_attributes(
     $class, $att->{$class}, {}, 'noquote', 'encode' );

    my $att = '';
    for my $atr (sort keys %$out)
      {
      # border is handled special below
      next if $atr =~ /^border/;
      $att .= "  $atr: $out->{$atr};\n";
      }

    my $border = $self->border_attribute($class) || '';

    # 'solid 1px #000000' =~ /^solid/;
    # 'solid 1px #000000' =~ /^solid 1px #000000/;
    $border = '' if $self->default_attribute($class,'border') =~ /^$border/;

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
    my $first = $n->as_pure_txt(); 		# [ A | B ]
    if ( defined $n->{autosplit} || ((@out == 0) && ( (scalar $n->predecessors() || 0) == 0)))
      {
      # single node without any connections (unless already output)
      next if exists $n->{autosplit} && !defined $n->{autosplit};
      $txt .= $first . "\n" unless defined $n->{_p};
      }

    $first = $n->_as_part_txt();		# [ A.0 ]
    # for all outgoing connections
    foreach my $other (@out)
      {
      # in case there exists more than one edge from $n --> $other
      my @edges = $n->edges_to($other);
      for my $edge (sort { $a->{id} <=> $b->{id} } @edges)
        {
        $txt .= $first . $edge->as_txt() . $other->_as_part_txt() . "\n";
        }
      }
    }

  foreach my $n (@nodes)
    {
    delete $n->{_p};			# clean up
    }

  $txt;
  }

#############################################################################

package Graph::Easy::Group;

use strict;

sub as_txt
  {
  my $self = shift;

  require Graph::Easy::As_txt;

  my $n = '';
  if (!$self->isa('Graph::Easy::Group::Anon'))
    {
    $n = $self->{name};
    # quote special chars in name
    $n =~ s/([\[\]\(\)\{\}\#])/\\$1/g;
    $n = ' ' . $n;
    }

  my $txt = "($n";

  $n = $self->{nodes};

  $txt .= (keys %$n > 0 ? "\n" : ' ');
  for my $name ( sort keys %$n )
    {
    $n->{$name}->{_p} = 1;                              # mark as processed
    $txt .= '  ' . $n->{$name}->as_pure_txt() . "\n";
    }
  $txt .= ")" . $self->attributes_as_txt() . "\n\n";

  # insert all the edges of the group

  #
  $txt;
  }

#############################################################################

package Graph::Easy::Node;

use strict;

sub attributes_as_txt
  {
  # return the attributes of this node as text description
  my ($self, $remap) = @_;

  # nodes that were autosplit
  if (exists $self->{autosplit})
    {
    # other nodes are invisible in as_txt: 
    return '' unless defined $self->{autosplit};
    # the first one might have had a label set
    }

  my $att = '';
  my $class = $self->class();
  my $g = $self->{graph};

  # XXX TODO: remove atttributes that are simple the default attributes

  my $new = $g->_remap_attributes( $self, $self->{att}, $remap, 'noquote', 'encode' );

  if (defined $self->{origin})
    {
    $new->{origin} = $self->{origin}->{name};
    $new->{offset} = join(',', $self->offset());
    }

  # shorten output for multi-celled nodes
  # for "rows: 2;" still output "rows: 2;", because it is shorter
  if (exists $new->{columns})
    {
    $new->{size} = ($new->{columns}||1) . ',' . ($new->{rows}||1);
    delete $new->{rows};
    delete $new->{columns};
    # don't output the default size
    delete $new->{size} if $new->{size} eq '1,1';
    } 

  for my $atr (sort keys %$new)
    {
    next if $atr =~ /^border/;                  # handled special

    $att .= "$atr: $new->{$atr}; ";
    }

  my $border = $self->border_attribute();

  # XXX TODO: should do this for all attributes, not only for border
  # XXX TODO: this seems wrong anyway

  # don't include default border
  $border = '' if ref $g && $g->attribute($class,'border') eq $border;
  $att .= "border: $border; " if $border ne '';

  # if we have a subclass, we probably need to include it
  my $c = '';
  $c = $1 if $class =~ /\.(\w+)/;

  # but we do not need to include it if our group has a nodeclass attribute
  $c = '' if ref($self->{group}) && $self->{group}->attribute('nodeclass') eq $c;

  # include our subclass as attribute
  $att .= "class: $c; " if $c ne '' && $c ne 'anon';

  # generate attribute text if nec.
  $att = ' { ' . $att . '}' if $att ne '';

  $att;
  }

sub _as_part_txt
  {
  # for edges, we need the name of the part of the first part, not the entire
  # autosplit text
  my $self = shift;

  my $name = $self->{name};

  # quote special chars in name
  $name =~ s/([\[\]\|\{\}\#])/\\$1/g;

  '[ ' .  $name . ' ]';
  }

sub as_pure_txt
  {
  my $self = shift;

  return '[ '. $self->{autosplit} .' ]' if exists $self->{autosplit} && defined $self->{autosplit};

  my $name = $self->{name};

  # quote special chars in name
  $name =~ s/([\[\]\|\{\}\#])/\\$1/g;

  '[ ' .  $name . ' ]';
  }

sub as_txt
  {
  my $self = shift;

  if (exists $self->{autosplit})
    {
    return '[ ' . $self->{autosplit}.' ]' if defined $self->{autosplit};
    return '';
    }

  my $name = $self->{name};

  # quote special chars in name
  $name =~ s/([\[\]\|\{\}\#])/\\$1/g;

  '[ ' .  $name . ' ]' . $self->attributes_as_txt();
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

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut

