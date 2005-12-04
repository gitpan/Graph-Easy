#############################################################################
# Layout directed graphs on a flat plane. Part of Graph::Easy.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Layout;

use vars qw/$VERSION/;

$VERSION = '0.14';

#############################################################################
#############################################################################

package Graph::Easy;

use strict;
use Graph::Easy::Node::Cell;
use Graph::Easy::Edge::Cell qw/
  EDGE_SHORT_E EDGE_SHORT_W EDGE_SHORT_N EDGE_SHORT_S

  EDGE_START_E EDGE_START_W EDGE_START_N EDGE_START_S

  EDGE_END_E EDGE_END_W EDGE_END_N EDGE_END_S

  EDGE_N_E EDGE_N_W EDGE_S_E EDGE_S_W

  EDGE_HOR EDGE_VER EDGE_CROSS
 /;

sub ACTION_NODE  () { 0; }	# place node somewhere
sub ACTION_TRACE () { 1; }	# trace path from src to dest
sub ACTION_CHAIN () { 2; }	# place node in chain (with parent)
sub ACTION_EDGES () { 3; }	# trace all edges (shortes connect. first)

use Graph::Easy::Layout::Chain;		# chain management
use Graph::Easy::Layout::Scout;		# pathfinding
use Graph::Easy::Layout::Path;		# path management

#############################################################################

sub _assign_ranks
  {
  # assign a rank to each node, so that they can be sorted into groups
  my $self = shift;

  # XXX TODO: we dont actually need them in sorted order
  my @N = $self->sorted_nodes();
  my @todo = ();

  # Put all nodes into rank 0 as default and gather all nodes that have
  # outgoing connections, but no incoming ones
  for my $n (@N)
    {
    $n->{rank} = 0;			# default is 0
    push @todo, $n
      if $n->successors() > 0 && $n->predecessors() == 0;
    }

  # The above step will create a list of todo nodes that start a chain, but
  # it will miss circular chains like CDEC (e.g. only A appears in todo):
  # A -> B;  C -> D -> E -> C;
  # We fix this as last step

  my $done = 0;
  while ($done < 2)
    {
    # while we still have nodes to follow
    while (@todo)
      {
      my $n = shift @todo;
      my $l = $n->{rank} + 1;
      for my $o ($n->successors())
        {
        if ($o->{rank} == 0)
          {
          #print "# Set $o->{name} to $l\n";
          $o->{rank} = $l;
          # XXX TODO: check that $o is not yet on @todo
          push @todo, $o;
          }
        }
      }
    # done all nodes in TODO, get nodes in circular chains
    $done++;

    last if $done == 2;			# early out
    for my $n (@N)
      {
      # node still in rank 0, but has incoming edges
      push @todo, $n
        if $n->{rank} == 0 && $n->predecessors() > 0;
      }
    } # while still something todo

  $self;
  }

