#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 65;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Parser") or die($@);
   };

can_ok ("Graph::Easy::Parser", qw/
  new
  from_text
  from_file
  reset
  error
  _match_edge
  _match_node
  _match_attributes
  _match_optional_attributes
  /);

#############################################################################
# create parser object

my $parser = Graph::Easy::Parser->new();

is (ref($parser), 'Graph::Easy::Parser');
is ($parser->error(), '', 'no error yet');

my $line = 0;
my $qr_edge = $parser->_match_edge();

foreach my $l (<DATA>)
  {
  chomp ($l);
  next if $l =~ /^\s*\z/;			# skip empty ones
  next if $l =~ /^#/;				# skip comments

  my ($in,$type,$style) = split /\|/, $l;

  if ($type < 0)
    {
    if (!unlike ($in, qr/^$qr_edge\z/, "$in"))
      {
      $in =~ /^$qr_edge/;
      print STDERR "# '$1' '$2' '$3' '$4' '$5'\n";
      }
    next;
    }

  # XXX TODO check edge style and type:
  # 0 - undirected 
  # 1 - left
  # 2 - right 
  # 3 - left and right 
  if (! like ($in, qr/^$qr_edge\z/, "$in"))
    {
    $in =~ /^$qr_edge/;
    print STDERR "# '$1' '$2' '$3' '$4' '$5'\n";
    }

  }

__DATA__
--|0|--
==|0|==
..|0|..
- |0| -
---|0|--
===|0|==
...|0|..
- - |0| -
----|0|--
====|0|==
....|0|..
<->|3|--
<=>|3|==
<.>|3|..
<- >|3| -
<-->|3|--
<==>|3|==
<..>|3|..
<- - >|3| -
<--->|3|--
<===>|3|==
<...>|3|..
<- - >|3| -
->|2|--
=>|2|==
.>|2|..
- >|2| -
-->|2|--
==>|2|==
..>|2|..
- - >|2| -
--->|2|--
===>|2|==
...>|2|..
- - >|2| -
<-|1|--
<=|1|==
<.|1|..
<- |1| -
<--|1|--
<==|1|==
<..|1|..
<- -|1| - 
<- ->|3| -
# with labels
- Landstrasse --|0|--
= Autobahn ==>|0|==
. Im Bau ..>|0|..
- Tunnel - >|0| -
<-- Landstrasse -|0|--
<== Autobahn =|0|==
<.. Im Bau .|0|..
<- - Tunnel -|0| -
<-- Landstrasse -->|0|--
<== Autobahn ==>|0|==
<.. Im Bau ..>|0|..
<- Tunnel - >|0| -
# failures
<<--|-1|
<<--|-1|
<<-->>|-1|
<<. -.->>|-1|
< - Tunnel - >|-1|

