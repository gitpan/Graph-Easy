#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 65;
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

$parser->no_fatal_errors(1);

foreach (<DATA>)
  {
  chomp;
  next if $_ =~ /^(\s*\z|#)/;			# skip empty lines or comments
  
  my ($in,$result) = split /\|/, $_;

  my $txt = $in;
  $txt =~ s/\\n/\n/g;					# insert real newlines

  # ^ => to '|' since '|' is the sep.
  $txt =~ s/[\^]/\|/g;

  $parser->reset();
  $parser->{graph} = Graph::Easy->new();		# for _color_as_hex

  my $class = 'node'; $class = 'edge' if $txt =~ /^(start|end)/;

  my $att = $parser->_parse_attributes($txt, $class);	# reuse parser object

  if (!ref($att))
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
    if (ref($att->{$k}) eq 'ARRAY')
      {
      $exp .= "$k=" . join(",", @{$att->{$k}}) . ';';    
      }
    else
      {
      $exp .= "$k=$att->{$k};";
      }
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
# attribute with a ";" inside quotes
label: "baz;bar"; color: red;|color=#ff0000;label="baz;bar";
border-style: double;|border-style=double;
border-width: 1;|border-width=1;
border-color: red;|border-color=#ff0000;
color: red; border: none; |border=none;color=#ff0000;
color:|error=Error in attribute: 'color:' doesn't look valid
: red;|error=Error in attribute: ': red;' doesn't look valid
: red|error=Error in attribute: ': red' doesn't look valid
color: reddish|error=Error in attribute: 'reddish' is not a valid color for a node
color:;background: red|error=Error in attribute: 'color:;background: red' doesn't look valid
shape:fruggle;|error=Error in attribute: 'fruggle' is not a valid shape for a node
color: rgb(256, 0, 0);|error=Error in attribute: 'rgb(256, 0, 0)' is not a valid color for a node
color: rgb(0, 256, 0);|error=Error in attribute: 'rgb(0, 256, 0)' is not a valid color for a node
color: rgb(0, 0, 256);|error=Error in attribute: 'rgb(0, 0, 256)' is not a valid color for a node
shape: qiggle;|error=Error in attribute: 'qiggle' is not a valid shape for a node
offset: -3,-2;|offset=-3,-2;
offset: 3,-2;|offset=3,-2;
offset: -3,2;|offset=-3,2;
offset: 2, 0;|offset=2, 0;
offset:  2 , 0;|offset=2 , 0;
offset:  2  ,  0;|offset=2  ,  0;
offset:  2  ,  0 ;|offset=2  ,  0;
fill: brown;|fill=#a52a2a;
point-style: qiggle;|error=Error in attribute: 'qiggle' is not a valid point-style for a node
toint-shape: qiggle;|error=Error in attribute: 'toint-shape' is not a valid attribute name for a node
autolink: qiggle;|error=Error in attribute: 'qiggle' is not a valid autolink for a node
size: 1, 2;|size=1, 2;
start: south, 1;|start=south, 1;
start: south , 1;|start=south , 1;
start: right , -1;|start=right , -1;
end: south, 1;|end=south, 1;
end: south , 1;|end=south , 1;
end: right , -1;|end=right , -1;
end: right,12345;|error=Error in attribute: 'right,12345' is not a valid end for a edge
start: right,12345;|error=Error in attribute: 'right,12345' is not a valid start for a edge
autolabel: name;|autolabel=name;
autolabel: name,1;|error=Error in attribute: 'name,1' is not a valid autolabel for a node
autolabel: name,10;|autolabel=name,10;
autolabel: name, 10;|autolabel=name, 10;
autolabel: name ,10;|autolabel=name ,10;
autolabel: name , 10;|autolabel=name , 10;
fill: red^green^yellow;|fill=#ff0000,#008000,#ffff00;
link: http://bloodgate.com/^index.html^/test;|link=http://bloodgate.com/,index.html,/test;
link: http://bloodgate.com/ ^ index.html^/test;|link=http://bloodgate.com/,index.html,/test;
shape: rect^img^rect;|shape=rect,img,rect;
