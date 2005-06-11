#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 27;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Cluster") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Cluster", qw/
  new
  error
  add_node
  add_nodes
  center_node
  nodes
  /);

can_ok ("Graph::Easy", qw/
  add_cluster
  del_cluster
  clusters
  cluster
  /);

#############################################################################
# basic tests

my $cluster = Graph::Easy::Cluster->new( name => 'cluster' );

is (ref($cluster), 'Graph::Easy::Cluster');

is ($cluster->error(), '', 'no error yet');

is (scalar $cluster->nodes(), 0, 'no nodes in cluster yet');

my $first = Graph::Easy::Node->new( name => 'first' );
my $second = Graph::Easy::Node->new( name => 'second' );

$cluster->add_node($first);
is (scalar $cluster->nodes(), 1, 'one node in cluster');

$cluster->add_nodes($first, $second);
is (scalar $cluster->nodes(), 2, 'two nodes in cluster');

#############################################################################
# center_node

$cluster->center_node($first);
is ($cluster->center_node(), $first, 'center_ndoe set');

#############################################################################
# graph tests

is ($cluster->{graph}, undef, 'unregistered yet');

my $graph = Graph::Easy->new();

is (scalar $graph->clusters(), 0, 'no clusters yet');
$graph->add_cluster ($cluster);
is ($cluster->{graph}, $graph, 'registered');
is (scalar $graph->clusters(), 1, 'one cluster');

# not added again
$graph->add_cluster ($cluster);
is (scalar $graph->clusters(), 1, 'one cluster');

is (join (" ", $graph->clusters()), $cluster, 'one cluster');
is ($graph->cluster ('cluster'), $cluster, 'found again');

$graph->del_cluster ($cluster);
is (scalar $graph->clusters(), 0, 'no clusters yet');

#############################################################################
# node placement (clustered)

$cluster = Graph::Easy::Cluster->new( name => 'cluster' );
$graph = Graph::Easy->new();
$graph->add_cluster ($cluster);

my $node = Graph::Easy::Node->new( name => 'A' );
$graph->add_node($node);
$node->add_to_cluster($cluster);
$second = Graph::Easy::Node->new( name => 'B', dx => 1, dy => 0 );
$graph->add_node($second);
$second->add_to_cluster($cluster);

$cluster->center_node($node);

is (scalar $graph->nodes(), 2, 'two nodes');

my $cells = { };

is ($node->place(1,1,$cells), 1, 'node can be placed');

is ($cells->{"1,1"}, $node, 'node was really placed');
is ($cells->{"2,1"}, $second, 'second node was placed, too');
is (scalar keys %$cells, 2, 'two nodes placed');

# 1,0 and 2,0 are blocked, so 0,0+1,0; 1,0+2,0 and 2,0+3,0 are blocked, too:
is ($node->place(0,1,$cells), 0, 'node cannot be placed again');
is ($node->place(1,1,$cells), 0, 'node cannot be placed again');
is ($node->place(2,1,$cells), 0, 'node cannot be placed again');

is (scalar keys %$cells, 2, 'two nodes placed');



