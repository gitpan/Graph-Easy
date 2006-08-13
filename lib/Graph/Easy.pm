############################################################################
# Layout directed graphs as 2D boxes on a flat plane
#
# (c) by Tels 2004-2006.
#############################################################################

package Graph::Easy;

use 5.008001;
use Graph::Easy::Base;
use Graph::Easy::Attributes;
use Graph::Easy::Edge;
use Graph::Easy::Group;
use Graph::Easy::Layout;
use Graph::Easy::Node;
use Graph::Easy::Node::Anon;
use Graph::Easy::Node::Empty;
use Scalar::Util qw/weaken/;

$VERSION = '0.46';
@ISA = qw/Graph::Easy::Base/;

use strict;

BEGIN 
  {
  # a few aliases for backwards compatibility
  *attribute = \&get_attribute; 
  *as_html_page = \&as_html_file;
  *as_graphviz_file = \&as_graphviz;
  *as_ascii_file = \&as_ascii;
  *as_boxart_file = \&as_boxart;
  *as_txt_file = \&as_txt;
  *_aligned_label = \&Graph::Easy::Node::_aligned_label;
  *_convert_pod = \&Graph::Easy::Node::_convert_pod;
  *_label_as_html = \&Graph::Easy::Node::_label_as_html;
  *default_attribute = \&Graph::Easy::Node::default_attribute; 
  *get_color_attribute = \&color_attribute;
  }

#############################################################################

sub new
  {
  # override new() as to not set the {id}
  my $class = shift;

  my $self = bless {}, $class;

  my $args = $_[0];
  $args = { @_ } if ref($args) ne 'HASH';

  $self->_init($args);
  }

sub DESTROY
  {
  my $self = shift;
 
  # Be carefull to not delete ->{graph}, these will be cleaned out by
  # Perl automatically in O(1) time, manual delete is O(N) instead.

  delete $self->{chains};
  # clean out pointers in child-objects so that they can safely be reused
  for my $n (values %{$self->{nodes}})
    {
    if (ref($n))
      {
      delete $n->{edges};
      delete $n->{group};
      }
    }
  for my $e (values %{$self->{edges}})
    {
    if (ref($e))
      {
      delete $e->{cells};
      delete $e->{to};
      delete $e->{from};
      }
    }
  for my $g (values %{$self->{groups}})
    {
    if (ref($g))
      {
      delete $g->{nodes};
      delete $g->{edges};
      }
    }
  }

sub _init
  {
  my ($self,$args) = @_;

  $self->{debug} = 0;
  $self->{timeout} = 5;			# in seconds
  $self->{strict} = 1;			# check attributes strict?
  
  $self->{class} = 'graph';
  $self->{id} = '';
  $self->{groups} = {};

  # node objects, indexed by their unique name
  $self->{nodes} = {};
  # edge objects, indexed by unique ID
  $self->{edges} = {};

  $self->{output_format} = 'html';

  $self->{_astar_bias} = 0.001;

  # default classes to use in add_foo() methods
  $self->{use_class} = {
    edge => 'Graph::Easy::Edge',
    group => 'Graph::Easy::Group',
    node => 'Graph::Easy::Node',
  };

  $self->{att} = {
  node => {
    align => 'center',
    'border' => 'solid 1px #000000',
    'border-style' => 'solid',
    'border-width' => '1',
    'border-color' => '#000000',
    fill => 'white',
    padding => '0.2em',
    'padding-left' => '0.3em',
    'padding-right' => '0.3em',
    margin => '0.1em',
    color => '#000000',
    colorscheme => 'inherit',
    },
  graph => {
    'align' => 'center',
    border => 'none',
    background => 'inherit',
    margin => '0.5em',
    padding => '0.5em',
    linkbase => '/wiki/index.php/',
    colorscheme => 'w3c',
    },
  edge => { 
    border => 'none',
    'border-style' => 'none',
    background => 'inherit',
    padding => '0.2em',
    margin => '0.1em',
    color => '#000000',
    'font' => 'monospaced, courier-new, courier, sans-serif',
    },
  group => { 
    'border' => 'dashed 1px #000000',
    'border-style' => 'dashed',
    'border-width' => '1',
    'border-color' => '#000000',
    'font-size' => '0.8em',
    fill => '#a0d0ff',
    padding => '0.2em',
    align => 'left',
    color => '#000000',
    },
  };

  # make copy of defaults, to not include them in output
  $self->{def_att} = { node => {}, graph => {}, edge => {}};
  foreach my $c (qw/node graph edge group/)
    {
    my $a = $self->{att}->{$c};
    foreach my $atr (keys %$a)
      {
      $self->{def_att}->{$c}->{$atr} = $a->{$atr};
      }
    }

  foreach my $k (keys %$args)
    {
    if ($k !~ /^(timeout|debug|strict)\z/)
      {
      $self->error ("Unknown option '$k'");
      }
    $self->{$k} = $args->{$k};
    }

  $self->{score} = undef;

  $self->randomize();

  $self;
  }

#############################################################################
# accessors

sub timeout
  {
  my $self = shift;

  $self->{timeout} = $_[0] if @_;
  $self->{timeout};
  }

sub debug
  {
  my $self = shift;

  $self->{debug} = $_[0] if @_;
  $self->{debug};
  }

sub strict
  {
  my $self = shift;

  $self->{strict} = $_[0] if @_;
  $self->{strict};
  }

sub is_simple_graph
  {
  # return true if the graph does not have multiedges
  my $self = shift;

  # check each node for multi-edges
  for my $n (values %{$self->{nodes}})
    {
    my %count;
    for my $e (values %{$n->{edges}})
      {
      my $id = "$e->{to}->{id},$e->{from}->{id}";
      return 0 if exists $count{$id};
      $count{$id} = undef;
      }
    }

  1;					# found none
  }

sub id
  {
  my $self = shift;

  $self->{id} = shift if defined $_[0];
  $self->{id};
  }

sub score
  {
  my $self = shift;

  $self->{score};
  }

sub randomize
  {
  my $self = shift;

  srand();
  $self->{seed} = rand(2 ** 31);

  $self->{seed};
  }

sub source_nodes
  {
  # return nodes with only outgoing edges
  my $self = shift;

  my @roots;
  for my $node (values %{$self->{nodes}})
    {
    push @roots, $node 
      if (keys %{$node->{edges}} != 0) && !$node->has_predecessors();
    }
  @roots;
  }

sub predecessorless_nodes
  {
  # return nodes with no incoming (but maybe outgoing) edges
  my $self = shift;

  my @roots;
  for my $node (values %{$self->{nodes}})
    {
    push @roots, $node 
      if (keys %{$node->{edges}} == 0) || !$node->has_predecessors();
    }
  @roots;
  }

sub label
  {
  my $self = shift;

  my $label = $self->{att}->{graph}->{label}; $label = '' unless defined $label;
  $label;
  }

sub link
  {
  # return the link, build from linkbase and link (or autolink)
  my $self = shift;

  my $link = $self->attribute('link');
  my $autolink = $self->attribute('autolink');
  if (!defined $link && defined $autolink)
    {
    $link = $self->{name} if $autolink eq 'name';
    # defined to avoid overriding "name" with the non-existant label attribute
    $link = $self->{att}->{label} if $autolink eq 'label' && defined $self->{att}->{label};
    $link = $self->{name} if $autolink eq 'label' && !defined $self->{att}->{label};
    }
  $link = '' unless defined $link;

  # prepend base only if link is relative
  if ($link ne '' && $link !~ /^([\w]{3,4}:\/\/|\/)/)
    {
    my $base = $self->attribute('linkbase');
    $link = $base . $link if defined $base;
    }

  $link;
  }

sub seed
  {
  my $self = shift;

  $self->{seed} = $_[0] if @_ > 0;

  $self->{seed};
  }

sub nodes
  {
  # return all nodes as objects
  my ($self) = @_;

  my $n = $self->{nodes};

  return scalar keys %$n unless wantarray;	# shortcut

  values %$n;
  }

sub anon_nodes
  {
  # return all anon nodes as objects
  my ($self) = @_;

  my $n = $self->{nodes};

  if (!wantarray)
    {
    my $count = 0;
    for my $node (values %$n)
      {
      $count++ if $node->is_anon();
      }
    return $count;
    }

  my @anon = ();
  for my $node (values %$n)
    {
    push @anon, $node if $node->is_anon();
    }
  @anon;
  }

sub edges
  {
  # return all the edges as objects
  my ($self) = @_;

  my $e = $self->{edges};

  return scalar keys %$e unless wantarray;	# shortcut

  values %$e;
  }

sub sorted_nodes
  {
  # return all nodes as objects, sorted by $f1 or $f1 and $f2
  my ($self, $f1, $f2) = @_;

  return scalar $self->nodes() unless wantarray;	# shortcut

  $f1 = 'id' unless defined $f1;
  # sorting on a non-unique field alone will result in unpredictable
  # sorting order due to hashing
  $f2 = 'name' if !defined $f2 && $f1 !~ /^(name|id)$/;

  my $sort;
  $sort = sub { $a->{$f1} <=> $b->{$f1} } if $f1;
  $sort = sub { $a->{$f1} cmp $b->{$f1} } if $f1 && $f1 =~ /^(name|title|label)$/;
  $sort = sub { $a->{$f1} <=> $b->{$f1} || $a->{$f2} <=> $b->{$f2} } if $f2;
  $sort = sub { $a->{$f1} <=> $b->{$f1} || $a->{$f2} cmp $b->{$f2} } if $f2 &&
           $f2 =~ /^(name|title|label)$/;

  # if we have groups, sort the nodes by their groups first:
#  if (keys %{$self->{groups}} > 0)
  if (3 < 1)
    {
    $sort = sub { 
      my $ag = 0; $ag = $a->{group}->{id} if ref $a->{group};
      my $bg = 0; $bg = $b->{group}->{id} if ref $b->{group};
      $ag <=> $bg || $a->{$f1} <=> $b->{$f1} 
      } if $f1;
    $sort = sub { 
      my $ag = 0; $ag = $a->{group}->{id} if ref $a->{group};
      my $bg = 0; $bg = $b->{group}->{id} if ref $b->{group};
      $ag <=> $bg || $a->{$f1} cmp $b->{$f1} 
      } if $f1 && $f1 =~ /^(name|title|label)$/;
    $sort = sub {
      my $ag = 0; $ag = $a->{group}->{id} if ref $a->{group};
      my $bg = 0; $bg = $b->{group}->{id} if ref $b->{group};
      $ag <=> $bg || $a->{$f1} <=> $b->{$f1} || $a->{$f2} <=> $b->{$f2} 
      } if $f2;
    $sort = sub { 
      my $ag = 0; $ag = $a->{group}->{id} if ref $a->{group};
      my $bg = 0; $bg = $b->{group}->{id} if ref $b->{group};
      $ag <=> $bg || $a->{$f1} <=> $b->{$f1} || $a->{$f2} cmp $b->{$f2} 
      } if $f2 && $f2 =~ /^(name|title|label)$/;
    }

  # the 'return' here should not be removed
  return sort $sort values %{$self->{nodes}};
  }

