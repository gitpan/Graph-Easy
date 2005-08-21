#!/usr/bin/perl -w

# test printing into a framebuffer

use Test::More;
use strict;

BEGIN
   {
   plan tests => 27;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Node") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Node", qw/
  _printfb
  _framebuffer
  /);

#############################################################################
# general framebuffer tests

my $node = Graph::Easy::Node->new();

is (ref($node), 'Graph::Easy::Node');

is ($node->error(), '', 'no error yet');

my $fb = $node->_framebuffer(2,3);

is (join ("::", @$fb), "  ::  ::  ", 'framebuffer set up');

$node->_printfb( $fb, 0,0, '+');
is (join ("::", @$fb), "+ ::  ::  ", 'print +');

$node->_printfb( $fb, 1,0, '+');
is (join ("::", @$fb), "++::  ::  ", 'print +');

$node->_printfb( $fb, 1,2, '+');
is (join ("::", @$fb), "++::  :: +", 'print +');

$node->_printfb( $fb, 0,0, '--');
is (join ("::", @$fb), "--::  :: +", 'print --');

$node->_printfb( $fb, 0,1, "''");
is (join ("::", @$fb), "--::'':: +", "print ''");

#############################################################################
# multiline printing

$fb = $node->_framebuffer(2,5);

$node->_printfb( $fb, 0,3, "+", "+");
is (join ("::", @$fb), "  ::  ::  ::+ ::+ ", 'print "+\n+"');

$node->_printfb( $fb, 0,2, "|", "|");
is (join ("::", @$fb), "  ::  ::| ::| ::+ ", 'print "\|\n\|"');

$fb = $node->_framebuffer(4,5);
is (join ("::", @$fb), "    ::    ::    ::    ::    ", 'new fb set up');

$node->_printfb( $fb, 1,1, "01", "234");

is (join ("::", @$fb), "    :: 01 :: 234::    ::    ", 'new fb set up');

#############################################################################
# _draw_border() tests

$fb = $node->_framebuffer(12,6);

$node->{w} = 12;
$node->{h} = 6;

$node->_draw_border( $fb, 'solid', 'solid', 'solid', 'solid');

is (join ("::", @$fb), 
  '+----------+::|          |::|          |::|          |::|          |::+----------+',
  'solid border');


$fb = $node->_framebuffer(8,4);

$node->{w} = 8;
$node->{h} = 4;

my @expect = (
  '        \n        \n        \n        ',
  '+------+\n|      |\n|      |\n+------+',
  '........\n:      :\n:      :\n........',
  '+- - - +\n\'      \'\n\'      \'\n+- - - +',
  '+.-.-.-+\n!      !\n!      !\n+.-.-.-+',
  '+..-..-+\n|      |\n:      :\n+..-..-+',
  '########\n#      #\n#      #\n########',
  '#======#\nH      H\nH      H\n#======#',
  '#= = = #\n"      "\n"      "\n#= = = #',
  '+~~~~~~+\n{      {\n}      }\n+~~~~~~+',
  );

my $i = 0;
for my $style (qw/ none solid dotted dashed dot-dash dot-dot-dash bold double double-dash wave/)
  {
  $node->_draw_border( $fb, $style, $style, $style, $style);
  is (join ('\n', @$fb), 
    $expect[$i],
    "$style border");
  $i++;
  }

#############################################################################
# _draw_border() tests with different styles

$fb = $node->_framebuffer(8,4);

$node->{w} = 8;
$node->{h} = 4;

$node->_draw_border( $fb, 'solid', 'dotted', 'solid', 'solid');

is (join ("::", @$fb), 
  '+------+::|      |::|      |::........',
  'solid border, except bottom, which is dotted');
