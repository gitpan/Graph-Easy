#!/usr/bin/perl -w

use Test::More;
use strict;
use File::Spec;

# test graphviz (dot) file input => ASCII output
# and back to as_txt() again

BEGIN
   {
   plan tests => 74;
   chdir 't' if -d 't';
   use lib '../lib';
   use_ok ("Graph::Easy") or die($@);
   use_ok ("Graph::Easy::Parser") or die($@);
   };

my @warnings;

#############################################################################
# override the warn method to catch warnigs

{
 no warnings 'redefine';

 package Graph::Easy::Base;

 sub warn {
   my ($self,$msg) = @_;
   push @warnings, $msg;
 }

}

#############################################################################
# parser object

my $parser = Graph::Easy::Parser->new( debug => 0);

is (ref($parser), 'Graph::Easy::Parser');
is ($parser->error(), '', 'no error yet');

my $dir = File::Spec->catdir('in','dot');

opendir DIR, $dir or die ("Cannot read dir 'in/grapviz': $!");
my @files = readdir(DIR); closedir(DIR);

binmode (STDERR, ':utf8') or die ("Cannot do binmode(':utf8') on STDERR: $!");
binmode (STDOUT, ':utf8') or die ("Cannot do binmode(':utf8') on STDOUT: $!");

eval { require Test::Differences; };

foreach my $f (sort @files)
  {
  next unless -f "$dir/$f";			# only files
  
  next unless $f =~ /\.dot/;			# ignore anything else

  print "# at $f\n";
  my $txt = readfile("$dir/$f");
  my $graph = $parser->from_text($txt);		# reuse parser object

  $f =~ /^(\d+)/;
  my $nodes = $1;

  if (!defined $graph)
    {
    fail ("Graphviz input was invalid: " . $parser->error());
    next;
    }
  is (scalar $graph->nodes(), $nodes, "$nodes nodes");

  # for slow testing machines
  $graph->timeout(20);
  my $ascii = $graph->as_ascii();

  my $of = $f; $of =~ s/\.dot/\.txt/;
  my $out = readfile(File::Spec->catfile('out','dot',$of));
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
  my $f_txt = File::Spec->catfile('txt','dot',$of);
  if (-f $f_txt)
    {
    $txt = readfile($f_txt);
    }

 if (!
   is ($graph->as_txt(), $txt, "$f as_txt"))
   {
   if (defined $Test::Differences::VERSION)
     {
     Test::Differences::eq_or_diff ($graph->as_txt(), $txt);
     }
   else
     {
     fail ("Test::Differences not installed");
     }
   }

  # print a debug output
  my $debug = $ascii;
  $debug =~ s/\n/\n# /g;
  print "# Generated:\n#\n# $debug\n";
  }

# check that only the expected warnings were generated
is (scalar @warnings, 6, 'Got exactly 6 warnings');

my $i = 0;
for my $name (qw/bar pname foo fname bar brabble/)
  {
  is ($warnings[$i], "Ignoring unknown attribute '$name'", 
	"Got warning about $name");
  $i++;
  }

1;

sub readfile
  {
  my ($file) = @_;

  open my $FILE, $file or die ("Cannot read file $file: $!");
  binmode ($FILE, ':utf8') or die ("Cannot do binmode(':utf8') on $FILE: $!");
  local $/ = undef;				# slurp mode
  my $doc = <$FILE>;
  close $FILE;

  $doc;
  }
