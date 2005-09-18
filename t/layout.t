#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 24;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Layout") or die($@);
   };

can_ok ("Graph::Easy", qw/
  _trace_path
  _find_path
  _create_cell
  _find_path_astar
  _find_path_loop

  _find_chains
  _assign_ranks
  /);

can_ok ("Graph::Easy::Node", qw/
  _shuffle_dir
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

my $src = Graph::Easy::Node->new( name => 'Bonn' );
my $dst = Graph::Easy::Node->new( 'Berlin' );
my $edge = Graph::Easy::Edge->new( style => 'solid' );
my $e = 3;				# elements per path cell (x,y,type)

#############################################################################
# _shuffle_dir()

my $array = [0,1,2,3];

is (join (",",@{ $src->_shuffle_dir($array,0)   }), '3,0,2,1', 'shuffle 0'  );
is (join (",",@{ $src->_shuffle_dir($array,90)  }), '0,1,2,3', 'shuffle 90' );
is (join (",",@{ $src->_shuffle_dir($array)     }), '0,1,2,3', 'shuffle '   );
is (join (",",@{ $src->_shuffle_dir($array,270) }), '2,3,1,0', 'shuffle 270');
is (join (",",@{ $src->_shuffle_dir($array,180) }), '1,2,0,3', 'shuffle 180');

#############################################################################
# _near_places()

$src->{x} = 1; $src->{y} = 1;

my $cells = {};
my @places = $src->_near_places($cells);
is (scalar @places, 4 * 2, '4 places');

@places = $src->_near_places($cells,2);		# $d == 2
is (scalar @places, 4 * 2, '4 places');

@places = $src->_near_places($cells,3);		# $d == 3
is (scalar @places, 4 * 2, '4 places');

@places = $src->_near_places($cells,3,0);	# $d == 3, type is 0
is (scalar @places, 4 * $e, '4 places');

#                        #1+3,1+0,1 ...
is (join (',', @places), '4,1,16,1,4,32,-2,1,64,1,-2,128', 'places');

#############################################################################
# _find_path()

$src->{x} = 1; $src->{y} = 1;
$dst->{x} = 1; $dst->{y} = 1;

my $coords = $graph->_find_path( $src, $dst, $edge);

is (scalar @$coords, 1*$e, 'same cell => short edge path');

$src->{x} = 1; $src->{y} = 1;
$dst->{x} = 2; $dst->{y} = 2;

#use Data::Dumper;

$coords = $graph->_find_path( $src, $dst, $edge);

#print STDERR "# " . Dumper($coords) . "\n";
#print STDERR "# " . Dumper($graph->{cells}) . "\n";

is (scalar @$coords, 1*$e, 'path with a bend');

# mark one cell as already occupied
$graph->{cells}->{"1,2"} = $src;

$src->{x} = 1; $src->{y} = 1;
$dst->{x} = 1; $dst->{y} = 3;

$coords = $graph->_find_path( $src, $dst, $edge);

#print STDERR "# " . Dumper($coords) . "\n";
#print STDERR "# " . Dumper($graph->{cells}) . "\n";

is (scalar @$coords, 3*$e, 'u shaped path (|---^)');

# block src over/under to avoid an U-shaped path
$graph->{cells}->{"2,1"} = $src;
$graph->{cells}->{"0,1"} = $src;

$coords = $graph->_find_path( $src, $dst, $edge);

#print STDERR "# " . Dumper($coords) . "\n";

# XXX TODO: check what path is actually generated here
is (scalar @$coords, 7*$e, 'cell already blocked');

delete $graph->{cells}->{"1,2"};

$coords = $graph->_find_path( $src, $dst, $edge);

is (scalar @$coords, 1*$e, 'straight path down');
is (join (":", @$coords), '1:2:' . (EDGE_SHORT_S() + EDGE_LABEL_CELL()), 'path 1,1 => 1,3');

$src->{x} = 1; $src->{y} = 0;
$dst->{x} = 1; $dst->{y} = 5;

$coords = $graph->_find_path( $src, $dst, $edge);

is (scalar @$coords, 4*$e, 'straight path down');
my $type = EDGE_VER();
my $type_label = EDGE_VER() + EDGE_LABEL_CELL();
is (join (":", @$coords), "1:1:$type_label:1:2:$type:1:3:$type:1:4:$type", 'path 1,0 => 1,5');

