#############################################################################
# Parse graphviz/dot text into a Graph::Easy object
#
# (c) by Tels 2005-2006.
#############################################################################

package Graph::Easy::Parser::Graphviz;

$VERSION = '0.06';
use base qw/Graph::Easy::Parser/;

use strict;

use constant NO_MULTIPLES => 1;

sub _init
  {
  my $self = shift;

  $self->SUPER::_init(@_);
  $self->{attr_sep} = '=';

  $self;
  }

sub reset
  {
  my $self = shift;

  $self->SUPER::reset(@_);

  # set some default attributes on the graph object, because graphviz has
  # different defaults as Graph::Easy
  my $g = $self->{graph};

  $g->set_attribute('colorscheme','x11');
  $g->set_attribute('flow','south');

  $self->{scope_stack} = [];

  $self;
  }

sub _unquote
  {
  my ($self, $name) = @_;

  $name = '' unless defined $name;

  $name =~ s/^"\s*//; 		# remove left-over quotes
  $name =~ s/\s*"\z//; 

  # unquote special chars
  $name =~ s/\\([\[\(\{\}\]\)#"])/$1/g;

  $name;
  }

sub _line_insert
  {
  # "a1 -> a2\na3 -> a4" => "a1 -> a2 a3 -> a4"
  ' ';
  }

#############################################################################

sub _match_boolean
  {
  # not used yet, match a boolean value
  qr/(true|false|\d+)/;
  }

sub _match_comment
  {
  # match the start of a comment

  # // comment
  qr#(:[^\\]|)//#;
  }

sub _match_multi_line_comment
  {
  # match a multi line comment

  # /* * comment * */
  qr#\s*/\*.*?\*/#;
  }

sub _match_optional_multi_line_comment
  {
  # match a multi line comment

  # "/* * comment * */" or ""
  qr#(?:\s*/\*.*?\*/|)#;
  }

sub _match_name
  {
  # Return a regexp that matches something like '"bonn"' or 'bonn'.

  # "node", "graph", "edge", "digraph", "subgraph" and "strict" are reserved:

  qr/\s*("[^"]*"|(?!(node|edge|digraph|subgraph|graph|edge|strict)\s)[\w]+)/i;
  }

sub _match_node
  {
  # Return a regexp that matches something like '"bonn"' or 'bonn' or 'bonn:f1'

  # "node", "graph", "edge", "digraph", "subgraph" and "strict" are reserved:

  #    "bonn"      Bonn, Bonn0, Bonn_0, node_0 etc                                 "Bonn":f1, "Bonn":"f1"
  qr/\s*("[^"]*"|(?!(node|edge|digraph|subgraph|graph|edge|strict)\s)[\w_]+)(:"?[\w]+"?)?/i;
  }

sub _match_group_start
  {
  qr/\s*(?:digraph|subgraph|graph)\s+([\w_]+)\s*\{/i;
  }

sub _match_pseudo_group_start
  {
  qr/\s*\{/;
  }

sub _match_group_end
  {
  # return a regexp that matches something like " }".
  qr/\s*\}\s*/;
  }

sub _match_edge
  {
  # Matches an edge
  qr/\s*(->|--)/;
  }

sub _match_single_attribute
  {
  qr/^\s*(\w+)\s*=\s*("[^"]+"|[^,\]\}\n\s;]+)[,\]\n\}\s;]?\s*/;
  }

sub _match_special_attribute
  {
  qr/^\s*(center|truecolor)[,;\s]?\s*/;
  }

sub _match_attributes
  {
  # return a regexp that matches something like " [ color=red; ]" and returns
  # the inner text without the []
  qr/\s*\[\s*([^\]]+?)\s*\];?/;
  }

sub _match_graph_attribute
  {
  # return a regexp that matches something like " color=red; " for attributes
  # that apply to a graph/subgraph
  qr/^\s*(\w+\s*=\s*("[^"]+"|[^;\n\s]+))([;\n\s]\s*|\z)/;
  }

sub _match_optional_attributes
  {
  # return a regexp that matches something like " [ color=red; ]" and returns
  # the inner text with the []
  qr/(\s*\[[^\]]+?\])?;?/;
  }

sub _clean_attributes
  {
  my ($self,$text) = @_;

  $text =~ s/^\s*\[\s*//;		# remove left-over "[" and spaces
  $text =~ s/\s*;?\s*\]\s*\z//;		# remove left-over "]" and spaces

  $text;
  }

#############################################################################

sub _new_scope
  {
  # create a new scope, with attributes from current scope
  my ($self, $is_group) = @_;

  my $scope = {};

  if (@{$self->{scope_stack}} > 0)
    {
    my $old_scope = $self->{scope_stack}->[-1];

    # make a copy of the old scope's attribtues
    for my $k (keys %$old_scope)
      {
      $scope->{$k} = $old_scope->{$k} unless $k =~ /^_/;
      }
    }
  $scope->{_is_group} = 1 if defined $is_group;

  push @{$self->{scope_stack}}, $scope;
  $scope;
  }

sub _add_group_match
  {
  # register handlers for group start/end
  my $self = shift;

  my $qr_pseudo_group_start = $self->_match_pseudo_group_start();
  my $qr_group_start = $self->_match_group_start();
  my $qr_group_end   = $self->_match_group_end();
  my $qr_edge  = $self->_match_edge();
  my $qr_ocmt  = $self->_match_optional_multi_line_comment();

  # "subgraph G {"
  $self->_register_handler( qr/^$qr_group_start/,
    sub
      {
      my $self = shift;
      my $graph = $self->{graph};
      my $gn = $self->_unquote($1);
      push @{$self->{group_stack}}, $graph->add_group($gn);
      $self->_new_scope( 1 );
      1;
      } );
  
  # "{ "
  $self->_register_handler( qr/^$qr_pseudo_group_start/,
    sub
      {
      my $self = shift;
      $self->_new_scope();
      # forget the left side
      $self->{left_edge} = undef;
      $self->{left_stack} = [ ];
      1;
      } );

  # "} -> " group/cluster/scope end with an edge
  $self->_register_handler( qr/^$qr_group_end$qr_ocmt$qr_edge/,
    sub
      {
      my $self = shift;
 
      my $scope = pop @{$self->{scope_stack}};
      return $self->parse_error(0) if !defined $scope;

      my $eg = $1;				# entire edge ("->" etc)
      my $edge_un = 0; $edge_un = 1 if $eg eq '--';	# undirected edge?
      my $edge_atr = {};

      if ($self->{_is_group})
        {
        my $group = pop @{$self->{group_stack}};
        }

      1;
      }, 
    sub
      {
      my ($self, $line) = @_;
      $line =~ qr/^$qr_group_end$qr_edge/;
      $1 . ' ';
      } );

  # "}" group/cluster/scope end
  $self->_register_handler( qr/^$qr_group_end/,
    sub
      {
      my $self = shift;
 
      my $scope = pop @{$self->{scope_stack}};
      return $self->parse_error(0) if !defined $scope;

      if ($self->{_is_group})
        {
        my $group = pop @{$self->{group_stack}};
        }
      # always reset the stack
      $self->{stack} = [ ];
      1;
      } );
  }

sub _edge_style
  {
  # To convert "--" or "->" we simple do nothing, since the edge style in
  # Graphviz can only be set via the attribute "style"
  my ($self, $ed) = @_;

  'solid';
  }

sub _build_match_stack
  {
  my $self = shift;

  my $qr_node  = $self->_match_node();
  my $qr_name  = $self->_match_name();
  my $qr_cmt   = $self->_match_multi_line_comment();
  my $qr_ocmt  = $self->_match_optional_multi_line_comment();
  my $qr_attr  = $self->_match_attributes();
  my $qr_gatr  = $self->_match_graph_attribute();
  my $qr_oatr  = $self->_match_optional_attributes();
  my $qr_edge  = $self->_match_edge();
  my $qr_pgr = $self->_match_pseudo_group_start();

  # remove multi line comments
  $self->_register_handler( qr/^$qr_cmt/, undef );
  
  # simple remove the graph start, but remember that we did this
  $self->_register_handler( qr/^\s*(strict\s+)?(digraph|graph)\s+$qr_ocmt$qr_node\s*$qr_ocmt\{/, 
    sub 
      {
      my $self = shift;
      $self->_new_scope(1);
      1;
      } );

  # end-of-statement
  $self->_register_handler( qr/^\s*;/, undef );

  # cluster/subgraph "subgraph G { .. }"
  # scope (dummy group): "{ .. }" 
  # scope/group/subgraph end: "}"
  $self->_add_group_match();

  # node [ color="red" ] etc 
  $self->_register_handler( qr/^(node|graph|edge)$qr_ocmt$qr_attr/,
    sub
      {
      my $self = shift;
      my $type = $1 || '';
      my $att = $self->_parse_attributes($2 || '', $type, NO_MULTIPLES );

      return undef unless defined $att;		# error in attributes?

      if ($type ne 'graph')
	{
	# apply the attributes to the current scope
	my $scope = $self->{scope_stack}->[-1];
	for my $k (keys %$att)
	  {
          $scope->{$k} = $att->{$k}; 
	  }
	}
      else
	{
	my $graph = $self->{graph};
	$graph->set_attributes ($type, $att);
	}

      # forget stacks
      $self->{stack} = [];
      $self->{left_edge} = undef;
      $self->{left_stack} = [];
      1;
      } );

  # color=red; (for graphs or subgraphs)
  $self->_register_attribute_handler($qr_gatr, 'parent');
  # [ color=red; ] (for nodes/edges)
  $self->_register_attribute_handler($qr_attr);

  # node chain continued like "-> { "Kassel" ... "
  $self->_register_handler( qr/^$qr_edge$qr_ocmt$qr_pgr$qr_ocmt$qr_node/,
    sub
      {
      my $self = shift;

      return if @{$self->{stack}} == 0;	# only match this if stack non-empty

      my $graph = $self->{graph};
      my $eg = $1;					# entire edge ("->" etc)
      my $n = $2;					# node name

      # XXX TODO: what about "1" -- "2" [ dir: both; ]?
      my $edge_un = 0; $edge_un = 1 if $eg eq '--';	# undirected edge?

      # need to defer edge attribute parsing until the edge exists
      my $edge_atr = {};

      # the right side node(s) (multiple in case of autosplit)
      my $nodes_b = [ $self->_new_node ($self->{graph}, $n, $self->{group_stack}) ];

      my $style = $self->_link_lists( $self->{stack}, $nodes_b,
	'--', '', $edge_atr, 0, $edge_un);

      # create a new scope
      $self->_new_scope();

      # remember the left side
      $self->{left_edge} = [ $style, '', $edge_atr, 0, $edge_un ];
      $self->{left_stack} = $self->{stack};

      # forget stack and remember the right side instead
      $self->{stack} = $nodes_b;

      1;
      } );

  # "Berlin"
  $self->_register_handler( qr/^$qr_node/,
    sub
      {
      my $self = shift;
      my $graph = $self->{graph};

      # only match this inside a "{ }" (normal, non-group) scope
      return if exists $self->{scope_stack}->[-1]->{_is_group};

      my $n1 = $1;
      push @{$self->{stack}},
        $self->_new_node ($graph, $n1, $self->{group_stack}, {}, $self->{stack});

      if (defined $self->{left_edge})
        {
        my $e = $self->{use_class}->{edge};
        my ($style, $edge_label, $edge_atr, $edge_bd, $edge_un) = @{$self->{left_edge}};

        foreach my $node (@{$self->{left_stack}})
          {
          my $edge = $e->new( { style => $style, name => $edge_label } );
          $edge->set_attributes($edge_atr) if $edge_atr;
          # "<--->": bidirectional
          $edge->bidirectional(1) if $edge_bd;
          $edge->undirected(1) if $edge_un;
          $graph->add_edge ( $node, $self->{stack}->[-1], $edge );
          }
        }
      1;
      } );

  # "Berlin" [ color=red ]
  $self->_register_node_attribute_handler($qr_node,$qr_oatr);

  # Things like ' "Node" ' will be consumed before, so we do not need a case
  # for '"Bonn" -> "Berlin"'

  # node chain continued like "-> "Kassel" [ ... ]"
  $self->_register_handler( qr/^$qr_edge$qr_ocmt$qr_node$qr_ocmt$qr_oatr/,
    sub
      {
      my $self = shift;

      return if @{$self->{stack}} == 0;	# only match this if stack non-empty

      my $graph = $self->{graph};
      my $eg = $1;					# entire edge ("->" etc)
      my $n = $2;					# node name

      # XXX TODO: what about "1" -- "2" [ dir: both; ]?
      my $edge_un = 0; $edge_un = 1 if $eg eq '--';	# undirected edge?

      # need to defer edge attribute parsing until the edge exists
      my $edge_atr = $5||'';

      # the right side node(s) (multiple in case of autosplit)
      my $nodes_b = [ $self->_new_node ($self->{graph}, $n, $self->{group_stack}) ];

      my $style = $self->_link_lists( $self->{stack}, $nodes_b,
	'--', '', $edge_atr, 0, $edge_un);

      # remember the left side
      $self->{left_edge} = [ $style, '', $edge_atr, 0, $edge_un ];
      $self->{left_stack} = $self->{stack};

      # forget stack and remember the right side instead
      $self->{stack} = $nodes_b;
      1;
      } );

  $self;
  }

sub _add_node
  {
  # add a node to the graph, overridable by subclasses
  my ($self, $graph, $name) = @_;

  # "a -- clusterB" should not create a spurious node named "clusterB"
  my @groups = $graph->groups();
  for my $g (@groups)
    {
    return $g if $g->{name} eq $name;
    }

  my $node = $graph->node($name);
 
  if (!defined $node)
    {
    $node = $graph->add_node($name);		# add

    # apply attributes from the current scope (only for new nodes)
    my $scope = $self->{scope_stack}->[-1];
    $self->error("Scope stack is empty!") unless defined $scope;
  
    my $is_group = $scope->{_is_group};
    delete $scope->{_is_group};
    $node->set_attributes($scope);
    $scope->{_is_group} = $is_group if $is_group;
    }

  $node;
  }

#############################################################################
# attribute remapping

# undef => drop that attribute
# not listed attributes are simple copied unmodified

my $remap = {
  'node' => {
    'distortion' => undef,
    # XXX TODO: ignore non-node attributes set in a scope
    'dir' => undef,
    'fixedsize' => undef,
    'group' => undef,
    'height' => undef,
    # a lot of example files have this spurious attribute
    'kind' => undef,
    'layer' => undef,
    'margin' => undef,
    'orientation' => undef, # \&_graphviz_remap_node_orientation,
    'peripheries' => \&_from_graphviz_node_peripheries,
    'pin' => undef,
    'pos' => undef,
    # XXX TODO: rank=0 should make that node the root node
    'rank' => undef,
    'rects' => undef,
    'regular' => undef,
    'root' => undef,
    'sides' => undef,
    'shapefile' => undef,
    'shape' => \&_from_graphviz_node_shape,
    'skew' => undef,
    'style' => \&_from_graphviz_style,
    'width' => undef,
    'z' => undef,
    },

  'edge' => {
    'arrowsize' => undef,
    'arrowhead' => undef,
#     'arrowhead' => \&_graphviz_remap_arrow_style,
    'arrowtail' => undef,
     # important for color lists like "red:red" => double edge
    'color' => \&_from_graphviz_edge_color,
    'constraint' => undef,
    'dir' => \&_from_graphviz_edge_dir,
    'decorate' => undef,
    'f' => undef,
    'headclip' => undef,
    'headhref' => undef,
    'headurl' => undef,
    'headport' => undef,
    'headlabel' => undef,
    'headport' => undef,
    'headtarget' => undef,
    'headtooltip' => undef,
    'href' => 'link',
    'labelangle' => undef,
    'labeldistance' => undef,
    'labelfloat' => undef,
    'labelfontcolor' => \&_from_graphviz_color,
    'labelfontname' => 'font',
    'labelfontsize' => 'font-size',
    'layer' => undef,
    'len' => undef,
    'lhead' => undef,
    'ltail' => undef,
    'minlen' => \&_from_graphviz_edge_minlen,
    'pos' => undef,
    'samehead' => undef,
    'samearrowhead' => undef,
    'sametail' => undef,
    'style' => \&_from_graphviz_edge_style,
    'tailclip' => undef,
    'tailhref' => undef,
    'tailurl' => undef,
    'tailport' => undef,
    'taillabel' => undef,
    'tailport' => undef,
    'tailtarget' => undef,
    'tailtooltip' => undef,
    'weight' => undef,
    },

  'graph' => {
    'damping' => undef,
    'K' => undef,
    'bb' => undef,
    'center' => undef,
    'charset' => undef,
    'clusterrank' => undef,
    'compound' => undef,
    'concentrate' => undef,
    'defaultdist' => undef,
    'dim' => undef,
    'dpi' => undef,
    'epsilon' => undef,
    'esep' => undef,
    'fontpath' => undef,
#    'labeljust' => \&_graphviz_remap_graph_labeljust,
    'labelloc' => \&_from_graphviz_graph_labelloc,
    'landscape' => undef,
    'layers' => undef,
    'layersep' => undef,
    'levelsgap' => undef,
    'margin' => undef,
    'mclimit' => undef,
    'mindist' => undef,
    'mode' => undef,
    'model' => undef,
    'nodesep' => undef,
    'normalize' => undef,
    'nslimit' => undef,
    'nslimit1' => undef,
    'ordering' => undef,
    'orientation' => undef,
    'outputorder' => undef,
    'overlap' => undef,
    'pack' => undef,
    'packmode' => undef,
    'page' => undef,
    'pencolor' => 'border-color',
    'quantum' => undef,
    'rankdir' => \&_from_graphviz_graph_rankdir,
    'ranksep' => undef,
    'ratio' => undef,
    'remincross' => undef,
    'resolution' => undef,
    'rotate' => undef,
    'samplepoints' => undef,
    'searchsize' => undef,
    'sep' => undef,
    'sep' => undef,
    'size' => undef,
    'splines' => undef,
    'start' => undef,
    'style' => \&_from_graphviz_style,
    'stylesheet' => undef,
    'truecolor' => undef,
    'viewport' => undef,
    'voro-margin' => undef,
    },

  'group' => {
#    'labeljust' => \&_graphviz_remap_graph_labeljust,
#    'labelloc' => \&_graphviz_remap_graph_labelloc,
    'pencolor' => \&_from_graphviz_color,
    'style' => \&_from_graphviz_style,
    'K' => undef,
    },

  'all' => {
    'color' => \&_from_graphviz_color,
    'colorscheme' => undef,
    'comment' => undef,
    'bgcolor' => \&_from_graphviz_color,
    'fillcolor' => \&_from_graphviz_color,
    'fontsize' => \&_from_graphviz_font_size,
    'fontcolor' => \&_from_graphviz_color,
    'fontname' => 'font',
    'lp' => undef,
    'nojustify' => undef,
    'rank' => undef,
    'showboxes' => undef,
    'target' => undef,
    'tooltip' => 'title',
    'url' => 'link',
    },
  };

my $rankdir = {
  'LR' => 'east',
  'RL' => 'west',
  'TB' => 'south',
  'BT' => 'north',
  };

sub _from_graphviz_graph_rankdir
  {
  my ($self, $name, $dir) = @_;

  my $d = $rankdir->{$dir} || 'east';

  ('flow', $d);
  }

my $shapes = {
  box => 'rect',
  polygon => 'rect',
  egg => 'rect',
  rectangle => 'rect',
  mdiamond => 'diamond',
  msquare => 'rect',
  plaintext => 'none',
  none => 'none',
  record => 'rect',
  };

sub _from_graphviz_node_shape
  {
  my ($self, $name, $shape) = @_;

  my @rc;
  my $s = lc($shape);
  if ($s =~ /^(triple|double)/)
    {
    $s =~ s/^(triple|double)//;
    push @rc, ('border-style','double');
    }

  # map the name to what Graph::Easy expects (ellipse stays as ellipse f.i.)
  $s = $shapes->{$s} || $s;

  (@rc, $name, $s);
  }

sub _from_graphviz_style
  {
  my ($self, $name, $style) = @_;

  my @styles = split /\s*,\s*/, $style;

  my @rc;
  for my $s (@styles)
    {
    @rc = ('shape', 'rounded') if $s eq 'rounded';
    @rc = ('border', 'black bold') if $s eq 'bold';
    @rc = () if $s eq 'filled';
    }

  @rc;
  }

sub _from_graphviz_node_peripheries
  {
  my ($self, $name, $cnt) = @_;

  return (undef,undef) if $cnt < 2;

  # peripheries = 2 => double border
  ('border-style', 'double');
  }

sub _from_graphviz_edge_minlen
  {
  my ($self, $name, $len) = @_;

  # 1 => 1, 2 => 3, 3 => 5 etc
  $len = $len * 2 - 1;
  ($name, $len);
  }

sub _from_graphviz_font_size
  {
  my ($self, $f, $size) = @_;

  # 20 => 20px
  $size = $size . 'px' if $size =~ /^\d+\z/;

  ('font-size', $size);
  }

sub _from_graphviz_graph_labelloc
  {
  my ($self, $l, $loc) = @_;

  $loc = 'top' if $loc eq 't'; 
  $loc = 'bottom' if $loc eq 'b';

  ('label-pos', $loc);
  }

sub _from_graphviz_edge_dir
  {
  my ($self, $name, $dir, $edge) = @_;

  # Modify the edge, depending on dir
  if (ref($edge))
    {
    # "forward" is the default and ignored
    $edge->flip() if $dir eq 'back';
    $edge->bidirectional(1) if $dir eq 'both';
    $edge->undirected(1) if $dir eq 'none';
    }

  (undef, undef);
  }

sub _from_graphviz_edge_style
  {
  my ($self, $name, $style, $object) = @_;

  # input: solid dashed dotted bold invis
  $style = 'invisible' if $style eq 'invis';

  ($name, $style);
  }

my $color_map = {
  fontcolor => 'color',
  bgcolor => 'background',
  fillcolor => 'fill',
  pencolor => 'border-color',
  labelfontcolor => 'label-color',
  color => 'color',
  };

sub _from_graphviz_color
  {
  # remape the color name and value
  my ($self, $name, $color) = @_;

  # "0.1 0.4 0.5" => "rgb(0.1,0.4,0.5)"
  if ($color =~ /\s/)
    {
    $color =~ s/\s/,/g; $color = 'rgb(' . $color . ')';
    }

  # XXX TODO: #ff00005f => #ff0000
  $color = $1 if $color =~ /^(#......)..\z/;

  ($color_map->{$name}, $color);
  }

sub _from_graphviz_edge_color
  {
  # remape the color name and value
  my ($self, $name, $color) = @_;

  my @colors = split /:/, $color;

  for my $c (@colors)
    {
    $c = Graph::Easy::Parser::Graphviz::_from_graphviz_color($self,$name,$c);
    }

  my @rc;
  if (@colors > 1)
    {
    # 'red:blue' => "style: double; color: red"
    push @rc, 'style', 'double';
    }

  (@rc, $color_map->{$name}, $colors[0]);
  }

#############################################################################

sub _remap_attributes
  {
  my ($self, $att, $object) = @_;

  # unquote attributes (especially colors)
  for my $val (values %$att)
    {
    $val =~ s/^"//;
    $val =~ s/"\z//;
    }
  print STDERR "# remapping attributes '$att' for $object\n" if $self->{debug};

  $self->{graph}->_remap_attributes($object, $att, $remap, 'noquote', undef, undef);
  }

1;
__END__

=head1 NAME

Graph::Easy::Parser::Graphviz - Parse graphviz text into Graph::Easy

=head1 SYNOPSIS

        # creating a graph from a textual description

        use Graph::Easy::Parser::Graphviz;
        my $parser = Graph::Easy::Parser::Graphviz->new();

        my $graph = $parser->from_text(
                "digraph Graph {\" .
                ' Bonn -> "Berlin"' . "\n}\n" );
        );
        print $graph->as_ascii();
        
	print $parser->from_file('mygraph.dot')->as_ascii();

=head1 DESCRIPTION

C<Graph::Easy::Parser::Graphviz> parses the text format from graphviz and
constructs a C<Graph::Easy> object from it.

The resulting object can than be used to layout and output the graph.

Please see the Grapviz manual for a full description of the syntax rules.

=head2 Output

The output will be a L<Graph::Easy|Graph::Easy> object (unless overrriden
with C<use_class()>), see the documentation for Graph::Easy what you can do
with it.

=head1 METHODS

C<Graph::Easy::Parser::Graphviz> supports the same methods
that its parent class C<Graph::Easy::Parser>:

=head2 new()

	use Graph::Easy::Parser::Graphviz;
	my $parser = Graph::Easy::Parser::Graphviz->new();

Creates a new parser object. The only valid parameter is debug,
when set to true it will enable debug output to STDERR:

	my $parser = Graph::Easy::Parser::Graphviz->new( debug => 1 );
	$parser->from_text('digraph G { A -> B }');

=head2 reset()

	$parser->reset();

Reset the status of the parser, clear errors etc. Automatically called
when you call any of the C<from_XXX()> methods below.

=head2 use_class()

	$parser->use_class('node', 'Graph::Easy::MyNode');

Override the class to be used to constructs objects while parsing.

See L<Graph::Easy::Parser> for further information.

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

The second calling style will create a temporary parser object,
parse the file and return the resulting C<Graph::Easy> object.

Returns undef for error, you can find out what the error was
with L<error()> when using the first calling style.

=head2 error()

	my $error = $parser->error();

Returns the last error, or the empty string if no error occured.

=head2 parse_error()

	$parser->parse_error( $msg_nr, @params);

Sets an error message from a message number and replaces embedded
templates like C<##param1##> with the passed parameters.

=head1 CAVEATS

=over 12

=item encoding and charset attribute

The Parser assumes the input to be C<utf-8>. Input files in <code>Latin1</code>
are not parsed properly, even when they have the charset attribute set.

=back

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2005 - 2006 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
