#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 38;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok qw/Graph::Easy::Edge/;
   use_ok qw/Graph::Easy::Edge::Cell/;
   }

can_ok ("Graph::Easy::Edge", qw/
  new
  error
  label
  cells
  add_cell
  clear_cells
  _unplace
  attribute
  undirected
  bidirectional
  has_ports

  set_attribute
  set_attributes

  group add_to_group
  background
  flow port

  start_port end_port
  from to start_at

  /);
  
use Graph::Easy::Edge::Cell qw/EDGE_SHORT_E/;
use Graph::Easy;

#############################################################################

# We need a graph to insert the edge into it, so that the edge gets the
# default settings from it. 
# XXX TODO: should we change the above?

my $graph = Graph::Easy->new();

my $edge = Graph::Easy::Edge->new();

$edge->{graph} = $graph;

is (ref($edge), 'Graph::Easy::Edge');

is ($edge->error(), '', 'no error yet');
is ($edge->undirected(), undef, 'not undirected');
is ($edge->bidirectional(), undef, 'not bidiriectional');
is ($edge->has_ports(), 0, 'has no port restrictions');

use_ok ('Graph::Easy::As_txt');

is ($edge->as_txt(), ' --> ', 'default is "-->"');

#############################################################################
# different styles

$edge = Graph::Easy::Edge->new( style => 'double' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' ==> ', '"==>"');

$edge = Graph::Easy::Edge->new( style => 'dotted' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' ..> ', '"..>"');

$edge = Graph::Easy::Edge->new( style => 'dashed' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' - > ', '"- >"');

$edge = Graph::Easy::Edge->new( style => 'wave' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' ~~> ', '"~~>"');

$edge = Graph::Easy::Edge->new( style => 'dot-dash' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' .-> ', '".->"');

$edge = Graph::Easy::Edge->new( style => 'double-dash' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' = > ', '"= >"');

$edge = Graph::Easy::Edge->new( style => 'dot-dot-dash' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' ..-> ', '"= >"');

$edge = Graph::Easy::Edge->new( style => 'bold' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' --> { style: bold; } ', ' --> { style: bold; }');

#############################################################################

$edge = Graph::Easy::Edge->new( label => 'train' );
$edge->{graph} = $graph;
is ($edge->as_txt(), ' -- train --> ', ' -- train -->');

#############################################################################
# cells

is (scalar $edge->cells(), 0, 'no cells');

my $path = Graph::Easy::Edge::Cell->new (
  edge => $edge,
  type => EDGE_SHORT_E,
  x => 1, y => 1,
);

is (scalar $edge->cells(), 1, 'one cell');

#$edge->add_cell($path);
#is (scalar $edge->cells(), 1, 'still one cell');

$path->{x}++;
$edge->add_cell($path);
is (scalar $edge->cells(), 2, 'two cells');

$edge->clear_cells();
is (scalar $edge->cells(), 0, 'no cells');

#############################################################################
# undirected/bidirectional

is ($edge->undirected(2), 1, 'undirected');
is ($edge->undirected(), 1, 'undirected');
is ($edge->undirected(0), 0, 'not undirected');
is ($edge->bidirectional(2), 1, 'bidiriectional');
is ($edge->bidirectional(), 1, 'bidiriectional');
is ($edge->bidirectional(0), 0, 'not bidiriectional');

#############################################################################
# has_ports()

$edge->set_attribute('start', 'south');
is ($edge->has_ports(), 1, 'has port restrictions');

$edge->set_attribute('end', 'north');
is ($edge->has_ports(), 1, 'has port restrictions');

$edge->del_attribute('start');
is ($edge->has_ports(), 1, 'has port restrictions');

$edge->del_attribute('end');
is ($edge->has_ports(), 0, 'has no port restrictions');

#############################################################################
# port()

$edge->set_attribute('start', 'south');
is (join(":", $edge->port('start')), "south:", "port('start')");

$edge->del_attribute('end');
$edge->del_attribute('start');

#############################################################################
# background()

is ($edge->background(), '', 'background()');

$graph = Graph::Easy->new();
my ($A,$B); ($A,$B,$edge) = $graph->add_edge('A','B');

my $group = $graph->add_group('G');
$group->add_member($edge);

my $cell = Graph::Easy::Edge::Cell->new( edge => $edge, graph => $graph );

# default group background
is ($cell->background(), '#a0d0ff', 'background() for group member');

$group->set_attribute('background', 'red');
is ($cell->background(), '#a0d0ff', 'background() for group member');

# now has the fill of the group as background
$group->set_attribute('fill', 'green');
is ($cell->background(), '#008000', 'background() for group member');


