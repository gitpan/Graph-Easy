#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 41;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Parser") or die($@);
   use_ok ("Graph::Easy") or die($@);
   };

can_ok ("Graph::Easy::Parser", qw/
  _parse_attributes
  /);


#############################################################################
# parser object

my $parser = Graph::Easy::Parser->new();

is (ref($parser), 'Graph::Easy::Parser');
is ($parser->error(), '', 'no error yet');

$parser->{graph} = Graph::Easy->new();			# for _color_as_hex

my $line = 0;

foreach (<DATA>)
  {
  chomp;
  next if $_ =~ /^\s*\z/;

  my ($in,$result) = split /\|/, $_;

  my $txt = $in;
  $txt =~ s/\\n/\n/g;					# insert real newlines

  $parser->reset();
  $parser->{graph} = Graph::Easy->new();		# for _color_as_hex

  my $att = $parser->_parse_attributes($txt);		# reuse parser object

  if (!defined $att)
    {
    if ($result =~ /^error=/)
      {
      my $res = $result; $res =~ s/^error=//; my $resq = quotemeta($res);
      like ($parser->error(), qr/$resq/, $res);
      }
    else
      {
      print '# Got unexpected error: ' . $parser->error(), "\n";
      fail ("$txt");
      }
    next;
    }

  my $exp = '';
  foreach my $k (sort keys %$att)
    {
    $exp .= "$k=$att->{$k};";    
    }

  is ($exp, $result, $in);
  }

__DATA__
|
color: red;|color=#ff0000;
color : red;|color=#ff0000;
 color : lime ; |color=#00ff00;
 color : yellow  |color=#ffff00;
color: rgb(1,1,1);|color=#010101;
color: rgb(255,1,1);|color=#ff0101;
color: rgb(255,255,1);|color=#ffff01;
color: rgb(255,255,255);|color=#ffffff;
color: #ff0;|color=#ffff00;
color: #0f0;|color=#00ff00;
color: slategrey;|color=#708090;
color: slategrey;|color=#708090;
color: gray;|color=#808080;
color: gray;|color=#808080;
border-style: double;|border-style=double;
border-width: 1;|border-width=1;
border-color: red;|border-color=#ff0000;
color: red; border: none; |border=none;color=#ff0000;
color:|error=Error in attribute: 'color:' doesn't look valid
: red;|error=Error in attribute: ': red' doesn't look valid
: red|error=Error in attribute: ': red' doesn't look valid
color: reddish|error=Error in attribute: 'reddish' is not a valid color for a node
color:;background: red|error=Error in attribute: 'color:' doesn't look valid
shape:fruggle;|error=Error in attribute: 'fruggle' is not a valid shape for a node
color: rgb(256, 0, 0);|error=Error in attribute: 'rgb(256, 0, 0)' is not a valid color for a node
color: rgb(0, 256, 0);|error=Error in attribute: 'rgb(0, 256, 0)' is not a valid color for a node
color: rgb(0, 0, 256);|error=Error in attribute: 'rgb(0, 0, 256)' is not a valid color for a node
shape: qiggle;|error=Error in attribute: 'qiggle' is not a valid shape for a node
offset: -3,-2;|offset=-3,-2;
offset: 3,-2;|offset=3,-2;
offset: -3,2;|offset=-3,2;
fill: brown;|fill=#a52a2a;
point-shape: qiggle;|error=Error in attribute: 'qiggle' is not a valid point-shape for a node
toint-shape: qiggle;|error=Error in attribute: 'qiggle' is not a valid toint-shape for a node
autolabel: qiggle;|error=Error in attribute: 'qiggle' is not a valid autolabel for a node
