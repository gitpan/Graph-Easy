#############################################################################
# output the graph in dot-format text
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::As_graphviz;

$VERSION = '0.11';

#############################################################################
#############################################################################

package Graph::Easy;

use strict;

my $remap = {
  'node' => {
    'fill' => 'fillcolor',
    'background' => undef,   # need a way to simulate that on non-rect nodes
    'title' => 'tooltip',
    'color' => 'fontcolor',
    'border-color' => 'color',
    'border-style' => \&_graphviz_remap_border_style,
    'border-width' => undef,
    'border' => undef,
    'shape' => \&_graphviz_remap_node_shape,
    'point-style' => undef,
    'rotate' => \&_graphviz_remap_node_rotate,
    },
  'edge' => {
    'title' => 'tooltip',
    'background' => undef,
    'border' => undef,
    'border-style' => undef,
    'style' => \&_graphviz_remap_edge_style,
    'arrow-style' => \&_graphviz_remap_arrow_style,
    'label-color' => \&_graphviz_remap_label_color,
    'start' => \&_graphviz_remap_port,
    'end' => \&_graphviz_remap_port,
    },
  'graph' => {
    'fill' => 'bgcolor',
    'background' => undef,
    'flow' => undef,
    'output' => undef,
    'label-pos' => 'labelloc',
    'gid' => 'undef',
    'border-color' => 'color',
    'border-style' => \&_graphviz_remap_border_style,
    'border-width' => undef,
    },
  'group' => {
    'border-color' => undef,
    'border-style' => undef,
    'border-width' => undef,
    'background' => undef,
    },
  'all' => {
    class => undef,
    'link' => \&_graphviz_remap_link,
    'linkbase' => undef,
    'autolink' => undef,
    'autotitle' => undef,
    'text-style' => undef,
    'font-size' => \&_graphviz_remap_fontsize,
    },
  'always' => {
    'link' => 1,
    'label_pos' => 1,
    'label-color' => 1,
    'rotate' => 1,
    },
  };

sub _graphviz_remap_edge_style
  {
  my ($self, $name, $style) = @_;

  # valid styles are: solid dashed dotted bold invis

  $style = 'solid' unless defined $style;

  $style = 'dotted' if $style =~ /^dot-/;	# dot-dash, dot-dot-dash
  $style = 'dashed' if $style =~ /^double-/;	# double-dash
  $style = 'dotted' if $style =~ /^wave/;	# wave
  $style = 'bold' if $style eq 'double';	# double

  # XXX TODO: These should be (3, 0.5em, 1em) instead of 3,7,14
  $style = 'setlinewidth(3)' if $style =~ /^bold-dash/;
  $style = 'setlinewidth(7)' if $style =~ /^broad/;
  $style = 'setlinewidth(14)' if $style =~ /^wide/;
  
  return (undef, undef) if $style eq 'solid';	# default style can be suppressed

  ($name, $style);
  }

sub _graphviz_remap_node_rotate
  {
  my ($graph, $name, $angle, $self) = @_;

  # do this only for objects, not classes 
  return (undef,undef) unless ref($self) && defined $angle;

  # despite what the manual says, dot rotates counter-clockwise, so fix that
  $angle = 360 - $angle;

  ('orientation', $angle);
  }

sub _graphviz_remap_port
  {
  my ($graph, $name, $port, $self) = @_;

  # do this only for objects, not classes 
  return (undef,undef) unless ref($self) && defined $port;

  $port = substr($port,0,1);	# "south,0" => "s"

  my $n = 'tailport'; $n = 'headport' if $name eq 'start';

  ($n, $port);
  }

sub _graphviz_remap_fontsize
  {
  # make sure the fontsize is in pixel or percent
  my ($self, $name, $style) = @_;

  # XXX TODO: This be 1 em
  my $fs = 11;

  if ($style =~ /^([\d.]+)em\z/)
    {
    $fs = $1 * 11;
    }
  elsif ($style =~ /^([\d.]+)%\z/)
    {
    $fs = ($1 / 100) * 11;
    }
#  # this is discouraged:
#  elsif ($style =~ /^([\d.]+)px\z/)
#    {
#    $fs = $1;
#    }
  else
    {
    require Carp;
    Carp::confess ("Illegal font-size '$fs'");
    }

  # font-size => fontsize
  ('fontsize', $fs);
  }

