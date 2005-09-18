#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 29;
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
  set_attribute
  set_attributes
  groups
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

is (scalar keys %{$edge->cells()}, 0, 'no cells');

my $path = Graph::Easy::Edge::Cell->new (
  edge => $edge,
  type => EDGE_SHORT_E,
  x => 1, y => 1,
);

$edge->add_cell($path);
is (scalar keys %{$edge->cells()}, 1, 'one cell');

$edge->add_cell($path);
is (scalar keys %{$edge->cells()}, 1, 'still one cell');

$path->{x}++;
$edge->add_cell($path);
is (scalar keys %{$edge->cells()}, 2, 'two cells');

$edge->clear_cells();
is (scalar keys %{$edge->cells()}, 0, 'no cells');

#############################################################################
# undirected/bidirectional

is ($edge->undirected(2), 1, 'undirected');
is ($edge->undirected(), 1, 'undirected');
is ($edge->undirected(0), 0, 'not undirected');
is ($edge->bidirectional(2), 1, 'bidiriectional');
is ($edge->bidirectional(), 1, 'bidiriectional');
is ($edge->bidirectional(0), 0, 'not bidiriectional');

