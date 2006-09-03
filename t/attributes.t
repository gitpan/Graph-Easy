#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 81;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Attributes") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy", qw/
  color_as_hex
  color_name
  color_value
  _remap_attributes
  valid_attribute
  /);

#############################################################################
# color_as_hex:

my $att = 'Graph::Easy';

is ($att->color_as_hex( 'red' ), '#ff0000', 'color red');
is ($att->color_as_hex( '#0000ff' ), '#0000ff', 'color #0000ff');
is ($att->color_as_hex( '#f0c' ), '#ff00cc', 'color #f0c');
is ($att->color_as_hex( 'rgb(128,255,0)' ), '#80ff00', 'color rgb(128,255,0)');
is ($att->color_as_hex('lavender'), '#e6e6fa', 'color lavender');
is ($att->color_as_hex('lavenderblush'), '#fff0f5', 'color lavenderblush');
is ($att->color_as_hex('lavenderbush'), undef, 'color lavenderbush does not exist');

#############################################################################
# color_name:

is ($att->color_name('red'), 'red', 'red => red');
is ($att->color_name('#ff0000'), 'red', '#ff0000 => red');
is ($att->color_name('#ffffff'), 'white', '#ffffff => white');
is ($att->color_name('#808080'), 'gray', '#808080 => gray');

#############################################################################
# color scheme support:

is ($att->color_name('grey', 'x11'), 'grey', 'grey => grey');
is ($att->color_name('#c0c0c0','x11'), 'gray', '#c0c0c0 => gray');
is ($att->color_name('#ffffff','x11'), 'white', '#ffffff => white');
is ($att->color_name('grey23','x11'), 'grey23', 'grey23 => grey23');
    
# 1  => '#ca0020', 2  => '#f4a582', 3  => '#bababa', 4  => '#404040', 
is ($att->color_name('1','rdgy4'), '1', '1 => 1 under rdgy4');

#############################################################################
# color_value:

is ($att->color_value('red'), '#ff0000', 'red => #ff0000');
is ($att->color_value('grey'), '#808080', 'grey => #808080');
is ($att->color_value('grey','x11'), '#c0c0c0', 'grey => #c0c0c0 under x11');
is ($att->color_value('grey23','x11'), '#3b3b3b', 'grey23 => #3b3b3b under x11');

# 1  => '#ca0020', 2  => '#f4a582', 3  => '#bababa', 4  => '#404040', 
is ($att->color_value('1','rdgy4'), '#ca0020', '1 => #ca0020 under rdgy4');
is ($att->color_value('4','rdgy4'), '#404040', '4 => #404040 under rdgy4');

#############################################################################
# valid_attribute:

$att = Graph::Easy->new();

my $new_value = $att->valid_attribute( 'color', 'redbrownish' );
is ($new_value, undef, 'color redbrownish is not valid');

$new_value = $att->valid_attribute( 'border-color', 'redbrownish' );
is ($new_value, undef, 'border-color redbrownish is not valid');

$new_value = $att->valid_attribute( 'border-shape', 'double' );
is (ref($new_value), 'ARRAY', 'border-shape is not valied');

# no class name: 'all' will be tested

for my $name (
    'red','w3c/red','x11/red', 'chocolate4', 'rgb(1,2,3)', 
    'rgb(10%,1%,2%)', 'rgb(8,1%,0.2)', 'w3c/grey',
   )
  {
  for my $class ( undef, 'node', 'node.subclass')
    {
    my $new_value = $att->valid_attribute( 'color', $name, $class );
    is ($new_value, $name, "color $name is valid");
    }
  }

#############################################################################
# fallback to color scheme 'x11'

$new_value = $att->valid_attribute( 'color', 'chocolate4' );
is ($new_value, 'chocolate4', 'color chocolate4 is valid');

#############################################################################
# valid_attribute for graph only:

$new_value = $att->valid_attribute( 'gid', '123', 'graph' );
is ($new_value, '123', 'gid 123 is valid for graph');

$new_value = $att->valid_attribute( 'gid', '123', 'node' );
is (ref($new_value), 'ARRAY', 'gid is invalid for nodes');

$new_value = $att->valid_attribute( 'gid', '123', 'edge' );
is (ref($new_value), 'ARRAY', 'gid is invalid for edges');

$new_value = $att->valid_attribute( 'output', 'html', 'graph' );
is ($new_value, 'html', 'output "html" is valid for graph');

$new_value = $att->valid_attribute( 'output', 'html', 'node' );
is (ref($new_value), 'ARRAY', 'output is invalid for nodes');

$new_value = $att->valid_attribute( 'output', 'html', 'edge' );
is (ref($new_value), 'ARRAY', 'output is invalid for edges');

#############################################################################
# setting attributes on graphs, nodes and edges

my $graph = Graph::Easy->new();

$graph->no_fatal_errors(1);

my ($n,$m,$e) = $graph->add_edge('A','B');

$n->set_attribute('color','red');
is ($graph->error(),'','no error');
$graph->error('');			# reset potential error for next test

$n->set_attribute('shape','point');
is ($graph->error(),'','no error');
$graph->error('');			# reset potential error for next test

$graph->set_attribute('graph', 'shape', 'point');
is ($graph->error(),"Error: 'shape' is not a valid attribute for graph",'no error');
$graph->error('');			# reset potential error for next test

$e->no_fatal_errors(1);

$e->set_attribute('shape','point');
is ($graph->error(),"Error: 'shape' is not a valid attribute for edge",'no error');
$graph->error('');			# reset potential error for next test


#############################################################################
# text-style attribute

for my $class (qw/edge graph node group/)
  {
  $graph->set_attribute($class, 'text-style', 'none');
  is ($graph->error(), '', "could set text-style on $class");
  $graph->error('');			# reset potential error for next test

  $graph->set_attribute($class, 'text-style', 'bold');
  is ($graph->error(), '', "could set text-style on $class");
  $graph->error('');			# reset potential error for next test

  $graph->set_attribute($class, 'text-style', 'bold underline');
  is ($graph->error(), '', "could set text-style on $class");
  $graph->error('');			# reset potential error for next test

  $graph->set_attribute($class, 'text-style', 'bold underline overline italic');
  is ($graph->error(), '', "could set text-style on $class");
  $graph->error('');			# reset potential error for next test
  }

$graph->set_attribute('graph', 'text-style', 'bold underline overline italic');

my $styles = $graph->text_styles();
is (join(',', sort keys %$styles), 'bold,italic,overline,underline', 'text_styles()');


my $node = $graph->add_node('one');

$node->set_attribute('text-style', 'bold underline overline italic');

$styles = $node->text_styles();
is (join(',', sort keys %$styles), 'bold,italic,overline,underline', 'text_styles() on node');


