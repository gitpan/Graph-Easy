#############################################################################
# output the graph in dot-format text
#
# (c) by Tels 2004-2006.
#############################################################################

package Graph::Easy::As_graphviz;

$VERSION = '0.19';

#############################################################################
#############################################################################

package Graph::Easy;

use strict;

my $remap = {
  'node' => {
    'align' => undef,
    'background' => undef,   # need a way to simulate that on non-rect nodes
    'basename' => undef,
    'border-color' => 'color',
    'border-style' => \&_graphviz_remap_border_style,
    'border-width' => undef,
    'border' => undef,
    'color' => 'fontcolor',
    'fill' => 'fillcolor',
    'label' => \&_graphviz_remap_label,
    'point-style' => undef,
    'rotate' => \&_graphviz_remap_node_rotate,
    'shape' => \&_graphviz_remap_node_shape,
    'title' => 'tooltip',
    'flow' => undef,
    },
  'edge' => {
    'align' => undef,
    'arrow-style' => \&_graphviz_remap_arrow_style,
    'background' => undef,
    'border' => undef,
    'border-style' => undef,
    'color' => \&_graphviz_remap_edge_color,
    'end' => \&_graphviz_remap_port,
    'flow' => undef,
    'label-color' => \&_graphviz_remap_label_color,
    'start' => \&_graphviz_remap_port,
    'style' => \&_graphviz_remap_edge_style,
    'title' => 'tooltip',
    'minlen' => \&_graphviz_remap_edge_minlen,
    },
  'graph' => {
    'align' => \&_graphviz_remap_align,
    'background' => undef,
    'border-color' => 'color',
    'border-style' => \&_graphviz_remap_border_style,
    'border-width' => undef,
    'fill' => 'bgcolor',
    'flow' => undef,
    'gid' => 'undef',
    'label-pos' => 'labelloc',
    'output' => undef,
    },
  'group' => {
    'align' => \&_graphviz_remap_align,
    'background' => undef,
    'border-color' => 'color',
    'border-style' => \&_graphviz_remap_border_style,
    'border-width' => undef,
    'color' => 'fontcolor',
    'fill' => 'fillcolor',
    'title' => 'tooltip',
    },
  'all' => {
    class => undef,
    'autolink' => undef,
    'autotitle' => undef,
    'font-size' => \&_graphviz_remap_fontsize,
    'font' => \&_graphviz_remap_font,
    'link' => \&_graphviz_remap_link,
    'linkbase' => undef,
    'text-style' => undef,
    },
  'always' => {
    'border-style' => 1,
    'label-pos' => 1,
    'label-color' => 1,
    'link' => 1,
    'rotate' => 1,
    'color' => 1,
    },
  };

sub _graphviz_remap_align
  {
  my ($self, $name, $style) = @_;

  return (undef, undef) if $style eq 'center';

  my $s = 'l';		# $style eq 'left';
  $s = 'r' if $style eq 'right';

  ('labeljust', $s);
  }

sub _graphviz_remap_edge_minlen
  {
  my ($self, $name, $len) = @_;

  $len = int(($len + 1) / 2);
  ($name, $len);
  }

sub _graphviz_remap_edge_color
  {
  my ($self, $name, $color, $object) = @_;

  my $style = ref($object) ? 
    $object->attribute('style') : 
    $self->attribute('style','edge');
  $style = '' unless defined $style;

  $color = 'black' unless defined $color;
 
  $color = $color . ':' . $color	# 'red:red'
    if $style =~ /^double/;

  ($name, $color);
  }