sub add_edge_once
  {
  # add an edge, unless it already exists. In that case it returns undef
  my ($self, $x, $y, $edge) = @_;

  # got an edge object? Don't add it twice!
  return undef if ref($edge);

  # turn plaintext scalars into objects 
  $x = $self->{nodes}->{$x} unless ref $x;
  $y = $self->{nodes}->{$y} unless ref $y;

  # nodes do exist => maybe the edge also exists
  if (ref($x) && ref($y))
    {
    my @ids = $x->edges_to($y);

    return undef if @ids;	# found already one edge?
    }

  $self->add_edge($x,$y,$edge);
  }

sub edge
  {
  # return an edge between two nodes as object
  my ($self, $x, $y) = @_;

  # turn plaintext scalars into objects 
  $x = $self->{nodes}->{$x} unless ref $x;
  $y = $self->{nodes}->{$y} unless ref $y;

  # node does not exist => edge does not exist
  return undef unless ref($x) && ref($y);

  my @ids = $x->edges_to($y);
  
  wantarray ? @ids : $ids[0];
  }

sub node
  {
  # return node by name
  my ($self,$name) = @_;
  $name = '' unless defined $name;

  $self->{nodes}->{$name};
  }

#############################################################################
# attribute handling

sub border_attribute
  {
  # Return "1px solid red" from the border-(style|color|width) attributes,
  # mainly used by as_txt() output. Does not use colorscheme!
  my ($self, $class) = @_;

  my ($style,$width,$color);

  if (defined $class)
    {
    $style = $self->attribute($class, 'border-style') || '';
    return $style if $style eq 'none';

    $width = $self->attribute($class, 'border-width') || '';
    $color = $self->attribute($class, 'border-color') || '';
    }
  else 
    {
    $style = $self->{att}->{'border-style'} || '';
    return $style if $style =~ /^(none|)\z/;
    $width = $self->{att}->{'border-width'} || '';
    $color = $self->{att}->{'border-color'} || '';
    }
  Graph::Easy::_border_attribute($style, $width, $color);
  }

sub color_attribute
  {
  # Just like get_attribute(), but for colors, and returns them as hex,
  # using the current colorscheme.
  my ($self, $class, $att) = @_;

  # allow calls of $self->color_attribute('fill') on Graph::Easy:
  ($class,$att) = ('graph',$class) unless defined $att;

  my $color = $self->get_attribute($class,$att);

  return $color unless defined $color;

  if ($color !~ /^#/ && $color ne '')
    {
    my $scheme = $self->attribute('colorscheme') || 'w3c';
    $color = Graph::Easy->color_as_hex($color, $scheme);
    }

  $color;
  }

sub get_attribute
  {
  # return the value of attribute $att from class $class
  my ($self, $class, $att) = @_;

  # allow calls of the style get_attribute('background');
  if (scalar @_ == 2)
    {
    $att = $class; $class = 'graph';
    }

  return $self->border_attribute($class) if $att eq 'border'; # virtual attribute

  return $self->{class} if $att eq 'class' && $class ne 'graph';

  my $a = $self->{att};
  return undef unless exists $a->{$class} && exists $a->{$class}->{$att};
  $a->{$class}->{$att};
  }

sub set_attribute
  {
  my ($self, $class, $name, $val) = @_;

  # allow calling in the style of $graph->set_attribute($name,$val);
  if (@_ == 3)
    {
    $val = $name;
    $name = $class;
    $class = 'graph';
    }

  $name = 'undef' unless defined $name;
  $val = 'undef' unless defined $val;

  # allowed classes and subclasses (except graph)
  if ($class !~ /^(node|group|edge|graph\z)/)
    {
    return $self->error ("Illegal class '$class' when trying to set attribute '$name' to '$val'");
    }

  $val = $self->unquote_attribute($class,$name,$val);

  if ($self->{strict})
    {
    my $v = $self->valid_attribute($name,$val,$class);

    # catch [] (invalid) and [ "red", "green" ] (multi-attribute on single object)
    if (ref($v) eq 'ARRAY')
      {
      $self->error("Error: '$name' is not a valid attribute for $class");
      return;
      }
    if (!defined $v)
      {
      $self->error("Error in attribute: '$val' is not a valid $name for $class");
      return;
      }
    $val = $v;
    }

  $self->{score} = undef;	# invalidate layout to force a new layout

  # handle special attribute 'gid' like in "graph { gid: 123; }"
  if ($class eq 'graph')
    {
    if ($name eq 'gid')
      {
      $self->{id} = $val;
      }
    # handle special attribute 'output' like in "graph { output: ascii; }"
    if ($name eq 'output')
      {
      $self->{output_format} = $val;
      }
    }

  if ($name eq 'border')
    {
    my $c = $self->{att}->{$class};

    my @rc = $self->split_border_attributes( $val ); 
    $c->{'border-style'} = $rc[0] if defined $rc[0];
    $c->{'border-width'} = $rc[1] if defined $rc[1];
    $c->{'border-color'} = $rc[2] if defined $rc[2];

    return $val;
    }

  $self->{att}->{$class}->{$name} = $val;
  }

sub set_attributes
  {
  my ($self, $class, $att) = @_;

  # if called as $graph->set_attributes( { color => blue } ), assume
  # class eq 'graph'

  if (defined $class && !defined $att)
    {
    $att = $class; $class = 'graph';
    }

  # allowed classes and subclasses (except graph)
  if ($class !~ /^(node|group|edge|graph\z)/)
    {
    return $self->error ("Illegal class '$class' when setting attributes");
    }

  # create class
  $self->{att}->{$class} = {} unless ref($self->{att}->{$class}) eq 'HASH';

  foreach my $a (keys %$att)
    {
    $self->set_attribute($class, $a, $att->{$a});
    } 
  $self;
  }

sub del_attribute ($$$)
  {
  my ($self, $class, $atr) = @_;

  delete $self->{att}->{$class}->{$atr};
  $self;
  }

#############################################################################
#############################################################################
# output (as_ascii, as_html) routines; as_txt() is in As_txt.pm

sub output_format
  {
  # set the output format
  my $self = shift;

  $self->{output_format} = shift if $_[0];
  $self->{output_format};
  }

sub output
  {
  # general output routine, to output the graph as the format that was
  # specified in the graph source itself
  my $self = shift;

  no strict 'refs';

  my $method = 'as_' . $self->{output_format};

  $self->_croak("Cannot find a method to generate '$self->{output_format}'")
    unless $self->can($method);

  $self->$method();
  }

sub _class_styles
  {
  # Create the style sheet with the class lists. This is used by both
  # css() and As_svg(). $skip is a qr// object that returns true for
  # attribute names to be skipped (e.g. excluded), and $map is a
  # HASH that contains mapping for attribute names for the output (only
  # used by As_svg()).
  # "$base" is the basename for classes (either "table.graph$id" if 
  # not defined, or whatever you pass in, like "" for svg).
  # $indent is a left-indenting spacer like "  ".
  # $overlay contains a HASH with attribute-value pairs to set as defaults.

  my ($self, $skip, $map, $base, $indent, $overlay) = @_;

  my $a = $self->{att};

  $indent = '' unless defined $indent;
  my $indent2 = $indent x 2; $indent2 = '  ' if $indent2 eq '';

  if (defined $overlay)
    {
    $a = {};

    # make a copy from $self->{att} to $a:

    for my $class (keys %{$self->{att}})
      {
      my $ac = $self->{att}->{$class};
      $a->{$class} = {};
      my $acc = $a->{$class};
      for my $k (keys %$ac)
        {
        $acc->{$k} = $ac->{$k};
        }
      # add the exra keys
      my $oc = $overlay->{$class};
      for my $k (keys %$oc)
        {
        $acc->{$k} = $oc->{$k} unless exists $acc->{$k};
        }
      }
    }

  my $id = $self->{id};

  my $class_list = { edge => {}, node => {}, group => {} };
  foreach my $primary (qw/edge node group/)
    {
    my $cl = $class_list->{$primary};			# shortcut
    foreach my $class (sort keys %$a)
      {
      if ($class =~ /^$primary\.(.*)/)
        {
        $cl->{$1} = undef;				# note w/o doubles
        }
      }
    }

  $base = "table.graph$id " unless defined $base;

  my $groups = $self->groups();				# do we have groups?

  my $css = '';
  foreach my $class (sort keys %$a)
    {
    next if keys %{$a->{$class}} == 0;			# skip empty ones

    my $c = $class; $c =~ s/\./-/g;			# node.city => node-city

    next if $class eq 'graph' and $base eq '';
    next if $class eq 'group' and $groups == 0;

    my $css_txt = '';
    my $cls = '';
    if ($class eq 'graph')
      {
      $css_txt .= "$indent$base\{\n";
      }
    else
      {
      if ($c !~ /\./)					# one of our primary ones
        {
        # generate also class list 			# like: "cities,node-rivers"
        $cls = join (",$base .$c-", sort keys %{ $class_list->{$c} });
        $cls = ", $base.$c-$cls" if $cls ne '';		# like: ",node-cities,node-rivers"
        }
      $css_txt .= "$indent$base.$c$cls {\n";
      }
    my $done = 0;
    foreach my $att (sort keys %{$a->{$class}})
      {
      # should be skipped?
      next if $att =~ $skip || $att eq 'border';

      # do not specify attribtes for the entire graph (only for the label)
      next if $class eq 'graph' && $att =~ /^(color|font|font-size|align|fill)\z/;

      $done++;						# how many did we really?
      my $val = $a->{$class}->{$att};

      # for groups, set to none, it will be later overriden for the different
      # cells (like "ga") with a border only on the appropriate side:
      $val = 'none' if $att eq 'border-style' && $class eq 'group';
      # fix border-widths to be in pixel
      $val .= 'px' if $att eq 'border-width' && $val !~ /(px|em|%)\z/;

      # change attribute name/value?
      if (exists $map->{$att})
	{
        $att = $map->{$att} unless ref $map->{$att};	# change attribute name?
        ($att,$val) = &{$map->{$att}}($self,$att,$val) if ref $map->{$att};
	}
      $css_txt .= "$indent2$att: $val;\n" if defined $att;
      }

    $css_txt .= "$indent}\n";
    $css .= $css_txt if $done > 0;			# skip if no attributes at all
    }
  $css;
  }

sub _skip
  {
  # return a regexp that specifies which attributes to suppress in CSS
  my ($self) = shift;

  # skip these for CSS
  qr/^(basename|columns|colorscheme|flow|format|rows|root|size|offset|origin|label|link|linkbase|(auto)?(link|title)|(node|edge)class|shape|arrow-style|label-color|point-style|text-style|style)\z/;
  }

sub _remap_text_wrap
  {
  my ($self,$name,$style) = @_;

  return (undef,undef) if $style eq 'none';

  # make text wrap again
  ('white-space','normal');
  }

sub css
  {
  my $self = shift;

  my $a = $self->{att};
  my $id = $self->{id};

  # for each primary class (node/group/edge) we need to find all subclasses,
  # and list them in the CSS, too. Otherwise "node-city" would not inherit
  # the attributes from "node".

  my $css = $self->_class_styles( $self->_skip(),
    {
      fill => 'background',
      'text-wrap' => \&_remap_text_wrap,
      align => 'text-align',
      font => 'font-family',
    }, undef, undef, 
    {
      graph => {
        'empty-cells' => 'show',
      },
    } );

  my @groups = $self->groups();

  # Set attributes for all TDs that start with "group" (hyphen seperated,
  # so that group classes are something like "group-cities". The second rule
  # is for all TD without any class at all (these are the "filler" cells):
  $css .= <<CSS
table.graph##id## td[class|="group"] { padding: 0.2em; }
CSS
  if scalar @groups > 0;

  $css .= <<CSS
table.graph##id## td {
  padding: 2px;
  background: inherit;
  white-space: nowrap;
  }
table.graph##id## span.l { float: left; }
table.graph##id## span.r { float: right; }
CSS
;

  # count anon nodes and append CSS for them if nec.
  $css .= <<CSSANON
table.graph##id## .node-anon {
  border: none;
  }
