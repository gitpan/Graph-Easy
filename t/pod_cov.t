#!/usr/bin/perl -w

use Test::More;
use strict;

my $tests;

BEGIN
   {
   $tests = 20;
   plan tests => $tests;
   chdir 't' if -d 't';
   use lib '../lib';
   };

SKIP:
  {
  skip("Test::Pod::Coverage 1.08 required for testing POD coverage", $tests)
    unless do {
    eval "use Test::Pod::Coverage 1.08";
    $@ ? 0 : 1;
    };
  for my $m (qw/
    Graph::Easy
    Graph::Easy::Node
    Graph::Easy::Group
    Graph::Easy::Edge
    Graph::Easy::Base
    Graph::Easy::As_ascii
    Graph::Easy::As_txt
    Graph::Easy::As_graphviz
    Graph::Easy::Layout::Chain
    Graph::Easy::Layout::Grid
    Graph::Easy::Layout::Path
    Graph::Easy::Layout::Scout
    Graph::Easy::Layout::Repair
    Graph::Easy::Attributes
    Graph::Easy::As_ascii
   /)
    {
    pod_coverage_ok( $m, "$m is covered" );
    }

  my $trustparents = { coverage_class => 'Pod::Coverage::CountParents' };
  for my $m (qw/
    Graph::Easy::Node::Anon
    Graph::Easy::Group::Anon
   /)
    {
    pod_coverage_ok( $m, $trustparents, "$m is covered" );
    }

  # Define the global CONSTANTS for internal usage
  my $trustme = { trustme => [ qr/^(
	ACTION_CHAIN|
	ACTION_NODE|
	ACTION_TRACE|
	ACTION_EDGES|
	ACTION_SPLICE|
	ATTR_COLOR|
	ATTR_DEFAULT_SLOT|
	ATTR_DESC_SLOT|
	ATTR_EXAMPLE_SLOT|
	ATTR_MATCH_SLOT|
	ATTR_STRING|
	ATTR_ANGLE|
	ATTR_PORT|
	ATTR_TYPE_SLOT|
    )\z/x ] };
  pod_coverage_ok( "Graph::Easy", $trustme );

  # Define the global CONSTANTS for internal usage
  $trustme = { trustme => [ qr/^(
	NO_MULTIPLES
    )\z/x ] };
  pod_coverage_ok( "Graph::Easy::Parser", $trustme );
  pod_coverage_ok( "Graph::Easy::Parser::Graphviz", $trustme );

  }

