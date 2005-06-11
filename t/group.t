#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 19;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Group") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Group", qw/
  new
  as_txt
  error
  name
  add_node
  add_nodes
  nodes
  /);

use Graph::Easy::Group::Cell qw/GROUP_INNER GROUP_ALL GROUP_LEFT/;

#############################################################################

my $group = Graph::Easy::Group->new();

is (ref($group), 'Graph::Easy::Group');

is ($group->error(), '', 'no error yet');

is ($group->as_txt(), "( Group \\#0\n)\n\n", 'as_txt (empty group)');
is (scalar $group->nodes(), 0, 'no nodes in group');

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

my $cell = Graph::Easy::Group::Cell->new( group => $group );

is ($cell->type(), GROUP_INNER, 'group_inner as default');

$cell->{x} = 0; $cell->{y} = 0;
my $cells = { '0,0' => $cell };

$cell->_set_type( $cells );

is ($cell->type(), GROUP_ALL, 'GROUP_ALL');
is ($cell->class(), 'group-all', 'group-all');

is ($cell->group( $group->{name} ), $group, "group()");

my $cell2 = Graph::Easy::Group::Cell->new( group => $group );
$cell2->{x} = 1; $cell2->{y} = 0;
$cells->{'1,0'} = $cell2;

my $cell3 = Graph::Easy::Group::Cell->new( group => $group );
$cell3->{x} = 0; $cell3->{y} = -1;
$cells->{'0,-1'} = $cell3;

my $cell4 = Graph::Easy::Group::Cell->new( group => $group );
$cell4->{x} = 0; $cell4->{y} = +1;
$cells->{'0,1'} = $cell4;

is ($cell2->group( $group->{name} ), $group, "group()");

$cell->_set_type( $cells );
is ($cell->type(), GROUP_LEFT, 'GROUP_LEFT');
is ($cell->class(), 'group-l', 'group-l');