CSSANON
 if $self->anon_nodes() > 0;

  # append CSS for edge cells (and their parts like va (vertical arrow
  # (left/right), vertical empty), etc)

  # hat - arrow pointing up
  # eb	- empty bottom
  # v	- arrow pointing down
  # el  - (vertical) empty left space of ver edge
  #       or empty vertical space on hor edge starts
  # lh  - edge label horizontal
  # lv  - edge label vertical
  # sv  - shifted arrow vertical
  # sh  - shifted arrow horizontal (right)
  # shl  - shifted arrow horizontal (left)

  $css .= <<CSS
table.graph##id## .va {
  vertical-align: center;
  line-height: 1.5em;
  width: 0.4em;
  }
table.graph##id## .el {
  width: 0.1em;
  max-width: 0.1em;
  min-width: 0.1em;
  }
table.graph##id## .lh, table.graph##id## .lv {
  font-size: 0.8em;
  padding-left: 0.4em;
  }
table.graph##id## .v, table.graph##id## .hat, table.graph##id## .sv {
  text-align: left;
  height: 0.5em;
  line-height: 0.6em;
  }
table.graph##id## .sv {
  position: relative;
  left: -0.5em;
  overflow: visible;
  }
table.graph##id## .sh, table.graph##id## .shl {
  position: relative;
  top: 0.8em;
  left: -0.2em;
  vertical-align: bottom;
  overflow: visible;
  }
table.graph##id## .shl {
  left: 0.2em;
  }
table.graph##id## .hat {
  padding-top: 0.5em;
  line-height: 0.5em;
  }
table.graph##id## .eb {
  max-height: 0.4em;
  line-height: 0.4em;
  }
CSS
  # if we have edges
  if keys %{$self->{edges}}  > 0;

  # append CSS for group cells (only if we actually have groups)

  if (@groups > 0)
    {
    foreach my $group (@groups)
      {
      my $class = $group->{class};

      my $border = $group->attribute('border-style') || 'none'; 

      $class =~ s/.*\.//;	# leave only subclass
      $css .= Graph::Easy::Group::Cell->_css($self->{id}, $class, $border); 
      }
    }

  # replace the id with either '' or '123', depending on our ID
  $css =~ s/##id##/$id/g;

  $css;
  }

sub html_page_header
  {
  # return the HTML header for as_html_file()
  my ($self, $css) = @_;
  
  my $html = <<HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
 <head>
 <meta http-equiv="Content-Type" content="text/html; charset=##charset##">
 <title>##title##</title>##CSS##
</head>
<body bgcolor=white text=black>
HTML
;

  $html =~ s/\n\z//;
  $html =~ s/##charset##/utf-8/g;
  my $t = $self->title();
  $html =~ s/##title##/$t/g;

  # insert CSS if requested
  $css = $self->css() unless defined $css;

  $html =~ s/##CSS##/\n <style type="text\/css">\n <!--\n $css -->\n <\/style>/ if $css ne '';
  $html =~ s/##CSS##//;

  $html;
  }

sub title
  {
  my $self = shift;

  my $title = $self->{att}->{graph}->{title};
  $title = $self->{att}->{graph}->{label} if !defined $title;
  $title = 'Untitled graph' if !defined $title;

  $title;
  }

sub html_page_footer
  {
  # return the HTML footer for as_html_file()
  my $self = shift;

  "\n</body></html>\n";
  }

sub as_html_file
  {
  my $self = shift;

  $self->layout() unless defined $self->{score};

  $self->html_page_header() . $self->as_html() . $self->html_page_footer();
  }

#############################################################################

sub _caption
  {
  # create the graph label as caption
  my $self = shift;

  my ($caption,$switch_to_center) = $self->_label_as_html();

  return ('','') unless defined $caption && $caption ne '';

  my $bg = $self->color_attribute('graph','fill') || '';

  my $style = ' style="';
  $style .= "background: $bg;" if $bg ne '';
    
  # the font family
  my $f = $self->attribute('graph','font') || '';
  $style .= "font-family: $f;" if $f ne '';

  # the text color
  my $c = $self->color_attribute('graph','color') || '';
  $style .= "color: $c;" if $c ne '';

  # bold, italic, underline, incl. fontsize and align
  $style .= $self->text_styles_as_css();

  $style =~ s/;\z//;				# remove last ';'
  $style .= '"' unless $style eq ' style="';

  $style =~ s/style="\s/style="/;		# remove leading space

  my $link = $self->link();

  if ($link ne '')
    {
    # encode critical entities
    $link =~ s/\s/\+/g;				# space
    $link =~ s/'/%27/g;				# replace quotation marks
    $caption = "<a href='$link'>$caption</a>";
    }

  $caption = "<tr>\n  <td colspan=##cols##$style>$caption</td>\n</tr>\n";

  my $pos = $self->attribute('graph','label-pos') || 'top';

  ($caption,$pos);
  } 

