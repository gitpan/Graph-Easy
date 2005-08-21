#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 23;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Attributes") or die($@);
   };

can_ok ("Graph::Easy", qw/
  color_as_hex
  color_name
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
is ($att->color_name('#808080'), 'grey', '#808080 => grey');

#############################################################################
# valid_attribute:

# no class name: 'all' will be tested

my $new_value = $att->valid_attribute( 'color', 'red' );
is ($new_value, '#ff0000', 'color red is valid');

$new_value = $att->valid_attribute( 'color', 'red', 'node' );
is ($new_value, '#ff0000', 'color red is valid for nodes');

$new_value = $att->valid_attribute( 'color', 'red', 'node.subclass' );
is ($new_value, '#ff0000', 'color red is valid for node.subclass');

$new_value = $att->valid_attribute( 'color', 'redbrownish' );
is ($new_value, undef, 'color redbrownish is not valid');

#############################################################################
# valid_attribute for graph only:

$new_value = $att->valid_attribute( 'gid', '123', 'graph' );
is ($new_value, '123', 'gid 123 is valid for graph');

$new_value = $att->valid_attribute( 'gid', '123', 'node' );
is ($new_value, undef, 'gid is invalid for nodes');

$new_value = $att->valid_attribute( 'gid', '123', 'edge' );
is ($new_value, undef, 'gid is invalid for edges');

$new_value = $att->valid_attribute( 'output', 'html', 'graph' );
is ($new_value, 'html', 'output "html" is valid for graph');

$new_value = $att->valid_attribute( 'output', 'html', 'node' );
is ($new_value, undef, 'output is invalid for nodes');

$new_value = $att->valid_attribute( 'output', 'html', 'edge' );
is ($new_value, undef, 'output is invalid for edges');