sub _follow_chain
  {
  # follow the chain from the node
  my ($node) = @_;

  my $self = $node->{graph};

  no warnings 'recursion';

  my $indent = ' ' x ($node->{_chain}->{id} + 1);
  print STDERR "#$indent Tracking chain from $node->{name}\n" if $self->{debug};

  # create a new chain and point it to the start node
  my $chain = Graph::Easy::Layout::Chain->new( start => $node, graph => $self );
  $self->{chains}->{ $chain->{id} } = $chain;

  my $done = 1;				# how many nodes did we process?
 NODE:
  while (3 < 5)
    {
    # Count "unique" successsors, ignoring selfloops, multiedges and nodes
    # in the same chain.

    my $c = $node->{_chain};

    local $node->{_c} = 1;		# stop back-ward loops

    my %suc;

    for my $e (values %{$node->{edges}})
      {
      my $to = $e->{to};

      # ignore self-loops
      next if $e->{from} == $e->{to};

#      print STDERR "# bidi $e->{from}->{name} to $e->{to}->{name}\n" if $e->{bidirectional} && $to == $node;

      # if it is bidirectional, and points the "wrong" way, turn it around
      $to = $e->{from} if $e->{bidirectional} && $to == $node;

      next if exists $to->{_c};		# backloop into current branch?

      next if defined $to->{_chain} &&	# ignore if it points to the same
		$to->{chain} == $c; 	# chain (backloop)

					# ignore multi-edges by dropping
      $suc{$to->{name}} = $to;		# duplicates
      }

    last if keys %suc == 0;		# the chain stopped here

    if (scalar keys %suc == 1)		# have only one unique successor?
      {
      my $s = $suc{ each %suc };

      if (!defined $s->{_chain})	# chain already done?
        {
        $c->add_node( $s );

        $node = $s;			# next node

        print STDERR "#$indent Skipping ahead to $node->{name}\n" if $self->{debug};

        $done++;			# one more
        next NODE;			# skip recursion
        }
      }

    # Select the longest chain from the list of successors
    # and join it with the current one:

    my $max = -1;
    my $next;				# successor
    my $next_chain = undef;

    print STDERR "#$indent $node->{name} successors: \n" if $self->{debug};

    my @rc;

    for my $s (values %suc)		# for all successors
      {

      print STDERR "# suc $s->{name} chain $s->{_chain}\n" if $self->{debug};

      $done += _follow_chain($s) 	# track chain
       if !defined $s->{_chain};	# if not already done

      next if $s->{_chain} == $c;	# skip backlinks

      my $ch = $s->{_chain};

      push @rc, [ $ch, $s ];
      # point node to new next node
      ($next_chain, $max, $next) = 
	($ch, $ch->{len}, $s) if $ch->{len} > $max;
      }

    if (defined $next_chain && $self->{debug})
      {
      print STDERR "#   results of tracking successors:\n";
      for my $ch (@rc)
        {
        my ($c,$s) = @$ch;
        my $len = $c->length($s);
        print STDERR "#    chain $c->{id} starting at $c->{start}->{name} (len $c->{len}) ".
                     " pointing to node $s->{name} (len from there: $len)\n";
        }
      print STDERR "# Max chain length is $max (chain id $next_chain->{id})\n";
      }

    if (defined $next_chain)
      {
      print STDERR "#$indent $node->{name} next: " . $next_chain->start()->{name} . "\n" if $self->{debug};

      if ($self->{debug})
	{
	print STDERR "# merging chains\n";
	$c->dump(); $next_chain->dump();
	}

      $c->merge($next_chain, $next);		# merge the two chains

      delete $self->{chains}->{$next_chain->{id}} if $next_chain->{len} == 0;
      }

    last;
    }

  print STDERR "#$indent Chain $node->{_chain} ended at $node->{name}\n" if $self->{debug};

  $done;				# return nr of done nodes
  }

sub _find_chains
  {
  # Track all node chains (A->B->C etc), trying to find the longest possible
  # node chain.
  my $self = shift;

  print STDERR "# Tracking chains\n" if $self->{debug};

  # drop all old chain info
  $self->{_chains} = { };
  $self->{_chain} = 0;					# new chain ID

  # For all not-done-yet nodes, track the chain starting with that node.

  # compute predecessors for all nodes: O(1)
  my $p;
  for my $n (values %{$self->{nodes}})
    {
    $n->{_chain} = undef;				# reset chain info
    $p->{$n->{name}} = $n->predecessors();
    }

  my $done = 0; my $todo = scalar keys %{$self->{nodes}};

  # Start at nodes with no predecessors (starting points) and then do the rest:
  for my $name (sort { $p->{$a} <=> $p->{$b} || $a cmp $b } keys %$p)
    {
    my $n = $self->{nodes}->{$name};

    last if $done == $todo;			# already processed all nodes?

    # track the chain unless already done and count number of nodes done
    $done += _follow_chain($n) unless defined $n->{_chain};
    }

  print STDERR "# Done all $todo nodes\n" if $done == $todo && $self->{debug};

  $self;
  }

#############################################################################
# debug

