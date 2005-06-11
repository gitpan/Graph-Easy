#!/usr/bin/perl -w

#############################################################################
# This script is used by both examples/ascii.pl and examples/html.pl to
# generate some sample graphs and then outputting them in the desired format.

use strict;
use warnings;

BEGIN
  {
  use lib '../lib';
  }

use Graph::Easy;

sub gen_graphs
  {
  my $graph = shift || Graph::Easy->new();
  my $method = shift || 'ascii';

  ###########################################################################
  my $node = Graph::Easy::Node->new( name => 'Bonn' );
  my $node2 = Graph::Easy::Node->new( name => 'Berlin' );

  $graph->add_edge( $node, $node2 );

  out ($graph, $method);
  
  ###########################################################################
  $graph->{debug} = 0;

  my $node3 = Graph::Easy::Node->new( name => 'Frankfurt',
    border => 'dotted 1px' );

  my $edge3 = Graph::Easy::Edge->new( style => '==>' );

  $graph->add_edge( $node2, $node3, $edge3 );

  out ($graph, $method);

  ###########################################################################
  my $node4 = Graph::Easy::Node->new( name => 'Dresden' );

  $graph->add_edge( $node3, $node4 );

  out ($graph, $method);

  ###########################################################################
  my $node5 = Graph::Easy::Node->new( name => 'Potsdam' );

  $graph->add_edge( $node2, $node5 );

  out ($graph, $method);

  ###########################################################################
  my $node6 = Graph::Easy::Node->new( name => 'Cottbus',
    border => '1px red solid',
   );

  my $edge5 = Graph::Easy::Edge->new( style => '..>' );

  $graph->add_edge( $node5, $node6, $edge5 );


  out ($graph, $method);
  
  ###########################################################################
  $graph->add_edge( $node6, $node3 );

  out ($graph, $method);

  }

1;