sub _graphviz_remap_edge_style
  {
  my ($self, $name, $style) = @_;

  # valid output styles are: solid dashed dotted bold invis

  $style = 'solid' unless defined $style;

  $style = 'dotted' if $style =~ /^dot-/;	# dot-dash, dot-dot-dash
  $style = 'dotted' if $style =~ /^wave/;	# wave

  # double lines will be handled in the color attribute as "color:color"
  $style = 'solid' if $style eq 'double';	# double
  $style = 'dashed' if $style =~ /^double-dash/;

  $style = 'invis' if $style eq 'invisible';	# invisible

  # XXX TODO: These should be (3, 0.5em, 1em) instead of 3,7,14
  $style = 'setlinewidth(3), dashed' if $style =~ /^bold-dash/;
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
  my ($graph, $name, $side, $self) = @_;

  # do this only for objects, not classes 
  return (undef,undef) unless ref($self) && defined $side;

  # XXX TODO
  # remap relative ports (front etc) to "south" etc

  # has a specific port, aka shared a port with another edge
  return (undef, undef) if $side =~ /,/;

  $side = $graph->_flow_as_side($self->flow(),$side);

  $side = substr($side,0,1);	# "south" => "s"

  my $n = 'tailport'; $n = 'headport' if $name eq 'end';

  ($n, $side);
  }

sub _graphviz_remap_font
  {
  # Remap the font names
  my ($self, $name, $style) = @_;

  # XXX TODO: "times" => "Times.ttf" ?
  ('fontname', $style);
  }

sub _graphviz_remap_fontsize
  {
  # make sure the fontsize is in pixel or percent
  my ($self, $name, $style) = @_;

  # XXX TODO: This should be 1 em
  my $fs = '11px';

  if ($style =~ /^([\d.]+)em\z/)
    {
    $fs = $1 * 11;
    }
  elsif ($style =~ /^([\d.]+)%\z/)
    {
    $fs = ($1 / 100) * 11;
    }
  # this is discouraged:
  elsif ($style =~ /^([\d.]+)px\z/)
    {
    $fs = $1;
    }
  else
    {
    $self->_croak("Illegal font-size '$fs'");
    }

  # font-size => fontsize
  ('fontsize', $fs);
  }

sub _graphviz_remap_border_style
  {
  my ($self, $name, $style, $node) = @_;

  my $shape = '';
  $shape = ($node->attribute('shape') || '') if ref($node);
 
  # some shapes don't need a border:
  return (undef,undef) if $shape =~ /^(none|invisible|img|point)\z/;

  # valid styles are: solid dashed dotted bold invis

  $style = '' unless defined $style;

  $style = 'dotted' if $style =~ /^dot-/;	# dot-dash, dot-dot-dash
  $style = 'dashed' if $style =~ /^double-/;	# double-dash
  $style = 'dotted' if $style =~ /^wave/;	# wave

  # border-style double will be handled extra with peripheries=2 later
  $style = 'solid' if $style eq 'double';

  # XXX TODO: These should be (3, 0.5em, 1em) instead of 3,7,14
  $style = 'setlinewidth(3)' if $style =~ /^bold/;
  $style = 'setlinewidth(7)' if $style =~ /^broad/;
  $style = 'setlinewidth(14)' if $style =~ /^wide/;

  my @rc;
  if ($style eq 'none')
    {
    my $fill = 'white'; $fill = $node->color_attribute('fill') if ref($node);
    $style = 'filled'; @rc = ('color', $fill);
    }
  
  # default style can be suppressed
  return (undef, undef) if $style =~ /^(|solid)\z/ && $shape ne 'rounded';

  # for graphviz v2.4 and up
  $style = 'filled,'.$style unless $style eq 'filled';
  $style = 'rounded,'.$style if $shape eq 'rounded';

  $style =~ s/,\z//;		# "rounded," => "rounded"

  push @rc, 'style', $style;
  @rc;
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

  # red => hex
  $color = $graph->color_as_hex($color, $self->attribute('colorscheme'))
    unless $color =~ /^#/;

  ('fontcolor', $color);
  }