sub as_html
  {
  # convert the graph to HTML+CSS
  my ($self) = shift;

  $self->layout() unless defined $self->{score};

  my $top = "\n";

  my $cells = $self->{cells};
  my ($rows,$cols);
  
  my $max_x = undef;
  my $min_x = undef;

  # find all x and y occurances to sort them by row/columns
  for my $k (keys %$cells)
    {
    my ($x,$y) = split/,/, $k;
    my $node = $cells->{$k};

    $max_x = $x if !defined $max_x || $x > $max_x;
    $min_x = $x if !defined $min_x || $x < $min_x;
    
    # trace the rows we do have
    $rows->{$y}->{$x} = $node;
    # record all possible columns
    $cols->{$x} = undef;
    }
  
  $max_x = 1, $min_x = 1 unless defined $max_x;
  
  # number of cells in the table, maximum  
  my $max_cells = $max_x - $min_x + 1;
  
  my $groups = scalar $self->groups();

  my $id = $self->{id};

  $top .=  "\n<table class=\"graph$id\" cellpadding=0 cellspacing=0";
  $top .= ">\n";

  my $html = '';

  # prepare the graph label
  my ($caption,$pos) = $self->_caption();

  # now run through all rows, and for each of them through all columns 
  for my $y (sort { ($a||0) <=> ($b||0) } keys %$rows)
    {

    # four rows at a time
    my $rs = [ [], [], [], [] ];

    # for all possible columns
    for my $x (sort { $a <=> $b } keys %$cols)
      {
      if (!exists $rows->{$y}->{$x})
	{
	# fill empty spaces with undef, butnot for parts of multicelled objects:
	push @{$rs->[0]}, undef;
	next;
	}
      my $node = $rows->{$y}->{$x};
      next if $node->isa('Graph::Easy::Node::Cell');		# skip empty cells

      # print STDERR "rendering $node->{x},$node->{y} ref($node)\n";

      my $h = $node->as_html();

      if (ref($h) eq 'ARRAY')
        {
        my $i = 0;
        #print STDERR '# expected 4 rows, but got ' . scalar @$h if @$h != 4;
	local $_;
        push @{$rs->[$i++]}, $_ for @$h;
        }
      else
        {
        push @{$rs->[0]}, $h;
        }
      }

    ######################################################################
    # remove trailing empty tag-pairs, then replace undef with empty tags

    for my $row (@$rs)
      {
      pop @$row while (@$row > 0 && !defined $row->[-1]);
      foreach (@$row)
        {
        $_ = " <td colspan=4 rowspan=4></td>\n" unless defined $_;
        }
      }

    # now combine equal columns to shorten output
    for my $row (@$rs)
      {
#     next;

      # append row to output
      my $i = 0;
      while ($i < @$row)
        {
        next if $row->[$i] =~ /border[:-]/;
#        next if $row->[$i] !~ />(\&nbsp;)?</;	# non-empty?
        next if $row->[$i] =~ /span /;		# non-empty?
        next if $row->[$i] =~ /^(\s|\n)*\z/;	# empty?

	# Combining these cells shows wierd artefacts when using the Firefox
	# WebDeveloper toolbar and outlining table cells, but it does not
	# seem to harm rendering in browsers:
        #next if $row->[$i] =~ /class="[^"]+ eb"/;	# is class=".. eb"

	# contains wo succ. cell?
        next if $row->[$i] =~ /(row|col)span.*\1span/m;	

        # count all sucessive equal ones
        my $j = $i + 1;

        $j++ while ($j < @$row && $row->[$j] eq $row->[$i]); # { $j++; }

        if ($j > $i + 1)
          {
          my $cnt = $j - $i - 1;

#         print STDERR "combining row $i to $j ($cnt) (\n'$row->[$i]'\n'$row->[$i+1]'\n'$row->[$j-1]'\n";

          # throw away
          splice (@$row, $i + 1, $cnt);

          # insert empty colspan if not already there
          $row->[$i] =~ s/<td/<td colspan=0/ unless $row->[$i] =~ /colspan/;
          # replace
          $row->[$i] =~ s/colspan=(\d+)/'colspan='.($1+$cnt*4)/e;
          }
        } continue { $i++; }
      }

    ######################################################################
    
    for my $row (@$rs)
      {
      # append row to output
      my $r = join('',@$row);

      if ($r !~ s/^[\s\n]*\z//)
	{
        # non empty rows get "\n</tr>"
        $r = "\n" . $r; # if length($r) > 0;
        }

      $html .= '<tr>' . $r . "</tr>\n\n";
      }
    }

  ###########################################################################
  # finally insert the graph label
  $max_cells *= 4;					# 4 rows for each cell
  $caption =~ s/##cols##/$max_cells/ if defined $caption;

  $html .= $caption if $pos eq 'bottom';
  $top .= $caption if $pos eq 'top';

  $html = $top . $html;

  # remove empty trailing <tr></tr> pairs
  $html =~ s#(<tr></tr>\n\n)+\z##;

  $html .= "</table>\n";
 
  $html;
  } 

############################################################################# 
# as_boxart_*
  
sub as_boxart
  {
  # Create box-drawing art using Unicode characters - will return utf-8.
  my ($self) = shift;

  require Graph::Easy::As_ascii;
  
  # select unicode box drawing characters
  $self->{_ascii_style} = 1;

  $self->_as_ascii(@_);
  }

sub as_boxart_html
  {
  # Output a box-drawing using Unicode, then return it as a HTML chunk
  # suitable to be embedded into an HTML page.
  my ($self) = shift;

  "<pre style='line-height: 1em; line-spacing: 0;'>\n" . 
    $self->as_boxart(@_) . 
    "\n</pre>\n";
  }

sub as_boxart_html_file
  {
  my $self = shift;

  $self->layout() unless defined $self->{score};

  $self->html_page_header(' ') . "\n" . 
    $self->as_boxart_html() . $self->html_page_footer();
  }

#############################################################################
# as_ascii_*

sub as_ascii
  {
  # Convert the graph to pretty ASCII art - will return utf-8.
  my $self = shift;

  # select 'ascii' characters
  $self->{_ascii_style} = 0;

  $self->_as_ascii(@_);
  }

sub _as_ascii
  {
  # Convert the graph to pretty ASCII or box art art - will return utf-8.
  my $self = shift;

  require Graph::Easy::As_ascii;
  require Graph::Easy::Layout::Grid;

  my $opt = ref($_[0]) eq 'HASH' ? $_[0] : { @_ };

  # include links?
  $self->{_links} = $opt->{links};

  $self->layout() unless defined $self->{score};

  # generate for each cell the width/height etc

  my ($rows,$cols,$max_x,$max_y) = $self->_prepare_layout('ascii');
  my $cells = $self->{cells};

  # offset where to draw the graph (non-zero if graph has label)
  my $y_start = 0;
  my $x_start = 0;

  my $align = $self->attribute('align') || 'center';

  # get the label lines and their alignment
  my ($label,$aligns) = $self->_aligned_label($align);

  # if the graph has a label, reserve space for it
  my $label_pos = 'top';
  if (@$label > 0)
    {
    # insert one line over and below
    unshift @$label, '';   push @$label, '';
    unshift @$aligns, 'c'; push @$aligns, 'c';

    $label_pos = $self->attribute('graph','label-pos') || 'top';
    $y_start += scalar @$label if $label_pos eq 'top';
    $max_y += scalar @$label + 1;
    print STDERR "# Graph with label, position $label_pos\n" if $self->{debug};

    my $old_max_x = $max_x;
    # find out the dimensions of the label and make sure max_x is big enough
    for my $l (@$label)
      {
      $max_x = length($l)+2 if (length($l) > $max_x+2);
      }
    $x_start = int(($max_x - $old_max_x) / 2);
    }

  print STDERR "# Allocating framebuffer $max_x x $max_y\n" if $self->{debug};

  # generate the actual framebuffer for the output
  my $fb = Graph::Easy::Node->_framebuffer($max_x, $max_y);

  # output the label
  if (@$label > 0)
    {
    my $y = 0; $y = $max_y - scalar @$label if $label_pos eq 'bottom';
    Graph::Easy::Node->_printfb_aligned($fb, 0, $y, $max_x, $max_y, $label, $aligns, 'top');
    }

  # draw all cells into framebuffer
  foreach my $v (values %$cells)
    {
    next if $v->isa('Graph::Easy::Node::Cell');		# skip empty cells

    # get as ASCII box
    my $x = $cols->{ $v->{x} } + $x_start;
    my $y = $rows->{ $v->{y} } + $y_start;
 
    my @lines = split /\n/, $v->as_ascii($x,$y);
    # get position from cell
    for my $i (0 .. scalar @lines-1)
      {
      next if length($lines[$i]) == 0;
      # XXX TODO: framebuffer shouldn't be to small!
      $fb->[$y+$i] = ' ' x $max_x if !defined $fb->[$y+$i];
      substr($fb->[$y+$i], $x, length($lines[$i])) = $lines[$i]; 
      }
    }

  for my $y (0..$max_y)
    {
    $fb->[$y] = '' unless defined $fb->[$y];
    $fb->[$y] =~ s/\s+\z//;		# remove trailing whitespace
    }
  my $out = join("\n", @$fb) . "\n";

  $out =~ s/\n+\z/\n/;		# remove trailing empty lines

  # restore height/width of cells from minw/minh
  foreach my $v (values %$cells)
    {
    $v->{h} = $v->{minh};
    $v->{w} = $v->{minw};
    } 
  $out;				# return output
  }

sub as_ascii_html
  {
  # Convert the graph to pretty ASCII art, then return it as a HTML chunk
  # suitable to be embedded into an HTML page.
  my ($self) = shift;

  "<pre>\n" . $self->_as_ascii(@_) . "\n</pre>\n";
  }

#############################################################################
# as_txt, as_graphviz and as_svg

sub as_graphviz
  {
  require Graph::Easy::As_graphviz;

  _as_graphviz(@_);
  }

sub as_debug
  {
  require Graph::Easy::As_txt;
  eval { require Graph::Easy::As_svg; };

  my $self = shift;

  my $output = '';
 
  $output .= '# Using Graph::Easy v' . $Graph::Easy::VERSION . "\n";
  if ($Graph::Easy::As_svg::VERSION)
    {
    $output .= '# Using Graph::Easy::As_svg v' . $Graph::Easy::As_svg::VERSION . "\n";
    }
  $output .= '# Running Perl v' . $] . " under $^O\n";

  $output . "\n# Input normalized as_txt:\n\n" . $self->_as_txt(@_);
  }

sub as_svg
  {
  require Graph::Easy::As_svg;
  require Graph::Easy::Layout::Grid;

  _as_svg(@_);
  }

sub as_svg_file
  {
  require Graph::Easy::As_svg;
  require Graph::Easy::Layout::Grid;

  _as_svg( $_[0], { standalone => 1 } );
  }

sub svg_information
  {
  my ($self) = @_;

  require Graph::Easy::As_svg;
  require Graph::Easy::Layout::Grid;

  # if it doesn't exist, render as SVG and thus create it
  _as_svg(@_) unless $self->{svg_info};

  $self->{svg_info};
  }

sub as_txt
  {
  require Graph::Easy::As_txt;

  _as_txt(@_);
  }

#############################################################################

