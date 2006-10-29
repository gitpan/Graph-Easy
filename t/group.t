#!/usr/bin/perl -w

# Test Graph::Easy::Group and Graph::Easy::Group::Cell

use Test::More;
use strict;

BEGIN
   {
   plan tests => 47;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Group") or die($@);
   use_ok ("Graph::Easy::Group::Cell") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Group", qw/
  new
  error
  name
  add_node
  add_nodes
  add_member

  nodes
  edges

  add_cell del_cell

  del_node
  del_edge
  del_member

  /);

can_ok ("Graph::Easy::Group::Cell", qw/
  _set_type
  class
  /);

#############################################################################

my $group = Graph::Easy::Group->new();

is (ref($group), 'Graph::Easy::Group');

is ($group->error(), '', 'no error yet');

my $graph = Graph::Easy->new();

use_ok ('Graph::Easy::As_txt');

# "insert" into a graph to get default attributes
$group->{graph} = $graph;

is ($group->as_txt(), "( Group \\#0 )\n\n", 'as_txt (empty group)');
is (scalar $group->nodes(), 0, 'no nodes in group');
is (scalar $group->edges(), 0, 'no edges in group');
is ($group->name(), 'Group #0', 'name()');

my $first = Graph::Easy::Node->new( name => 'first' );
my $second = Graph::Easy::Node->new( name => 'second' );

$group->add_node($first);
is (scalar $group->nodes(), 1, 'one node in group');

$group->add_nodes($first, $second);
is (scalar $group->nodes(), 2, 'two nodes in group');

is ($group->as_txt(), <<HERE
( Group \\#0
  [ first ]
  [ second ]
)

HERE
, 'as_txt (group with two nodes)');

#############################################################################
# attribute nodeclass

$group = Graph::Easy::Group->new();
$group->set_attributes ( { 'nodeclass' => 'city', } );

is ($first->class(),'node', 'class is "node"');

$group->add_node($first);

is ($first->class(),'node.city', 'class is now "node.city"');

#############################################################################
# Group::Cells

my $c = '_cells';

my $cell = Graph::Easy::Group::Cell->new( group => $group, x => 0, y => 0, );
is (scalar keys %{$group->{$c}}, 1, 'one cell');

my $cells = { '0,0' => $cell };

$cell->_set_type( $cells );

is ($cell->class(), 'group ga', 'group ga');

is ($cell->group( $group->{name} ), $group, "group()");

my $cell2 = Graph::Easy::Group::Cell->new( group => $group, x => 1, y => 0 );
is (scalar keys %{$group->{$c}}, 2, 'one more cell');
$cells->{'1,0'} = $cell2;

my $cell3 = Graph::Easy::Group::Cell->new( group => $group, x => 0, y => -1 );
is (scalar keys %{$group->{$c}}, 3, 'one more cell');
$cells->{'0,-1'} = $cell3;

my $cell4 = Graph::Easy::Group::Cell->new( group => $group, x => 0, y => 1 );
is (scalar keys %{$group->{$c}}, 4, 'one more cell');
$cells->{'0,1'} = $cell4;

is ($cell2->group( $group->{name} ), $group, "group()");

$cell->_set_type( $cells );
is ($cell->class(), 'group gl', 'group gl');

#############################################################################
# attributes on cells

# The default attributes are returned by attribute():

is ($group->attribute('border-style'), 'dashed', 'group border');
is ($group->attribute('borderstyle'), 'dashed', 'group border');
is ($cell->attribute('border'), '', 'default border on this cell');
is ($cell->attribute('border-style'), 'dashed', 'default border on this cell');

is ($group->default_attribute('border-style'), 'dashed', 'group is dashed');
is ($cell->default_attribute('border'), 'dashed 1px #000000', 'dashed border on this cell');
is ($cell->default_attribute('border-style'), 'dashed', 'dashed border on this cell');

is ($group->default_attribute('fill'), '#a0d0ff', 'fill on group');
is ($group->attribute('fill'), '#a0d0ff', 'fill on group');
is ($cell->default_attribute('fill'), '#a0d0ff', 'fill on group cell');
is ($cell->attribute('fill'), '#a0d0ff', 'fill on group cell');

#############################################################################
# del_cell();

#print join (" ", keys %{$group->{cells}}),"\n";

is (scalar keys %{$group->{$c}}, 4, 'one less');
$group->del_cell($cell);

is (scalar keys %{$group->{$c}}, 3, 'one less');
is ($cell->group(), undef, "no group() on deleted cell");

#############################################################################
# del_node() & del_edge(), when node/edge are in a group (bug until 0.39)

$graph = Graph::Easy->new();

$group = $graph->add_group('group');

my ($A,$B,$E) = $graph->add_edge('A','B','E');

for my $m ($A,$B,$E)
  {
  $group->add_member($m);
  }

is ($group->nodes(), 2, '2 nodes in group');
is ($group->edges(), 1, '1 edge in group');

$graph->del_node($A);

is ($group->nodes(), 1, '1 node in group');
is ($group->edges(), 0, '0 edge in group');

($A,$B,$E) = $graph->add_edge('A','B','E');

$group->add_member($A);
$group->add_member($E);

is ($group->nodes(), 2, '2 nodes in group');
is ($group->edges(), 1, '1 edge in group');

$graph->del_edge($E);

is ($group->nodes(), 2, '2 nodes in group');
is ($group->edges(), 0, '0 edge in group');

