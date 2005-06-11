#!/usr/bin/perl -w

#############################################################################
# This script uses examples/common.pl to generate some example graphs and
# displays them in ASCII.

use strict;
use warnings;

BEGIN { chdir 'examples' if -d 'examples'; }

require "common.pl";

sub out
  {
  my ($graph,$method) = @_;

  $method = 'as_' . $method;
  print $graph->$method(), "\n";
  }

gen_graphs ();

