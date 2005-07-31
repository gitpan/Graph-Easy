#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 54;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Layout") or die($@);
   };

use Graph::Easy;

#############################################################################
# layer tests

my $graph = Graph::Easy->new();

is (ref($graph), 'Graph::Easy');
is ($graph->error(), '', 'no error yet');

my $A = Graph::Easy::Node->new( name => 'A' );
my $B = Graph::Easy::Node->new( 'B' );
my $C = Graph::Easy::Node->new( 'C' );
my $D = Graph::Easy::Node->new( 'D' );
my $E = Graph::Easy::Node->new( 'E' );

is ($B->name(), 'B');
is ($A->{layer}, undef, 'no layers assigned yet');

$graph->_assign_layers();
is ($A->{layer}, undef, 'A not part of graph');
is ($A->connections(), 0);

$graph->add_edge( $A, $B );
$graph->_assign_layers();
is ($A->connections(), 1);
is ($B->connections(), 1);
is_layer($A, 0); is_layer($B, 1);

$graph->add_edge( $B, $C );
$graph->_assign_layers();
is_layer($A, 0); is_layer($B, 1); is_layer($C, 2);

$graph->add_edge( $C, $D );
$graph->_assign_layers();
is_layer($A, 0); is_layer($B, 1); is_layer($C, 2); is_layer($D, 3);

$graph = Graph::Easy->new();
$graph->add_edge( $C, $D );
$graph->add_edge( $A, $B );
$graph->_assign_layers();
is_layer($A, 0); is_layer($B, 1);
is_layer($C, 0); is_layer($D, 1);

$graph->add_edge( $D, $E );
$graph->_assign_layers();
is_layer($A, 0); is_layer($B, 1);
is_layer($C, 0); is_layer($D, 1); is_layer($E, 2);

print "# IDs A B C D E: ".
      $A->{id}. " ".
      $B->{id}. " ".
      $C->{id}. " ".
      $D->{id}. " ".
      $E->{id}. "\n";

# circular path C->D->E->C
$graph->add_edge( $E, $C );
$graph->_assign_layers();
is_layer($A, 0); is_layer($B, 1);
# D => 1, then E => 2, then C => 3 (since C is still 0)
is_layer($C, 3); is_layer($D, 1); is_layer($E, 2);

#############################################################################
# looping node

$graph = Graph::Easy->new();
$graph->add_edge( $A, $A );
$graph->_assign_layers();
is ($A->connections(), 2);
# since A = 0, it will get 1
is_layer($A, 1);

#############################################################################
# multiedged graph

$graph = Graph::Easy->new();
$graph->add_edge( $A, $B );
$graph->add_edge( $A, $B ); # add second edge
$graph->_assign_layers();
# second edge does not alter result
is (scalar $A->successors(), 1);
is ($A->connections(), 2);
is (scalar $B->predecessors(), 1);
is ($B->connections(), 2);
is_layer($A, 0);
is_layer($B, 1);

#############################################################################
# near nodes (2 in layer 0, one in layer 1, 1 in layer 2)

$graph = Graph::Easy->new();
$graph->add_edge( $A, $B );
$graph->add_edge( $C, $B );
$graph->add_edge( $B, $D );
$graph->_assign_layers();
is ($A->connections(), 1);
is ($B->connections(), 3);
is ($C->connections(), 1);
is ($D->connections(), 1);
is_layer($A, 0);
is_layer($B, 1);
is_layer($C, 0);
is_layer($D, 2);

my @nodes = $graph->sorted_nodes();
is_deeply (\@nodes, [ $A, $B, $C, $D ], 'nodes sorted on id');

@nodes = $graph->sorted_nodes('layer');
is_deeply (\@nodes, [ $A, $C, $B, $D ], 'nodes sorted on layer');

@nodes = $graph->sorted_nodes('layer', 'name');
is_deeply (\@nodes, [ $A, $C, $B, $D ], 'nodes sorted on layer and name');

$A->{name} = 'a';
@nodes = $graph->sorted_nodes('layer', 'name');
is_deeply (\@nodes, [ $C, $A, $B, $D ], 'nodes sorted on layer and name');

$A->{name} = 'Z';
@nodes = $graph->sorted_nodes('layer', 'name');
is_deeply (\@nodes, [ $C, $A, $B, $D ], 'nodes sorted on layer and name');

@nodes = $graph->sorted_nodes('layer', 'id');
is_deeply (\@nodes, [ $A, $C, $B, $D ], 'nodes sorted on layer and id');

1;

#############################################################################

sub is_layer
  {
  my ($n, $l) = @_;

  is ($n->{layer}, $l, "$n->{name} is layer $l");
  }
