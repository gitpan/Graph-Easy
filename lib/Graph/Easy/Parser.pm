#############################################################################
# Parse text definition into a Graph::Easy object
#
# (c) by Tels 2004 - 2006.
#############################################################################

package Graph::Easy::Parser;

use Graph::Easy;
use Graph::Easy::Base;

$VERSION = '0.22';
@ISA = qw/Graph::Easy::Base/;

use strict;

sub NO_MULTIPLES () { 1; }

sub _init
  {
  my ($self,$args) = @_;

  $self->{error} = '';
  $self->{debug} = 0;
  
  foreach my $k (keys %$args)
    {
    if ($k !~ /^(debug)\z/)
      {
      require Carp;
      Carp::confess ("Invalid argument '$k' passed to Graph::Easy::Parser->new()");
      }
    $self->{$k} = $args->{$k};
    }

  # setup default class names for generated objects
  $self->{use_class} = {
    edge => 'Graph::Easy::Edge',
    group => 'Graph::Easy::Group',
    graph => 'Graph::Easy',
    node => 'Graph::Easy::Node',
  };

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

  $self->{clusters} = {};		# cluster names we already created

  Graph::Easy::Base::_reset_id();	# start with the same set of IDs

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
    binmode PARSER_FILE, ':utf8' or die ("binmode '$file', 'utf8' failed: $!");
    $doc = <PARSER_FILE>;		# read entire file
    close PARSER_FILE;
    }

  $self->from_text($doc);
  }

sub use_class
  {
  # use the provided class for generating objects of the type $object
  my ($self, $object, $class) = @_;

  $self->_croak("Expected one of node, edge, group or graph, but got $object")
    unless $object =~ /^(node|group|graph|edge)\z/;

  $self->{use_class}->{$object} = $class;

  $self;  
  }

