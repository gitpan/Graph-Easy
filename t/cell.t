#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 26;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Node::Cell") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Node::Cell", qw/
  new
  as_ascii as_txt as_html
  error
  contains
  class
  name
  successors
  predecessors
  width
  height
  pos
  x
  y
  class
  title
  del_attribute
  set_attribute
  set_attributes
  attribute
  attributes_as_txt
  as_pure_txt
  group groups add_to_groups
  /);

#############################################################################

my $node = Graph::Easy::Node::Cell->new();

is (ref($node), 'Graph::Easy::Node::Cell');

is ($node->error(), '', 'no error yet');

is ($node->x(), 0, 'x == 0');
is ($node->y(), 0, 'x == 0');
is ($node->label(), '', 'label');
is ($node->name(), '', 'name');
is ($node->title(), '', 'no title per default');
is (join(",", $node->pos()), "0,0", 'pos = 0,0');
is ($node->width(),  0, 'w = 0');
is ($node->height(), 0, 'h = 0');

is (scalar $node->successors(), undef, 'no outgoing links');
is (scalar $node->predecessors(), undef, 'no incoming links');

is ($node->class(), '', 'class filler');

#############################################################################
# as_ascii/as_html

is ($node->as_ascii(), '', 'as_ascii');
is ($node->as_html(), "<td></td>\n", 'as_html');

#############################################################################
# group tests

is ($node->groups(), 0, 'no groups yet');

is ($node->group('foo'), undef, 'no groups yet');
is ($node->groups(), 0, 'no groups yet');

use Graph::Easy::Group;

my $group = Graph::Easy::Group->new( { name => 'foo' } );
$node->add_to_groups($group);

is ($node->group('foo'), $group, 'group foo');
is ($node->groups(), 1, 'one group');

#############################################################################
# title tests

$node->set_attribute('title', "foo title");

is ($node->title(), 'foo title', 'foo title');

$node->del_attribute('title');
$node->set_attribute('autotitle', 'name');

is ($node->title(), $node->name(), 'title equals name');

#############################################################################
# invisible nodes

$node = Graph::Easy::Node->new( { name => "anon 0", label => 'X' } );
$node->set_attribute('shape', "invisible");

is ($node->as_ascii(), "", 'invisible text node');


