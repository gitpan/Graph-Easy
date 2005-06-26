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
like ($html, qr/Berlin/, 'contains Bonn');

#############################################################################
# with some nodes with atributes

$bonn->set_attribute( 'autotitle' => 'name' );

$html = $graph->as_html();

like ($html, qr/title="Bonn"/, 'contains title="Bonn"');
unlike ($html, qr/title="Berlin"/, "doesn't contains title Berlin");

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
# "==>" must result in "==" and not "doubledouble" (bug until v0.19)

my $cell = $edge->cells()->{"1,0"};

is (ref($cell), 'Graph::Easy::Edge::Cell', 'found edge cell');
$cell->{style} = 'double';

$css = $graph->css();
$html = $graph->as_html();

unlike ($html, qr/double/, '==> is not "doubledouble"');

$cell->{att}->{label} = 'one label to bind them';
$css = $graph->css();
$html = $graph->as_html();

unlike ($html, qr/double/, '==> is not "doubledouble"');