sub from_text
  {
  my ($self,$txt) = @_;

  $self = $self->new() unless ref $self;

  $self->reset();

  $self->{graph} = $self->{use_class}->{graph}->new( { debug => $self->{debug}, strict => 0 } );
  my $graph = $self->{graph};
 
  my $uc = $self->{use_class};

  # instruct the graph to use the custom classes, too
  for my $o (keys %$uc)
    {
    $graph->use_class($o, $uc->{$o}) unless $o eq 'graph';	# group, node and edge
    }

  return $graph if !defined $txt || $txt =~ /^\s*\z/;		# empty text?

  my @lines = split /\n/, $txt;

  my $e = $uc->{edge};

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

  my @left_stack = ();	# stack for the left side for "[]->[],[],..."
  my $left_edge = undef;

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

      # convert tabs to spaces (the regexps don't expect tabs)
      $curline =~ s/\t/ /g;
      }
    
    chomp($curline);

    my $line = $backbuffer . $curline;

    # convert #808080 into \#808080, and "#fff" into "\#fff"
    $line =~ s/:\s*(#([a-fA-F0-9]{6}|[a-fA-F0-9]{3}))/: \\$1/g;

    # remove comment at end of line (but leave \# alone):
    $line =~ s/[^\\]#.*//;

    # remove white space at start/end
    $line =~ s/^\s+//;
    $line =~ s/\s+\z//;

#    print STDERR "# at line '$line' stack: ", join(",", @stack),"\n";

    # node { color: red; } or 
    # node.graph { color: red; }
    if ($line =~ /^(node|graph|edge|group)(\.\w+)?$qr_attr/)
      {
      my $type = $1 || '';
      my $class = $2 || '';
      my $att = $self->_parse_attributes($3 || '', $type, NO_MULTIPLES );

      return undef unless defined $att;		# error in attributes?

      $graph->set_attributes ( "$type$class", $att);

      # forget stacks
      @stack = ();
      $left_edge = undef;
      @left_stack = ();

      # purge parsed part from line
      $line =~ s/^(node|graph|edge|group)(\.\w+)?$qr_attr//;
      }
    # ( group start [
    elsif ($line =~ /^$qr_group_start/)
      {
      my $gn = $1; $gn = '' unless defined $gn;		# group name

      # unquote special chars
      $gn =~ s/\\([\[\(\{\}\]\)#\|])/$1/g;

      push @group_stack, $graph->add_group($gn);

      $line =~ s/^$qr_group_start/\[/;
      }
    # ) # group end
    elsif ($line =~ /^$qr_group_end$qr_oatr/)
      {

      $self->parse_error(0) and return undef if @group_stack == 0;

      my $group = pop @group_stack;

      my $a1 = $self->_parse_attributes($1||'', 'group', NO_MULTIPLES);
      return undef if $self->{error};

      $group->set_attributes($a1);

      # the new left side is the group itself
      @stack = ($group);

      $line =~ s/^$qr_group_end$qr_oatr//;
      }
    # { attributes }
    elsif ($line =~ /^$qr_attr/)
      {
      # This happens in the case of "[ Test ]\n { ... }", the node is consumed
      # first, and the attributes are left over:

      my ($a, $max_idx) = $self->_parse_attributes($1||'');

      if (@stack == 0)
        {
        # error, no object that the attributes can apply to
        $self->parse_error(3);
        return undef;
        }

      return undef if $self->{error};

      if ($max_idx != 1)
	{
#	print STDERR "max_idx = $max_idx, stack contains ", join (" , ", @stack),"\n";
	my $i = 0;
	# XXX TODO: what on "[A], [ B|C ] { fill: red|green; }" ?
        for my $n (@stack)
	  {
	  $n->set_attributes($a, $i++);
	  }
	}
      else
	{
        # set attributes on all nodes on stack
        for my $n (@stack) { $n->set_attributes($a); }
	}

      # remove parsed part
      $line =~ s/^$qr_attr//;
      }
    # "[ A ] { ... }"
    elsif ($line =~ /^$qr_node$qr_oatr/)
      {
      my $n1 = $1;
      my $a1 = $self->_parse_attributes($2||'');
      return undef if $self->{error};

      @stack = $self->_new_node ($graph, $n1, \@group_stack, $a1);

      # forget left stack
      $left_edge = undef;
      @left_stack = ();

      $line =~ s/^$qr_node$qr_oatr//;
      }
    # , [ Berlin ] { color: red; }
    elsif ($line =~ /^$qr_comma$qr_node$qr_oatr/)
      {
      my $n1 = $1;
      my $a1 = $self->_parse_attributes($2||'');
      return undef if $self->{error};

      push @stack, $self->_new_node ($graph, $n1, \@group_stack, $a1, \@stack);

      if (defined $left_edge)
	{
	my ($style, $edge_label, $edge_atr, $edge_bd, $edge_un) = @$left_edge;

	foreach my $node (@left_stack)
          {
	  my $edge = $e->new( { style => $style, name => $edge_label } );
	  $edge->set_attributes($edge_atr);
	  # "<--->": bidirectional
	  $edge->bidirectional(1) if $edge_bd;
	  $edge->undirected(1) if $edge_un;
	  $graph->add_edge ( $node, $stack[-1], $edge );
          }
	}

      $line =~ s/^$qr_comma$qr_node$qr_oatr//;
      }
    # Things like "[ Node ]" will be consumed before, so we do not need a case
    # for "[ A ] -> [ B ]":
    # node chain continued like "-> { ... } [ Kassel ] { ... }"
    elsif (@stack != 0 && $line =~ /^$qr_edge$qr_oatr$qr_node$qr_oatr/)
      {
      my $eg = $1;					# entire edge ("-- label -->" etc)

      my $edge_bd = $2 || $4;				# bidirectional edge ('<') ?
      my $edge_un = 0;					# undirected edge?
      $edge_un = 1 if !defined $2 && !defined $5;

      # optional edge label
      my $edge_label = $7; $edge_label = '' unless defined $edge_label;
      my $ed = $3 || $5 || $1;				# edge pattern/style ("--")

      my $edge_atr = $11 || '';				# save edge attributes

      my $n = $12;					# node name
      my $a1 = $self->_parse_attributes($13||'');	# node attributes
      return undef if $self->{error};

      $edge_atr = $self->_parse_attributes($edge_atr, 'edge');
      return undef if $self->{error};

      # strip trailing spaces
      $edge_label =~ s/\s+\z//;

      # the right side node(s) (multiple in case of autosplit)
      my @nodes_b = $self->_new_node ($graph, $n, \@group_stack, $a1);

      my $style = $self->_link_lists( \@stack, \@nodes_b,
	$ed, $edge_label, $edge_atr, $edge_bd, $edge_un);

      # remember the left side
      $left_edge = [ $style, $edge_label, $edge_atr, $edge_bd, $edge_un ];
      @left_stack = @stack;

      # forget stack and remember the right side instead
      @stack = @nodes_b;

      $line =~ s/^$qr_edge$qr_oatr$qr_node$qr_oatr//;
      }
    # Things like ")" will be consumed before, so we do not need a case
    # for ") -> { ... } ( Group [ B ]":
    # edge to a group like "-> { ... } ( Group ["
    elsif (@stack != 0 && $line =~ /^$qr_edge$qr_oatr$qr_group_start/)
      {
      my $eg = $1;					# entire edge ("-- label -->" etc)

      my $edge_bd = $2 || $4;				# bidirectional edge ('<') ?
      my $edge_un = 0;					# undirected edge?
      $edge_un = 1 if !defined $2 && !defined $5;

      # optional edge label
      my $edge_label = $7; $edge_label = '' unless defined $edge_label;
      my $ed = $3 || $5 || $1;				# edge pattern/style ("--")

      my $edge_atr = $11 || '';				# save edge attributes

      my $gn = $12; $gn = '' unless defined $gn;	# group name

      $edge_atr = $self->_parse_attributes($edge_atr, 'edge');
      return undef if $self->{error};

      # unquote special chars in group name
      $gn =~ s/\\([\[\(\{\}\]\)#\|])/$1/g;

      @group_stack = ( $graph->add_group( $gn) );

      # strip trailing spaces
      $edge_label =~ s/\s+\z//;

      my $style = $self->_link_lists( \@stack, \@group_stack,
	$ed, $edge_label, $edge_atr, $edge_bd, $edge_un);

      # remember the left side
      $left_edge = [ $style, $edge_label, $edge_atr, $edge_bd, $edge_un ];
      @left_stack = @stack;

      # forget stack
      @stack = ();

      $line =~ s/^$qr_edge$qr_oatr$qr_group_start/\[/;
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

  print STDERR "# Parsing done\n" if $graph->{debug};

  # turn on strict checking on returned graph
  $graph->strict(1);

  $graph;
  }

#############################################################################
# internal routines

sub _link_lists
  {
  # Given two node lists and an edge style, links each node from list
  # one to list two.
  my ($self, $left, $right, $ed, $label, $edge_atr, $edge_bd, $edge_un) = @_;

  my $graph = $self->{graph};
 
  my $style = undef;			# default is "inherit from class"
  $style = 'double-dash' if $ed =~ /^(= )+\z/; 
  $style = 'double' if $ed =~ /^=+\z/; 
  $style = 'dotted' if $ed =~ /^\.+\z/; 
  $style = 'dashed' if $ed =~ /^(- )+\z/; 
  $style = 'dot-dot-dash' if $ed =~ /^(..-)+\z/; 
  $style = 'dot-dash' if $ed =~ /^(\.-)+\z/; 
  $style = 'wave' if $ed =~ /^\~+\z/; 
  $style = 'bold' if $ed =~ /^#+\z/; 

  my $e = $self->{use_class}->{edge};

  # add edges for all nodes in the left list
  for my $node (@$left)
    {
    for my $node_b (@$right)
      {
      my $edge = $e->new( { style => $style, name => $label } );
      $edge->set_attributes($edge_atr);
      # "<--->": bidirectional
      $edge->bidirectional(1) if $edge_bd;
      $edge->undirected(1) if $edge_un;
      $graph->add_edge ( $node, $node_b, $edge );
      }
    }

  $style;
  }

sub _new_node
  {
  # Create a new node unless it doesn't already exist. If the group stack
  # contains entries, the new node appears first in this/these group(s), so
  # add it to these groups. If the newly created node contains "|", we auto
  # split it up into several nodes and cluster these together.
  my ($self, $graph, $name, $group_stack, $att, $stack) = @_;

  print STDERR "# Parser: new node '$name'\n" if $graph->{debug};

  # unquote special chars
  $name =~ s/\\([\[\(\{\}\]\)#])/$1/g;

  my $autosplit;
  my $uc = $self->{use_class};

  my @rc = ();

  if ($name =~ /^\s*\z/)
    {
    print STDERR "# Parser: Creating anon node\n" if $graph->{debug};
    # create a new anon node and add it to the graph
    my $class = $uc->{node} . '::Anon';
    my $node = $class->new();
    @rc = ( $graph->add_node($node) );
    }
  elsif ($name =~ /[^\\]\|/)
    {
    $autosplit = 1;

    # build base name: "A|B |C||D" => "ABCD"
    my $base_name = $name; $base_name =~ s/\s*\|\|?\s*//g;

    # use user-provided base name
    $base_name = $att->{basename} if exists $att->{basename};

    # strip trailing/leading spaces on basename
    $base_name =~ s/\s+\z//;
    $base_name =~ s/^\s+//;

    my $first_in_row;			# for relative placement of new row

    # first one gets: "ABC", second one "ABC.1" and so on
    # Try to find a unique cluster name in case some one get's creative and names the
    # last part "-1":

    # does work without cluster-id?
    if (exists $self->{clusters}->{$base_name})
      {
      my $g = 1;
      while ($g == 1)
        {
        my $base_try = $base_name; $base_try .= '-' . $self->{cluster_id} if $self->{cluster_id};
        last if !exists $self->{clusters}->{$base_try};
        $self->{cluster_id}++;
        }
      $base_name .= '-' . $self->{cluster_id} if $self->{cluster_id}; $self->{cluster_id}++;
      }

    print STDERR "# Parser: Autosplitting node with basename '$base_name'\n" if $graph->{debug};

    $self->{clusters}->{$base_name} = undef;	# reserve this name

    my $x = 0; my $y = 0; my $idx = 0;
    my $remaining = $name; my $sep; my $last_sep = '';
    my $add = 0;
    while ($remaining ne '')
      {
      # XXX TODO: parsing of "\|" and "|" in one node
      $remaining =~ s/^([^\|]*)(\|\|?|\z)//;
      my $part = $1 || ' ';
      $sep = $2;

      # fix [|G|] to have one empty part as last part
      if ($add == 0 && $remaining eq '' && $sep =~ /\|\|?/)
        {
        $add++;				# only do it once
        $remaining .= '|' 
        }

      my $class = $uc->{node};
      if ($part eq ' ')
        {
        # create an empty node with no border
        $class .= "::Empty";
        }
      elsif ($part =~ /^0x20{2,}\z/)
        {
        # create an empty node with border
        $part = ' ';
        }
      else
        {
        $part =~ s/^\s+//;	# rem spaces at front
        $part =~ s/\s+\z//;	# rem spaces at end
        }

      my $node_name = "$base_name.$idx";

      if ($graph->{debug})
	{
        my $empty = '';
        $empty = ' empty' if $class ne $self->{use_class}->{node};
        print STDERR "# Parser:  Creating$empty autosplit part '$part'\n" if $graph->{debug};
	}

      # if it doesn't exist, add it, otherwise retrieve node object to $node
      if ($class =~ /::Empty/)
        {
        my $node = $graph->node($node_name);
        if (!defined $node)
	  {
	  # create node object from the correct class
	  $node = $class->new($node_name);
          $graph->add_node($node);
	  }
        }

      my $node = $graph->add_node($node_name);
      $node->{autosplit_label} = $part;

      push @rc, $node;
      if (@rc == 1)
        {
        # for correct as_txt output
        $node->{autosplit} = $name;
        $node->{autosplit} =~ s/\s+\z//;	# strip trailing spaces
        $node->{autosplit} =~ s/^\s+//;		# strip leading spaces
        $node->set_attribute('basename', $att->{basename}) if defined $att->{basename};
	$first_in_row = $node;
        }
      else
        {
	# second, third etc get previous as origin
        my ($sx,$sy) = (1,0);
	my $origin = $rc[-2];
        if ($last_sep eq '||')
          {
	  ($sx,$sy) = (0,1); $origin = $first_in_row;
          $first_in_row = $node;
          } 
        $node->relative_to($origin,$sx,$sy);

	# suppress as_txt output for other parts
        $node->{autosplit} = undef;
        }	
      # nec. for border-collapse
      $node->{autosplit_xy} = "$x,$y";

      $idx++;						# next node ID
      $last_sep = $sep;
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
    print STDERR "# Parser: Creating normal node\n" if $graph->{debug};

    # strip trailing and leading spaces
    $name =~ s/\s+\z//; 
    $name =~ s/^\s+//; 

    # collapse multiple spaces
    $name =~ s/\s+/ /g;

    # unquote \|
    $name =~ s/\\\|/\|/g;

    @rc = ( $graph->add_node($name) );		# add unless exists
    }

  $self->parse_error(5) if exists $att->{basename} && !$autosplit;

  my $b = $att->{basename};
  delete $att->{basename};

  # on a node list "[A],[B] { ... }" set attributes on all nodes
  # encountered so far, too:
  if (defined $stack)
    {
    for my $node (@$stack)
      {
      $node->set_attributes ($att, 0);
      }
    }
  my $index = 0;
  for my $node (@rc)
    {
    $node->add_to_group($group_stack->[-1]) if @$group_stack != 0;

    $node->set_attributes ($att, $index);
    $index++;
    }
  
  $att->{basename} = $b if defined $b;

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
  qr/(\s*\{[^\}]+?\})?/;
  }

sub _match_node
  {
  # return a regexp that matches something like " [ bonn ]" and returns
  # the inner text without the [] (might leave some spaces)

  #        v--- for empty nodes
  #         v-- normal nodes  
  qr/\s*\[(|[^\]]*?[^\\])\]/;
  }

sub _match_group_start
  {
  # return a regexp that matches something like " ( group [" and returns
  # the text between "(" and "["
  qr/\s*\(\s*([^\[]*?)\s*\[/;
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
       ([^>\[\{]*?)				 # many label chars (but not ">"!)
       (\s+\5)>				 # a space and pattern before ">"
     |					# undirected edge (without arrows and label)
       (\.\.-|\.-)+			 # pattern (style) of edge (at least once)
     |
       (=\s|=|-\s|-|\.|~){2,}		 # these at least two times
     )
     /x;
   }

sub _parse_attributes
  {
  # takes a text like "attribute: value;  attribute2 : value2;" and
  # Returns a hash with the attributes. $class defaults to 'node'.
  # In list context, also returns a flag that is maxlevel-1 when one
  # of the attributes was a multiple one (aka 2 for "red|green", 1 for "red");
  my ($self, $text, $class, $no_multiples) = @_;

  $class ||= 'node';
  my $att = {};

  $text =~ s/^\s*\{\s*//;	# remove left-over "{" and spaces
  $text =~ s/\s*\}\s*\z//;	# remove left-over "}" and spaces

  my @atts = split /\s*;\s*/, $text;

  my $multiples = 0;

  foreach my $a (@atts)
    {
    $self->error ("Error in attribute: '$a' doesn't look valid to me.")
      and return undef 
    unless ($a =~ /^\s*([^:]+?)\s*:\s*(.+?)\s*\z/);	# "name: value"

    my ($name, $val) = ($1,$2);

    $val =~ s/\\#/#/g;					# unquote \#

    my $v = Graph::Easy->valid_attribute($name,$val,$class);

    my $rc = 2;			# invaid attribute value
    if (ref($v) eq 'ARRAY' && @$v == 0)
      {
      $rc = 1;			# invalid attribute name
      $v = undef;
      }
    $multiples = scalar @$v if ref($v) eq 'ARRAY';

    return $self->parse_error(4,$val,$name,$class), return
      if $no_multiples && $multiples;			# | and no multiples
							# => error

    return $self->parse_error($rc,$val,$name,$class), return
      unless defined $v;				# stop on error

    $att->{$name} = $v;
    }

  return $att unless wantarray;

  ($att, $multiples || 1);
  }

sub parse_error
  {
  # take a msg number, plus params, and throws an exception
  my $self = shift;
  my $msg_nr = shift;

  # XXX TODO: should really use the msg nr mapping
  my $msg = "Found unexpected group end at line $self->{line_nr}";			# 0
  $msg = "Error in attribute: '##param2##' is not a valid attribute name for a ##param3##"			# 1
        if $msg_nr == 1;
  $msg = "Error in attribute: '##param1##' is not a valid ##param2## for a ##param3##"
	if $msg_nr == 2;								# 2
  $msg = "Error: Found attributes, but expected group or node start"
	if $msg_nr == 3;								# 3
  $msg = "Error in attribute: multi-attribute '##param1##' not allowed here"
	if $msg_nr == 4;								# 4
  $msg = "Error in attribute: basename not allowed for non-autosplit nodes"
	if $msg_nr == 5;								# 5

  my $i = 1;
  foreach my $p (@_)
    {
    $msg =~ s/##param$i##/$p/g; $i++;
    }

  $self->error($msg . ' at line ' . $self->{line_nr});
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

The input consists of text describing the graph, encoded in UTF-8.

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

The output will be a L<Graph::Easy|Graph::Easy> object (unless overrriden
with C<use_class()>), see the documentation for Graph::Easy what you can do
with it.

=head1 EXAMPLES

See L<Graph::Easy> for an extensive list of examples.

=head1 METHODS

C<Graph::Easy::Parser> supports the following methods:

=head2 new()

	use Graph::Easy::Parser;
	my $parser = Graph::Easy::Parser->new();

Creates a new parser object. The only valid parameter is debug,
when set to true it will enable debug output to STDERR:

	my $parser = Graph::Easy::Parser->new( debug => 1 );
	$parser->from_text('[A] -> [ B ]');

=head2 reset()

	$parser->reset();

Reset the status of the parser, clear errors etc. Automatically called
when you call any of the C<from_XXX()> methods below.

=head2 use_class()

	$parser->use_class('node', 'Graph::Easy::MyNode');

Override the class to be used to constructs objects while parsing. The
first parameter can be one of the following:

	node
	edge
	graph
	group

The second parameter should be a class that is a subclass of the
appropriate base class:

	package Graph::Easy::MyNode;

	use Graph::Easy::Node;
	use base qw/Graph::Easy::Node/;

	# override here methods for your node class

	######################################################
	# when overriding nodes, we also need ::Anon

	package Graph::Easy::MyNode::Anon;

	use Graph::Easy::MyNode;
	use base qw/Graph::Easy::MyNode/;
	use base qw/Graph::Easy::Node::Anon/;

	######################################################
	# and :::Empty

	package Graph::Easy::MyNode::Empty;

	use Graph::Easy::MyNode;
	use base qw/Graph::Easy::MyNode/;

	######################################################
	package main;
	
	use Graph::Easy::Parser;
	use Graph::Easy;

	use Graph::Easy::MyNode;
	use Graph::Easy::MyNode::Anon;
	use Graph::Easy::MyNode::Empty;

	my $parser = Graph::Easy::Parser;

	$parser->use_class('node', 'Graph::Easy::MyNode');

	my $graph = $parser->from_text(...);

The object C<$graph> will now contain nodes that are of your
custom class instead of plain C<Graph::Easy::Node>.

When overriding nodes, you also should provide subclasses
for C<Graph::Easy::Node::Anon> and C<Graph::Easy::Node::Empty>,
and make these subclasses of your custom node class as shown
above. For edges, groups and graphs, you need just one subclass.

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

	my $attributes = $parser->_parse_attributes( $txt, $class );
	my ($att, $multiples) = $parser->_parse_attributes( $txt, $class );
  
B<Internal usage only>. Takes a text like this:

	attribute: value;  attribute2 : value2;

and returns a hash with the attributes.

In list context, also returns the max count of multiple attributes, e.g.
3 when it encounters something like C<< red|green|blue >>. When

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
