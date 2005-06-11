#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 13;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Layout") or die($@);
   };

can_ok ("Graph::Easy", qw/
  _trace_path
  _find_path
  _remove_path
  _create_cell
  _find_path_hard
  _find_path_u_shaped
  /);

isnt ($Graph::Easy::VERSION, undef, 'VERSION in Layout');

use Graph::Easy;

Graph::Easy::Edge::Cell->import (qw/
  EDGE_HOR EDGE_VER EDGE_LABEL_CELL
  EDGE_SHORT_S
/);

#############################################################################
# layout tests

my $graph = Graph::Easy->new();

is (ref($graph), 'Graph::Easy');

is ($graph->error(), '', 'no error yet');

#############################################################################
# _find_path()

my $src = Graph::Easy::Node->new( name => 'Bonn' );
my $dst = Graph::Easy::Node->new( 'Berlin' );

$src->{x} = 1; $src->{y} = 1;
$dst->{x} = 1; $dst->{y} = 1;

my @coords = $graph->_find_path( $src, $dst);

is (scalar @coords, 1, 'same cell => short edge path');

$src->{x} = 1; $src->{y} = 1;
$dst->{x} = 2; $dst->{y} = 2;

@coords = $graph->_find_path( $src, $dst);

is (scalar @coords, 1, 'path with a bend');

# mark one cell as already occupied
$graph->{cells}->{"1,2"} = $src;

$src->{x} = 1; $src->{y} = 1;
$dst->{x} = 1; $dst->{y} = 3;

@coords = $graph->_find_path( $src, $dst);

is (scalar @coords, 5, 'u shaped path');

# block src over/under to avoid an U-shaped path
$graph->{cells}->{"2,1"} = $src;
$graph->{cells}->{"0,1"} = $src;

@coords = $graph->_find_path( $src, $dst);
is (scalar @coords, 0, 'cell already blocked (test might fail if A* is implemented!)');

delete $graph->{cells}->{"1,2"};

@coords = $graph->_find_path( $src, $dst);

is (scalar @coords, 1, 'straight path down');
is (join (":", @coords), '1,2,' . (EDGE_SHORT_S() + EDGE_LABEL_CELL()), 'path 1,1 => 1,3');

$src->{x} = 1; $src->{y} = 0;
$dst->{x} = 1; $dst->{y} = 5;

@coords = $graph->_find_path( $src, $dst);

is (scalar @coords, 4, 'straight path down');
my $type = EDGE_VER();
my $type_label = EDGE_VER() + EDGE_LABEL_CELL();
is (join (":", @coords), "1,1,$type_label:1,2,$type:1,3,$type:1,4,$type", 'path 1,0 => 1,5');


