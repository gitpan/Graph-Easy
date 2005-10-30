#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 23;
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

like ($html, qr/border-bottom:.*;\s*color: #ff0000/, 'some edge got color red');


#############################################################################
# edge color vs. label colors

$graph->set_attribute( 'edge', 'color' => 'green' );

$html = $graph->as_html();

like ($html, qr/border-bottom:.*#008000.*;\s*color: #ff0000/, 'some edge got color red');

#############################################################################
# caption from label

$graph->set_attribute( 'graph', 'label' => 'My Graph Label' );

$html = $graph->as_html();

like ($html, qr/<td colspan=12 style='background: inherit; text-align: center'>My Graph Label<\/td>/,
	'graph caption from label');

#############################################################################
# caption with label-pos

$graph->set_attribute( 'graph', 'label' => 'My Graph Label' );
$graph->set_attribute( 'graph', 'label-pos' => 'bottom' );

$html = $graph->as_html();

like ($html, qr/<td colspan=12 style='background: inherit; text-align: center'>My Graph Label<\/td>/,
 'graph caption from label');

#############################################################################
# html_file includes <title> and charset:

$html = $graph->as_html_file();

my $charset =
  quotemeta('<meta http-equiv="Content-Type" content="text/html; charset=utf-8">');

like ($html, qr/$charset/, 'html_file includes charset definition');
like ($html, qr/<title>My Graph Label<\/title>/, 'html_file includes <title>');

#############################################################################
# egdes with links, titles and colors

$graph = Graph::Easy->new();

$edge = Graph::Easy::Edge->new();

$edge = $graph->add_edge('Friedrichshafen', 'Immenstaad');

$edge->set_attribute('title', 'Vrooom!');
$edge->set_attribute('color', 'orange');
$edge->set_attribute('text-style', 'none');
$edge->set_attribute('font-size', '1.5em');
$edge->set_attribute('link', 'http://bloodgate.com');
$edge->set_attribute('label', 'Schiff');

# This tests edge->as_html(), which will not be called for normal operations,
# in these cases we would convert the single edge cells to HTML.

my $edge_html = <<EDGE
 <td colspan=4 rowspan=4 class='edge' title="Vrooom!"><a class='l' href='http://bloodgate.com' style="color: #ffa500; text-decoration: none; font-size: 1.5em;">Schiff</a></td>
EDGE
;
is ($edge->as_html(), $edge_html, 'edge->as_html()');

# entire graph as html

$html = $graph->as_html();

$edge_html = <<EDGE_CELL
<td colspan=2 rowspan=2 class="edge lh" style="border-bottom: solid 2px #ffa500;" title="Vrooom!"><a class='l' href='http://bloodgate.com' style='color: #ffa500; text-decoration: none; font-size: 1.5em;'>Schiff</a></td>
EDGE_CELL
;
my $like = quotemeta($edge_html); 

like ($html, qr/$like/, 'graph->as_html() contains proper edge html');

