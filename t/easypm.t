#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 106;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy", qw/
  new
  css as_html as_html_page as_txt
  as_ascii as_ascii_html
  as_graphviz as_svg
  html_page_header
  html_page_footer
  error
  node nodes edges
  add_edge
  add_node
  set_attributes
  set_attribute
  get_attribute
  attribute
  del_attribute
  score
  id
  group groups add_group del_group
  is_simple_graph

  text_style
  text_styles
  text_styles_as_css
  /);

#############################################################################
# adding edges/nodes

my $graph = Graph::Easy->new();

is (ref($graph), 'Graph::Easy');

is ($graph->error(), '', 'no error yet');
is ($graph->is_simple_graph(), 1, 'simple graph (0 nodes)');

my $node = Graph::Easy::Node->new( name => 'Bonn' );
my $node2 = Graph::Easy::Node->new( name => 'Berlin' );

is (scalar $graph->nodes(), 0, 'no nodes');
is (scalar $graph->edges(), 0, 'no edges');

$graph->add_edge( $node, $node2 );

is (scalar $graph->nodes(), 2, '2 nodes');
is (scalar $graph->edges(), 1, '1 edges');
is ($graph->is_simple_graph(), 1, 'simple graph (2 nodes, 1 edge)');

my $node3 = Graph::Easy::Node->new( name => 'Frankfurt');

$graph->add_edge( $node2, $node3 );

is (scalar $graph->nodes(), 3, '3 nodes');
is (scalar $graph->edges(), 2, '2 edges');
is ($graph->is_simple_graph(), 1, 'still simple graph');

my $node4 = Graph::Easy::Node->new( name => 'Dresden' );

$graph->add_edge( $node3, $node4 );

is (scalar $graph->nodes(), 4, '4 nodes');
is (scalar $graph->edges(), 3, '3 edges');
is ($graph->is_simple_graph(), 1, 'still simple graph');

my $node5 = Graph::Easy::Node->new( name => 'Potsdam' );

$graph->add_edge( $node2, $node5 );

is (scalar $graph->nodes(), 5, '5 nodes');
is (scalar $graph->edges(), 4, '4 edges');
is ($graph->is_simple_graph(), 1, 'still simple graph');

my $node6 = Graph::Easy::Node->new( name => 'Cottbus' );

$graph->add_edge( $node5, $node6 );

is (scalar $graph->nodes(), 6, '6 nodes');
is (scalar $graph->edges(), 5, '5 edges');
is ($graph->is_simple_graph(), 1, 'still simple graph');

#############################################################################
# attribute tests

is ($graph->attribute('node', 'background'), undef, 
	'node.background = undef');

is ($graph->attribute('node', 'fill'), 'white', 
	'node { fill: white }');

is ($graph->attribute('graph', 'border'), '', 
	'graph { border: none; }');

$graph->set_attributes ('graph', { color => 'white', background => 'red' });

is ($graph->attribute('graph', 'background'), '#ff0000', 
	'now: graph { background: #ff0000 }');
is ($graph->attribute('graph', 'color'), '#ffffff', 
	'now: graph { color: #ffffff }');

good_css ($graph);

#############################################################################
# ID tests

is ($graph->id(), '', 'id is empty string');

is ($graph->id('42'), '42', 'id is now 42');

good_css($graph);

#############################################################################
# ID tests with sub-classes

$graph->set_attributes ('node.cities', { color => '#808080' } );

good_css($graph, 
  'table.graph42 .node-cities',
  'table.graph42 .node, table.graph42 .node-cities'
  );

#############################################################################
# group tests

is ($graph->groups(), 0, 'no groups yet');

is ($graph->group('foo'), undef, 'no groups yet');
is ($graph->groups(), 0, 'no groups yet');

my $group = Graph::Easy::Group->new( { name => 'Cities' } );
$graph->add_group($group);

is ($graph->group('Cities'), $group, "group 'cities'");
is ($graph->groups(), 1, 'one group');
is ($graph->group('cities'), undef, 'no group');
is ($graph->groups(), 1, 'one group');

is ($graph->as_txt(), <<HERE
graph {
  background: red;
  color: white;
}
node.cities { color: grey; }

( Cities
)

[ Bonn ] --> [ Berlin ]
[ Berlin ] --> [ Frankfurt ]
[ Berlin ] --> [ Potsdam ]
[ Frankfurt ] --> [ Dresden ]
[ Potsdam ] --> [ Cottbus ]
HERE
, 'with empty group Cities'); 

$node->add_to_groups($group);

is ($graph->as_txt(), <<HERE
graph {
  background: red;
  color: white;
}
node.cities { color: grey; }

( Cities
  [ Bonn ]
)

[ Bonn ] --> [ Berlin ]
[ Berlin ] --> [ Frankfurt ]
[ Berlin ] --> [ Potsdam ]
[ Frankfurt ] --> [ Dresden ]
[ Potsdam ] --> [ Cottbus ]
HERE
, 'with empty group Cities'); 


