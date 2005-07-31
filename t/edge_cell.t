#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 15;
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

  edge_type
  /);

use Graph::Easy::Edge::Cell qw/EDGE_SHORT_W EDGE_HOR/;
use Graph::Easy::Edge;

#############################################################################

my $path = Graph::Easy::Edge::Cell->new();

is (ref($path), 'Graph::Easy::Edge::Cell');

is ($path->error(), '', 'no error yet');

is ($path->x(), 0, 'x == 0');
is ($path->y(), 0, 'x == 0');
is ($path->label(), '', 'label');
is (join(",", $path->pos()), "0,0", 'pos = 0,0');
is ($path->width(), undef, 'w = undef');	# no graph => thus no width yet

$path = Graph::Easy::Edge::Cell->new( type => EDGE_SHORT_W);

is ($path->type(), EDGE_SHORT_W, 'edge to the left');

#############################################################################
# attribute()

my $edge = Graph::Easy::Edge->new();

$edge->set_attribute( color => 'blue', border => 'none');

$path = Graph::Easy::Edge::Cell->new( type => EDGE_SHORT_W, edge => $edge);

is ($path->attribute('color'), 'blue');

#############################################################################
# as_txt/as_html

#print $path->as_ascii();
#print $path->as_html();

$path->_correct_size();

my $ascii = $path->as_ascii();
$ascii =~ s/^\s+//;
$ascii =~ s/\s+\z//;

is ($ascii, "<--", 'as ascii');
is ($path->as_html(), "<td class='edge'>&lt;------<\/td>\n", 'as html');

#############################################################################
# edge_type()

is (Graph::Easy::Edge::Cell::edge_type( EDGE_HOR() ), 'horizontal', 'edge_type()');
