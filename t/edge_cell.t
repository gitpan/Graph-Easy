#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 24;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Edge::Cell") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Edge::Cell", qw/
  new
  as_ascii as_html
  error
  pos
  x
  y
  label
  width
  height
  style
  type

  _draw_cross
  _draw_ver
  _draw_hor
  _draw_corner
  _make_cross

  edge_type
  /);

use Graph::Easy::Edge::Cell qw/
  EDGE_SHORT_W EDGE_CROSS EDGE_END_N EDGE_START_E EDGE_HOR EDGE_VER
  /;
use Graph::Easy::Edge;

#############################################################################

my $edge = Graph::Easy::Edge->new();

my $path = Graph::Easy::Edge::Cell->new( edge => $edge );

is (ref($path), 'Graph::Easy::Edge::Cell');

is ($path->error(), '', 'no error yet');

is ($path->x(), 0, 'x == 0');
is ($path->y(), 0, 'x == 0');
is ($path->label(), undef, 'no label');
is (join(",", $path->pos()), "0,0", 'pos = 0,0');
is ($path->width(), undef, 'w = undef');	# no graph => thus no width yet

$path = Graph::Easy::Edge::Cell->new( edge => $edge, type => EDGE_SHORT_W);

is ($path->type(), EDGE_SHORT_W, 'edge to the left');

#############################################################################
# attribute()

$edge->set_attribute( color => 'blue', border => 'none');

$path = Graph::Easy::Edge::Cell->new( type => EDGE_SHORT_W, edge => $edge);

is ($path->attribute('color'), 'blue');

#############################################################################
# as_txt/as_html

$path->_correct_size();

is ($path->{w}, 5, 'w == 5');
is ($path->{h}, 3, 'h == 3');

my $ascii = $path->as_ascii(0,0);
$ascii =~ s/^\s+//;
$ascii =~ s/\s+\z//;

is ($ascii, "<--", 'as ascii');
is ($path->as_html(), "<td class='edge'>&lt;------<\/td>\n", 'as html');

# rendering of seems
$edge = Graph::Easy::Edge->new( style => 'dot-dash' );
$path = Graph::Easy::Edge::Cell->new( type => EDGE_HOR, edge => $edge);
$path->{w} = 10;

$ascii = $path->as_ascii(0,0);
$ascii =~ s/^\s+//;
$ascii =~ s/\s+\z//;

is ($ascii, ".-.-.-.-.-", 'as ascii');

$ascii = $path->as_ascii(1,0);
$ascii =~ s/^\s+//;
$ascii =~ s/\s+\z//;

is ($ascii, "-.-.-.-.-.", 'as ascii');

my $other = Graph::Easy::Edge->new( style => 'dashed' );

$path->{type} = EDGE_HOR;
$path->_make_cross($other);

$ascii = $path->as_ascii();
is ($ascii, "  '       \n.-#-.-.-.-\n  '       ", 'crossing between dot-dash and dashed');

$path->{style} = 'dotted';
$path->{style_ver} = 'solid';

$ascii = $path->as_ascii();
is ($ascii, "  |       \n..!.......\n  |       ", 'crossing between dotted and solid');


#############################################################################
# edge_type()

my $et = 'Graph::Easy::Edge::Cell::edge_type';

{
  no strict 'refs';
  is (&$et( EDGE_HOR() ), 'horizontal', 'EDGE_HOR');
  is (&$et( EDGE_VER() ), 'vertical', 'EDGE_VER');
  is (&$et( EDGE_CROSS() ), 'crossing', 'EDGE_CROSS');
  is (&$et( EDGE_SHORT_W() ), 'horizontal, ending west, starting east', 'EDGE_SHORT_W');
}