#############################################################################
# title/link/autolink/autotitle/linkbase not in CSS

$graph->set_attributes ('node', 
  { link => 123, title => 123, autolink => 'name', autotitle => 'name' } );
$graph->set_attributes ('graph', { linkbase => '123/' } );

good_css ($graph);

# check that add_node( 'name' ) works

$graph = Graph::Easy->new();

my $bonn = $graph->add_node( 'Bonn' );

is (scalar $graph->nodes(), 1, 'one node');
is ($graph->node('Bonn'), $bonn, 'add_node returned $bonn');

# already in graph, try to add as "name"
my $bonn2 = $graph->add_node( 'Bonn' );

is (scalar $graph->nodes(), 1, 'one node');
is ($bonn2, $graph->node('Bonn'), 'add_node returned $bonn');
is ($bonn, $bonn2, 'same node');

# already in graph, try to add as node object
my $bonn3 = $graph->add_node( $bonn );

is (scalar $graph->nodes(), 1, 'one node');
is ($bonn3, $graph->node('Bonn'), 'add_node returned $bonn');
is ($bonn, $bonn3, 'same node');

my $bonn5 = Graph::Easy::Node->new('Bonn');
my $bonn4 = $graph->add_node( $bonn5);

#make sure that $bonn is not replaced by $bonn5 in graph!
is (scalar $graph->nodes(), 1, 'one node');
is ($bonn4, $graph->node('Bonn'), 'add_node returned $bonn');
is ($bonn, $bonn4, 'same node');

#############################################################################
# adding an edge with two plain scalars as names

$graph = Graph::Easy->new();
my $edge = $graph->add_edge( 'Test', 'Test2' );

is (scalar $graph->nodes(), 2, '2 nodes');
is (scalar $graph->edges(), 1, '1 edge');
is ($edge, $graph->edge('Test', 'Test2'), 'edge() works');

# adding a multi-edge
$graph->add_edge( 'Test', 'Test2' );

is (scalar $graph->nodes(), 2, '2 nodes');
is (scalar $graph->edges(), 2, '2 edges');

# this assumes "Test" is created before "Test2"
my @N = sort { $a->{id} <=> $b->{id} } $graph->nodes();

my @E = $N[0]->edges_to($N[1]);

is (@E, 2, '2 edges from Test to Test2');

# this should work now:
my $ascii = $graph->as_ascii();

like ($ascii, qr/Test/, 'Test found in output');
like ($ascii, qr/Test2/, 'Test found in output');

# test that add_edge('Test','Test') does not create two nodes

$graph = Graph::Easy->new();
my ($a,$b,$e) = $graph->add_edge( 'Test', 'Test' );

is ($a->{id}, $b->{id}, "one node for ('test','test')");
is ($a, $b, "one object for ('test','test')");

#############################################################################
# is_ascii_html()

$ascii = $graph->as_ascii_html();

like ($ascii, qr/<pre>(.|\n)*<\/pre>/, 'as_ascii_html');

#############################################################################
# is_simple_graph()

$graph = Graph::Easy->new();
$edge = $graph->add_edge( 'Test', 'Test2' );
is ($graph->is_simple_graph(), 1, 'still simple graph');

$edge = $graph->add_edge( 'Test', 'Test2' );
is ($graph->is_simple_graph(), 0, 'not simple graph');

$edge = $graph->add_edge( 'Test', 'Test2' );
is ($graph->is_simple_graph(), 0, 'not simple graph');

$graph = Graph::Easy->new();
$edge = $graph->add_edge( 'Test', 'Test' );
is ($graph->is_simple_graph(), 1, 'still simple graph');

$edge = $graph->add_edge( 'Test', 'Test2' );
is ($graph->is_simple_graph(), 1, 'still simple graph');

$edge = $graph->add_edge( 'Test', 'Test' );
is ($graph->edges(), 3, '3 edges');
is ($graph->nodes(), 2, '2 nodes');
is ($graph->is_simple_graph(), 0, 'not simple graph');

1; # all tests done

#############################################################################

sub good_css
  {
  my $graph = shift;

  my $css = $graph->css();

  foreach my $class (qw/edge node/, )
    {
    like ($css, qr/table\.graph\d* \.$class/, "$class in css");
    }
  like ($css, qr/graph\d* \{/, "graph in css");
  foreach my $add (@_)
    {
    like ($css, qr/$add/, "$add in css");
    }
  foreach my $attr (qw/link label title linkbase autotitle autolabel/)
    {
    unlike ($css, qr/$attr/, "$attr not in css");
    }
  }

