#############################################################################
# Parse text definition into a Graph::Easy object
#
# (c) by Tels 2004 - 2005.
#############################################################################

package Graph::Easy::Parser;

use 5.006001;
use strict;
use Graph::Easy;
use Graph::Easy::Attributes;

use vars qw/$VERSION/;

$VERSION = '0.13';

sub new
  {
  my $class = shift;

  my $self = bless {}, $class;

  my $args = $_[0];
  $args = { @_ } if ref($args) ne 'HASH';

  $self->_init($args);
  }

sub _init
  {
  my ($self,$args) = @_;

  $self->{error} = '';
  $self->{debug} = 0;
  
  foreach my $k (keys %$args)
    {
#    if ($k !~ /^(|debug)\z/)
#      {
#      $self->error ("Unknown option '$k'");
#      }
    $self->{$k} = $args->{$k};
    }

  $self;
  }

sub reset
  {
  # reset the status of the parser, clear errors etc.
  my $self = shift;

  $self->{error} = '';
  $self->{anon_id} = 0;
  $self->{cluster_id} = '';		# each cluster gets a unique ID
  $self->{line_nr} = -1;
  $self->{graph} = undef;

  $self;
  }

sub from_file
  {
  my ($self,$file) = @_;

  $self = $self->new() unless ref $self;

  my $doc;
  local $/ = undef;			# slurp mode
  # if given a reference, assume it is a glob, or something like that
  if (ref($file))
    {
    $doc = <$file>;
    }
  else
    {
    open PARSER_FILE, $file or die (ref($self).": Cannot read $file: $!");
    $doc = <PARSER_FILE>;		# read entire file
    close PARSER_FILE;
    }

  $self->from_text($doc);
  }

