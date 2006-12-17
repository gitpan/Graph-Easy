#!/usr/bin/perl -w

# Test nesting of groups

use Test::More;
use strict;

BEGIN
   {
   plan tests => 19;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Group") or die($@);
   use_ok ("Graph::Easy::Group::Cell") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

#############################################################################
# $group->add_member($inner);

my $graph = Graph::Easy->new();

my $group = $graph->add_group('Outer');

is (ref($group), 'Graph::Easy::Group');
is ($group->error(), '', 'no error yet');

my $inner = $graph->add_group('Inner');
$group->add_member($inner);

check_groups($group,$inner);

#############################################################################
# $inner->add_to_group($group);

$graph = Graph::Easy->new();

$group = $graph->add_group('Outer');

is (ref($group), 'Graph::Easy::Group');
is ($group->error(), '', 'no error yet');

$inner = $graph->add_group('Inner');

$inner->add_to_group($group);

check_groups($group,$inner);

# all tests done
1;

#############################################################################

sub check_groups
  {
  my ($group,$inner) = @_;

  is ($inner->{group}, $group, 'inner is in outer');

  my @groups = $group->groups();

  is (@groups, 1, 'one group in outer');
  is ($groups[0], $inner, 'and it is "Inner"');

  @groups = $inner->groups();

  is (@groups, 0, 'no group in Inner');
 
  is ($inner->attribute('group'), 'Outer', 'attribute("group")');
  is ($group->attribute('group'), '', 'attribute("group")');
  }
