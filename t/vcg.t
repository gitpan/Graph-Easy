#!/usr/bin/perl -w

# Some basic VCG tests

use Test::More;
use strict;

BEGIN
   {
   plan tests => 31;
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

#############################################################################
# custom attributes from parsed text

# XXX TODO: this doesn't work: "energetic attraction: 0.7"

$graph = $parser->from_text( <<EOG

graph: {title: "red vs. black"
colorentry 42: 128 128 128
ignore_singles: 1
	node: { title: "A" color: 42 fontname: "serif" focus: 2 }
	node: { title: "B" color: 1 focus: 1 }
	edge: { sourcename: "A" targetname: "B" class: 1 anchor: foo }
}
EOG
);

is ($parser->error(), '', 'no error');

is (ref($graph), 'Graph::Easy', 'Parsing worked');

is (scalar $graph->nodes(), 2, 'two nodes');
is ($graph->label(), 'red vs. black', 'title => label');

is ($graph->attribute('x-vcg-ignore_singles'), '1', 'graph has x-ignore_singles');

$A = $graph->node('A');
is ($A->attribute('font'), 'serif', 'fontname => font');
is ($A->attribute('x-vcg-focus'), '2', 'A has x-vcg-focus');

my $B = $graph->node('B');
is ($B->attribute('x-vcg-focus'), '1', 'B has x-vcg-focus');

my $E = $graph->edge('A','B');
is ($E->attribute('x-vcg-anchor'), 'foo', 'B->B has x-vcg-anchor');

#############################################################################
# attributes (custom and normal)

$vcg = $graph->as_vcg();

unlike ($vcg, qr/x-/, 'no custom attributs were output');
like ($vcg, qr/fontname/, 'no custom attributs were output');
unlike ($vcg, qr/font:/, 'font => fontname');