sub from_text
  {
  my ($self,$txt) = @_;

  $self->reset();

  $self->{graph} = Graph::Easy->new( { debug => $self->{debug} } );
  my $graph = $self->{graph};

  return $graph if !defined $txt || $txt =~ /^\s*\z/;		# empty text?

  my @lines = split /\n/, $txt;

  my $c = 'Graph::Easy::Node';
  my $e = 'Graph::Easy::Edge';
  my $g = 'Graph::Easy::Group';

  # regexps for the different parts
  my $qr_node = _match_node();
  my $qr_attr = _match_attributes();
  my $qr_oatr = _match_optional_attributes();
  my $qr_edge = _match_edge();
  my $qr_comma = _match_comma();

  my $qr_group_start = _match_group_start();
  my $qr_group_end   = _match_group_end();

  # After "[ 1 ] -> [ 2 ]" we push "2" on the stack and when we encounter
  # " -> [ 3 ]" treat the stack as a node-list left of "3".
  # In addition, for " [ 1 ], [ 2 ] => [ 3 ]", the stack will contain
  # "1" and "2" when we encounter "3".
  my @stack = ();

  my @group_stack = ();	# all the (nested) groups we are currently in
  my $backbuffer = '';	# left over fragments to be combined with next line

  ###########################################################################
  # main parsing loop

  LINE:
  while (@lines > 0 || $backbuffer ne '')
    {
    my $curline = '';
    
    if (@lines > 0)
      {
      $self->{line_nr}++;
      $curline = shift @lines;
      next if $curline =~ /^\s*(#|\z)/;		# comment or empty line?
      }
    
    chomp($curline);

    my $line = $backbuffer . $curline;

    # XXX TODO: this should *only* capture "fff" or "ffffff", but not "ffff":
    # convert #808080 into \#808080
    $line =~ s/:\s*(#[a-fA-F0-9]{3,6})/: \\$1/g;

    # remove comment at end of line (but leave \# alone):
    $line =~ s/[^\\]#.*//;

    # remove white space at start/end
    $line =~ s/^\s+//;
    $line =~ s/\s+\z//;

    #print STDERR "# at line '$line' stack: ", join(",", @stack),"\n";

    # node { color: red; } or 
    # node.graph { color: red; }
    # XXX TODO: group-label, edge-label
    if ($line =~ /^(node|graph|edge|group)(\.\w+)?$qr_attr\z/)
      {
      my $type = $1 || '';
      my $class = $2 || '';
      my $att = $self->_parse_attributes($3 || '');

      return undef unless defined $att;		# error in attributes?

      $graph->set_attributes ( "$type$class", $att);

      # forget stack
      @stack = ();

      # and current line
      $line = '';
      }
    # ( group start [
    elsif ($line =~ /^$qr_group_start/)
      {
      my $gn = $1 || '';			# group name

      # unquote special chars
      $gn =~ s/\\([\[\(\{\}\]\)#\|])/$1/g;

      my $group = $graph->group ($gn);
      if (!defined $group)
        {
        $group = $g->new( { name => $gn } );
        $graph->add_group ($group);
        }
      push @group_stack, $group;

      $line =~ s/^$qr_group_start/\[/;
      }
    # ) # group end
    elsif ($line =~ /^$qr_group_end$qr_oatr/)
      {

      if (@group_stack == 0)
        {
        $self->parse_error("Found unexpected group end at line $self->{line_nr}");
        return undef;
        }
      my $group = pop @group_stack;

      my $a1 = $self->_parse_attributes($1||'');	# group attributes
      return undef if $self->{error};
      $group->set_attributes($a1);

      $line =~ s/^$qr_group_end$qr_oatr//;
      }
    # [ Berlin ] { color: red; }
    elsif ($line =~ /^$qr_node$qr_oatr/)
      {
      my $n1 = $1;
      my $a1 = $self->_parse_attributes($2||'');
      return undef if $self->{error};

      @stack = $self->_new_node ($graph, $n1, \@group_stack, $a1);

      $line =~ s/^$qr_node$qr_oatr//;
      }
    # , [ Berlin ] { color: red; }
    elsif ($line =~ /^$qr_comma$qr_node$qr_oatr/)
      {
      my $n1 = $1;
      my $a1 = $self->_parse_attributes($2||'');
      return undef if $self->{error};

      @stack = $self->_new_node ($graph, $n1, \@group_stack, $a1);

      $line =~ s/^$qr_comma$qr_node$qr_oatr//;
      }
    # Things like "[ Node ]" will be consumed before, so we do not need a case
    # for "[ A ] -> [ B ]":
    # node chain continued like "-> { ... } [ Kassel ] { ... }"
    elsif (@stack != 0 && $line =~ /^$qr_edge$qr_oatr$qr_node$qr_oatr/)
      {
      my $eg = $1;					# entire edge ("-- label -->" etc)

      my $edge_bd = $2 || $4;				# bidirectional edge ('<') ?
      my $edge_label = $7 || '';			# optional edge label
      my $ed = $3 || $5;				# edge pattern/style ("--")

      my $edge_atr = $11 || '';				# save edge attributes

      my $n = $12;					# node name
      my $a1 = $self->_parse_attributes($13||'');	# node attributes
      return undef if $self->{error};

      $edge_atr = $self->_parse_attributes($edge_atr, 'edge');
      return undef if $self->{error};

      # strip trailing spaces
      $edge_label =~ s/\s*\z//;

      my @nodes_b = $self->_new_node ($graph, $n, \@group_stack, $a1);

      my $style = 'solid';			# default
      $style = 'double-dash' if $ed =~ /^(= )+\z/; 
      $style = 'double' if $ed =~ /^=+\z/; 
      $style = 'dotted' if $ed =~ /^\.+\z/; 
      $style = 'dashed' if $ed =~ /^(- )+\z/; 
      $style = 'dot-dot-dash' if $ed =~ /^(..-)+\z/; 
      $style = 'dot-dash' if $ed =~ /^(\.-)+\z/; 
      $style = 'wave' if $ed =~ /^\~+\z/; 
      $style = 'bold' if $ed =~ /^#+\z/; 

      # add edges for all nodes in the left list
      foreach my $node (@stack)
        {
#        print STDERR "# continued: edge from $node->{name} => $node_b->{name}\n";

        foreach my $node_b (@nodes_b)
          {
          my $edge = $e->new( { style => $style, name => $edge_label } );
          $edge->set_attributes($edge_atr);
	  # "<--->": bidirectional
          $edge->bidirectional(1) if $edge_bd;
          $graph->add_edge ( $node, $node_b, $edge );
          }
        }
#      print STDERR "# handled stack\n";
 
      # remember the right side
      @stack = @nodes_b;

      $line =~ s/^$qr_edge$qr_oatr$qr_node$qr_oatr//;
      }
    else
      {
      # couldn't handle that fragement, so accumulate it
      last LINE if @lines == 0;			# but not if it is the very last

      $line = $backbuffer . $curline;
      }

    $backbuffer = $line;
    }

   if ($backbuffer ne '')
    { 
    $self->error("'$backbuffer' not recognized by parser.");
    return undef;
    }

  $graph;
  }

#############################################################################
# internal routines

sub _new_node
  {
  # Create a new node unless it doesn't already exist. If the group stack
  # contains entries, the new node appears first in this/these group(s), so
  # add it to these groups. If the newly created node contains "|", we split
  # it up into several nodes and cluster these together.
  my ($self, $graph, $name, $group_stack, $att) = @_;

  # strip trailing spaces
  $name =~ s/\s*\z//;
  # collapse multiple spaces
  $name =~ s/\s+/ /g;
  # unquote special chars
  $name =~ s/\\([\[\(\{\}\]\)#])/$1/g;

  my @rc = ();

  if ($name eq '')
    {
    # create a new anon node and add it to the graph
    my $node = Graph::Easy::Node::Anon->new();
    $graph->add_node($node);
    push @rc, $node;
    }
  elsif ($name =~ /[^\\]\|/)
    {
#    print STDERR "$name is to be split\n";

    # build base name: "A|B |C||D" => "ABCD"
    my $base_name = $name; $base_name =~ s/\s*\|\|?\s*//g;

    # first one gets: "ABC", second one "ABC.1" and so on
    # Try to find a unique cluster name in case some one get's creative and names the
    # last part "-1":

    my $g = 1;
    while ($g == 1)
      {
      my $base_try = $base_name; $base_try .= '-' . $self->{cluster_id} if $self->{cluster_id};
      last if !defined $graph->cluster($base_try);
      $self->{cluster_id}++;
      }
    $base_name .= '-' . $self->{cluster_id} if $self->{cluster_id}; $self->{cluster_id}++;

    my $cluster = Graph::Easy::Cluster->new( name => $base_name );
    $graph->add_cluster($cluster); 

    my $x = 0; my $y = 0; my $idx = 0;
    my $remaining = $name;
    while ($remaining ne '')
      {
      # XXX TODO: parsing of "\|" and "|" in one node
      $remaining =~ s/^([^\|]*)(\|\|?|\z)//;
      my $part = $1 || '';
      my $sep = $2;

#      print STDERR "# at part $part for $name ($idx=$x,$y) (remaining: $remaining)\n";

      $part =~ s/^\s*//;	# rem spaces at front
      $part =~ s/\s*$//;	# rem spaces at end

      my $node_name = "$base_name.$idx";

      if ($part ne '')
        {
        my $node = Graph::Easy::Node->new( { name => $node_name, label => $part, dx => $x, dy => $y } );
        $node->add_to_cluster($cluster);
        $graph->add_node($node);
        push @rc, $node;
        if (@rc == 1)
          {
          # make second, third etc node relative to first one
          $cluster->center_node($rc[0]);
          }
        else
          {
          $node->origin($rc[0]);		# relative to this one
          }
        $idx++;					# next node ID
        }
      $x++;
      # || starts a new row:
      if ($sep eq '||')
        {
        $x = 0; $y++;
        }
      } 
    }
  else
    {
    # unquoe \|
    $name =~ s/\\\|/\|/g;

    # try to find node with that name
    my $node = $graph->node($name);
    # not found? so create a new one and add it to the graph
    if (!defined $node)
      {
      $node = Graph::Easy::Node->new( { name => $name } );
      $graph->add_node($node);
      }
    push @rc, $node;
    }

  foreach my $node (@rc)
    {
    $node->add_to_groups(@$group_stack) if @$group_stack != 0;
    $node->set_attributes ($att);
    }

  # return list of created nodes (usually one, but more for "A|B")
  @rc;
  }

sub _match_comma
  {
  # return a regexp that matches something like " , " like in:
  # "[ Bonn ], [ Berlin ] => [ Hamburg ]"
  qr/\s*,\s*/;
  }

sub _match_attributes
  {
  # return a regexp that matches something like " { color: red; }" and returns
  # the inner text without the {}
  qr/\s*\{\s*([^\}]+?)\s*\}/;
  }

sub _match_optional_attributes
  {
  # return a regexp that matches something like " { color: red; }" and returns
  # the inner text with the {}
  #qr/(\s*\{\s*[^\}]+?\s*\})?/;
  qr/(\s*\{[^\}]+?\})?/;
  }

sub _match_node
  {
  # return a regexp that matches something like " [ bonn ]" and returns
  # the inner text without the [] (might leave some spaces)

  #           v--- for empty nodes
  #            v-- normal nodes  
  qr/\s*\[\s*(|[^\]]*?[^\\])\]/;
  }

sub _match_group_start
  {
  # return a regexp that matches something like " ( group [" and returns
  # the text between "(" and "["
  qr/\s*\(\s*([^\[]+?)\s*\[/;
  }

sub _match_group_end
  {
  # return a regexp that matches something like " )".
  qr/\s*\)\s*/;
  }

sub _match_edge_simple
  {
  # matches edges like "--", "- - ", "..-" etc

  qr/\s*
     (
       (\.\.-|\.-)+			 # pattern (style) of edge (at least once)
     |
       (=\s|=|-\s|-|\.|~){2,}		 # these at least two times
     )/x;
  }

sub _match_edge
  {
  # Matches all possible edge variants like:
  # -->, ---->, ==> etc
  # <-->, <---->, <==>, <..> etc
  # <-- label -->, <.- label .-> etc  
  # -- label -->, .- label .-> etc  

  # "- " must come before "-"!
  # likewise, "..-" must come before ".-" must come before "."

  qr/\s*
     (					# egde without label ("-->")
       (<?) 				 # optional left "<"
       (=\s|=|-\s|-|\.\.-|\.-|\.|~)+>	 # pattern (style) of edge
     |					# edge with label ("-- label -->")
       (<?) 				 # optional left "<"
       ((=\s|=|-\s|-|\.\.-|\.-|\.|~)+)	 # pattern (style) of edge
       \s*				 # followed by at least a space
       ([^>]*?)				 # many label chars (but not ">"!)
       (\s+\5)>				 # a space and pattern before ">"
     |					# edge with label ("-- label -->")
       (\.\.-|\.-)+			 # pattern (style) of edge (at least once)
     |
       (=\s|=|-\s|-|\.|~){2,}		 # these at least two times
     )
     /x;
   }

sub _parse_attributes
  {
  # takes a text like "attribute: value;  attribute2 : value2;" and
  # returns a hash with the attributes. $class defaults to 'node'.
  my ($self,$text,$class) = @_;

  $class ||= 'node';
  my $att = {};

  $text =~ s/^\s*\{//;		# remove left-over {
  $text =~ s/\}\s*\z//;		# remove left-over }

  my @atts = split /\s*;\s*/, $text;

  foreach my $a (@atts)
    {
    $self->error ("Error in attribute: '$a' doesn't look valid to me.")
      and return undef 
    unless ($a =~ /^\s*([^:]+?)\s*:\s*(.+?)\s*\z/);	# "name: value"

    my ($name, $val) = ($1,$2);

    $val =~ s/\\#/#/g;					# unquote \#

    my $v = Graph::Easy::Attributes->valid_attribute($name,$val,$class);
    $self->parse_error(2,$val,$name,$class), return
      unless defined $v;				# stop on error

    $att->{$name} = $v;
    }
  $att;
  }

sub parse_error
  {
  # take a msg number, plus params, and throws an exception
  my $self = shift;
  my $msg_nr = shift;

  # XXX TODO: should really use the msg nr mapping
  my $msg = "Value '##param2##' for attribute '##param1##' is invalid";
  $msg = "Error in attribute: '##param1##' is not a valid ##param2## for ##param3##" if $msg_nr == 2;

  my $i = 1;
  foreach my $p (@_)
    {
    $msg =~ s/##param$i##/$p/g; $i++;
    }

  $self->error($msg . ' at line ' . $self->{line_nr});
  }

sub error
  {
  my $self = shift;

  $self->{error} = $_[0] if defined $_[0];
  $self->{error};
  }

1;
__END__

=head1 NAME

Graph::Easy::Parser - Parse graph from textual description

=head1 SYNOPSIS

        # creating a graph from a textual description
        use Graph::Easy::Parser;
        my $parser = Graph::Easy::Parser->new();

        my $graph = $parser->from_text(
                '[ Bonn ] => [ Berlin ]'.
                '[ Berlin ] => [ Rostock ]'.
        );
        print $graph->as_ascii( );

=head1 DESCRIPTION

C<Graph::Easy::Parser> lets you parse simple textual descriptions
of graphs, and constructs a C<Graph::Easy> object from them.

The resulting object can than be used to layout and output the graph.

=head2 Input

The input consists of text describing the graph.

	[ Bonn ]      --> [ Berlin ]
	[ Frankfurt ] <=> [ Dresden ]
	[ Bonn ]      --> [ Frankfurt ]
	[ Bonn ]      = > [ Frankfurt ]

The output will be a L<Graph::Easy|Graph::Easy> object, see there for what you
can do with it.

=over 2

=item nodes

Nodes are rendered (or "quoted", if you wish) with enclosing square brackets:

	[ Single node ]
	[ Node A ] --> [ Node B ]

=item edges

The edges between the nodes can have the following styles:

	->		solid
	=>		double
	.>		dotted
	~>		wave

	- >		dashed
	.->		dot-dash
	..->		dot-dot-dash
	= >		double-dash

There is also the style "bold". Unlike the others, this can only be
set via the (optional) edge attributes:

	[ AB ] --> { style: bold; } [ ABC ]

You can repeat each of the style-patterns as much as you like:

	--->
	==>
	=>
	~~~~~>
	..-..-..->

Note that in patterns longer than one character, the entire
pattern must be repeated e.g. all characters of the pattern must be
present. Thus:

	..-..-..->	# valid dot-dot-dash
	..-..-..>	# invalid!

	.-.-.->		# valid dot-dash
	.-.->		# invalid!

In additon to the styles, the following two directions are possible:

	 --		edge without arrow heads
	 -->		arrow at target node (end point)
	<-->		arrow on both the source and target node
			(end and start point)

Of course you can combine all directions with all styles. However,
note that edges without arrows cannot use the shortcuts for styles:

	---		# valid
	.-.-		# valid
	.-		# invalid!
	-		# invalid!
	~		# invalid!

Just remember to use at least two repititions of the full pattern
for arrow-less edges.

You can also give edges a label, either by inlining it into the style,
or by setting it via the attributes:

	[ AB ] --> { style: bold; label: foo; } [ ABC ]

	-- foo -->
	... baz ...>

	-- solid -->
	== double ==>
	.. dotted ..>
	~~ wave ~~>

	-  dashed - >
	=  double-dash = >
	.- dot-dash .->
	..- dot-dot-dash ..->

Note that the two patterns on the left and right of the label must be
the same, and that there is a space between the left pattern and the
label, as well as the label and the right pattern.

You may use inline label only with edges that have an arrow. Thus:

	<-- label -->	# valid
	-- label -->	# valid

	-- label --	# invalid!

To use a label with an edge without arrow heads, use the attributes:

	[ AB ] -- { label: edgelabel; } [ CD ]

=back

Please see the manual for a full description of the syntax rules.

=head2 Output

The output will be a L<Graph::Easy|Graph::Easy> object, see there for what you
can do with it.

=head1 EXAMPLES

See L<Graph::Easy> for an extensive list of examples.

=head1 METHODS

C<Graph::Easy::Parser> supports the following methods:

=head2 new()

	use Graph::Easy::Parser;
	my $parser = Graph::Easy::Parser->new();

Creates a new parser object.

=head2 reset()

	$parser->reset();

Reset the status of the parser, clear errors etc.

=head2 from_text()

	my $graph = $parser->from_text( $text );

Create a L<Graph::Easy|Graph::Easy> object from the textual description in C<$text>.

Returns undef for error, you can find out what the error was
with L<error()>.

This method will reset any previous error, and thus the C<$parser> object
can be re-used to parse different texts by just calling C<from_text()>
multiple times.

=head2 from_file()

	my $graph = $parser->from_file( $filename );
	my $graph = Graph::Easy::Parser->from_file( $filename );

Creates a L<Graph::Easy|Graph::Easy> object from the textual description in the file
C<$filename>.

The second calling style will create a temporary Graph::Easy::Parser object,
parse the file and return the resulting Graph::Easy object.

Returns undef for error, you can find out what the error was
with L<error()> when using the first calling style.

=head2 error()

	my $error = $parser->error();

Returns the last error, or the empty string if no error occured.

=head2 parse_error()

	$parser->parse_error( $msg_nr, @params);

Sets an error message from a message number and replaces embedded
templates like C<##param1##> with the passed parameters.

=head2 _parse_attributes()

	my $attributes = $parser->_parse_attributes( $txt );
  
B<Internal usage only>. Takes a text like this:

	attribute: value;  attribute2 : value2;

and returns a hash with the attributes.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