sub _graphviz_remap_border_style
  {
  my ($self, $name, $style) = @_;

  # valid styles are: solid dashed dotted bold invis

  $style = 'dotted' if $style =~ /^dot-/;	# dot-dash, dot-dot-dash
  $style = 'dashed' if $style =~ /^double-/;	# double-dash
  $style = 'dotted' if $style =~ /^wave/;	# wave

  # border-style double will be handled extra with peripheries=2 later
  $style = 'solid' if $style eq 'double';

  # XXX TODO: These should be (3, 0.5em, 1em) instead of 3,7,14
  $style = 'setlinewidth(3)' if $style =~ /^bold/;
  $style = 'setlinewidth(7)' if $style =~ /^broad/;
  $style = 'setlinewidth(14)' if $style =~ /^wide/;
  
  # default style can be suppressed
  return (undef, undef) if $style =~ /^(solid|none)\z/;

  ('style', $style);
  }

sub _graphviz_remap_link
  {
  my ($graph, $name, $l, $self) = @_;

  # do this only for objects, not classes 
  return (undef,undef) unless ref($self);

  my $link = $self->link();
  
  ('URL', $link);
  }

sub _graphviz_remap_label_color
  {
  my ($graph, $name, $color, $self) = @_;

  # do this only for objects, not classes 
  return (undef,undef) unless ref($self);
  
  # no label => no color nec.
  return (undef, $color) if ($self->label()||'') eq '';

  # the label color falls back to the edge color
  $color = $self->attribute('color') unless defined $color;

  ('fontcolor', $color);
  }

sub _graphviz_remap_node_shape
  {
  my ($self, $name, $style) = @_;

  # valid styles are: solid dashed dotted bold invis

  my $s = $style;
  $s = 'plaintext' if $style =~ /^(invisible|none)/;

  ($name, $s);
  }

sub _graphviz_remap_arrow_style
  {
  my ($self, $name, $style) = @_;

  my $s = 'normal';
 
  $s = $style if $style =~ /^(none|open)\z/;
  $s = 'empty' if $style eq 'closed';

  my $n = 'arrowhead';
  $n = 'arrowtail' if $self->{_flip_edges};

  ($n, $s);
  }

