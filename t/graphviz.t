#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 30;
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

$graph->add_edge ($bonn, $berlin);

like ($graph->as_graphviz(), qr/Bonn/, 'contains Bonn');
like ($graph->as_graphviz(), qr/Berlin/, 'contains Bonn');

unlike ($graph->as_graphviz(), qr/\w+=,/, "doesn't contain empty defintions");

#print $graph->as_graphviz(),"\n";

#############################################################################
# with atributes on the graph

$graph->set_attribute( 'graph', 'background' => 'red' );

like ($graph->as_graphviz(), qr/bgcolor="#ff0000"/, 'contains bgcolor="#ff0000"');

#print $graph->as_graphviz(),"\n";

#############################################################################
# with some nodes with atributes

$bonn->set_attribute( 'shape' => 'box' );

like ($graph->as_graphviz(), qr/[^"]Bonn[^"]/, 'contains Bonn unquoted');
like ($graph->as_graphviz(), qr/[^"]Berlin[^"]/, 'contains Bonn unquoted');
like ($graph->as_graphviz(), qr/shape=box/, 'contains shape');

#print $graph->as_graphviz(),"\n";

#############################################################################
# remapped attributes, quoted attributes

$bonn->set_attributes( { 
  background => '#808080', 
  title => 'title string', 
  color => 'red', 
  'border-color' => 'brown',
  class => 'city',
  } );

my $grviz = $graph->as_graphviz();

like ($grviz, qr/fillcolor="#808080"/, 'contains fillcolor');
like ($grviz, qr/tooltip="title string"/, 'contains tooltip');
like ($grviz, qr/color=brown/, 'contains color');
like ($grviz, qr/fontcolor=red/, 'contains fontcolor');
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

