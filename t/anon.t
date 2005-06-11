#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 20;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Node::Anon") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Node::Anon", qw/
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

my $node = Graph::Easy::Node::Anon->new();

is (ref($node), 'Graph::Easy::Node::Anon');

is ($node->error(), '', 'no error yet');

is ($node->x(), 0, 'x == 0');
is ($node->y(), 0, 'y == 0');
is ($node->width(), 3, 'w == 3');
is ($node->height(), 3, 'h == 3');
is ($node->label(), '#0', 'label');
is ($node->name(), '#0', 'name');
is ($node->title(), '', 'no title per default');
is (join(",", $node->pos()), "0,0", 'pos = 0,0');

is ($node->{graph}, undef, 'no graph');
is (scalar $node->successors(), undef, 'no outgoing links');
is (scalar $node->predecessors(), undef, 'no incoming links');
is ($node->{graph}, undef, 'successors/predecssors leave graph alone');

#############################################################################
# as_txt/as_html

is ($node->as_txt(), '[ ]', 'anon as_txt');
is ($node->as_html(), "<td class='node-anon'>#0</td>\n",
 'as_html');
is ($node->as_ascii(), "", 'anon as_ascii');

