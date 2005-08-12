#############################################################################
# Layout directed graphs on a flat plane. Part of Graph::Easy.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Layout;

use vars qw/$VERSION/;

$VERSION = '0.09';

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
sub ACTION_PLACE () { 1; }	# place node at specific location
sub ACTION_TRACE () { 2; }	# trace path from src to dest

use Graph::Easy::Layout::Scout;	# pathfinding
use Graph::Easy::Layout::Path;	# path management

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

  $self->_find_chains();
  $self;
  }

sub _follow_chain
  {
  my ($n) = shift;

  no warnings 'recursion';

  # prevent loops be defining _chain
  $n->{_chain} = 0;
 
  my @suc = $n->successors();
  for my $s (@suc)
    {
    return if $s->{_chain} > 0;				# do not process?

    my $chain = $n->{_chain}; $n->{_chain} = 1;		# mark "no processing"
    _follow_chain($s) unless defined $s->{_chain};
    $n->{_chain} = $chain;				# restore

#    print STDERR "# got ", $s->{_chain} ||'undef'," for $s->{name}\n";
    if ($s->{_chain} <= $n->{_chain})
      {
#      print STDERR "# replacing $n->{_chain} with ", $s->{_chain} - 1," for $n->{name}\n";
      $n->{_chain} = $s->{_chain} - 1;
      $n->{_next} = $s;
      }
    }
  }

sub _find_chains
  {
  # assign a "longest chain" ptr to each node
  my $self = shift;

  # go through all nodes, and remember all leaf nodes: O(N)
  my $leaf;
  my $nodes = $self->{nodes};
  for my $n (values %$nodes)
    {
    $n->{_next} = undef;
    $n->{_chain} = undef;
    if ($n->successors() == 0)
      {
      $leaf->{$n->{id}} = $n;
      }
    }

  print STDERR "# Tracking chains\n" if $self->{debug};
 
  # For each leaf, go backwards until we hit more than one predecessor,
  # or one with _chain already set
  for my $n (keys %$leaf)
    {
    my $cur = $leaf->{$n};

    print STDERR "# starting chain at $cur->{name} ", $cur->{_chain}||'undef',"\n" if $self->{debug};
    my $step = 0; my $last;
    while (!defined $cur->{_chain} || ($cur->{_chain} > $step))
      {
      $cur->{_chain} = $step; $step--;
      $cur->{_next} = $last;
      print STDERR "# at chain len $step, $cur->{name}\n" if $self->{debug};
      my @pr = $cur->predecessors();
      last if @pr != 1;			# stop at the end of a chain,
					# or at multiple branches
      $last = $cur;
      $cur = $pr[0];			# continue with next node
      }
    }

  # make a copy
  my $todo;
  for my $n (values %$nodes)
    {
    $todo->{$n->{name}} = $n unless defined $n->{_chain};
    }

  while (keys %$todo > 0)
    {
    for my $n (values %$todo)
      {
      _follow_chain($n) unless defined $n->{_chain};
      delete $todo->{$n->{name}} if defined $n->{_chain};
      }
    }

   if ($self->{debug})
     {
     print STDERR "# Generated the following chain info:\n";
     for my $n (values %$nodes)
       {
       my $c = $n->{_chain}; $c = 'undef' if !defined $c;
       my $nt = $n->{_next}; $nt = $nt->{name} if ref($nt); $nt = 'undef' if !defined $nt;
       print STDERR "#  $n->{name} $c -> $nt\n";
       }
    }

  $self;
  }

#############################################################################
# grow nodes

sub _grow_nodes
  {
  # grow nodes so that their connections do fit on their sides
  my $self = shift;

  for my $n (values %{$self->{nodes}})
    {
    $n->grow();
    }
  $self;
  }

#############################################################################
# debug

