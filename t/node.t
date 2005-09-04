#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 108;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Node") or die($@);
   use_ok ("Graph::Easy") or die($@);
   use_ok ("Graph::Easy::As_ascii") or die($@);
   };

can_ok ("Graph::Easy::Node", qw/
  new
  as_ascii as_txt as_html
  error
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
  offset
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
  origin

  is_multicelled

  _place _check_place _place_children find_grandparent
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
is ($node->is_multicelled(), 0, 'no multicelled');
is ($node->rows(), 1, '1 row');
is ($node->columns(), 1, '1 column');

# these are not set, because the node doesn't have a border and thus inherits
# it
is ($node->attribute('border'), undef, 'attribute("border")');
is ($node->attribute('border-style'), undef, 'attribute("border-style")');

is (join(",",$node->dimensions()), "7,1", 'dimensions = (7,1)');

is ($node->origin(), undef, 'not clustered');
is (join(",",$node->offset()), '0,0', 'not clustered');

is (scalar $node->successors(), undef, 'no outgoing links');
is (scalar $node->sorted_successors(), 0, 'no outgoing links');
is (scalar $node->predecessors(), undef, 'no incoming links');

my $edge = Graph::Easy::Node->new();

$edge->set_attribute('class' => 'edge');

is ($edge->class(), 'node.edge', 'class edge');

is ($edge->border_attribute(), '', 'border_attribute()');

my $other = Graph::Easy::Node->new();

is (scalar $node->edges_to($other), undef, 'no graph, no links');

#############################################################################
# predecessors(), successors(), connections() and edges_to() tests

my $graph = Graph::Easy->new( );

$other = Graph::Easy::Node->new( 'Name' );

$edge = $graph->add_edge ($node, $other);

is ($node->{graph}, $graph, "node's graph points to \$graph");
is ($other->{graph}, $graph, "other's graph points to \$graph");

is ($node->successors(), 1, '1 outgoing');
is (scalar $node->sorted_successors(), 1, '1 outgoing');
is ($node->predecessors(), 0, '0 incoming');
is (scalar $node->edges_to($other), 1, '1 link to $other');
is ($node->connections(), 1, '1 connection');

my @E = $node->edges_to($other);

is (scalar @E, 1, '1 link to $other');
is ($E[0], $edge, 'first link to $other is $edge');

is ($other->successors(), 0, '0 outgoing');
is (scalar $other->sorted_successors(), 0, '0 outgoing');
is ($other->predecessors(), 1, '1 incoming');
is ($other->connections(), 1, '1 connection');

$graph->add_edge('First', 'Name');

@E = $node->edges_to($other);
is (scalar @E, 1, '1 link to $other');
is ($E[0], $edge, 'first link to $other is $edge');

$graph->add_edge('Name', 'Name');

#############################################################################
# as_txt/as_html

my $r = 'colspan=4 rowspan=4';

is ($node->as_txt(), '[ Node \#0 ]', 'as_txt');
is ($node->as_html(), " <td $r class='node'>Node #0</td>\n",
 'as_html');

# no quoting of () nec.
$node->{name} = 'Frankfurt (Oder)';

is ($node->as_txt(), '[ Frankfurt (Oder) ]', 'as_txt');
is ($node->as_html(), " <td $r class='node'>Frankfurt (Oder)</td>\n",
 'as_html');

# quoting of |
$node->{name} = 'Frankfurt |-|';

is ($node->as_txt(), '[ Frankfurt \|-\| ]', 'as_txt');
is ($node->as_html(), " <td $r class='node'>Frankfurt |-|</td>\n",
 'as_html');

# quoting of []
$node->{name} = 'Frankfurt [ { #1 } ]';

is ($node->as_txt(), '[ Frankfurt \[ \{ \#1 \} \] ]', 'as_txt');
is ($node->as_html(), " <td $r class='node'>Frankfurt [ { #1 } ]</td>\n",
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
is ($node->as_html(), " <td $r class='node-cities'>Node #0</td>\n",
 'as_html');
is ($node->as_pure_txt(), '[ Node \#0 ]', 'as_txt_node');

$node->set_attribute ( 'color', 'blue' );
is ($node->as_txt(), '[ Node \#0 ] { color: blue; class: cities; }', 'as_txt');
is ($node->as_html(), " <td $r class='node-cities' style=\"color: #0000ff\">Node #0</td>\n",
 'as_html');
is ($node->as_pure_txt(), '[ Node \#0 ]', 'as_pure_txt');

$node->set_attributes ( { color => 'purple' } );
is ($node->as_txt(), '[ Node \#0 ] { color: purple; class: cities; }', 'as_txt');
is ($node->as_html(), " <td $r class='node-cities' style=\"color: #800080\">Node #0</td>\n",
 'as_html');
is ($node->as_pure_txt(), '[ Node \#0 ]', 'as_pure_txt');

#############################################################################
# set_attributes(class => foo)

$node->set_attributes ( { class => 'foo', color => 'orange' } );

is ($node->class(), 'node.foo', 'class set correctly');
is ($node->sub_class(), 'foo', 'class set correctly');
is ($node->attribute('color'), '#ffa500', 'color set correctly');

is ($node->as_txt(), '[ Node \#0 ] { color: orange; class: foo; }', 'as_txt');
is ($node->as_html(), " <td $r class='node-foo' style=\"color: #ffa500\">Node #0</td>\n",
 'as_html');

$node->set_attribute ( 'class', 'bar' );

is ($node->as_txt(), '[ Node \#0 ] { color: orange; class: bar; }', 'as_txt');
is ($node->as_html(), " <td $r class='node-bar' style=\"color: #ffa500\">Node #0</td>\n",
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
    '[ Node \#0 ] { color: orange; link: http://bloodgate.com/; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    " <td $r class='node-bar' style=\"color: #ffa500\"> <a href='http://bloodgate.com/'>Node #0</a> </td>\n",
    'as_html');
  }

foreach my $l (
  'perl/',
  '"perl/"',
  )
  {
  $node->set_attribute('link', $l);

  is ($node->as_txt(), 
    '[ Node \#0 ] { color: orange; link: perl/; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    " <td $r class='node-bar' style=\"color: #ffa500\"> <a href='/wiki/index.php/perl/'>Node #0</a> </td>\n",
    'as_html');
  }

$node->set_attribute('link', "test test&");
  is ($node->as_txt(), 
    '[ Node \#0 ] { color: orange; link: test test&; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    " <td $r class='node-bar' style=\"color: #ffa500\"> <a href='/wiki/index.php/test+test&'>Node #0</a> </td>\n",
    'as_html');

$node->set_attribute('color', "\\#801010");
  is ($node->as_txt(), 
    '[ Node \#0 ] { color: #801010; link: test test&; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    " <td $r class='node-bar' style=\"color: #801010\"> <a href='/wiki/index.php/test+test&'>Node #0</a> </td>\n",
    'as_html');

#############################################################################
# skipping of attributes (should not appear in HTML)

$node->set_attribute('flow','right');
$node->set_attribute('point-style','diamond');

  is ($node->as_txt(), 
    '[ Node \#0 ] { color: #801010; flow: 90; link: test test&; point-style: diamond; class: bar; }', 'as_txt');
  is ($node->as_html(), 
    " <td $r class='node-bar' style=\"color: #801010\"> <a href='/wiki/index.php/test+test&'>Node #0</a> </td>\n",
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

is ($node->width(), '7', 'width 7');
is ($node->height(), '3', 'height 3');

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



