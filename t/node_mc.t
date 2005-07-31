#!/usr/bin/perl -w

# test nodes with more than one cell

use Test::More;
use strict;

BEGIN
   {
   plan tests => 20;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Node") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Node", qw/
  new
  /);

#############################################################################

my $node = Graph::Easy::Node->new();

is (ref($node), 'Graph::Easy::Node');

is ($node->error(), '', 'no error yet');

is ($node->connections(), 0, 'no connections yet');

my $other = Graph::Easy::Node->new();

#############################################################################
# connections() tests

my $graph = Graph::Easy->new( );

$other = Graph::Easy::Node->new( 'Name' );
$graph->add_edge ($node, $other);

is ($node->connections(), 1, 'one connection');

#############################################################################
# grow tests

for (1..4)
  {
  my $o = Graph::Easy::Node->new( "Name $_" );
  $graph->add_edge ($node, $o);
  }

is ($node->connections(), 5, '5 connections');

$node->grow();

is ($node->connections(), 5, '5 connections');
is ($node->columns(), 1, '1 column');
is ($node->rows(), 2, '2 rows');
is ($node->is_multicelled(), 1, 'is multicelled');

#############################################################################
# node placement (multi-cell)

my $cells = { };

is ($node->place(1,1,$cells), 1, 'node can be placed');

is (scalar keys %$cells, 2, '2 entries');
is ($cells->{"1,1"}, $node, 'node was really placed');
my $filler = $cells->{"1,2"};
is (ref($filler), 'Graph::Easy::Node::Cell', 'filler cell');
is ($filler->node(), $node, 'filler associated with node');

is ($node->place(1,1,$cells), 0, 'node cannot be placed again');
is ($cells->{"1,1"}, $node, 'node still there placed');
is (scalar keys %$cells, 2, 'still two entries');


