#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 28;
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

is ($group->as_txt(), "( Group \\#0\n)\n\n", 'as_txt (empty group)');
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

my $cell = Graph::Easy::Group::Cell->new( group => $group, x => 0, y => 0, );
is (scalar keys %{$group->{cells}}, 1, 'one cell');

my $cells = { '0,0' => $cell };

$cell->_set_type( $cells );

is ($cell->class(), 'group ga', 'group ga');

is ($cell->group( $group->{name} ), $group, "group()");

my $cell2 = Graph::Easy::Group::Cell->new( group => $group, x => 1, y => 0 );
is (scalar keys %{$group->{cells}}, 2, 'one more cell');
$cells->{'1,0'} = $cell2;

my $cell3 = Graph::Easy::Group::Cell->new( group => $group, x => 0, y => -1 );
is (scalar keys %{$group->{cells}}, 3, 'one more cell');
$cells->{'0,-1'} = $cell3;

my $cell4 = Graph::Easy::Group::Cell->new( group => $group, x => 0, y => 1 );
is (scalar keys %{$group->{cells}}, 4, 'one more cell');
$cells->{'0,1'} = $cell4;

is ($cell2->group( $group->{name} ), $group, "group()");

$cell->_set_type( $cells );
is ($cell->class(), 'group gl', 'group gl');

#############################################################################
# del_cell();

print join (" ", keys %{$group->{cells}}),"\n";

is (scalar keys %{$group->{cells}}, 4, 'one less');
$group->del_cell($cell);

is (scalar keys %{$group->{cells}}, 3, 'one less');
is ($cell->group(), undef, "no group() on deleted cell");

