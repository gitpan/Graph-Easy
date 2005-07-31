#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 11;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Attributes") or die($@);
   };

can_ok ("Graph::Easy::Attributes", qw/
  color_as_hex
  valid_attribute
  /);

#############################################################################
# color_as_hex:

my $att = 'Graph::Easy::Attributes';

is ($att->color_as_hex( 'red' ), '#ff0000', 'color red');
is ($att->color_as_hex( '#0000ff' ), '#0000ff', 'color #0000ff');
is ($att->color_as_hex( '#f0c' ), '#ff00cc', 'color #f0c');
is ($att->color_as_hex( 'rgb(128,255,0)' ), '#80ff00', 'color rgb(128,255,0)');
is ($att->color_as_hex('lavender'), '#e6e6fa', 'color lavender');
is ($att->color_as_hex('lavenderblush'), '#fff0f5', 'color lavenderblush');
is ($att->color_as_hex('lavenderbush'), undef, 'color lavenderbush does not exist');

#############################################################################
# valid_attribute:

my $new_value = Graph::Easy::Attributes->valid_attribute( 'color', 'red' );

is ($new_value, '#ff0000', 'color red is valid');

$new_value = Graph::Easy::Attributes->valid_attribute( 'color', 'redbrownish' );

is ($new_value, undef, 'color redbrownish is not valid');


