#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 92;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Node") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Node", qw/
  new
  as_ascii as_txt as_html
  error
  contains
  class
  dimensions
  name
  sorted_successors
  successors
  predecessors
  connections
  edges_to
  width
  height
  columns
  rows
  grow
  pos
  x
  y
  class
  title
  place
  shape
  del_attribute
  set_attribute
  set_attributes
  attribute
  attributes_as_txt
  border_attribute
  as_pure_txt
  group groups add_to_groups
  add_to_cluster
  cluster
  origin
  /);

#############################################################################

my $node = Graph::Easy::Node->new();

is (ref($node), 'Graph::Easy::Node');

is ($node->error(), '', 'no error yet');

is ($node->x(), 0, 'x == 0');
is ($node->y(), 0, 'x == 0');
is ($node->label(), 'Node #0', 'label');
is ($node->name(), 'Node #0', 'name');
is ($node->class(), 'node', 'class node');
is ($node->title(), '', 'no title per default');
is (join(",", $node->pos()), "0,0", 'pos = 0,0');
is ($node->width(), undef, 'w = undef');	# no graph => thus no width yet
is ($node->height(), 3, 'h = 3');
is ($node->shape(), 'rect', 'default shape is "rect"');
is ($node->border_attribute(), '', 'border_attribute()');
is ($node->connections(), 0, 'no connections yet');

# these are not set, because the node doesn't have a border and thus inherits
# it
is ($node->attribute('border'), undef, 'attribute("border")');
is ($node->attribute('border-style'), undef, 'attribute("border-style")');

is (join(",",$node->dimensions()), "7,1", 'dimensions = (7,1)');

is ($node->cluster(), undef, 'not clustered');
is ($node->origin(), undef, 'not clustered');
is (join(",",$node->relpos()), '0,0', 'not clustered');

is (scalar $node->successors(), undef, 'no outgoing links');
is (scalar $node->sorted_successors(), 0, 'no outgoing links');
is (scalar $node->predecessors(), undef, 'no incoming links');

my $edge = Graph::Easy::Node->new( class => 'edge', w => 19);

is ($edge->class(), 'edge', 'class edge');
is ($edge->width(), 19, 'specified w as 19');

is ($edge->border_attribute(), '', 'border_attribute()');

my $other = Graph::Easy::Node->new();

#############################################################################
# predecessors() and successors() tests

my $graph = Graph::Easy->new( );

$other = Graph::Easy::Node->new( 'Name' );
$graph->add_edge ($node, $other);

is ($node->successors(), 1, '1 outgoing');
is (scalar $node->sorted_successors(), 1, '1 outgoing');
is ($node->predecessors(), 0, '0 incoming');

is ($other->successors(), 0, '0 outgoing');
is (scalar $other->sorted_successors(), 0, '0 outgoing');
is ($other->predecessors(), 1, '1 incoming');

#############################################################################
# as_txt/as_html

is ($node->as_txt(), '[ Node \#0 ]', 'as_txt');
is ($node->as_html(), "<td class='node'>Node #0</td>\n",
 'as_html');

# no quoting of () nec.
$node->{name} = 'Frankfurt (Oder)';

is ($node->as_txt(), '[ Frankfurt (Oder) ]', 'as_txt');
is ($node->as_html(), "<td class='node'>Frankfurt (Oder)</td>\n",
 'as_html');

# quoting of |
$node->{name} = 'Frankfurt |-|';

is ($node->as_txt(), '[ Frankfurt \|-\| ]', 'as_txt');
is ($node->as_html(), "<td class='node'>Frankfurt |-|</td>\n",
 'as_html');

# quoting of []
$node->{name} = 'Frankfurt [ { #1 } ]';

is ($node->as_txt(), '[ Frankfurt \[ \{ \#1 \} \] ]', 'as_txt');
is ($node->as_html(), "<td class='node'>Frankfurt [ { #1 } ]</td>\n",
 'as_html');


#############################################################################
# as_txt with labels

$node->set_attribute('label', 'thelabel');
$node->{name} = 'name';

is ($node->as_txt(), '[ name ] { label: thelabel; }', 'as_txt');

# reset name for next tests
$node->{name} = 'Node #0';
$node->del_attribute('label');

#############################################################################
# as_txt/as_html w/ subclass and attributes

$node->{class} = 'node.cities';

is ($node->as_txt(), '[ Node \#0 ] { class: cities; }', 'as_txt');
is ($node->as_html(), "<td class='node-cities'>Node #0</td>\n",
 'as_html');
is ($node->as_pure_txt(), '[ Node \#0 ]', 'as_txt_node');