sub _graphviz_remap_node_shape
  {
  my ($self, $name, $style, $object) = @_;

  # img needs no shape, and rounded is handled as style
  return (undef,undef) if $style =~ /^(img|rounded)\z/;

  # valid styles are: solid dashed dotted bold invis

  my $s = $style;
  $s = 'plaintext' if $style =~ /^(invisible|none|point)\z/;

  if (ref($object))
    {
    my $border = $object->attribute('border-style') || '';
    $s = 'plaintext' if $border eq 'none';
    }

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

sub _graphviz_remap_label
  {
  my ($self, $name, $style, $node) = @_;

  my $s = $style;

  my $shape = 'rect';
  $shape = ($node->attribute('shape') || '') if ref($node);

  # only for nodes and when they have a "shape: img"
  if ($shape eq 'img')
    {
    my $s = '<<TABLE BORDER="0"><TR><TD><IMG SRC="##url##" /></TD></TR></TABLE>>';

    my $url = $node->label();
    $url =~ s/\s/\+/g;				# space
    $url =~ s/'/%27/g;				# replace quotation marks
    $s =~ s/##url##/$url/g;
    }

  ($name, $s);
  }

#############################################################################

sub _att_as_graphviz
  {
  # convert a hash with attribute => value mappings to a string
  my ($self, $out) = @_;
 
  my $att = '';
  for my $atr (keys %$out)
    {
    my $v = $out->{$atr};
    $v =~ s/\n/\\n/g;

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
    }
  $att;
  }

sub _generate_group_edge
  {
  # Given an edge (from/to at least one group), generate the graphviz code
  my ($self, $e, $indent) = @_;

  my $edge_att = $e->attributes_as_graphviz();

  my $a = ''; my $b = '';
  my $from = $e->{from};
  my $to = $e->{to};

  ($from,$to) = ($to,$from) if $self->{_flip_edges};
  if ($from->isa('Graph::Easy::Group'))
    {
    # find an arbitray node inside the group
    my ($n, $v) = each %{$from->{nodes}};
    
    $a = 'ltail="cluster' . $from->{id}.'"';	# ltail=cluster0
    $from = $v;
    }

  if ($to->isa('Graph::Easy::Group'))
    {
    # find an arbitray node inside the group
    my ($n, $v) = each %{$to->{nodes}};
    
    $b = 'lhead="cluster' . $to->{id}.'"';	# lhead=cluster0
    $to = $v;
    }

  my $other = $to->as_graphviz_txt();
  my $first = $from->as_graphviz_txt();

  $e->{_p} = undef;				# mark as processed

  my $att = $a; 
  $att .= ', ' . $b if $b ne ''; $att =~ s/^,//;
  if ($att ne '')
    {
    if ($edge_att eq '')
      {
      $edge_att = " [ $att ]";
      }
    else
      {
      $edge_att =~ s/ \]/, $att \]/;
      }
    }

  "$indent$first -> $other$edge_att\n";		# return edge text
  }

sub _insert_edge_attribute
  {
  # insert an additional attribute into an edge attribute string
  my ($self, $att, $new_att) = @_;

  return '[ $new_att ]' if $att eq '';		# '' => '[ ]'

  $att =~ s/\s?\]/,$new_att ]/;
  $att;
  }

