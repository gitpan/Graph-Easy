#!/usr/bin/perl -w

# Some basic VCG tests

use Test::More;
use strict;

BEGIN
   {
   plan tests => 19;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy") or die($@);
   use_ok ("Graph::Easy::Parser") or die($@);
   };

can_ok ('Graph::Easy', qw/
  as_vcg
  as_vcg_file
  /);

#############################################################################
my $graph = Graph::Easy->new();

my $vcg = $graph->as_vcg();
my $vcg_file = $graph->as_vcg_file();

is ($vcg, $vcg_file, 'as_vcg and as_vcg_file are equal');

#############################################################################
# Parsing

my $parser = Graph::Easy::Parser->new( debug => 0 );

$graph = $parser->from_text( <<EOG
// test
graph: {
	node: { title: "A" }
	node: { title: "B" }
	edge: { sourcename: "A" targetname: "B" }
}
EOG
);

is (ref($graph), 'Graph::Easy', 'Parsing worked');

is (scalar $graph->nodes(), 2, 'two nodes');
my $nodes = '';
for my $n ($graph->nodes())
  {
  $nodes .= "$n->{name}, ";
  }
is ($nodes, "A, B, ", 'two nodes A and B');
is (scalar $graph->edges(), 1, 'one edge');

is ($graph->as_txt(), "[ A ] --> [ B ]\n", 'as_txt matches');

#############################################################################

$graph = $parser->from_text( <<EOG
// test
graph: {
edge.color: black
node.textcolor: red
	node: { title: "A" }
	node: { title: "B" }
	edge: { sourcename: "A" targetname: "B" }
}
EOG
);

is (ref($graph), 'Graph::Easy', 'Parsing worked');

is (scalar $graph->nodes(), 2, 'two nodes');
$nodes = '';
for my $n ($graph->nodes())
  {
  $nodes .= "$n->{name}, ";
  }
is ($nodes, "A, B, ", 'two nodes A and B');
is (scalar $graph->edges(), 1, 'one edge');

is ($graph->attribute('node','color'), 'red', 'textcolor red for nodes');

#############################################################################

$graph = $parser->from_text( <<EOG

graph: {title: "red vs. black"
colorentry 42: 128 128 128
	node: { title: "A" color: 42 }
	node: { title: "B" color: 1 } 
	edge: { sourcename: "A" targetname: "B" }
}
EOG
);

is ($parser->error(), '', 'no error');

is (ref($graph), 'Graph::Easy', 'Parsing worked');

is (scalar $graph->nodes(), 2, 'two nodes');
is ($graph->label(), 'red vs. black', 'title => label');

my $A = $graph->node('A');
is ($A->attribute('fill'), 'rgb(128,128,128)', 'A is grey');