sub add_edge
  {
  my ($self,$x,$y,$edge) = @_;
 
  my $uc = $self->{use_class};
 
  $edge = $uc->{edge}->new() unless defined $edge;
  $edge = $uc->{edge}->new(label => $edge) unless ref($edge);

  $self->_croak("Adding an edge object twice is not possible")
    if (exists ($self->{edges}->{$edge->{id}}));

  $self->_croak("Cannot add edge $edge ($edge->{id}), it already belongs to another graph")
    if ref($edge->{graph}) && $edge->{graph} != $self;

  my $nodes = $self->{nodes};
  my $groups = $self->{groups};

  my $xn = $x; my $yn = $y;
  $xn = $x->{name} if ref($x);
  $yn = $y->{name} if ref($y);

  # convert plain scalars to Node objects if nec.
  $x = $nodes->{$xn} if exists $nodes->{$xn};		# first look them up
  $y = $nodes->{$yn} if exists $nodes->{$yn};

  $x = $uc->{node}->new( $x ) unless ref $x;		# if this fails, create
  $y = $x if !ref($y) && $y eq $xn;			# make add_edge('A','A') work
  $y = $uc->{node}->new( $y ) unless ref $y;

  print STDERR "# add_edge '$x->{name}' ($x->{id}) -> '$y->{name}' ($y->{id}) (edge $edge->{id})\n" if $self->{debug};

  for my $n ($x,$y)
    {
    $self->_croak("Cannot add node $n ($n->{name}), it already belongs to another graph")
      if ref($n->{graph}) && $n->{graph} != $self;
    }

  # Register the nodes and the edge with our graph object
  # and weaken the references. Be carefull to not needlessly
  # override and weaken again an already existing reference, this
  # is an O(N) operation in most Perl versions, and thus very slow.

  weaken($x->{graph} = $self) unless ref($x->{graph});
  weaken($y->{graph} = $self) unless ref($y->{graph});
  weaken($edge->{graph} = $self) unless ref($edge->{graph});

  # Store at the edge from where to where it goes for easier reference
  $edge->{from} = $x;
  $edge->{to} = $y;
 
  # store the edge at the nodes/groups, too
  $x->{edges}->{$edge->{id}} = $edge;
  $y->{edges}->{$edge->{id}} = $edge;

  # index nodes by their name so that we can find $x from $x->{name} fast
  my $store = $nodes; $store = $groups if $x->isa('Graph::Easy::Group');
  $store->{$x->{name}} = $x;
  $store = $nodes; $store = $groups if $y->isa('Graph::Easy::Group');
  $store->{$y->{name}} = $y;

  # index edges by "id1,id2,edgeid" so we can find them fast
  $self->{edges}->{$edge->{id}} = $edge;

  $self->{score} = undef;			# invalidate last layout

  wantarray ? ($x,$y,$edge) : $edge;
  }

sub add_node
  {
  my ($self,$x) = @_;

  my $n = $x;
  if (ref($x))
    {
    $n = $x->{name}; $n = '0' unless defined $n;
    }

  $self->_croak("Cannot add node with empty name to graph.") if $n eq '';

  $self->_croak("Cannot add node $x ($n), it already belongs to another graph")
    if ref($x) && ref($x->{graph}) && $x->{graph} != $self;

  my $no = $self->{nodes};
  return $no->{$n} if exists $no->{$n};

  my $uc = $self->{use_class};
  $x = $uc->{node}->new( $x ) unless ref $x;

  # store the node
  $no->{$n} = $x;

  # Register the nodes and the edge with our graph object
  # and weaken the references. Be carefull to not needlessly
  # override and weaken again an already existing reference, this
  # is an O(N) operation in most Perl versions, and thus very slow.

  if (!ref($x->{graph}))
    {
    $x->{graph} = $self;
    weaken($x->{graph});
    }

  $self->{score} = undef;			# invalidate last layout

  $x;
  }

#############################################################################
# merging

sub merge_nodes
  {
  # Merge two nodes, by dropping all connections between them, and then
  # drawing all connections from/to $B to $A, then drop $B
  my ($self, $A, $B) = @_;

  $A = $self->node($A) unless ref($A);
  $B = $self->node($B) unless ref($B);

  # if the node is part of a group, deregister it first from there
  $B->{group}->del_node($B) if ref($B->{group});

  my @edges = values %{$A->{edges}};

  # drop all connections from A --> B
  for my $edge (@edges)
    {
    next unless $edge->{to} == $B;

#    print STDERR "# dropping $edge->{from}->{name} --> $edge->{to}->{name}\n";
    $self->del_edge($edge);
    }

  # Move all edges from/to B over to A, but drop "B --> B" and "B --> A".
  for my $edge (values %{$B->{edges}})
    {
    # skip if going from B --> A or B --> B
    next if $edge->{to} == $A || ($edge->{to} == $B && $edge->{from} == $B);

#    print STDERR "# moving $edge->{from}->{name} --> $edge->{to}->{name} to ";

    $edge->{from} = $A if $edge->{from} == $B;
    $edge->{to} = $A if $edge->{to} == $B;

#   print STDERR " $edge->{from}->{name} --> $edge->{to}->{name}\n";

    delete $B->{edges}->{$edge->{id}};
    $A->{edges}->{$edge->{id}} = $edge;
    }

  $self->del_node($B);

  $self;
  }

#############################################################################
# deletion

sub del_node
  {
  my ($self, $node) = @_;

  # make object
  $node = $self->{nodes}->{$node} unless ref($node);

  # doesn't exist, so we don't need to do anything
  return unless ref($node);

  # if node is part of a group, delete it there, too
  $node->{group}->del_node($node) if ref $node->{group};

  delete $self->{nodes}->{$node->{name}};

  # delete all edges from/to this node
  for my $edge (values %{$node->{edges}})
    {
    # drop the edge from our global edge list
    delete $self->{edges}->{$edge->{id}};
 
    my $to = $edge->{to}; my $from = $edge->{from};

    # drop the edge from the other node
    delete $from->{edges}->{$edge->{id}} if $from != $node;
    delete $to->{edges}->{$edge->{id}} if $to != $node;
    }

  # decouple node from the graph
  $node->{graph} = undef;
  # reset cached size
  $node->{w} = undef;

  # drop all edges from the node locally
  $node->{edges} = { };

  $self->{score} = undef;			# invalidate last layout

  $self;
  }

sub del_edge
  {
  my ($self, $edge) = @_;

  $self->_croak("del_edge() needs an object") unless ref $edge;

  # if edge is part of a group, delete it there, too
  $edge->{group}->del_edge($edge) if ref $edge->{group};

  my $to = $edge->{to}; my $from = $edge->{from};

  # delete the edge from the nodes
  delete $from->{edges}->{$edge->{id}};
  delete $to->{edges}->{$edge->{id}};
  
  # drop the edge from our global edge list
  delete $self->{edges}->{$edge->{id}};

  $edge->{from} = undef;
  $edge->{to} = undef;

  $self;
  }

#############################################################################
# group management

sub add_group
  {
  # add a group object
  my ($self,$group) = @_;

  my $uc = $self->{use_class};

  # group with that name already exists?
  my $name = $group; 
  $group = $self->{groups}->{ $group } unless ref $group;

  # group with that name doesn't exist, so create new one
  $group = $uc->{group}->new( name => $name ) unless ref $group;

  # index under the group name for easier lookup
  $self->{groups}->{ $group->{name} } = $group;

  # register group with ourself and weaken the reference
  $group->{graph} = $self;
  {
    no warnings; # dont warn on already weak references
    weaken($group->{graph});
  } 
  $self->{score} = undef;			# invalidate last layout

  $group;
  }

sub del_group
  {
  # delete group
  my ($self,$group) = @_;

  delete $self->{groups}->{ $group->{name} };
 
  $self->{score} = undef;			# invalidate last layout

  $self;
  }

sub group
  {
  # return group by name
  my ($self,$name) = @_;

  $self->{groups}->{ $name };
  }

sub groups
  {
  # return number of groups (or groups as object list)
  my ($self) = @_;

  return sort { $a->{name} cmp $b->{name} } values %{$self->{groups}}
    if wantarray;

  scalar keys %{$self->{groups}};
  }

sub use_class
  {
  # use the provided class for generating objects of the type $object
  my ($self, $object, $class) = @_;

  $self->_croak("Expected one of node, edge or group, but got $object")
    unless $object =~ /^(node|group|edge)\z/;

  $self->{use_class}->{$object} = $class;

  $self;  
  }

#############################################################################
#############################################################################
# Animation support

sub animation_as_graph
  {
  my $self = shift;

  my $graph = Graph::Easy->new();

  $graph->add_node('onload');

  # XXX TODO

  $graph;
  }

1;
__END__

=head1 NAME

Graph::Easy - Render graphs as ASCII, HTML, SVG or via Graphviz

=head1 SYNOPSIS

	use Graph::Easy;
	
	my $graph = Graph::Easy->new();

	$graph->add_edge ('Bonn', 'Berlin');

	# will not add it, since it already exists
	$graph->add_edge_once ('Bonn', 'Berlin');

	print $graph->as_ascii( );

	# prints:

	# +------+     +--------+
	# | Bonn | --> | Berlin |
	# +------+     +--------+

	# slightly more verbose way:

	my $graph = Graph::Easy->new();

	my $bonn = Graph::Easy->add_node('Bonn');
	$bonn->set_attribute('border', 'solid 1px black')

	my $berlin = $graph->add_node('Berlin');

	$graph->add_edge ($bonn, $berlin);

	print $graph->as_ascii( );

	# You can use plain scalars as node names and for the edge label:
	$graph->add_edge ('Berlin', 'Frankfurt', 'via train');

	# adding edges with attributes:

        my $edge = Graph::Easy::Edge->new();
	$edge->set_attributes(
                label => 'train',
                style => 'dotted',
                color => 'red',
        );

	# now with the optional edge object
	$graph->add_edge ($bonn, $berlin, $edge);

	# raw HTML section
	print $graph->as_html( );

	# complete HTML page (with CSS)
	print $graph->as_html_file( );

	# creating a graph from a textual description	
	use Graph::Easy::Parser;
	my $parser = Graph::Easy::Parser->new();

	my $graph = $parser->from_text(
		"[ Bonn ] => [ Berlin ] \n".
		"[ Bonn ] => [ Rostock ]"
	);

	print $graph->as_ascii( );

	# Outputs something like:

	# +------+       +---------+
	# | Bonn |   --> | Rostock |
	# +------+       +---------+
	#   |
	#   |
	#   v
	# +--------+
	# | Berlin |
	# +--------+

	# Other possibilities:

	# SVG (possible after you installed Graph::Easy::As_svg):
	print $graph->as_svg( );

	# Graphviz:
	my $graphviz = $graph->as_graphviz();
	`dot -Tpng -o graph.png $graphviz`;

=head1 DESCRIPTION

C<Graph::Easy> lets you generate graphs consisting of various shaped
nodes connected by edges (with optional labels).

It works on a grid (manhattan layout), and thus the output is
most usefull for flow charts, network diagrams, or hierarchy trees.

X<graph>
X<drawing>
X<diagram>
X<flowchart>
X<layout>
X<manhattan>