sub _suppress_edge_attribute
  {
  # remove the named attribute from the edge attribute string
  my ($self, $att, $sup_att) = @_;

  $att =~ s/$sup_att=("(\\"|[^"])*"|[^\s\n,;]+)[,;]?//;
  $att;
  }

sub _generate_edge
  {
  # Given an edge, generate the graphviz code for it
  my ($self, $e, $indent) = @_;

  # skip links from/to groups, these will be done later
  return '' if 
    $e->{from}->isa('Graph::Easy::Group') ||
    $e->{to}->isa('Graph::Easy::Group');

  my $invis = $self->{_graphviz_invis};

  # attributes for invisible helper nodes
  my $inv = ' [ label="",shape=none,style=filled,height=0,width=0 ]';

  my $other = $e->{to}->as_graphviz_txt();
  my $first = $e->{from}->as_graphviz_txt();

  my $edge_att = $e->attributes_as_graphviz();
  my $txt = '';

  my $modify_edge = 0;
  my $suppress = ($self->{_flip_edges} ? 'arrowtail=none' : 'arrowhead=none');;

  # if the edge has a shared start/end port
  if ($e->has_ports())
    {
    my @edges = ();

    my ($side,@port) = $e->port('start');
    @edges = $e->{from}->edges_at_port('start',$side,@port) if defined $side && @port > 0;

    if (@edges > 1)					# has strict port
      {
      # access the invisible node
      my $sp = $e->port('start');
      my $key = "$e->{from}->{name},start,$sp";
      my $invis_id = $invis->{$key};
      if (!defined $invis_id)
	{
	# create the invisible helper node
	# find a name for it, carefully avoiding names of other nodes: 
	$self->{_graphviz_invis_id}++ while (defined $self->node($self->{_graphviz_invis_id}));
	$invis_id = $self->{_graphviz_invis_id}++;

	# output the helper node
	$txt .= $indent . "$invis_id$inv\n";
        my $e_att = $self->_insert_edge_attribute($edge_att,$suppress);
        $e_att = $self->_suppress_edge_attribute($e_att,'label');
	if ($self->{_flip_edges})
	  {
	  $txt .= $indent . "$invis_id -> $first$e_att\n";
	  }
	else
	  {
	  $txt .= $indent . "$first -> $invis_id$e_att\n";
	  }
	$invis->{$key} = $invis_id;		# mark as created
	}
      # "joint0" etc
      $first = $invis_id;
      }

    ($side,@port) = $e->port('end');
    @edges = ();
    @edges = $e->{to}->edges_at_port('end',$side,@port) if defined $side && @port > 0;
    if (@edges > 1)
      {
      my $ep = $e->port('end');
      my $key = "$e->{to}->{name},end,$ep";
      my $invis_id = $invis->{$key};

      if (!defined $invis_id)
	{
	# create the invisible helper node
	# find a name for it, carefully avoiding names of other nodes:
	$self->{_graphviz_invis_id}++ while (defined $self->node($self->{_graphviz_invis_id}));
	$invis_id = $self->{_graphviz_invis_id}++;

	# output the helper node
	$txt .= $indent . "$invis_id$inv\n";
	if ($self->{_flip_edges})
	  {
	  $txt .= $indent . "$other -> $invis_id$edge_att\n";
	  }
	else
	  {
	  $txt .= $indent . "$invis_id -> $other$edge_att\n";
	  }
	$invis->{$key} = $invis_id;			# mark as output
	}
      # "joint1" etc
      $other = $invis_id;
      $modify_edge++;
      }
    }

  ($other,$first) = ($first,$other) if $self->{_flip_edges};

  $e->{_p} = undef;				# mark as processed

  $edge_att = $self->_insert_edge_attribute($edge_att,$suppress)
    if $modify_edge;

  $txt . "$indent$first -> $other$edge_att\n";		# return edge text
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


  my $flow = $self->attribute('graph','flow');
  $flow = 'east' unless defined $flow;

  $flow = Graph::Easy->_direction_as_number($flow);

  # for LR, BT layouts
  $self->{_flip_edges} = 0;
  $self->{_flip_edges} = 1 if $flow == 270 || $flow == 0;
  
  my $groups = $self->groups();

  $txt .= "  compound=true; // allow edges between groups\n\n"
    if $groups > 0;

  # to keep track of invisible helper nodes
  $self->{_graphviz_invis} = {};
  # name for invisible helper nodes
  $self->{_graphviz_invis_id} = 'joint0';

  my $atts =  $self->{att};
  for my $class (sort keys %$atts)
    {
    next if $class =~ /\./;		# skip subclasses

    my $out = $self->_remap_attributes( $class, $atts->{$class}, $remap, 'noquote', undef, 'remap_colors');

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

    my $att = $self->_att_as_graphviz($out);
    $txt .= "  $class [$att];\n" if $att ne '';
    }

  $txt .= "\n" if $txt ne '';		# insert newline

  ###########################################################################
  # output groups as subgraphs

  # insert the edges into the proper group
  $self->_edges_into_groups() if $groups > 0;

  my $indent = '    ';
  for my $group (sort { $a->{name} cmp $b->{name} } values %{$self->{groups}})
    {
    # quote special chars in group name
    my $name = $group->{name}; $name =~ s/([\[\]\(\)\{\}\#"])/\\$1/g;

    # output group attributes first
    $txt .= "  subgraph \"cluster$group->{id}\" {\n${indent}label=\"$name\";\n";
   
    # make a copy of the attributes
    my $copy = {};
    for my $a (keys %{$group->{att}})
      {
      $copy->{$a} = $group->{att}->{$a};
      }
    # set some defaults
    $copy->{'border-style'} = 'solid' unless defined $copy->{'border-style'};

    my $out = $self->_remap_attributes( $group->class(), $copy, $remap, 'noquote', undef, 'remap_colors');

    # set some defaults
    $out->{fillcolor} = '#a0d0ff' unless defined $copy->{fillcolor};
    $out->{color} = 'black' unless defined $copy->{color};
    $out->{style} = 'filled' unless defined $copy->{style};

    $out->{labeljust} = 'l';

    my $att = '';
    # we need to output style first ("filled" and "color" need come later)
    for my $atr (reverse sort keys %$out)
      {
      my $v = $out->{$atr};
      $v = '"' . $v . '"' if $v !~ /^[a-z0-9A-Z]+\z/;	# quote if nec.
      $att .= "    $atr=$v;\n";
      }
    $txt .= $att . "\n" if $att ne '';
 
    # output nodes (w/ or w/o attributes) in that group
    for my $n (values %{$group->{nodes}})
      {
      my $att = $n->attributes_as_graphviz();
      $n->{_p} = undef;			# mark as processed
      $txt .= $indent . $n->as_graphviz_txt() . $att . "\n";
      }

    # output node connections in this group
    for my $e (values %{$group->{edges}})
      {
      next if exists $e->{_p};
      $txt .= $self->_generate_edge($e, $indent);
      }

    $txt .= "  }\n";
    }

  my $root = $self->attribute('root');
  $root = '' unless defined $root;

  my $count = 0;
  # output nodes with attributes first, sorted by their name
  for my $n (sort { $a->{name} cmp $b->{name} } values %{$self->{nodes}})
    {
    next if exists $n->{_p};
    my $att = $n->attributes_as_graphviz($root);
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
        $txt .= $self->_generate_edge($e, '  ');
        }
      }
    }

  # insert now edges between groups (clusters/subgraphs)

  foreach my $e (values %{$self->{edges}})
    {
    $txt .= $self->_generate_group_edge($e, '  ') 
     if $e->{from}->isa('Graph::Easy::Group') ||
        $e->{to}->isa('Graph::Easy::Group');
    }

  # clean up
  for my $n ( values %{$self->{nodes}}, values %{$self->{edges}})
    {
    delete $n->{_p};
    }
  delete $self->{_graphviz_invis};		# invisible helper nodes

  $txt .  "\n}\n";	# close the graph again
  }

package Graph::Easy::Node;

sub attributes_as_graphviz
  {
  # return the attributes of this node as text description
  my ($self, $root) = @_;
  $root = '' unless defined $root;

  my $att = '';
  my $class = $self->class();

  return '' unless ref $self->{graph};

  $self->_croak("Object $self ($self->{name}) is not part of a graph") unless ref $self->{graph};

  my $g = $self->{graph};

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
  $a = $g->_remap_attributes( $self, $a, $remap, 'noquote', undef, 'remap_colors');

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
  my $shape = $a->{shape} || 'rect';
  if ($class =~ /node/ && $shape eq 'plaintext')
    {
    my $p = $self->parent();
    $a->{fillcolor} = $p->attribute('fill') || 'white';
    }

  my $sh = $self->attribute('shape') || 'rect';

  # for point-shaped nodes, include the point as label and set width/height
  if ($sh eq 'point')
    {
    require Graph::Easy::As_ascii;		# for _u8 and point-style

    my $style = $self->_point_style( $self->attribute('point-style') || 'star' );

    $a->{label} = $style;
    # for point-shaped invisible nodes, set height/width = 0
    $a->{width} = 0, $a->{height} = 0 if $style eq '';  
    }
  if ($sh eq 'invisible')
    {
    $a->{label} = ' ';
    }

  $a->{rank} = '0' if $root ne '' && $root eq $self->{name};

  # create the attributes as text:
  for my $atr (sort keys %$a)
    {
    my $v = $a->{$atr};
    $v =~ s/"/\\"/g;		# '2"' => '2\"'

    # don't quote labels like "<<TABLE.."
    if ($atr eq 'label' && $v =~ /^<<TABLE/)
      {
      my $va = $v; $va =~ s/\\"/"/g;		# unescape \"
      $att .= "$atr=$va, ";
      next;
      }

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

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
