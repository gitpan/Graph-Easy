#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 101;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy") or die($@);
   };

#############################################################################
my $graph = Graph::Easy->new();

is (ref($graph), 'Graph::Easy');

is ($graph->error(), '', 'no error yet');

is ($graph->nodes(), 0, '0 nodes');
is ($graph->edges(), 0, '0 edges');

is (join (',', $graph->edges()), '', '0 edges');

like ($graph->as_graphviz(), qr/digraph.*\{/, 'looks like digraph');
unlike ($graph->as_graphviz(), qr/#/, 'and has proper comment');
like ($graph->as_graphviz(), qr#// Generated#, 'and has proper comment');

#############################################################################
# after first call to as_graphviz, these should now exist:

can_ok ("Graph::Easy::Node", qw/
  attributes_as_graphviz
  as_graphviz_txt
  /);

#############################################################################
# with some nodes

my $bonn = Graph::Easy::Node->new( name => 'Bonn' );
my $berlin = Graph::Easy::Node->new( 'Berlin' );

my $edge = $graph->add_edge ($bonn, $berlin);

my $grviz = $graph->as_graphviz();

like ($grviz, qr/Bonn/, 'contains Bonn');
like ($grviz, qr/Berlin/, 'contains Bonn');

like ($grviz, qr/arrowhead=open/, 'contains open arrowheads');

unlike ($grviz, qr/\w+=,/, "doesn't contain empty defintions");

#print $graph->as_graphviz(),"\n";

#############################################################################
# with attributes on the graph

$graph->set_attribute( 'graph', 'fill' => 'red' );

like ($graph->as_graphviz(), qr/bgcolor="#ff0000"/, 'contains bgcolor="#ff0000"');

#print $graph->as_graphviz(),"\n";

#############################################################################
# with label/label-pos attributes on the graph

$graph->set_attribute( 'graph', 'label' => 'My Label' );
$grviz = $graph->as_graphviz();

like ($grviz, qr/label="My Label"/, 'graph label');
like ($grviz, qr/labelloc=top/, 'default is top (dot 1.1 seems to get this wrong)');

$graph->set_attribute( 'graph', 'label-pos' => 'top' );
$grviz = $graph->as_graphviz();

like ($grviz, qr/label="My Label"/, 'graph label');
like ($grviz, qr/labelloc=top/, 'default is top');

#print $graph->as_graphviz(),"\n";

$graph->set_attribute( 'graph', 'label-pos' => 'bottom' );
$grviz = $graph->as_graphviz();

like ($grviz, qr/label="My Label"/, 'graph label');
like ($grviz, qr/labelloc=bottom/, 'now bottom');

#print $graph->as_graphviz(),"\n";

#############################################################################
# with some nodes with atributes

$bonn->set_attribute( 'shape' => 'rect' );

like ($graph->as_graphviz(), qr/[^"]Bonn[^"]/, 'contains Bonn unquoted');
like ($graph->as_graphviz(), qr/[^"]Berlin[^"]/, 'contains Bonn unquoted');
like ($graph->as_graphviz(), qr/shape=box/, 'contains shape');

#print $graph->as_graphviz(),"\n";

#############################################################################
# remapped attributes, quoted attributes

$bonn->set_attributes( { 
  fill => '#808080', 
  title => 'title string', 
  color => 'red', 
  'border-color' => 'brown',
  class => 'city',
  } );

$grviz = $graph->as_graphviz();

like ($grviz, qr/fillcolor="#808080"/, 'contains fillcolor');
like ($grviz, qr/tooltip="title string"/, 'contains tooltip');
like ($grviz, qr/color="#a52a2a"/, 'contains color');
like ($grviz, qr/fontcolor="#ff0000"/, 'contains fontcolor');
unlike ($grviz, qr/(city|class)/, "doesn't contain class");

#print $graph->as_graphviz(),"\n";

#############################################################################
# quoting (including " in node names)

$bonn->{name} = 'Bonn"';

$grviz = $graph->as_graphviz();
like ($grviz, qr/"Bonn\\""/, 'quoted Bonn"');

$bonn->{name} = 'Bonn und Umgebung';

$grviz = $graph->as_graphviz();
like ($grviz, qr/"Bonn und Umgebung"/, 'quoted "Bonn und Umgebung"');

is (join(",", $graph->_graphviz_remap_edge_style('style', 'bold')), 'style,bold', 'style,bold');
is (join(",", $graph->_graphviz_remap_edge_style('style', 'double')), 'style,bold', 'style,double => style, bold');

my ($name,$style) = $graph->_graphviz_remap_edge_style('style', 'solid');

is ($name, undef, 'style=solid suppressed');
is ($style, undef, 'style=solid suppressed');

$bonn->{name} = '2A';

$grviz = $graph->as_graphviz();
like ($grviz, qr/"2A"/, '"2A" must be quoted');

$bonn->{name} = '123';

$grviz = $graph->as_graphviz();
like ($grviz, qr/ 123 /, '"123" needs no quotes');

# strict should come last in this list:
for (qw/0AB graph subgraph edge node Graph Edge Strict strict/)
  {
  $bonn->{name} = $_;

  $grviz = $graph->as_graphviz();
  like ($grviz, qr/"$_"/, "'$_' needs quotes");
  }

$bonn->set_attribute('label', 'Graph::Easy');

$grviz = $graph->as_graphviz();
like ($grviz, qr/label="Graph::Easy"/, 'label with non \w needs quoting');

#############################################################################
# flow directions

$graph->set_attribute('graph','flow','south');

$grviz = $graph->as_graphviz();
unlike ($grviz, qr/rankdir/, 'flow south needs no rankdir');
like ($grviz, qr/"strict" -> Berlin/, 'edge direction normal');

$graph->set_attribute('graph','flow','west');

$grviz = $graph->as_graphviz();
like ($grviz, qr/rankdir=LR/, 'flow west has LR and reversed edges');
like ($grviz, qr/Berlin -> "strict"/, 'edge direction reversed');
like ($grviz, qr/dir=back/, 'edge direction reversed');

$graph->set_attribute('graph','flow','up');

$grviz = $graph->as_graphviz();
unlike ($grviz, qr/rankdir/, 'flow west has TB and reversed edges');
like ($grviz, qr/Berlin -> "strict"/, 'edge direction reversed');
like ($grviz, qr/dir=back/, 'edge direction reversed');

#############################################################################
# arrow styles

# flow is up, so arrowhead becomes arrowtail:

$graph->set_attribute('edge', 'arrow-style', 'closed');

is ($graph->get_attribute('edge', 'arrow-style'), 'closed');

$grviz = $graph->as_graphviz();
like ($grviz, qr/arrowtail=empty/, 'arrow-style closed => empty');

$graph->set_attribute('edge', 'arrow-style', 'filled');
is ($graph->get_attribute('edge', 'arrow-style'), 'filled');

$grviz = $graph->as_graphviz();
like ($grviz, qr/arrowtail=normal/, 'arrow-style filled => normal');

# set flow to down, so arrowtail becomes arrowhead again
$graph->set_attribute('graph','flow','down');

$grviz = $graph->as_graphviz();
like ($grviz, qr/arrowhead=normal/, 'arrow-style filled => normal');

$graph->del_attribute('edge','arrow-style');
$edge->set_attribute('arrow-style','filled');
is ($graph->error(),'', 'no error');

$grviz = $graph->as_graphviz();
like ($grviz, qr/arrowhead=normal/, 'arrow-style filled => normal');

$edge->set_attribute('arrow-style','none');
is ($graph->error(),'', 'no error');

$grviz = $graph->as_graphviz();
like ($grviz, qr/arrowhead=none/, 'arrow-style none');


#############################################################################
# bidirectional edges

my $e = $graph->add_edge('A','B');

$e->bidirectional(1);

$grviz = $graph->as_graphviz();
like ($grviz, qr/A -> B.*dir=both/, 'bidirectional edge');


#############################################################################
#############################################################################
# label-color vs. color

$e->set_attribute('color','red');
$e->set_attribute('label-color','blue');
$e->set_attribute('label','A to B');

$grviz = $graph->as_graphviz();
like ($grviz, qr/A -> B \[ color="#ff0000", dir=both, fontcolor="#0000ff", label/, 'label-color');

#############################################################################
# missing label-color (fall back to color)

$e->del_attribute('label-color');
$grviz = $graph->as_graphviz();
like ($grviz, qr/A -> B \[ color="#ff0000", dir=both, fontcolor="#ff0000", label/, 'label-color');

$e->del_attribute('label','A to B');

#############################################################################
# no label, no fontcolor nec.:

$e->del_attribute('label');
$grviz = $graph->as_graphviz();
like ($grviz, qr/A -> B \[ color="#ff0000", dir=both \]/, 'label-color');

#############################################################################
# link vs. autolink and linkbase

$graph->set_attribute('node','linkbase','http://bloodgate.com/');

$grviz = $graph->as_graphviz();
unlike ($grviz, qr/bloodgate.com/, 'linkbase alone does nothing');
unlike ($grviz, qr/link/, 'linkbase alone does nothing');

$graph->set_attribute('node','autolink','name');

$grviz = $graph->as_graphviz();
like ($grviz, qr/URL="http:\/\/bloodgate.com/, 'linkbase plus link');

$graph->del_attribute('node','autolink');
$graph->set_attribute('graph','autolink','name');

is ($graph->attribute('graph','autolink'), 'name', 'autolink=name');

$grviz = $graph->as_graphviz();
like ($grviz, qr/URL="http:\/\/bloodgate.com/, 'linkbase plus link');


#############################################################################
# link vs. autolink and linkbase

$bonn->set_attribute('point-style', 'star');
is ($graph->error(),'', 'no error');

$grviz = $graph->as_graphviz();
unlike ($grviz, qr/point-style/, 'point-style is filtered out');


#############################################################################
# node shape "none"

$bonn->{name} = 'Bonn';
$bonn->set_attribute( 'shape' => 'none' );

$grviz = $graph->as_graphviz();
like ($graph->as_graphviz(), qr/[^"]Bonn[^"]/, 'contains Bonn unquoted');
like ($graph->as_graphviz(), qr/Bonn.*shape=plaintext/, 'contains shape=plaintext');


# some different node shapes

for my $s (qw/
  invhouse invtrapezium invtriangle
  triangle octagon hexagon pentagon house
  septagon trapezium
  /)
  {
  $bonn->set_attribute( 'shape' => $s );

  $grviz = $graph->as_graphviz();
  like ($graph->as_graphviz(), qr/[^"]Bonn[^"]/, 'contains Bonn unquoted');
  like ($graph->as_graphviz(), qr/Bonn.*shape=$s/, 'contains shape=plaintext');
  }

#############################################################################
# font-size support

$bonn->set_attribute( 'font-size' => '2em' );

$grviz = $graph->as_graphviz();
like ($graph->as_graphviz(), qr/[^"]Bonn[^"]/, 'contains Bonn unquoted');
like ($graph->as_graphviz(), qr/Bonn.*fontsize=22/, '11px eq 1em');

#############################################################################
# quoting of special characters

$bonn->set_attribute( 'label' => '$a = 2;' );
$grviz = $graph->as_graphviz();

like ($graph->as_graphviz(), qr/Bonn.*label="\$a = 2;"/, 'contains label unquoted');

$bonn->set_attribute( 'label' => '2"' );
$grviz = $graph->as_graphviz();

like ($graph->as_graphviz(), qr/Bonn.*label="2\\""/, 'contains label 2"');