=head2 Input

Apart from driving the module with Perl code, you can also use
C<Graph::Easy::Parser> to parse graph descriptions like:

	[ Bonn ]      --> [ Berlin ]
	[ Frankfurt ] <=> [ Dresden ]
	[ Bonn ]      --  [ Frankfurt ]

See the C<EXAMPLES> section below for how this might be rendered.

=head2 Creating graphs

First, create a graph object:

	my $graph = Graph::Easy->new();

Then add a node to it:

	my $node = $graph->add_node('Koblenz');

Don't worry, adding the node again will do nothing:

	$node = $graph->add_node('Koblenz');

You can get back a node by its name with C<node()>:

	$node = $graph->node('Koblenz');

You can either add another node:

	my $second = $graph->node('Frankfurt');

Or add an edge straight-away:

	my ($first,$second,$edge) = $graph->add_edge('Mainz','Ulm');

Adding the edge the second time creates another edge from 'Mainz' to 'Ulm':

	my $other_edge;
	 ($first,$second,$other_edge) = $graph->add_edge('Mainz','Ulm');

This can be avoided by using C<add_edge_once()>:

	my $edge = $graph->add_edge_once('Mainz','Ulm');
	if (defined $edge)
	  {
	  # the first time the edge was added, so do something with it
	  $edge->set_attribute('color','blue');
	  }

You can set attributes on nodes and edges:

	$node->attribute('fill', 'yellow');
	$edge->attribute('label', 'train');

It is possible to add an edge with a label:

	$graph->add_edge('Cottbus', 'Berlin', 'my label');

You can also add self-loops:

	$graph->add_edge('Bremen','Bremen');

For more options please see the online manual at:

	http://bloodgate.com/perl/graph/manual/

=head2 Output

The output can be done in various styles:

=over 2

=item ASCII ART

Uses things like C<+>, C<-> C<< < >> and C<|> to render the boxes.

=item BOXART

Uses Unicode box art drawing elements to output the graph.

=item HTML

HTML tables with CSS making everything "pretty".

=item SVG

Creates a Scalable Vector Graphics output.

=item Graphviz

Creates graphviz code that can be feed to 'dot', 'neato' or similiar programs.

=back

X<ascii>
X<html>
X<svg>
X<boxart>
X<graphviz>
X<dot>
X<neato>

=head1 EXAMPLES

The following examples are given in the simple text format that is understood
by L<Graph::Easy::Parser|Graph::Easy::Parser>.

You can also see many more examples at:

L<http://bloodgate.com/perl/graph/>

=head2 One node

The most simple graph (apart from the empty one :) is a graph consisting of
only one node:

	[ Dresden ]

=head2 Two nodes

A simple graph consisting of two nodes, linked together by a directed edge:

	[ Bonn ] -> [ Berlin ]

=head2 Three nodes

A graph consisting of three nodes, and both are linked from the first:

	[ Bonn ] -> [ Berlin ]
	[ Bonn ] -> [ Hamburg ]

=head2 Three nodes in a chain

A graph consisting of three nodes, showing that you can chain connections together:

	[ Bonn ] -> [ Berlin ] -> [ Hamburg ]

=head2 Two not connected graphs

A graph consisting of two seperate parts, both of them not connected
to each other:

	[ Bonn ] -> [ Berlin ]
	[ Freiburg ] -> [ Hamburg ]

=head2 Three nodes, interlinked

A graph consisting of three nodes, and two of the are connected from
the first node:

	[ Bonn ] -> [ Berlin ]
	[ Berlin ] -> [ Hamburg ]
	[ Bonn ] -> [ Hamburg ]

=head2 Different edge styles

A graph consisting of a couple of nodes, linked with the
different possible edge styles.

	[ Bonn ] <-> [ Berlin ]		# bidirectional
	[ Berlin ] ==> [ Rostock ]	# double
	[ Hamburg ] ..> [ Altona ]	# dotted
	[ Dresden ] - > [ Bautzen ]	# dashed
	[ Leipzig ] ~~> [ Kirchhain ]	# wave
	[ Hof ] .-> [ Chemnitz ]	# dot-dash
	[ Magdeburg ] <=> [ Ulm ]	# bidrectional, double etc
	[ Magdeburg ] -- [ Ulm ]	# arrow-less edge

More examples at: L<http://bloodgate.com/perl/graph/>

=head1 ANIMATION SUPPORT

It is possible to add animations to a graph. This is done by
adding I<steps> via the pseudo-class C<step>:

	step.0 {
	  target: Bonn;		# find object with id=Bonn, or
				# if this fails, the node named
				# "Bonn".
	  animate: fill:	# animate this attribute
	  from: yellow;		# start value (0% of duration)
	  via: red;		# at 50% of the duration
	  to: yellow;		# and 100% of duration
	  wait: 0;		# after triggering, wait so many seconds
	  duration: 5;		# entire time to go from "from" to "to"
	  trigger: onload;	# when to trigger this animation
	  repeat: 2;		# how often to repeat ("2" means two times)
				# also "infinite", then "next" will be ignored
	  next: 1;		# which step to take after repeat is up
	}
	step.1 {
	  from: white;		# set to white
	  to: white;
	  duration: 0.1;	# 100ms
	  next: 0;		# go back to step.0
	}

Here two steps are created, I<0> and I<1> and the animation will
be going like this:

                               0.1s
	                     +-------------------------------+
	                     v                               |
	+--------+  0s   +--------+  5s   +--------+  5s   +--------+
	| onload | ----> | step.0 | ----> | step.0 | ----> | step.1 |
	+--------+       +--------+       +--------+       +--------+

You can generate a a graph with the animation flow via
C<animation_as_graph()>.

=head2 Output

Currently no output formats supports animations yet.

=head1 METHODS

C<Graph::Easy> supports the following methods:

=head2 new()

        use Graph::Easy;

        my $graph = Graph::Easy->new( );
        
Creates a new, empty C<Graph::Easy> object.

Takes optinal a hash reference with a list of options. The following are
valid options:

	debug			if true, enables debug output

=head2 error()

	my $error = $graph->error();

Returns the last error or '' for none.
Optionally, takes an error message to be set.

	$graph->error( 'Expected Foo, but found Bar.' );

=head2 add_edge()

	my ($first, $second, $edge) = $graph->add_edge( 'node 1', 'node 2');
	my $edge = $graph->add_edge( $x, $y, $edge);
	$graph->add_edge( $x, $y);

Add an edge between nodes X and Y. The optional edge object defines
the style of the edge, if not present, a default object will be used.

When called in scalar context, will return C<$edge>. In array/list context
it will return the two nodes and the edge object.

C<$x> and C<$y> should be either plain scalars with the names of
the nodes, or objects of L<Graph::Easy::Node|Graph::Easy::Node>,
while the optional C<$edge> should be L<Graph::Easy::Edge|Graph::Easy::Edge>.

Note: C<Graph::Easy> graphs are multi-edged, and adding the same edge
twice will result in two edges going from C<$x> to C<$y>! See
C<add_edge_once()> on how to avoid that.

You can also use C<edge()> to check whether an edge from X to Y already exists
in the graph.
 
=head2 add_edge_once()

	my ($first, $second, $edge) = $graph->add_edge_once( 'node 1', 'node 2');
	my $edge = $graph->add_edge_once( $x, $y, $edge);
	$graph->add_edge_once( $x, $y);

	if (defined $edge)
	  {
	  # got added once, so do something with it
	  $edge->set_attribute('label','unique');
	  }

Adds an edge between nodes X and Y, unless there exists already
an edge between these two nodes. See C<add_edge()>.

Returns undef when an edge between X and Y already exists.

When called in scalar context, will return C<$edge>. In array/list context
it will return the two nodes and the edge object.

=head2 add_node()

	my $node = $graph->add_node( 'Node 1' );
	$graph->add_node( $x );

Add a single node X to the graph. C<$x> should be either a
C<Graph::Easy::Node> object, or a unique name for the node. Will do
nothing if the node already exists in the graph.

It returns an C<Graph::Easy::Node> object.

=head2 del_node()

	$graph->del_node('Node name');
	$graph->del_node($node);

Delete the node with the given name from the graph.

=head2 del_edge()

	$graph->del_edge($edge);

Delete the given edge object from the graph. You can use C<edge()> to find
an edge from Node A to B:

	$graph->del_edge( $graph->edge('A','B') );

=head2 merge_nodes()

	$graph->merge_nodes( $first_node, $second_node );

Merge two nodes. Will delete all connections between the two nodes, then
move over any connection to/from the second node to the first, then delete
the second node from the graph.

Any set attributes on the second node will be lost.

=head2 get_attribute()

	my $value = $graph->get_attribute( $class, $name );

Return the value of attribute C<$name> from class C<$class>.

Example:

	my $color = $graph->attribute( 'node', 'color' );

=head2 attribute()

	my $value = $graph->attribute( $class, $name );

C<attribute> is an alias for L<get_attribute>.

=head2 color_attribute()

	# returns f.i. #ff0000
	my $color = $graph->get_color_attribute( 'node', 'color' );

Just like get_attribute(), but only for colors, and returns them as hex,
using the current colorscheme.

=head2 get_color_attribute()

Is an alias to C<color_attribute()>.

=head2 set_attribute()

	$graph->set_attribute( $class, $name, $val );

Sets a given attribute named C<$name> to the new value C<$val> in the class
specified in C<$class>.

Example:

	$graph->set_attribute( 'graph', 'gid', '123' );

The class can be one of C<graph>, C<edge>, C<node> or C<group>. The last
three can also have subclasses like in C<node.subclassname>.

=head2 set_attributes()

	$graph->set_attributes( $class, $att );

Given a class name in C<$class> and a hash of mappings between attribute names
and values in C<$att>, will set all these attributes.

The class can be one of C<graph>, C<edge>, C<node> or C<group>. The last
three can also have subclasses like in C<node.subclassname>.

Example:

	$graph->set_attributes( 'node', { color => 'red', background => 'none' } );

=head2 del_attribute()

	$graph->del_attribute('border');

Delete the attribute with the given name.

