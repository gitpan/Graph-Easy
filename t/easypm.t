#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 76;
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
  score
  id
  group groups add_group del_group
  _color_as_hex
  /);

#############################################################################
# layout tests

my $graph = Graph::Easy->new();

is (ref($graph), 'Graph::Easy');

is ($graph->error(), '', 'no error yet');

my $node = Graph::Easy::Node->new( name => 'Bonn' );
my $node2 = Graph::Easy::Node->new( name => 'Berlin' );

$graph->add_edge( $node, $node2 );

#print $graph->as_ascii();

$graph->{debug} = 0;

my $node3 = Graph::Easy::Node->new( name => 'Frankfurt', border => 'dotted' );

$graph->add_edge( $node2, $node3 );

#print $graph->as_ascii();

my $node4 = Graph::Easy::Node->new( name => 'Dresden' );

$graph->add_edge( $node3, $node4 );

#print $graph->as_ascii();

my $node5 = Graph::Easy::Node->new( name => 'Potsdam' );

$graph->add_edge( $node2, $node5 );

#print $graph->as_ascii();

my $node6 = Graph::Easy::Node->new( name => 'Cottbus' );

$graph->add_edge( $node5, $node6 );

#print $graph->as_ascii();

#############################################################################
# _color_as_hex()

is ($graph->_color_as_hex('red'), '#ff0000', 'color red');
is ($graph->_color_as_hex('rgb(255,0,0)'), '#ff0000', 'color rgb(255,0,0)');
is ($graph->_color_as_hex('rgb( 255, 0, 0)'), '#ff0000', 'color rgb( 255, 0, 0)');
is ($graph->_color_as_hex('rgb( 255 , 0 , 0 )'), '#ff0000', 'color rgb( 255 , 0 , 0 )');
is ($graph->_color_as_hex('#ff0000'), '#ff0000', 'color #ff0000 stays');

is ($graph->_color_as_hex('lavender'), '#e6e6fa', 'color lavender');
is ($graph->_color_as_hex('lavenderblush'), '#fff0f5', 'color lavenderblush');

is ($graph->_color_as_hex('lavenderbush'), undef, 'color lavenderbush does not exist');

#############################################################################
# attribute tests

is ($graph->attribute('node', 'background'), 'white', 
	'node { background: white }');

is ($graph->attribute('graph', 'border'), '', 
	'graph { border: none; }');

$graph->set_attributes ('graph', { color => 'white', background => 'red' });

is ($graph->attribute('graph', 'background'), 'red', 
	'now: graph { background: red }');
is ($graph->attribute('graph', 'color'), 'white', 
	'now: graph { color: white }');

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
node.cities { color: #808080; }

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
node.cities { color: #808080; }

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

1; # all tests done

#############################################################################

sub good_css
  {
  my $graph = shift;

  my $css = $graph->css();

  foreach my $class (qw/edge group/, )
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