sub _as_graphviz
  {
  my ($self) = @_;

  # convert the graph to a textual representation
  # does not need a layout() beforehand!

  # generate the class attributes first
  my $name = "GRAPH_" . ($self->{gid} || '0');

  my $txt = "digraph $name {\n\n" .
            "  // Generated by Graph::Easy $Graph::Easy::VERSION" .
	    " at " . scalar localtime() . "\n\n";


  my $flow = $self->attribute('graph','flow'); $flow = 90 unless defined $flow;

  # for LR, BT layouts
  $self->{_flip_edges} = 0;
  $self->{_flip_edges} = 1 if $flow == 270 || $flow == 0;

  my $atts =  $self->{att};
  for my $class (sort keys %$atts)
    {
    next if $class =~ /\./;		# skip subclasses

    my $out = $self->_remap_attributes( $class, $atts->{$class}, $remap, 'noquote');

    # per default, our nodes are rectangular, white, filled boxes
    if ($class eq 'node')
      {
      $out->{shape} = 'box' unless $out->{shape}; 
      $out->{style} = 'filled' unless $out->{style};
      $out->{fontsize} = '11' unless $out->{fontsize};
      $out->{fillcolor} = 'white' unless $out->{fillcolor};
      }
    elsif ($class eq 'graph')
      {
      $out->{rankdir} = 'LR' if $flow == 90 || $flow == 270;
      $out->{labelloc} = 'top' if defined $out->{label} && !defined $out->{labelloc};
      }
    elsif ($class eq 'edge')
      {
      $out->{dir} = 'back' if $flow == 270 || $flow == 0;
      my ($name,$style) = $self->_graphviz_remap_arrow_style('arrow-style',
        $self->attribute('edge','arrow-style') || 'open' );
      $out->{$name} = $style;
      }

    my $att = '';
    for my $atr (keys %$out)
      {
      my $v = $out->{$atr};
      $v = '"' . $v . '"' if $v !~ /^[a-z0-9A-Z]+\z/;	# quote if nec.
      $att .= "  $atr=$v,\n";
      }

    $att =~ s/,\n\z/ /;			# remove last ","
    if ($att ne '')
      {
      # the following makes short, single definitions to fit on one line
      if ($att !~ /\n.*\n/ && length($att) < 40)
        {
        $att =~ s/\n/ /; $att =~ s/( )+/ /g;
        }
      else
        {
        $att =~ s/\n/\n  /g;
        $att = "\n  $att";
        }
      $txt .= "  $class [$att];\n";
      }
    }

  $txt .= "\n" if $txt ne '';		# insert newline

  ###########################################################################
  # output groups as subgraphs

  # insert the edges into the proper group
  $self->_edges_into_groups() if $self->groups() > 0;

  my $indent = '    ';
  for my $group (sort { $a->{name} cmp $b->{name} } values %{$self->{groups}})
    {
    # quote special chars in group name
    my $name = $group->{name}; $name =~ s/([\[\]\(\)\{\}\#"])/\\$1/g;

    # output group attributes first
    $txt .= "  subgraph \"cluster$group->{id}\" {\n${indent}label=\"$name\";\n";
    $txt .= $indent. "labeljust=l; style=filled;\n";
    my $bg = $group->attribute('fill') || '#a0d0ff';
    $txt .= $indent. "fillcolor=\"$bg\";\n";
    my $fg = $group->attribute('border-color') || 'black';
    $txt .= $indent. "color=\"$fg\";\n";

    my ($f,$fs) = $self->_graphviz_remap_fontsize('font-size',$group->attribute('font-size'));
    $fs *= 1.2; $txt .= $indent. "$f=\"$fs\";\n";

    # XXX TODO:
    # writing both bgcolor and color makes dot ignore the background :(
#    my $b = $group->attribute('border-color') || 'black';
#    $txt .= $indent. "color=\"$b\";\n";

    # output node attributes first
    for my $n (values %{$group->{nodes}})
      {
      my $att = $n->attributes_as_graphviz();
      if ($att ne '')
	{
	$n->{_p} = undef;			# mark as processed
	$txt .= $indent . $n->as_graphviz_txt() . $att . "\n";
	}
#      print STDERR "# in group $name: $n->{name}\n";
      }

    # output node connections in this group
    for my $e (values %{$group->{edges}})
      {
#      print STDERR "# at edge $e->id}\n";
      my $edge_att = $e->attributes_as_graphviz();
      my $other = $e->{to}->as_graphviz_txt();
      my $first = $e->{from}->as_graphviz_txt();
      ($other,$first) = ($first,$other) if $self->{_flip_edges};
      $txt .= "$indent$first -> $other$edge_att\n";
      $e->{_p} = undef;				# mark as processed
      }

    $txt .= "  }\n";
    }

  my $count = 0;
  # output nodes with attributes first, sorted by their name
  for my $n (sort { $a->{name} cmp $b->{name} } values %{$self->{nodes}})
    {
    next if exists $n->{_p};
    my $att = $n->attributes_as_graphviz();
    if ($att ne '')
      {
      $n->{_p} = undef;			# mark as processed
      $count++;
      $txt .= "  " . $n->as_graphviz_txt() . $att . "\n"; 
      }
    }
 
  $txt .= "\n" if $count > 0;		# insert a newline

  my @nodes = $self->sorted_nodes();

  foreach my $n (@nodes)
    {
    my @out = $n->successors();
    my $first = $n->as_graphviz_txt();
    if ((@out == 0) && ( (scalar $n->predecessors() || 0) == 0))
      {
      # single node without any connections (unless already output)
      $txt .= "  " . $first . "\n" unless exists $n->{_p};
      }
    # for all outgoing connections
    foreach my $other (reverse @out)
      {
      # in case there is more than one edge going from N to O
      my @edges = $n->edges_to($other);
      foreach my $e (@edges)
        {
        next if exists $e->{_p};
        my $edge_att = $e->attributes_as_graphviz();
        if ($self->{_flip_edges})
          {
          $txt .= "  " . $other->as_graphviz_txt() . " -> $first$edge_att\n";
          }
        else
          {
          $txt .= "  " . $first . " -> " . $other->as_graphviz_txt() . "$edge_att\n";
          }
        }
      }
    }

  for my $n ( values %{$self->{nodes}}, values %{$self->{edges}})
    {
    delete $n->{_p};
    }

  $txt .  "\n}\n";	# close the graph again
  }

package Graph::Easy::Node;

sub attributes_as_graphviz
  {
  # return the attributes of this node as text description
  my $self = shift;

  my $att = '';
  my $class = $self->class();

  my $g = $self->{graph} || 'Graph::Easy';

  # if we are in a subclass, also add attributes of that class
  my $a = $self->{att};

  if ($class =~ /\./)
    {
    $a = {};
    # copy own attributes
    my $att = $self->{att};
    for my $k (keys %$att)
      {
      $a->{$k} = $att->{$k};
      }
    # copy class attributes
    $att = $g->{att}->{$class};
    for my $k (keys %$att)
      {
      $a->{$k} = $att->{$k};
      }
    }
  $a = $g->_remap_attributes( $self, $a, $remap, 'noquote');

  # bidirectional and undirected edges
  if ($self->{bidirectional})
    {
    delete $a->{dir};
    my ($n,$s) = Graph::Easy::_graphviz_remap_arrow_style(
	$self,'', $self->attribute('arrow-style') || 'open');
    $a->{arrowhead} = $s; 
    $a->{arrowtail} = $s; 
    }
  if ($self->{undirected})
    {
    delete $a->{dir};
    $a->{arrowhead} = 'none'; 
    $a->{arrowtail} = 'none'; 
    }

  # border-style: double:
  my $style = $self->attribute('border-style') || 'solid';
  $a->{peripheries} = 2 if $style =~ /^double/;

  # For nodes with shape plaintext, set the fillcolor to the background of
  # the graph/group
  if ($class =~ /node/ && exists $a->{shape} && $a->{shape} eq 'plaintext')
    {
    my $p = $self->parent();
    $a->{fillcolor} = $p->attribute('fill') || 'white';
    }

  # create the attributes as text:
  for my $atr (sort keys %$a)
    {
    my $v = $a->{$atr};
    $v =~ s/"/\\"/g;		# '2"' => '2\"'
    $v = '"' . $v . '"' if $v !~ /^[a-z0-9A-Z]+\z/
	|| $atr eq 'URL';	# quote if nec.
    $att .= "$atr=$v, ";
    }
  $att =~ s/,\s$//;             # remove last ","

  # generate attribute text if nec.
  $att = ' [ ' . $att . ' ]' if $att ne '';

  $att;
  }

sub as_graphviz_txt
  {
  # return the node itself (w/o attributes) as graphviz representation
  my $self = shift;

  my $name = $self->{name};

  # escape special chars in name (including doublequote!)
  $name =~ s/([\[\]\(\)\{\}\#"])/\\$1/g;

  # quote if necessary:
  # 2, A, A2, "2A", "2 A" etc
  $name = '"' . $name . '"' if $name !~ /^([a-zA-Z_]+|\d+)\z/ ||
 	$name =~ /^(subgraph|graph|node|edge|strict)\z/i;	# reserved keyword

  $name;
  }
 
1;
__END__

=head1 NAME

Graph::Easy::As_graphviz - Generate graphviz description from graph object

=head1 SYNOPSIS

	use Graph::Easy;
	
	my $graph = Graph::Easy->new();

	my $bonn = Graph::Easy::Node->new(
		name => 'Bonn',
	);
	my $berlin = Graph::Easy::Node->new(
		name => 'Berlin',
	);

	$graph->add_edge ($bonn, $berlin);

	print $graph->as_graphviz();

	# prints something like:

	# digraph NAME { Bonn -> Berlin }

=head1 DESCRIPTION

C<Graph::Easy::As_graphviz> contains just the code for converting a
L<Graph::Easy|Graph::Easy> object to a textual description suitable for
feeding it to graphviz.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
