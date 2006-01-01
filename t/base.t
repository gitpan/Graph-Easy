#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 4;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Base") or die($@);
   };

can_ok ("Graph::Easy::Base", qw/
  new error
  _init
  self
  class
  sub_class
  main_class
  /);

#############################################################################
# Base tests

my $base = Graph::Easy::Base->new();

is (ref($base), 'Graph::Easy::Base', 'new seemed to work');
is ($base->error(), '', 'no error yet');
