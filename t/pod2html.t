#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 4;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Pod2HTML") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Pod2HTML", qw/
  new
  go
  /);

#############################################################################

my $parser = Graph::Easy::Pod2HTML->new();

is (ref($parser), 'Graph::Easy::Pod2HTML');