=head2 unquote_attribute()

	# returns '"Hello World!"'
	my $value = $self->unquote_attribute('node','label','"Hello World!"');
	# returns 'red'
	my $color = $self->unquote_attribute('node','color','"red"');

Return the attribute unquoted except for labels and titles.

=head2 border_attribute()

  	my $border = $graph->border_attribute();

Return the combined border attribute like "1px solid red" from the
border-(style|color|width) attributes.

=head2 split_border_attributes()

  	my ($style,$width,$color) = $graph->split_border_attribute($border);

Split the border attribute (like "1px solid red") into the three different parts.

=head2 source_nodes()

	my @roots = $graph->source_nodes();

Returns all nodes that have only outgoing edges, e.g. are the root of a tree,
in no particular order.

Isolated nodes (no edges at all) will B<not> be included, see
C<predecessorless_nodes()> to get these, too.

In scalar context, returns the number of source nodes.

=head2 predecessorless_nodes()

	my @roots = $graph->predecessorless_nodes();

Returns all nodes that have no incoming edges, regardless of whether
they have outgoing edges or not, in no particular order.

Isolated nodes (no edges at all) B<will> be included in the list.

See also C<source_nodes()>.

In scalar context, returns the number of predecessorless nodes.

=head2 timeout()

	print $graph->timeout(), " seconds timeout for layouts.\n";
	$graph->timeout(12);

Get/set the timeut for layouts in seconds. If the layout process did not
finish after that time, it will be stopped and a warning will be printed.

=head2 strict()

	print "Graph has strict checking\n" if $graph->strict();
	$graph->strict(undef);		# disable strict attribute checks

Get/set the strict option. When set to a true value, all attribute names and
values will be strictly checked and unknown/invalid one will be rejected.

This option is on by default.

=head2 layout()

	$graph->layout();

Creates the internal structures to layout the graph. 

This methods will be called automatically when you call any of the
C<as_FOO> methods or C<output()> as described below.

See also: C<timeout()>.

=head2 output_format()

	$graph->output_format('html');

Set the outputformat. One of 'html', 'ascii', 'graphviz', 'svg' or 'txt'.
See also C<output()>.

=head2 output()

	my $out = $graph->output();

Output the graph in the format set by C<output_format()>.

=head2 as_ascii()

	print $graph->as_ascii();

Return the graph layout in ASCII art, in utf-8.

=head2 as_ascii_file()

	print $graph->as_ascii_file();

Is an alias for C<as_ascii>.

=head2 as_ascii_html()

	print $graph->as_ascii_html();

Return the graph layout in ASCII art, suitable to be embedded into an HTML
page. Basically it wraps the output from L<as_ascii()> into
C<< <pre> </pre> >> and inserts real HTML links. The returned
string is in utf-8.

=head2 as_boxart()

	print $graph->as_box();

Return the graph layout as box drawing using Unicode characters in utf-8.

=head2 as_boxart_file()

	print $graph->as_boxart_file();

Is an alias for C<as_box>.

=head2 as_boxart_html()

	print $graph->as_boxart_html();

Return the graph layout as box drawing using Unicode characters,
as chunk that can be embedded into an HTML page.

Basically it wraps the output from L<as_boxart()> into
C<< <pre> </pre> >> and inserts real HTML links. The returned
string is in utf-8.

=head2 as_boxart_html_file()

	print $graph->as_boxart_html_file();

Return the graph layout as box drawing using Unicode characters,
as a full HTML page complete with header and footer.

=head2 as_html()

	print $graph->as_html();

Return the graph layout as HTML section. See L<css()> to get the
CSS section to go with that HTML code. If you want a complete HTML page
then use L<as_html_file()>.

=head2 as_html_page()

	print $graph->as_html_page();

Is an alias for C<as_html_file>.

=head2 as_html_file()

	print $graph->as_html_file();

Return the graph layout as HTML complete with headers, CSS section and
footer. Can be viewed in the browser of your choice.

=head2 add_group()

	my $group = $graph->add_group('Group name');

Add a group to the graph and return it as C<Graph::Easy::Group> object.

=head2 group()

	my $group = $graph->group('Name');

Returns the group with the name C<Name> as C<Graph::Easy::Group> object.

=head2 groups()

	my @groups = $graph->groups();

Returns the groups of the graph as C<Graph::Easy::Group> objects,
in arbitrary order.

=head2 del_group()

	$graph->del_group($name);

Delete the group with the given name.

=head2 edges()

	my @edges = $graph->edges();

Returns the edges of the graph as C<Graph::Easy::Edge> objects,
in arbitrary order.

=head2 is_simple_graph()

	if ($graph->is_simple_graph())
	  {
	  }

Returns true if the graph does not have multiedges.

=head2 label()

	my $label = $graph->label();

Returns the label of the graph.

=head2 title()

	my $title = $graph->title();

Returns the (mouseover) title of the graph.

=head2 link()

	my $link = $graph->link();

Return a potential link (for the graphs label), build from the attributes C<linkbase>
and C<link> (or autolink). Returns '' if there is no link.

=head2 as_graphviz()

	print $graph->as_graphviz();

Return the graph as graphviz code, suitable to be feed to a program like
C<dot> etc.

=head2 as_graphviz_file()

	print $graph->as_graphviz_file();

Is an alias for C<as_graphviz()>.

=head2 angle()

        my $degrees = Graph::Easy->angle( 'south' );
        my $degrees = Graph::Easy->angle( 120 );

Check an angle for being valid and return a value between -359 and 359
degrees. The special values C<south>, C<north>, C<west>, C<east>, C<up>
and C<down> are also valid and converted to degrees.

=head2 nodes()

	my $nodes = $graph->nodes();

In scalar context, returns the number of nodes/vertices the graph has.

In list context, returns all nodes as objects, in arbitrary order.

=head2 anon_nodes()

	my $anon_nodes = $graph->anon_nodes();

In scalar context, returns the number of anon nodes (aka
C<Graph::Easy::Node::Anon>) the graph has.

In list context, returns all anon nodes as objects, in arbitrary order.

=head2 html_page_header()

	my $header = $graph->html_page_header();
	my $header = $graph->html_page_header($css);

Return the header of an HTML page. Used together with L<html_page_footer>
by L<as_html_page> to construct a complete HTML page.

Takes an optional parameter with the CSS styles to be inserted into the
header. If C<$css> is not defined, embedds the result of C<< $self->css() >>.

=head2 html_page_footer()

	my $footer = $graph->html_page_footer();

Return the footer of an HTML page. Used together with L<html_page_header>
by L<as_html_page> to construct a complete HTML page.

=head2 css()

	my $css = $graph->css();

Return CSS code for that graph. See L<as_html()>.

=head2 as_txt()

	print $graph->as_txt();

Return the graph as a textual representation, that can be parsed with
C<Graph::Easy::Parser> back to a graph.

This does not call L<layout()> since the actual text representation
is more a dump of the graph, than a certain layout.

=head2 as_txt_file()

	print $graph->as_txt_file();

Is an alias for C<as_txt()>.

=head2 as_svg()

	print $graph->as_svg();

Return the graph as SVG (Scalable Vector Graphics), which can be
embedded into HTML pages. You need to install
C<Graph::Easy::As_svg> first to make this work.

See also C<as_svg_file()>.

=head2 as_svg_file()

	print $graph->as_svg_file();

Returns SVG just like C<as_svg()>, but this time as standalone SVG,
suitable for storing it in a file and referencing it externally.

After calling C<as_svg_file()> or C<as_svg()>, you can retrieve
some SVG information, notable C<width> and C<height> via
C<svg_information>.

=head2 svg_information()

	my $info = $graph->svg_information();

	print "Size: $info->{width}, $info->{height}\n";

Return information about the graph created by the last
C<as_svg()> or C<as_svg_file()> call.

The following fields are set:

	width		width of the SVG in pixels
	height		height of the SVG in pixels

=head2 sorted_nodes()

	my $nodes =
	 $graph->sorted_nodes( );		# default sort on 'id'
	my $nodes = 
	 $graph->sorted_nodes( 'name' );	# sort on 'name'
	my $nodes = 
	 $graph->sorted_nodes( 'layer', 'id' );	# sort on 'layer', then on 'id'

In scalar context, returns the number of nodes/vertices the graph has.
In list context returns a list of all the node objects (as reference),
sorted by their attribute(s) given as arguments. The default is 'id',
e.g. their internal ID number, which amounts more or less to the order
they have been inserted.

This routine will sort the nodes by their group first, so the requested
sort order will be only valid if there are no groups or inside each
group.

=head2 as_debug()

	print $graph->as_debug();

Return debugging information like version numbers of used modules,
and a textual representation of the graph.

This does not call L<layout()> since the actual text representation
is more a dump of the graph, than a certain layout.

=head2 node()

	my $node = $graph->node('node name');

Return node by unique name (case sensitive). Returns undef if the node
does not exist in the graph.

=head2 edge()

	my $edge = $graph->edge( $x, $y );

Returns the edge objects between nodes C<$x> and C<$y>. Both C<$x> and C<$y>
can be either scalars with names or C<Graph::Easy::Node> objects.

Returns undef if the edge does not yet exist.

In list context it will return all edges from C<$x> to C<$y>, in
scalar context it will return only one (arbitrary) edge.

=head2 id()

	my $graph_id = $graph->id();
	$graph->id('123');

Returns the id of the graph. You can also set a new ID with this routine. The
default is ''.

The graph's ID is used to generate unique CSS classes for each graph, in the
case you want to have more than one graph in an HTML page.

=head2 seed()

	my $seed = $graph->seed();
	$graph->seed(2);

Get/set the random seed for the graph object. See L<randomize()>
for a method to set a random seed.

The seed is used to create random numbers for the layouter. For
the same graph, the same seed will always lead to the same layout.

=head2 randomize()

	$graph->randomize();

Set a random seed for the graph object. See L<seed()>.

=head2 debug()

	my $debug = $graph->debug();	# get
	$graph->debug(1);		# enable
	$graph->debug(0);		# disable

Enable, disable or read out the debug status. When the debug status is true,
additional debug messages will be printed on STDERR.

=head2 score()

	my $score = $graph->score();

