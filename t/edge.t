#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 14;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok qw/Graph::Easy::Edge/;
   use_ok qw/Graph::Easy::Edge::Cell/;
   }

can_ok ("Graph::Easy::Edge", qw/
  new
  as_txt
  error
  label
  cells
  add_cell
  clear_cells
  attribute
  set_attribute
  set_attributes
  groups
  /);
  
use Graph::Easy::Edge::Cell qw/EDGE_SHORT_E/;

#############################################################################

my $edge = Graph::Easy::Edge->new();

is (ref($edge), 'Graph::Easy::Edge');

is ($edge->error(), '', 'no error yet');

is ($edge->as_txt(), ' --> ', 'default is "-->"');

#############################################################################
# different styles

$edge = Graph::Easy::Edge->new( style => 'double' );
is ($edge->as_txt(), ' ==> ', '"==>"');

$edge = Graph::Easy::Edge->new( style => 'wave' );
is ($edge->as_txt(), ' ~~> ', '"~~>"');

$edge = Graph::Easy::Edge->new( style => 'dot-dash' );
is ($edge->as_txt(), ' .-> ', '".->"');

#############################################################################
# cells

is (scalar keys %{$edge->cells()}, 0, 'no cells');

my $path = Graph::Easy::Edge::Cell->new (
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

