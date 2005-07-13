#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 35;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ('Graph::Easy', qw/
  output_format
  output
  seed randomize

  border_attribute
  /);

#############################################################################
my $graph = Graph::Easy->new();

is (ref($graph), 'Graph::Easy');

ok (defined $graph->{seed}, 'seed was initialized');

is ($graph->error(), '', 'no error yet');
is ($graph->output_format(), 'html', 'default output format is html');

is ($graph->nodes(), 0, '0 nodes');
is ($graph->edges(), 0, '0 edges');
is ($graph->border_attribute('graph'), '', 'graph border is none');
is ($graph->border_attribute('group'), '1px dashed black', 'group border is 1px dashed black');
is ($graph->border_attribute('node'), '1px solid black', 'node border is 1px solid black');
is ($graph->border_attribute('edge'), '', 'edge border is none');

is (join (',', $graph->edges()), '', '0 edges');

like ($graph->output(), qr/table/, 'default output worked');

my $bonn = Graph::Easy::Node->new( name => 'Bonn' );
my $berlin = Graph::Easy::Node->new( 'Berlin' );

my $edge = $graph->add_edge ($bonn, $berlin);

is (ref($edge), 'Graph::Easy::Edge', 'add_edge() returns the new edge');

is ($graph->nodes(), 2, '2 nodes added');
is ($graph->edges(), 1, '1 edge');

is ($graph->as_txt(), "[ Bonn ] --> [ Berlin ]\n", 'as_txt for 2 nodes');

is (ref($graph->edge($bonn,$berlin)), 'Graph::Easy::Edge', 'edge from objects');
is ($graph->edge($berlin,$bonn), undef, 'berlin not connecting to bonn');

is (ref($graph->edge('Bonn', 'Berlin')), 'Graph::Easy::Edge', 'edge from names');

my @E = $graph->edges();

my $en = '';
for my $e (@E)
  {
  $en .= $e->{style} . '.';
  }

is ($en, 'solid.', 'edges() in list context');

#############################################################################

my $ffm = Graph::Easy::Node->new( name => 'Frankfurt a. M.' );
$graph->add_edge ($ffm, $bonn);

is ($graph->nodes (), 3, '3 nodes');
is ($graph->edges (), 2, '2 edges');

# print $graph->as_ascii();

#############################################################################
# as_txt() (simple nodes)

is ( $graph->as_txt(), <<HERE
[ Frankfurt a. M. ] --> [ Bonn ]
[ Bonn ] --> [ Berlin ]
HERE
, 'as_txt() for 3 nodes with 2 edges');

my $schweinfurt = Graph::Easy::Node->new( name => 'Schweinfurt' );
$graph->add_edge ($schweinfurt, $bonn);

is ($graph->nodes (), 4, '4 nodes');
is ($graph->edges (), 3, '3 edges');

is ( $graph->as_txt(), <<HERE
[ Frankfurt a. M. ] --> [ Bonn ]
[ Schweinfurt ] --> [ Bonn ]
[ Bonn ] --> [ Berlin ]
HERE
, 'as_txt() for 4 nodes with 3 edges');

#############################################################################
# as_txt() (nodes with attributes)

$bonn->set_attribute('class', 'cities');

is ( $graph->as_txt(), <<HERE
[ Bonn ] { class: cities; }

[ Frankfurt a. M. ] --> [ Bonn ]
[ Schweinfurt ] --> [ Bonn ]
[ Bonn ] --> [ Berlin ]
HERE
, 'as_txt() for 4 nodes with 3 edges and attributes');

$bonn->set_attribute('border', 'none');
$bonn->set_attribute('color', 'red');
$berlin->set_attribute('color', 'blue');

# border is second-to-last, class is the last attribute:

is ( $graph->as_txt(), <<HERE
[ Berlin ] { color: blue; }
[ Bonn ] { color: red; border: none; class: cities; }

[ Frankfurt a. M. ] --> [ Bonn ]
[ Schweinfurt ] --> [ Bonn ]
[ Bonn ] --> [ Berlin ]
HERE
, 'as_txt() for 4 nodes with 3 edges and class attribute');


$graph->set_attribute('graph', 'border', '1px dashed');
$graph->set_attribute('edge', 'border', 'blue solid 1px');

# graph/node/edge attributes come first

is ( $graph->as_txt(), <<HERE
edge { border: 1px solid blue; }
graph { border: 1px dashed; }

[ Berlin ] { color: blue; }
[ Bonn ] { color: red; border: none; class: cities; }

[ Frankfurt a. M. ] --> [ Bonn ]
[ Schweinfurt ] --> [ Bonn ]
[ Bonn ] --> [ Berlin ]
HERE
, 'as_txt() for 4 nodes with 3 edges and graph/node/edge attributes');

#############################################################################
# output and output_format:

$graph = Graph::Easy->new();
is (ref($graph), 'Graph::Easy', 'new worked');

$graph->add_edge ($bonn, $berlin);

like ($graph->output(), qr/table/, 'default output worked');

$graph->set_attribute('graph', 'output', 'ascii');

is ($graph->output_format(), 'ascii', 'output format changed to ascii');
unlike ($graph->output(), qr/<table>/, 'ascii output worked');


