#!/usr/bin/perl -w

# test Graph::Easy::Parser::Graphviz

use Test::More;
use strict;

BEGIN
   {
   plan tests => 39;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Parser::Graphviz") or die($@);
   };

can_ok ("Graph::Easy::Parser::Graphviz", qw/
  new
  from_text
  from_file
  reset
  error
  use_class
  _parse_attributes
  _remap_attributes
  _match_comment
  _build_match_stack
  /);

#############################################################################
# parser object

my $c = 'Graph::Easy::Parser::Graphviz';

my $parser = Graph::Easy::Parser::Graphviz->new( debug => 0 );

is (ref($parser), $c);
is ($parser->error(), '', 'no error yet');

#############################################################################
# from_text() and from_file() with Class->method style calling

my $graph = Graph::Easy::Parser::Graphviz->from_text('digraph G1 { "A" }');

is (ref($graph), 'Graph::Easy');
is ($graph->nodes(), 1, 'one node');

#$graph = Graph::Easy::Parser::Graphviz->from_file('in/1node.txt');
#
#is (ref($graph), 'Graph::Easy');
#is ($graph->nodes(), 1, 'one node');

#############################################################################
# matching nodes

my $node_qr = $parser->_match_node();

like ('"A"', $node_qr, '"A" is a node');
like ('Bonn12', $node_qr, 'Bonn12 is a node');
like ('"Bonn"', $node_qr, '"Bonn" is a node');

#############################################################################
# general pattern tests

my $line = 0;

foreach (<DATA>)
  {
  chomp;
  next if $_ =~ /^\s*\z/;			# skip empty lines
  next if $_ =~ /^#/;				# skip comments

  die ("Illegal line $line in testdata") unless $_ =~ /^(.*)\|([^\|]*)$/;
  my ($in,$result) = ($1,$2);

  my $txt = $in;
  $txt =~ s/\\n/\n/g;				# insert real newlines

#  Graph::Easy::Node->_reset_id();		# to get "#0" for each test
  my $graph = $parser->from_text($txt);		# reuse parser object

  if (!defined $graph)
    {
    fail($parser->error());
    next;
    }
  if ($graph->error)
    {
    fail($graph->error());
    next;
    }
 
  my $got = scalar $graph->nodes();

  my @edges = $graph->edges();

  my $es = 0;
  foreach my $e (sort { $a->label() cmp $b->label() } @edges)
    {
    $es ++ if $e->label() ne '';
    }

  $got .= '+' . $es if $es > 0;

  for my $n ( sort { $a->{name} cmp $b->{name} || $b->{att}->{label} cmp $a->{att}->{label} }
   ($graph->nodes(), $graph->edges()) )
    {
    $got .= "," . $n->label() unless $n->label() =~ /^\s?\z/ || $n->label() eq $n->name();
    $got .= "," . $n->name() unless $n->name() eq '';
    } 
  
  my @groups = $graph->groups();

  for my $gr ( @groups )
    {
    $got .= ',' . $gr->name();
    }

  is ($got, $result, $in);
  }

__DATA__
|0
# anon nodes
""|1,#0
""->""|2,#0,#1
"Bonn"->""|2,#1,Bonn
""->"Bonn"|2,#0,Bonn
# lines starting with '#' are discared
"Bonn"\n#"Berlin"|1,Bonn
# First "#0" and "#1" are created, and ID 2 goes to the edge.
# then "#3" is created, and ID 4 goes to the second edge. Therefore
# "#0" and "#3" are the two anon nodes.
""->"Bonn"->""|3,#0,#3,Bonn
# multiple spaces in nodes
" Bonn and Berlin "|1,Bonn and Berlin
" Bonn  and  Berlin  "|1,Bonn and Berlin
"  Bonn   and  Berlin  "|1,Bonn and Berlin
"  Bonn \n  and  Berlin  "|1,Bonn and Berlin
"  Bonn \n\n  and  Berlin  "|1,Bonn and Berlin
# normal tests
" Berlin "|1,Berlin
"Hamburg"|1,Hamburg
  "  Dresden  "  |1,Dresden
" Pirna " [ color="red" ]|1,Pirna
" Bonn " -> " Berlin "|2,Berlin,Bonn
" Bonn " -> " Berlin "\n"Berlin" -> "Frankfurt"|3,Berlin,Bonn,Frankfurt
" Bonn \( \#1 \) " -> " Berlin "\n"Berlin" -> "Frankfurt"|3,Berlin,Bonn ( #1 ),Frankfurt
" Bonn " [ color=red ]\n"Berlin" -> "Frankfurt"|3,Berlin,Bonn,Frankfurt
"Bonn"[color=red]\n"Berlin"->"Frankfurt"|3,Berlin,Bonn,Frankfurt
" Bonn " -> " Berlin "\n"Berlin" -> "Frankfurt"|3,Berlin,Bonn,Frankfurt
" Bonn " -> "Berlin" [color=blue] \n"Berlin" -> "Frankfurt"|3,Berlin,Bonn,Frankfurt
Bonn -> Berlin [color=blue] \nBerlin -> Frankfurt|3,Berlin,Bonn,Frankfurt
# comments
" Bonn " -> " Berlin " [ color="#A0a0A0" ] // failed " Bonn " -> [ Ulm ]|2,Berlin,Bonn
" Bonn " -> " Berlin " [ color="#A0a0A0" ] //80808080 failed [ Bonn ] -> [ Ulm ]|2,Berlin,Bonn
" Bonn " -> " Berlin " [ color="#A0a0A0" ] //808080 failed [ Bonn ] -> [ Ulm ]|2,Berlin,Bonn
" Bonn " -> " Berlin " [ color="#A0a0A0" ] /*808080 failed [ Bonn ] -> [ Ulm ]*/|2,Berlin,Bonn
" Bonn " -> " Berlin " [ color="#A0a0A0" ] /*808080 failed\n [ Bonn ] -> [ Ulm ]*/|2,Berlin,Bonn
# node chains
" Bonn " -> " Berlin "\n -> " Kassel "|3,Berlin,Bonn,Kassel

