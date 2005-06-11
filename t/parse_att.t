#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 14;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy::Parser") or die($@);
   };

can_ok ("Graph::Easy::Parser", qw/
  _parse_attributes
  /);

#############################################################################
# parser object

my $parser = Graph::Easy::Parser->new();

is (ref($parser), 'Graph::Easy::Parser');
is ($parser->error(), '', 'no error yet');

my $line = 0;

foreach (<DATA>)
  {
  chomp;
  next if $_ =~ /^\s*\z/;

  my ($in,$result) = split /\|/, $_;

  my $txt = $in;
  $txt =~ s/\\n/\n/g;				# insert real newlines

  $parser->reset();

  my $att = $parser->_parse_attributes($txt);		# reuse parser object

  if (!defined $att)
    {
    if ($result =~ /^error=/)
      {
      my $res = $result; $res =~ s/^error=//;
      like ($parser->error(), qr/$res/, 'error msg');
      }
    else
      {
      print '# Got unexpected error: ' . $parser->error();
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
color: red;|color=red;
color : red;|color=red;
 color : red ; |color=red;
 color : red  |color=red;
color: red; background: none; |background=none;color=red;
color:|error=Error in atttribute: 'color:' doesn't look valid
: red;|error=Error in atttribute: ': red' doesn't look valid
: red|error=Error in atttribute: ': red' doesn't look valid
color:;background: red|error=Error in atttribute: 'color:' doesn't look valid
