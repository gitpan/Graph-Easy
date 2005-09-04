#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 18;
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

my $html = $graph->as_html();

like ($html, qr/<table/, 'looks like HTML to me');

#############################################################################
# with some nodes

my $bonn = Graph::Easy::Node->new( name => 'Bonn' );
my $berlin = Graph::Easy::Node->new( 'Berlin' );

my $edge = $graph->add_edge ($bonn, $berlin);

$html = $graph->as_html();

like ($html, qr/Bonn/, 'contains Bonn');
like ($html, qr/Berlin/, 'contains Berlin');

#############################################################################
# with some nodes with atributes

$bonn->set_attribute( 'autotitle' => 'name' );

$html = $graph->as_html();

like ($html, qr/title="Bonn"/, 'contains title="Bonn"');
unlike ($html, qr/title="Berlin"/, "doesn't contain title Berlin");

#print $graph->as_svg(),"\n";

#############################################################################
# check that "shape:" does not appear in CSS or HTML

$bonn->set_attribute( 'shape' => 'circle' );
$graph->set_attribute ( 'node', 'shape', 'ellipse' );

my $css = $graph->css();
$html = $graph->as_html();

unlike ($css, qr/shape/, 'shape does not appear in CSS');
unlike ($html, qr/shape/, 'shape does not appear in HTML');

#############################################################################
# "shape: invisible" should result in an empty td tag w/ "border: none"

$bonn->set_attribute( 'shape' => 'invisible' );

$css = $graph->css();
$html = $graph->as_html();

unlike ($html, qr/display:\s*none/, 'shape invisible is not display: none');
like ($html, qr/td.*border:\s*none/, 'shape invisible results in border: none');

#############################################################################
# label colors

$graph->set_attribute( 'edge', 'label-color' => 'red' );

$css = $graph->css();
$html = $graph->as_html();

like ($html, qr/border-bottom:.*; color: #ff0000/, 'some edge got color red');


#############################################################################
# edge color vs. label colors

$graph->set_attribute( 'edge', 'color' => 'green' );

$html = $graph->as_html();

like ($html, qr/border-bottom:.*#008000.*; color: #ff0000/, 'some edge got color red');

#############################################################################
# caption from label

$graph->set_attribute( 'graph', 'label' => 'My Graph Label' );

$html = $graph->as_html();

like ($html, qr/<caption>My Graph Label<\/caption>/, 'graph caption from label');