sub _dump_stack
  {
  my ($self, @todo) = @_;

  print STDERR "# Action stack contains ", scalar @todo, " steps:\n";
  for my $action (@todo)
    {
    my $action_type = $action->[0];
    if ($action_type == ACTION_NODE)
      {
      my ($at,$node,$try) = @$action;
      print STDERR "#  place '$node->{name}' with try $try\n";
      }
    elsif ($action_type == ACTION_CHAIN)
      {
      my ($at, $node, $try, $parent) = @$action;
      print STDERR
       "#  chain '$node->{name}' from parent '$parent->{name} with try $try'\n";
      }
    elsif ($action_type == ACTION_TRACE)
      {
      my ($at,$edge) = @$action;
      my ($src,$dst) = ($edge->{from}, $edge->{to});
      print STDERR
       "#  trace '$src->{name}' to '$dst->{name}' via edge $edge->{id}\n";
      }
    elsif ($action_type == ACTION_EDGES)
      {
      my ($at,$src) = @$action;
      print STDERR
       "#  trace all edges from '$src->{name}', shortest first\n";
      }
    }
  }

#############################################################################
# layout the graph

sub layout
  {
  my $self = shift;

  # protect the layout with a timeout:
  
  eval {
    local $SIG{ALRM} = sub { die "layout did not finish in time\n" };
    alarm(abs($self->{timeout} || 5));

  # Reset the sequence of the random generator, so that for the same
  # seed, the same layout will occur. Both for testing and repeatable
  # layouts based on max score.

  srand($self->{seed});

  ###########################################################################
  # do some assorted stuff beforehand

  local $_; $_->grow() for (values %{$self->{nodes}});

  $self->_assign_ranks();

  foreach my $n (values %{$self->{nodes}})
    {
    $n->{x} = undef;			# mark every node as not placed yet
    $n->{y} = undef;
    $n->{w} = undef;			# force size recalculation
    $n->{_todo} = undef;		# mark as todo
    }

  # find (longest possible) chains of nodes to "straighten" graph
  $self->_find_chains();

  ###########################################################################
  # prepare our stack of things we need to do before we are finished

  my @todo;				# action stack

  if ($self->{debug})
    {
    print STDERR "#  Generated the following chains:\n";

  for my $chain (sort { $a->{len} <=> $b->{len} } values %{$self->{chains}})
      {
      $chain->dump('  ');
      }
    }

  # mark all edges as unprocessed, so that we do not process them twice
  for my $edge (values %{$self->{edges}})
    { 
    $edge->clear_cells();
    $edge->{_todo} = undef;		# mark as todo
    }

  # XXX TODO:
  # put all chains on heap (based on their len)
  # take longest chain, resolve it and all "connected" chains, repeat until
  # heap is empty

  for my $chain (sort { $b->{len} <=> $a->{len} || $a->{start}->{name} cmp $b->{start}->{name} } 
     values %{$self->{chains}})
    {
    print STDERR "# laying out chain $chain->{id} (len $chain->{len})\n" if $self->{debug};

    # layout the chain nodes, then resolve inter-chain links, then traverse
    # chains recursively
    push @todo, @{ $chain->layout() } unless $chain->{_done};
    }

  # After laying out all chained nodes and their links, we need to resolve
  # left-over edges and links. We do this for each node, and then for each of
  # its edges, but do the edges shortest-first.
  
  for my $n (values %{$self->{nodes}})
    {
    # gather to-do edges
    my @edges = ();
    for my $e (values %{$n->{edges}})
      {
      # edge already done?
      next unless exists $e->{_todo};

      push @edges, $e;
      delete $e->{_todo};
      }
    # sort them on their shortest distances
    @edges = sort { $b->_distance() <=> $a->_distance() } @edges;

    # put them on the action stack in that order
    for my $e (@edges)
      {
      push @todo, [ ACTION_TRACE, $e ];
      }
    }

  $self->_dump_stack(@todo) if $self->{debug};

  ###########################################################################
  # prepare main backtracking-loop

  my $score = 0;			# overall score
  $self->{cells} = { };			# cell array (0..x,0..y)
  my $cells = $self->{cells};

  print STDERR "# Start\n" if $self->{debug};

  $self->{padding_cells} = 0;		# set to false (no filler cells yet)

  my @done = ();			# stack with already done actions
  my $step = 0;
  my $tries = 16;

  TRY:
  while (@todo > 0)			# all actions on stack done?
    {
    $step ++;
    print STDERR "\n# Step $step: Score is $score\n" if $self->{debug};

    # pop one action and mark it as done
    my $action = shift @todo; push @done, $action;

    # get the action type (ACTION_NODE etc)
    my $action_type = $action->[0];

    my ($src, $dst, $mod, $edge);

    if ($action_type == ACTION_NODE)
      {
      my (undef, $node,$try) = @$action;
      print STDERR "# step $step: action place '$node->{name}' (try $try)\n" if $self->{debug};

      $mod = 0 if defined $node->{x};
      # $action is node to be placed, generic placement at "random" location
      $mod = $self->_find_node_place( $cells, $node, undef, $try ) if (!defined $node->{x});
      }
    elsif ($action_type == ACTION_CHAIN)
      {
      my (undef, $node,$try,$parent) = @$action;
      print STDERR "# step $step: action chain '$node->{name}' to '$parent->{name}'\n" if $self->{debug};

      $mod = 0 if defined $node->{x};
      $mod = $self->_find_node_place( $cells, $node, $try, $parent ) if (!defined $node->{x});
      }
    elsif ($action_type == ACTION_TRACE)
      {
      # find a path to the target node
      ($action_type,$edge) = @$action;

      $src = $edge->{from}; $dst = $edge->{to};

      print STDERR "# step $step: action trace '$src->{name}' => '$dst->{name}'\n" if $self->{debug};

      if (!defined $dst->{x})
        {
        warn ("Target node not yet placed");

        # put current action back
        unshift @todo, $action;

	# if near-placement fails, place generic. So insert action to place
	# target beforehand:
        unshift @todo, [ ACTION_NODE, $dst ];

	$tries--;
	last TRY if $tries == 0;
        next TRY;
	}        

      # find path (mod is score modifier, or undef if no path exists)
      $mod = $self->_trace_path( $src, $dst, $edge );
      }
    else
      {
      require Carp;
      Carp::confess ("Illegal action $action->[0] on TODO stack");
      }

    if (!defined $mod)
      {
      # rewind stack
      if (($action_type == ACTION_NODE || $action_type == ACTION_CHAIN))
        { 
        print STDERR "# Step $step: Rewind stack for $action->[1]->{name}\n" if $self->{debug};

        # undo node placement and free all cells
        $action->[1]->_unplace() if defined $action->[1]->{x};
        $action->[2]++;		# increment try for placing
        $tries--;
	last TRY if $tries == 0;
        }
      else
        {
        print STDERR "# Step $step: Rewind stack for path from $src->{name} to $dst->{name}\n" if $self->{debug};
    
        # if we couldn't find a path, we need to rewind one more action (just
	# redoing the path would would fail again!)

#        unshift @todo, pop @done;
#        unshift @todo, pop @done;

#        $action = $todo[0];
#        $action_type = $action->[0];

#        $self->_dump_stack(@todo);
#
#        if (($action_type == ACTION_NODE || $action_type == ACTION_CHAIN))
#          {
#          # undo node placement
#          $action->[1]->_unplace();
#          $action->[2]++;		# increment try for placing
#          }
  	$tries--;
	last TRY if $tries == 0;
        next TRY;
        } 
      unshift @todo, $action;
      next TRY;
      } 

    $score += $mod;
    print STDERR "# Step $step: Score is $score\n" if $self->{debug};
    }

    $self->{score} = $score;			# overall score

#  if ($tries == 0)
     {
      # count placed nodes
      my $nodes = 0;
      my $i = 1;
      for my $n (sort values %{$self->{nodes}})
        {
        $nodes++ if defined $n->{x};
        }
      my $edges = 0;
      $i = 1;
      for my $e (values %{$self->{edges}})
        {
        $edges++ if scalar @{$e->{cells}} > 0 && !exists $e->{_todo};
        }
      my $e_nodes = scalar keys %{$self->{nodes}};
      my $e_edges = scalar keys %{$self->{edges}};
      if  ( ($nodes != $e_nodes) ||
            ($edges != $e_edges) )
        {
        $self->error( "Layouter could only place $nodes nodes/$edges edges out of $e_nodes/$e_edges - giving up");
        }
      }

    # all things on the stack were done, or we encountered an error

    # fill in group info and return
    $self->_fill_group_cells($cells) unless $self->{error};

    };					# end of timeout protected code

  alarm(0);				# disable alarm

  # cleanup
  $self->{chains} = undef;		# drop chain info
  foreach my $n (values %{$self->{nodes}})
    {
    # drop old chain info
    $n->{_next} = undef;
    delete $n->{_chain};
    delete $n->{_c};
    }
  die $@ if $@;				# propagate errors

  }

