#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 13;
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

like ($graph->as_graphviz(), qr/"Bonn"/, 'contains Bonn');
like ($graph->as_graphviz(), qr/"Berlin"/, 'contains Bonn');

#print $graph->as_graphviz(),"\n";

#############################################################################
# with some nodes with atributes

$bonn->set_attribute( 'shape' => 'box' );

like ($graph->as_graphviz(), qr/"Bonn"/, 'contains Bonn');
like ($graph->as_graphviz(), qr/"Berlin"/, 'contains Bonn');
like ($graph->as_graphviz(), qr/shape=box/, 'contains shape');

#print $graph->as_graphviz(),"\n";