$node->set_attribute ( 'color', 'blue' );
is ($node->as_txt(), '[ Node \#0 ] { color: blue; class: cities; }', 'as_txt');
is ($node->as_html(), "<td class='node-cities' style=\"color: blue\">Node #0</td>\n",
 'as_html');
is ($node->as_pure_txt(), '[ Node \#0 ]', 'as_pure_txt');

$node->set_attribute ( 'padding', '1em' );
is ($node->as_txt(), '[ Node \#0 ] { color: blue; padding: 1em; class: cities; }', 'as_txt');
is ($node->as_html(), "<td class='node-cities' style=\"color: blue; padding: 1em\">Node #0</td>\n",
 'as_html');
is ($node->as_pure_txt(), '[ Node \#0 ]', 'as_pure_txt');

$node->set_attributes ( { padding => '2em', color => 'purple' } );
is ($node->as_txt(), '[ Node \#0 ] { color: purple; padding: 2em; class: cities; }', 'as_txt');
is ($node->as_html(), "<td class='node-cities' style=\"color: purple; padding: 2em\">Node #0</td>\n",
 'as_html');
is ($node->as_pure_txt(), '[ Node \#0 ]', 'as_pure_txt');

#############################################################################
# set_attributes(class => foo)

$node->set_attributes ( { class => 'foo', color => 'octarine' } );

is ($node->as_txt(), '[ Node \#0 ] { color: octarine; padding: 2em; class: foo; }', 'as_txt');
is ($node->as_html(), "<td class='node-foo' style=\"color: octarine; padding: 2em\">Node #0</td>\n",
 'as_html');

$node->set_attribute ( 'class', 'bar' );

is ($node->as_txt(), '[ Node \#0 ] { color: octarine; padding: 2em; class: bar; }', 'as_txt');
is ($node->as_html(), "<td class='node-bar' style=\"color: octarine; padding: 2em\">Node #0</td>\n",
 'as_html');

#############################################################################
# set_attribute() with encoded entities (%3a etc) and quotation marks

foreach my $l (
  'http://bloodgate.com/',
  '"http://bloodgate.com/"',
  '"http%3a//bloodgate.com/"',
  )
  {
  $node->set_attribute('link', $l);

  is ($node->as_txt(), 
    '[ Node \#0 ] { color: octarine; link: http://bloodgate.com/; padding: 2em; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    "<td class='node-bar' style=\"color: octarine; padding: 2em\"> <a href='http://bloodgate.com/'>Node #0</a> </td>\n",
    'as_html');
  }

foreach my $l (
  'perl/',
  '"perl/"',
  )
  {
  $node->set_attribute('link', $l);

  is ($node->as_txt(), 
    '[ Node \#0 ] { color: octarine; link: perl/; padding: 2em; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    "<td class='node-bar' style=\"color: octarine; padding: 2em\"> <a href='/wiki/index.php/perl/'>Node #0</a> </td>\n",
    'as_html');
  }

$node->set_attribute('link', "test test&");
  is ($node->as_txt(), 
    '[ Node \#0 ] { color: octarine; link: test test&; padding: 2em; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    "<td class='node-bar' style=\"color: octarine; padding: 2em\"> <a href='/wiki/index.php/test+test&'>Node #0</a> </td>\n",
    'as_html');

$node->set_attribute('color', "\\#801010");
  is ($node->as_txt(), 
    '[ Node \#0 ] { color: #801010; link: test test&; padding: 2em; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    "<td class='node-bar' style=\"color: #801010; padding: 2em\"> <a href='/wiki/index.php/test+test&'>Node #0</a> </td>\n",
    'as_html');

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

$node->set_attribute('autotitle', 'label');

is ($node->title(), $node->name(), 'title equals name');

$node->set_attribute('label', 'label');
is ($node->title(), 'label', 'title equals label');

#############################################################################
# invisible nodes

$node = Graph::Easy::Node->new( { name => "anon 0", label => 'X' } );
$node->set_attribute('shape', "invisible");

is ($node->as_ascii(), "", 'invisible text node');

#############################################################################
# as_ascii() and label vs name (bug until v0.16)

$node = Graph::Easy::Node->new( { name => "Node #0", label => 'label' } );
is ($node->label(), 'label', 'node label eq "label"');

$node->_correct_size();

like ($node->as_ascii(), qr/label/, 'as_ascii uses label, not name');

#############################################################################
# node placement (unclustered)

$node = Graph::Easy::Node->new();

my $cells = { };

is ($node->place(1,1,$cells), 1, 'node can be placed');

is ($cells->{"1,1"}, $node, 'node was really placed');
is (scalar keys %$cells, 1, 'one entry');

is ($node->place(1,1,$cells), 0, 'node cannot be placed again');
is ($cells->{"1,1"}, $node, 'node still there placed');
is (scalar keys %$cells, 1, 'one entry');