sub _dump_stack
  {
  my ($self, @todo) = @_;

  for my $action (@todo)
    {
    my $action_type = $action->[0];
    if ($action_type == ACTION_NODE)
      {
      my ($node) = $action->[1];
      print STDERR "# action place '$node->{name}'\n" if $self->{debug};
      }
    elsif ($action_type == ACTION_PLACE)
      {
      my ($at, $node, $x,$y) = @$action;
      print STDERR "# action place '$node->{name}' at $x,$y\n" if $self->{debug};
      }
    elsif ($action_type == ACTION_TRACE)
      {
      my ($action_type,$src,$dst,$edge) = @$action;
      print STDERR "# action trace '$src->{name}' to '$dst->{name}' via edge $edge->{id}\n" if $self->{debug};
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

  $self->_grow_nodes();
  $self->_assign_ranks();

  ###########################################################################
  # prepare our stack of things we need to do before we are finished

  my @V = $self->sorted_nodes('_chain', 'rank');

  # mark all edges as unprocessed, so that we do not process them twice
  for my $edge (values %{$self->{edges}})
    { 
    $edge->{_done} = undef;
    }

  # Starting with the highest chain rank, we follow it until the end. then
  # we add whatever is still left.
  # [0]->[1]->[2]->[3]->[4] [1]->[8] would get 0..4 in the first run through,
  # then 1..8 in the second one and so on until all nodes are done.
 
  my (@todo,$done);			# actions still to do
  foreach my $n (@V)
    {
    $n->{x} = undef;			# mark every node as not placed yet
    $n->{y} = undef;

    push @todo, [ ACTION_NODE, $n ] unless exists $done->{$n};	# node needs to be placed
    $done->{$n} = undef;

    print STDERR "# following $n->{name}\n" if $self->{debug};
 
    # follow the chain
    my $c = $n;
    while (defined $c->{_next})
      {
      my $l = $c; $c = $c->{_next};
      print STDERR "# followed to $c->{name}\n" if $self->{debug};
      
      # node needs to be placed and path to target need to be found
      push @todo, [ ACTION_NODE, $c ] unless exists $done->{$c};
      $done->{$c} = undef;

      # in case there is more than one edge going from N to O
      my @edges = $l->edges_to($c);
      foreach my $edge (@edges)
        {
        if (!defined $edge)
          {
          require Carp;
          Carp::confess("Couldn't find edge from $l->{name} to $c->{name}");
          }
        print STDERR "# trace $l->{name} -> $c->{name} via edge $edge->{id}\n" if $self->{debug};
        # path to target need to be found
        push @todo, [ ACTION_TRACE, $l, $c, $edge ] unless defined $edge->{_done};
        $edge->{_done} = 1;
        }
      last if $l == $c;			# self-loop?
      }

    # after following the chain, make sure all successors are handled, too
    my @suc = $n->successors();

    print STDERR "# successors of $n->{name}\n" if $self->{debug};
  
    # sort successors by their chain target values, higher chain values first
    # the idea is to create short forward edges first
    @suc = sort { $a->{_chain} <=> $b->{_chain} } @suc;
    for my $s (@suc)
      {    
      print STDERR "# place $s->{name}\n" if $self->{debug};
      # node needs to be placed
      push @todo, [ ACTION_NODE, $s ] unless exists $done->{$s};
      $done->{$s} = undef;

      # in case there is more than one edge going from N to O
      my @edges = $n->edges_to($s);
      @edges = sort { $a->{id} <=> $b->{id} } @edges;
      foreach my $edge (@edges)
        {
        if (!defined $edge)
          {
          require Carp;
          Carp::confess("Couldn't find edge from $n->{name} to $s->{name}");
          }
        print STDERR "# trace $n->{name} -> $s->{name} via edge $edge->{id}\n" if $self->{debug};
        # path to target need to be found
        push @todo, [ ACTION_TRACE, $n, $s, $edge ] unless defined $edge->{_done};
        $edge->{_done} = 1;
        }
      }
    }

  $self->_dump_stack(@todo) if $self->{debug};

  ###########################################################################
  # prepare main backtracking-loop

  my $score = 0;			# overall score
  $self->{cells} = { };			# cell array (0..x,0..y)
  my $cells = $self->{cells};

  print STDERR "# Start\n" if $self->{debug};

  my @done = ();			# stack with already done actions
  my $step = 0;
  my $tries = 3;

  TRY:
  while (@todo > 0)			# all actions on stack done?
    {
    $step ++;
#    sleep(1) if $self->{debug};
    
    print STDERR "\n# Step $step: Score is $score\n" if $self->{debug};

    # pop one action and mark it as done
    my $action = shift @todo; push @done, $action;

    # get the action type (ACTION_PLACE etc)
    my $action_type = $action->[0];

    my ($src, $dst, $mod, $edge);

    print STDERR "# Step $step: action type $action->[0]\n" if $self->{debug};

    if ($action_type == ACTION_NODE)
      {
      my ($node) = $action->[1];
      print STDERR "# step $step: action place '$node->{name}'\n" if $self->{debug};

      # $action is node to be placed, generic placement at "random" location
      $mod = 0;
      $mod = $self->_find_node_place( $cells, $node ) if (!defined $node->{x});
      }
    elsif ($action_type == ACTION_PLACE)
      {
      my ($at, $node, $x,$y) = @$action;
      # try to place node at $x, $y
      next TRY if $node->place($x,$y,$cells);
      }
    elsif ($action_type == ACTION_TRACE)
      {
      # find a path to the target node

      ($action_type,$src,$dst,$edge) = @$action;

      print STDERR "# step $step: action trace '$src->{name}' => '$dst->{name}'\n" if $self->{debug};

      if (!defined $dst->{x})
        {
        warn ("Target node not yet placed");

        # put current action back
        unshift @todo, $action;

	# if near-placement fails, place generic. So insert action to place
	# target beforehand:
        unshift @todo, [ ACTION_NODE, $dst ];

        next TRY;
	}        

      # find path (mod is score modifier, or undef if no path exists)
      $mod = $self->_trace_path( $src, $dst, $edge );
      }
    else
      {
      require Carp;
      Carp::croak ("Illegal action $action->[0] on TODO stack");
      }

    if (!defined $mod)
      {
      # rewind stack
      if (($action_type == ACTION_NODE || $action_type == ACTION_PLACE))
        { 
        print STDERR "# Step $step: Rewind stack for $action->{name}\n" if $self->{debug};

        # undo node placement and free all cells
        # XXX TODO: free all nodes in one cluster
        $action->unplace();
        }
      else
        {
        print STDERR "# Step $step: Rewind stack for path from $src->{name} to $dst->{name}\n" if $self->{debug};
    
        # if we couldn't find a path, we need to rewind one more action (just
	# redoing the path would would fail again!)

        unshift @todo, $action;
        unshift @todo, pop @done;

        $action = $todo[0];
        $action_type = $action->[0];

        if (($action_type == ACTION_NODE || $action_type == ACTION_PLACE))
          {
          # undo node placement
          # XXX TODO: free all nodes in one cluster
          $action->unplace();
          }
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

    if ($tries == 0)
      {
      # count placed nodes
      my $nodes = 0;
      for my $n (@V)
        {
        $nodes++ if defined $n->{x};
        }
      my $edges = 0;
      for my $e (values %{$self->{edges}})
        {
        $edges++ if keys %{$e->{cells}} > 0;
        }
      $self->error( "Layouter could only place $nodes/$edges nodes/edges out of " 
                   . scalar @V . "/" . (scalar keys %{$self->{edges}}) . " - giving up");
      }

    # all things on the stack were done, or we encountered an error

    # fill in group info and return
    $self->_fill_group_cells($cells) if $tries != 0;

    };

  die $@ if $@;		# propagate errors
  alarm(0);		# disable alarm

  }

#############################################################################

sub _fill_group_cells
  {
  # after doing a layout(), we need to add the group to each cell based on
  # what group the nearest node is in.
  my ($self, $cells_layout) = @_;

  # if layout not done yet, do so
  $self->layout() unless defined $self->{score};

  # We need to insert "filler" cells around each node/edge/cell. If we do not
  # have groups, this will ensure that nodes in two consecutive rows do not
  # stick together. (We could achive the same effect with "cellpadding=3" on
  # the table, but the cellpadding area cannot be have a different background
  # color, which leaves ugly holes in colored groups).

  # To "insert" the filler cells, we simple multiply each X and Y by 2, this
  # is O(N) where N is the number of actually existing cells. Otherwise we
  # would have to create the full table-layout, and then insert rows/columns.

  my $cells = {};
  for my $key (keys %$cells_layout)
    {
    my ($x,$y) = split /,/, $key;
    my $cell = $cells_layout->{$key};
    $x *= 2;
    $y *= 2;
    $cell->{x} = $x;
    $cell->{y} = $y;
    $cells->{"$x,$y"} = $cells_layout->{$key};
    # now insert filler cells above and left of this cell
    $x -= 1;
    $cells->{"$x,$y"} = Graph::Easy::Node::Cell->new ( graph => $self );
    $y -= 1;
    $cells->{"$x,$y"} = Graph::Easy::Node::Cell->new ( graph => $self );
    $x += 1;
    $cells->{"$x,$y"} = Graph::Easy::Node::Cell->new ( graph => $self);
    }

  $self->{cells} = $cells;		# override with new cell layout

  # take a shortcut if we do not have groups
  return $self if $self->groups == 0;
  
  # for all nodes, set sourounding cells to group
  for my $key (keys %$cells)
    {
    my $n = $cells->{$key};
    my $xn = $n->{x}; my $yn = $n->{y};
    next unless defined $xn && defined $yn;	# only if node was placed

    next if ref($n) =~ /(Group|Node)::Cell/;

    my $group;

    if (ref($n) =~ /Node/)
      {
      my @groups = $n->groups();

      # XXX TODO: handle nodes with more than one group
      next if @groups != 1;			# no group? or more than one?
      $group = $groups[0];
      }
    elsif (ref($n) =~ /Edge/)
      {
      my $edge = $n;
      $edge = $edge->{edge} if ref($n) =~ /Cell/;

      # find out whether both nodes have the same group
      my $left = $edge->from();
      my $right = $edge->to();
      my @l_g = $left->groups();
      my @r_g = $right->groups();
      if (@l_g == @r_g && @l_g > 0 && $l_g[-1] == $r_g[-1])
        {
        # edge inside group
        $group = $l_g[-1];
        }
      }

    next unless defined $group;

    my $background = $group->attribute( 'background' );

    # XXX TODO: take nodes with more than one cell into account
    for my $x ($xn-1 .. $xn+1)
      {
      for my $y ($yn-1 .. $yn+1)
	{
	my $cell;

	if (!exists $cells->{"$x,$y"})
	  {
	  $cell = Graph::Easy::Group::Cell->new (
	    group => $group, graph => $self,
	    );
	  }
        else
          {
	  $cell = $cells->{"$x,$y"};

	  # convert filler cells to group cells
          if (ref($cell) !~ /(Node\z|Edge)/)
	    {
	    $cell = Graph::Easy::Group::Cell->new (
	      graph => $self, group => $group,
 	      );
            }
	  else
	    {
            if (ref($cell) =~ /Edge/)
	      {
              # add the edge-cell to the group
	      $cell->{groups}->{ $group->{name} } = $group;
	      }
	    }
          }
	$cells->{"$x,$y"} = $cell;
	$cell->{x} = $x;
	$cell->{y} = $y;
	# override the background attribute with the one from the group
        $cell->set_attribute('background', $background ) unless ref($cell) =~ /Node/;
	}
      }
    }
  # for all group cells, set their right type (for border) depending on
  # neighbour cells
  for my $key (keys %$cells)
    {
    my $cell = $cells->{$key};
    $cell->_set_type($cells) if ref($cell) =~ /Group::Cell/;
    }
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