#############################################################################

sub _fill_group_cells
  {
  # after doing a layout(), we need to add the group to each cell based on
  # what group the nearest node is in.
  my ($self, $cells_layout) = @_;

  # if layout not done yet, do so
  $self->layout() unless defined $self->{score};

  print STDERR "\n# Padding with fill cells, have ", 
    scalar $self->groups(), " groups.\n" if $self->{debug};

  # take a shortcut if we do not have groups
  return $self if $self->groups == 0;

  $self->{padding_cells} = 1;		# set to true

  # Put all edges between two nodes with the same group in the group as well
  for my $edge (values %{$self->{edges}})
    {
    my $gf = $edge->{from}->group();
    my $gt = $edge->{to}->group();

    $edge->add_to_group($gf) if defined $gf && defined $gt && $gf == $gt;
    }

  # We need to insert "filler" cells around each node/edge/cell.

  # To "insert" the filler cells, we simple multiply each X and Y by 2, this
  # is O(N) where N is the number of actually existing cells. Otherwise we
  # would have to create the full table-layout, and then insert rows/columns.

  my $c = 'Graph::Easy::Group::Cell';
  my $cells = {};
  for my $key (keys %$cells_layout)
    {
    my ($x,$y) = split /,/, $key;
    my $cell = $cells_layout->{$key};
    $x *= 2;
    $y *= 2;
    $cell->{x} = $x;
    $cell->{y} = $y;
    $cells->{"$x,$y"} = $cell; 

#    print STDERR "# inserting for $x, $y, ", $cell->{name} || '', "\n";

    # find the primary node/edge for node/edge cells
    $cell = $cell->{node} if $cell->isa('Graph::Node::Cell');
    $cell = $cell->{edge} if $cell->isa('Graph::Edge::Cell');

    my $group = $cell->group();

    # not part of group, so no group-cells nec.
    next unless $group;

    # now insert filler cells around this cell
    my $ofs = [ -1, 0,
		0, -1,
		+1, 0,
		+1, 0,
		0, +1,
		0, +1,
		-1, 0,
		-1, 0,  ];
    while (@$ofs > 0)
      {
      $x += shift @$ofs;
      $y += shift @$ofs;

      $cells->{"$x,$y"} = $c->new ( graph => $self, group => $group, x => $x, y => $y )
        unless exists $cells->{"$x,$y"};
      }
    }

  $self->{cells} = $cells;		# override with new cell layout

  # XXX TODO
  # we should "grow" the group area to close holes

  # for all group cells, set their right type (for border) depending on
  # neighbour cells
  for my $key (keys %$cells)
    {
    my $cell = $cells->{$key};
    $cell->_set_type($cells) if ref($cell) =~ /Group::Cell/;
    }
  $self;
  }

1;
__END__

=head1 NAME

Graph::Easy::Layout - Layout the graph from Graph::Easy

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

	$graph->layout();

	print $graph->as_ascii( );

	# prints:

	# +------+     +--------+
	# | Bonn | --> | Berlin |
	# +------+     +--------+

=head1 DESCRIPTION

C<Graph::Easy::Layout> contains just the actual layout code for
L<Graph::Easy|Graph::Easy>.

=head1 METHODS

C<Graph::Easy::Layout> injects the following methods into the C<Graph::Easy>
namespace:

=head2 layout()

	$graph->layout();

Layout the actual graph.

=head2 _assign_ranks()

	$graph->_assign_ranks();

Used by C<layout()> to assign each node a rank, so they can be sorted
and grouped on these.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
