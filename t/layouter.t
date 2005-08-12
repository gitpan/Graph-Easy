#!/usr/bin/perl -w

use Test::More;
use strict;

# test parsing and laying out the graphs (with no strict checks on the
# output except that it should work)

BEGIN
   {
   plan tests => 10;
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

opendir DIR, "layouter" or die ("Cannot read dir 'in': $!");
my @files = readdir(DIR); closedir(DIR);

foreach my $f (sort @files)
  {
  next unless -f "layouter/$f";			# only files
  
  next unless $f =~ /\.txt/;			# ignore anything else

  print "# at $f\n";
  my $txt = readfile("layouter/$f");
  my $graph = $parser->from_text($txt);		# reuse parser object

  if (!defined $graph)
    {
    fail ("Graph input was invalid: " . $parser->error());
    next;
    }

  my $ascii = $graph->as_ascii();

  is ($graph->error(), '', 'no error on layout');

  # print a debug output
  $ascii =~ s/\n/\n# /g;
  print "# Generated:\n#\n# $ascii\n";
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
