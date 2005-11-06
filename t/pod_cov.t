#!/usr/bin/perl -w

use Test::More;
use strict;

my $tests;

BEGIN
   {
   $tests = 5;
   plan tests => $tests;
   chdir 't' if -d 't';
   use lib '../lib';
   };


SKIP:
  {
  skip("Test::Pod::Coverage 1.00 required for testing POD coverage", $tests)
    unless do {
    eval "use Test::Pod::Coverage 1.00";
    $@ ? 0 : 1;
    };
  for my $m (qw/
    Graph::Easy::Node
    Graph::Easy::Parser
    Graph::Easy::Group
    Graph::Easy::Edge
   /)
    {
    pod_coverage_ok( $m, "$m is covered" );
    }

  # Define the global CONSTANTS for internal usage
  my $trustme = { trustme => [ qr/^(
	ACTION_CHAIN|
	ACTION_NODE|
	ACTION_TRACE|
	ATTR_COLOR|
	ATTR_DEFAULT_SLOT|
	ATTR_DESC_SLOT|
	ATTR_EXAMPLE_SLOT|
	ATTR_MATCH_SLOT|
	ATTR_STRING|
	ATTR_ANGLE|
	ATTR_TYPE_SLOT|
    )\z/x ] };
  pod_coverage_ok( "Graph::Easy", $trustme );

  }

