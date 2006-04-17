#!/usr/bin/perl -w

use Test::More;
use strict;

# test graphviz (dot) file input => ASCII output

# TODO: and back to as_txt() again

BEGIN
   {
   plan tests => 8;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy") or die($@);
   use_ok ("Graph::Easy::Parser") or die($@);
   };

#############################################################################
# parser object

my $parser = Graph::Easy::Parser->new( debug => 0);

is (ref($parser), 'Graph::Easy::Parser');
is ($parser->error(), '', 'no error yet');

my $dir = "in/graphviz/";

opendir DIR, $dir or die ("Cannot read dir 'in/grapviz': $!");
my @files = readdir(DIR); closedir(DIR);

eval { require Test::Differences; };

foreach my $f (sort @files)
  {
  next unless -f "$dir/$f";			# only files
  
  next unless $f =~ /\.dot/;			# ignore anything else

  print "# at $f\n";
  my $txt = readfile("$dir/$f");
  my $graph = $parser->from_text($txt);		# reuse parser object

# $txt =~ s/\n\s+\z/\n/;			# remove trailing whitespace
# $txt =~ s/(^|\n)\s*#[^#]{2}.*\n//g;		# remove comments
 
  $f =~ /^(\d+)/;
  my $nodes = $1;

  if (!defined $graph)
    {
    warn ("Graphviz input was invalid: " . $parser->error());
    next;
    }
  is (scalar $graph->nodes(), $nodes, "$nodes nodes");

  # for slow testing machines
  $graph->timeout(20);
  my $ascii = $graph->as_ascii();

  my $of = $f; $of =~ s/\.dot/\.txt/;
  my $out = readfile("out/graphviz/$of");
  $out =~ s/(^|\n)\s*#[^#=]{2}.*\n//g;		# remove comments
  $out =~ s/\n\n\z/\n/mg;			# remove empty lines

# print "txt: $txt\n";
# print "ascii: $ascii\n";
# print "should: $out\n";

  if (!
    is ($ascii, $out, "from $f"))
    {
    if (defined $Test::Differences::VERSION)
      {
      Test::Differences::eq_or_diff ($ascii, $out);
      }
    else
      {
      fail ("Test::Differences not installed");
      }
    }

  # if the txt output differes, read it in
  if (-f "txt/$f")
    {
    $txt = readfile("txt/$f");
    }

# if (!
#   is ($graph->as_txt(), $txt, "$f as_txt"))
#   {
#   if (defined $Test::Differences::VERSION)
#     {
#     Test::Differences::eq_or_diff ($graph->as_txt(), $txt);
#     }
#   else
#     {
#     fail ("Test::Differences not installed");
#     }
#   }

  # print a debug output
  my $debug = $ascii;
  $debug =~ s/\n/\n# /g;
  print "# Generated:\n#\n# $debug\n";
  }

1;

sub readfile
  {
  my ($file) = @_;

  open FILE, $file or die ("Cannot read file $file: $!");
  local $/ = undef;				# slurp mode
  my $doc = <FILE>;
  close FILE;

  $doc;
  }