Returns the score of the graph, or undef if L<layout()> has not yet been called.

Higher scores are better, although you cannot compare scores for different
graphs. The score should only be used to compare different layouts of the same
graph against each other:

	my $max = undef;

	$graph->randomize();
	my $seed = $graph->seed(); 

	$graph->layout();
	$max = $graph->score(); 

	for (1..10)
	  {
	  $graph->randomize();			# select random seed
	  $graph->layout();			# layout with that seed
	  if ($graph->score() > $max)
	    {
	    $max = $graph->score();		# store the new max store
	    $seed = $graph->seed();		# and it's seed
	    }
	  }

	# redo the best layout
	if ($seed ne $graph->seed())
	  {
	  $graph->seed($seed);
	  $graph->layout();
	  }
	# output graph:
	print $graph->as_ascii();		# or as_html() etc

=head2 valid_attribute()

	my $new_value =
	  Graph::Easy->valid_attribute( $name, $value, $class );

	if (ref($new_value) eq 'ARRAY')
	  {
	  # throw error
          die ("'$name' is not a valid attribute name for '$class'");
	  }
	elsif (!defined $new_value)
	  {
	  # throw error
          die ("'$value' is no valid '$name' for '$class'");
	  }

Check that a C<$name,$value> pair is a valid attribute in class C<$class>,
and returns a new value.

The return value can differ from the passed in value, f.i.:

	print Graph::Easy->valid_attribute( 'color', 'red' );

This would print '#ff0000';

It returns an array ref if the attribute name is invalid, and undef if the
value is invalid.
	
=head2 color_as_hex()

	my $hexred   = Graph::Easy->color_as_hex( 'red' );
	my $hexblue  = Graph::Easy->color_as_hex( '#0000ff' );
	my $hexcyan  = Graph::Easy->color_as_hex( '#f0f' );
	my $hexgreen = Graph::Easy->color_as_hex( 'rgb(0,255,0)' );

Takes a valid color name or definition (hex, short hex, or RGB) and returns the
color in hex like C<#ff00ff>.

=head2 color_value($color_name, $color_scheme)

	my $color = Graph::Easy->color_name( 'red' );	# #ff0000
	print Graph::Easy->color_name( '#ff0000' );	# #ff0000

	print Graph::Easy->color_name( 'snow', 'x11' );

Given a color name, returns the color in hex. See L<color_name>
for a list of possible values for the optional C<$color_scheme>
parameter.

=head2 color_name($color_value, $color_scheme)

	my $color = Graph::Easy->color_name( 'red' );	# red
	print Graph::Easy->color_name( '#ff0000' );	# red

	print Graph::Easy->color_name( 'snow', 'x11' );

Takes a hex color value and returns the name of the color.

The optional parameter is the color scheme, where the following
values are possible:

 w3c			(the default)
 x11			(what graphviz uses as default)

Plus the following ColorBrewer schemes are supported, see the
online manual for examples and their usage:

 accent3 accent4 accent5 accent6 accent7 accent8

 blues3 blues4 blues5 blues6 blues7 blues8 blues9

 brbg3 brbg4 brbg5 brbg6 brbg7 brbg8 brbg9 brbg10 brbg11

 bugn3 bugn4 bugn5 bugn6 bugn7 bugn8 bugn9 bupu3 bupu4 bupu5 bupu6 bupu7
 bupu8 bupu9

 dark23 dark24 dark25 dark26 dark27 dark28

 gnbu3 gnbu4 gnbu5 gnbu6 gnbu7 gnbu8 gnbu9

 greens3 greens4 greens5 greens6 greens7 greens8 greens9

 greys3 greys4 greys5 greys6 greys7 greys8 greys9

 oranges3 oranges4 oranges5 oranges6 oranges7 oranges8 oranges9

 orrd3 orrd4 orrd5 orrd6 orrd7 orrd8 orrd9

 paired3 paired4 paired5 paired6 paired7 paired8 paired9 paired10 paired11
 paired12 pastel13 pastel14 pastel15 pastel16 pastel17 pastel18 pastel19

 pastel23 pastel24 pastel25 pastel26 pastel27 pastel28

 piyg3 piyg4 piyg5 piyg6 piyg7 piyg8 piyg9 piyg10 piyg11

 prgn3 prgn4 prgn5 prgn6 prgn7 prgn8 prgn9 prgn10 prgn11

 pubu3 pubu4 pubu5 pubu6 pubu7 pubu8 pubu9

 pubugn3 pubugn4 pubugn5 pubugn6 pubugn7 pubugn8 pubugn9

 puor3 puor4 puor5 puor6 puor7 puor8 puor9 purd3 purd4 purd5 purd6 purd7 purd8
 purd9 puor10 puor11

 purples3 purples4 purples5 purples6 purples7 purples8 purples9

 rdbu10 rdbu11 rdbu3 rdbu4 rdbu5 rdbu6 rdbu7 rdbu8 rdbu9 rdgy3 rdgy4 rdgy5 rdgy6

 rdgy7 rdgy8 rdgy9 rdpu3 rdpu4 rdpu5 rdpu6 rdpu7 rdpu8 rdpu9 rdgy10 rdgy11

 rdylbu3 rdylbu4 rdylbu5 rdylbu6 rdylbu7 rdylbu8 rdylbu9 rdylbu10 rdylbu11

 rdylgn3 rdylgn4 rdylgn5 rdylgn6 rdylgn7 rdylgn8 rdylgn9 rdylgn10 rdylgn11

 reds3 reds4 reds5 reds6 reds7 reds8 reds9

 set13 set14 set15 set16 set17 set18 set19 set23 set24 set25 set26 set27 set28
 set33 set34 set35 set36 set37 set38 set39

 set310 set311 set312

 spectral3 spectral4 spectral5 spectral6 spectral7 spectral8 spectral9
 spectral10spectral11

 ylgn3 ylgn4 ylgn5 ylgn6 ylgn7 ylgn8 ylgn9

 ylgnbu3 ylgnbu4 ylgnbu5 ylgnbu6 ylgnbu7 ylgnbu8 ylgnbu9

 ylorbr3 ylorbr4 ylorbr5 ylorbr6 ylorbr7 ylorbr8 ylorbr9

 ylorrd3 ylorrd4 ylorrd5 ylorrd6 ylorrd7 ylorrd8 ylorrd9

=head2 color_names()

	my $names = Graph::Easy->color_names();

Return a hash with name => value mapping for all known colors.

=head2 text_style()

	if ($graph->text_style('bold, italic'))
	  {
	  ...
	  }

Checks the given style list for being valid.

=head2 text_styles()

	my $styles = $graph->text_styles();	# or $edge->text_styles() etc.

	if ($styles->{'italic'})
	  {
	  print 'is italic\n';
	  }

Return a hash with the given text-style properties, aka 'underline', 'bold' etc.

=head2 text_styles_as_css()

	my $styles = $graph->text_styles_as_css();	# or $edge->...() etc.

Return the text styles as a chunk of CSS styling that can be embedded into
a C< style="" > parameter.

=head2 use_class()

	$graph->use_class('node', 'Graph::Easy::MyNode');

Override the class to be used to constructs objects when calling
C<add_edge()>, C<add_group()> or C<add_node()>.

The first parameter can be one of the following:

	node
	edge
	group

Please see the documentation about C<use_class()> in C<Graph::Easy::Parser>
for examples and details.

=head2 animation_as_graph()

	my $graph_2 = $graph->animation_as_graph();
	print $graph_2->as_ascii();

Returns the animation of C<$graph> as a graph describing the flow of the
animation. Usefull for debugging animation flows.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy::As_svg>, L<Graph::Easy::Manual> and L<Graph::Easy::Parser>.

=head2 Related Projects

L<Graph::Layout::Aesthetic>, L<Graph> and L<Text::Flowchart>.

There is also an very old, unrelated project from ca. 1995, which does something similiar.
See L<http://rw4.cs.uni-sb.de/users/sander/html/gsvcg1.html>.

Testcases and more examples under:

L<http://bloodgate.com/perl/graph/>.

=head1 LIMITATIONS

This module is now quite complete, but there are still some limitations.
Hopefully further development will lift these.

=head2 Scoring

Scoring is not yet implemented, each generated graph will be the same regardless
of the random seed.

=head2 Syntax

See L<http://bloodgate.com/perl/graph/> for limits of the syntax. Mostly this
are limitations in the parser, which cannot yet handle the following features:

=over 2

=item nesting (graph-in-a-graph)

Nested graphs are not yet possible. However, the grouping feature can simulate
a single nesting layer like so:

	( German cities:

	  [ Bonn ] -> [ Berlin ]
	)

=item scopes

Scopes are not yet implemented.

=back

=head2 Layouter

The layouter can not yet handle links between groups (or between
a group and a node, or vice versa).

=head2 Paths

=over 2

=item No optimizations

In complex graphs, non-optimal layout part like this one might appear:

	+------+     +--------+
	| Bonn | --> | Berlin | --> ...
	+------+     +--------+
	               ^
	               |
	               |
	+---------+    |
	| Kassel  | ---+
	+---------+

A second-stage optimizer that simplifies these layouts is not yet implemented.

In addition the general placement/processing strategy as well as the local
strategy might be improved.

=back

=head2 Output formats

Some output formats are not yet complete in their
implementation. Please see the online manual at
L<http://bloodgate.com/perl/graph/manual> under "Output" for
details.

X<graph>
X<manual>
X<online>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the terms of the GPL version 2.

See the LICENSE file for a copy of the GPL.

This product includes color specifications and designs developed by Cynthia
Brewer (http://colorbrewer.org/). See the LICENSE file for the full license
text that applies to these color schemes.

X<gpl>
X<apache-style>
X<cynthia>
X<brewer>
X<colorscheme>
X<license>

=head1 NAME CHANGE

The package was formerly known as C<Graph::Simple>. The name was changed
for two reasons:

=over 2

=item *

In graph theory, a C<simple> graph is a special type of graph. This software,
however, supports more than simple graphs.

=item *

Creating graphs should be easy even when the graphs are quite complex.

=back

=head1 AUTHOR

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>

X<tels>

=cut
