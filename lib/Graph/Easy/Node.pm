#############################################################################
# Represents one node in a Graph::Easy
#
# (c) by Tels 2004-2005. Part of Graph::Easy
#############################################################################

package Graph::Easy::Node;

$VERSION = '0.17';

use strict;
use Graph::Easy::Attributes;

#############################################################################

{
  # protected vars
  my $id = 0;
  sub _new_id { $id++; }
  sub _reset_id { $id = 0; }
}

#############################################################################

sub new
  {
  # Create a new object. This is a generic routine that is inherited
  # by many other things like Edge, Cell etc.
  my $class = shift;

  my $args = $_[0];
  $args = { name => $_[0] } if ref($args) ne 'HASH' && @_ == 1;
  $args = { @_ } if ref($args) ne 'HASH' && @_ > 1;
  
  my $self = bless {}, $class;

  $self->{id} = _new_id();

  $self->_init($args);
  }

sub _init
  {
  # Generic init routine, to be overriden in subclasses.
  my ($self,$args) = @_;
  
  $self->{name} = 'Node #' . $self->{id};
  
  # attributes
  $self->{att} = { };
  $self->{class} = 'node';		# default class

  foreach my $k (keys %$args)
    {
    if ($k !~ /^(label|name)\z/)
      {
      require Carp;
      Carp::confess ("Invalid argument '$k' passed to Graph::Easy::Node->new()");
      }
    $self->{$k} = $args->{$k};
    $self->{att}->{$k} = $args->{$k} if $k eq 'label';
    }
  
  $self->{x} = 0;
  $self->{y} = 0;
 
  # size of node in cells (are != 1 for multi-celled nodes)
  $self->{cx} = 1;
  $self->{cy} = 1;
 
  # These are undef (to save memory) until needed: 
  # $self->{groups} = {};
  # $self->{children} = {};
  # $self->{dx} = 0;		# relative to no other node
  # $self->{dy} = 0;
  # $self->{origin} = 0;
  
  $self;
  }

sub _border_styles
  {
  # return the four border styles (right, bottom, left, top)
  my $self = shift;

  my $border = $self->attribute('border-style') || 'none';
  my $width = $self->attribute('border-width') || '1';
  my $color = $self->attribute('border-color') || 'black';

  # XXX TODO:
  ($border, $width, $color, 
   $border, $width, $color, 
   $border, $width, $color, 
   $border, $width, $color);
  }

sub _correct_size
  {
  # Correct {w} and {h} after parsing. This is a fallback in case
  # the output specific routines (_correct_site_ascii() etc) do
  # not exist.
  my $self = shift;

  return if defined $self->{w};

  my $border = $self->attribute('border-style') || 'none';

  my $shape = $self->attribute('shape') || 'rect';

  if ($shape eq 'point')
    {
    $self->{w} = 5;
    $self->{h} = 3;
    }
  elsif ($shape eq 'invisible')
    {
    $self->{w} = 3;
    $self->{h} = 3;
    }
  else
    {
    my ($w,$h) = $self->dimensions();
    $self->{h} = $h + 2;
    $self->{w} = $w + 2;
    $self->{w} += 2 if $border ne 'none';
    }

  return if $border eq 'none' || !exists $self->{autosplit};

  my ($asx, $asy) = split /,/, $self->{autosplit_xy};

  # XXX TODO: base on "border-collapse: collapse;"
  # find out whether the cell above/left of us is a node (w/ border)
  my $cells = $self->{graph}->{cells};
  my $x = $self->{x}; my $y = $self->{y};

  my $top = $cells->{"$x," . ($y-1)};
  my $left = $cells->{($x-1) . ",$y"};

  my $bottom = $cells->{"$x," . ($y+1)};
  my $right = $cells->{($x+1) . ",$y"};
  my $bottomright = $cells->{($x+1) . "," . ($y+1)};
  
  my $check = qr/^Graph::Easy::Node/;
  my $check_2 = qr/^Graph::Easy::Node\z/;

  # count the number of cells below and right of us (0..3)
  $self->{rightbelow_count} = 0;
 
  # XXX TODO: we need to fix this 
  $self->{rightbelow_count}++ if ref($bottom) =~ $check_2;
  $self->{rightbelow_count}++ if ref($right) =~ $check_2;
  $self->{rightbelow_count}++ if ref($bottomright) =~ $check_2;

  $self->{have_below} = 1 if ref($bottom) =~ $check;
#  $self->{have_above} = 1 if ref($top) =~ $check;
#  $self->{have_left} = 1 if ref($left) =~ $check;
  $self->{have_right} = 1 if ref($right) =~ $check;

  $self->{border_collapse_bottom} = 1 if ref($bottom) =~ $check;
  $self->{border_collapse_right} = 1 if ref($right) =~ $check;

  # nodes not in first row/column are smaller
  $self->{w}-- if $asx != 0;
  $self->{h}-- if $asy != 0;

  if (ref($top) =~ $check)
    {
    $self->{no_border_top} = 1;# if $top;
    }
  if (ref($left) =~ $check)
    {
    $self->{no_border_left} = 1;# if $left;
    }
  }

sub _unplace
  {
  # free the cells this node occupies from $cells
  my ($self,$cells) = @_;

  my $x = $self->{x}; my $y = $self->{y};
  delete $cells->{"$x,$y"};
  $self->{x} = undef;
  $self->{y} = undef;

  if ($self->{cx} + $self->{cy} > 2)	# one of them > 1!
    {
    for my $ax (1..$self->{cx})
      {
      my $sx = $x + $ax - 1;
      for my $ay (1..$self->{cy})
        {
        my $sy = $y + $ay - 1;
        # free cell
        delete $cells->{"$sx,$sy"};
        }
      }
    } # end handling multi-celled node

  # unplace all edges leading to/from this node, too:
  for my $e (values %{$self->{edges}})
    {
    $e->_unplace($cells);
    }

  $self;
  }

sub _place_children
  {
  # recursively place node and its children
  my ($self, $x, $y, $cells) = @_;

  no warnings 'recursion';

  return 0 unless $self->_check_place($x,$y,$cells);

  print STDERR "# placing children of $self->{name} based on $x,$y\n" if $self->{debug};

  for my $child (values %{$self->{children}})
    {
    my $rc = $child->_place_children($x + $child->{dx},$y + $child->{dy},$cells);
    return $rc if $rc == 0;
    }
  $self->_place($x,$y,$cells);
  }

sub _place
  {
  # place this node at the requested position (without checking)
  my ($self, $x, $y, $cells) = @_;

  $self->{x} = $x;
  $self->{y} = $y;
  $cells->{"$x,$y"} = $self;

  # a multi-celled node will be stored like this:
  # [ node   ] [ filler ]
  # [ filler ] [ filler ]
  # [ filler ] [ filler ] etc.

  if ($self->{cx} + $self->{cy} > 2)    # one of them > 1!
    {
    for my $ax (1..$self->{cx})
      {
      my $sx = $x + $ax - 1;
      for my $ay (1..$self->{cy})
        {
        next if $ax == 1 && $ay == 1;   # skip left-upper most cell
        my $sy = $y + $ay - 1;

        # We might even get away with creating only one filler cell
        # although then its "x" and "y" values would be "wrong".

        my $filler = Graph::Easy::Node::Cell->new ( node => $self );
        $filler->{x} = $sx;
        $filler->{y} = $sy;
        $cells->{"$sx,$sy"} = $filler;
        }
      }
    } # end handling of multi-celled node

  1;					# did place us
  } 

sub _check_place
  {
  # chack that a node can be placed at $x,$y (w/o checking its children)
  my ($self,$x,$y,$cells) = @_;

  # node cannot be placed here
  return 0 if exists $cells->{"$x,$y"};

  if ($self->{cx} + $self->{cy} > 2)	# one of them > 1!
    {
    for my $ax (1..$self->{cx})
      {
      my $sx = $x + $ax - 1;
      for my $ay (1..$self->{cy})
        {
        my $sy = $y + $ay - 1;
        # node cannot be placed here
        return 0 if exists $cells->{"$sx,$sy"};
        }
      }
    }
  1;					# can place it here
  }

sub place
  {
  # Tries to place the node at position ($x,$y) by checking that
  # $cells->{"$x,$y"} is still free. If the node belongs to a cluster,
  # checks all nodes of the cluster (and when all of them can be
  # placed simultanously, does so).
  # Returns true if the operation succeeded, otherwise false.
  my ($self,$x,$y,$cells) = @_;

  # inlined from _check() for speed reasons:

  # node cannot be placed here
  return 0 if exists $cells->{"$x,$y"};

  if ($self->{cx} + $self->{cy} > 2)	# one of them > 1!
    {
    for my $ax (1..$self->{cx})
      {
      my $sx = $x + $ax - 1;
      for my $ay (1..$self->{cy})
        {
        my $sy = $y + $ay - 1;
        # node cannot be placed here
        return 0 if exists $cells->{"$sx,$sy"};
        }
      }
    }

  my $children = 0;
  $children = scalar keys %{$self->{children}} if $self->{children};

  # relativ to another, or has children (relativ to us)
  if (defined $self->{origin} || $children > 0)
    {
    # The coordinates of the origin node. Because 'dx' and 'dy' give
    # our distance from the origin, we can compute the origin by doing
    # "$x - $dx"

    my $grandpa = $self; my $ox = 0; my $oy = 0;
    # Find our grandparent (e.g. the root of origin chain), and the distance
    # from $x,$y to it:
    ($grandpa,$ox,$oy) = $self->find_grandparent() if $self->{origin};

    # Traverse all children and check their places, place them if poss.
    # This will also place ourselves, because we are a grandchild of $grandpa
    return $grandpa->_place_children($x + $ox,$y + $oy,$cells);
    }

  # finally place this node at the requested position
  $self->_place($x,$y,$cells);
  }

#############################################################################

sub error
  {
  my $self = shift;

  $self->{error} = $_[0] if defined $_[0];
  $self->{error} || '';
  }

sub _formatted_label
  {
  my $self = shift;

  my $name = $self->label();
  $name =~ s/\\n/\n/g;			# insert newlines

  # split into lines, remove extranous spacing
  my @lines = split /\n/, $name;
  my $i = 0;
  while ($i < scalar @lines)
    {
    $lines[$i] =~ s/^\s+//;			# remove spaces at front
    $lines[$i] =~ s/^\s+$//;			# remove spaces at end
    $i++;
    }
  @lines;
  }

#############################################################################
# as_html conversion and helper functions related to that

my $node_remap = {
  node => {
    fill => 'background',
    background => undef,
    'border' => undef,
    'border-style' => undef,
    'border-width' => undef,
    'border-color' => undef,
    columns => undef,
    flow => undef,
    origin => undef,
    offset => undef, 
    'point-style' => undef,
    rows => undef, 
    size => undef,
    shape => undef,
    },
  edge => {
    fill => undef,
    'border' => undef,
    },
  all => {
    autolink => undef,
    autotitle => undef,
    'font-size' => undef,
    label => undef,
    link => undef,
    linkbase => undef,
    style => undef,
    'text-style' => undef,
    title => undef,
    },
  };

sub as_html
  {
  my ($self, $noquote) = @_;

  my $tag = 'td';

  my $id = $self->{graph}->{id};
  my $a = $self->{att};
  my $g = $self->{graph};

  # return yourself as HTML
  my $shape = $self->attribute('shape') || '';

  my $class = $self->class();

  # how many rows/columns will this node span?
  my $rs = ($self->{cy} || 1) * 4;
  my $cs = ($self->{cx} || 1) * 4;

  # shape: invisible; must result in an empty cell
  if ($shape eq 'invisible' && $class ne 'node.anon')
    {
    return " <$tag colspan=$cs rowspan=$rs style=\"border: none; background: inherit;\"></$tag>\n";
    }

  my $c = $class; $c =~ s/\./-/g;	# node.city => node-city

  my $html = " <$tag colspan=$cs rowspan=$rs";
  $html .= " class='$c'" if $c ne '';
   
  my $name = $self->label(); 

  if (!$noquote)
    {
    $name =~ s/&/&amp;/g;			# quote &
    $name =~ s/>/&gt;/g;			# quote >
    $name =~ s/</&lt;/g;			# quote <

    $name =~ s/([^\\])\\n/$1\n/g;		# "\\n" to "\n" (but not "\\\n")
    $name =~ s/\n/<br>/g;			# |\n|\nv => |<br>|<br>v
    $name =~ s/^\s*<br>//;			# remove empty leading line
    $name =~ s/<br>/<br \/>/g;			# correct <br>
    }

  my $style = '';

  $style .= "-moz-border-radius: 10%; border-radius: 10%; " if $shape eq 'rounded';
  $style .= "-moz-border-radius: 100%; border-radius: 100%; " if $shape eq 'ellipse';
  if ($shape eq 'circle')
    {
    my ($w, $h) = $self->dimensions();
    my $r = $w; $r = $h if $h > $w;
    my $size = ($r * 0.7) . 'em';
    $style .= "-moz-border-radius: 100%; border-radius: 100%; height: $size; width: $size; ";
    }

  my $out = $self->{graph}->_remap_attributes( $self, $self->{att}, $node_remap, 'noquote', 'encode');

  if (!$self->isa('Graph::Easy::Edge'))
    {
    $out->{border} = Graph::Easy::_border_attribute_as_html( 
	$self->attribute('border-style'),
	$self->attribute('border-width'),
	$self->attribute('border-color'));
    my $c = $class; $c =~ s/\..*//;
    my $DEF = $g->border_attribute ($c);
    delete $out->{border} if $out->{border} =~ /^\s*\z/ || $out->{border} eq $DEF; #$g->{att}->{node}->{border};
    delete $out->{border} if $class eq 'node.anon' && $out->{border} eq 'none';
    }

  # shape: none; means no border, and background instead fill color
  if ($shape eq 'none')
    {
    my $bg = $self->attribute('background') || 'inherit'; 
    $out->{background} = $bg;
    $out->{border} = 'none';
    }

  for my $atr (sort keys %$out)
    {
    $style .= "$atr: $out->{$atr}; ";
    }

  $style .= $self->text_styles_as_css();	# bold, italic, underline etc.

  $style =~ s/;\s$//;				# remove '; ' at end
  $style =~ s/\s+/ /g;				# '  ' => ' '
  $style =~ s/^\s+//;				# remove ' ' at front

  my $title = $self->title();
  $title =~ s/"/&#22;/g;			# replace quotation marks
  $html .= " title=\"$title\"" if $title ne '';	# add mouse-over title

  my $link = $self->link();

  my $end_tag = "</$tag>\n";

  if ($link ne '')
    {
    # encode critical entities
    $link =~ s/\s/\+/g;				# space
    $link =~ s/'/%27/g;				# replace quotation marks
    $html .= "><a class='l' href='$link'";	# put the style on "<a.."
    $end_tag = '</a>'.$end_tag;
    }
  $html .= " style=\"$style\"" if $style;
  $html .= ">$name";
  $html .= "$end_tag";
  $html;
  }

#############################################################################
# multi-celled nodes

sub grow
  {
  # grows the node until it has sufficient cells for all incoming/outgoing
  # edges
  my $self = shift;

  # XXX TODO: grow the node based on its label dimensions
#  my ($w,$h) = $self->dimensions();
#
#  my $cx = int(($w+2) / 5) || 1;
#  my $cy = int(($h) / 3) || 1;
#
#  $self->{cx} = $cx if $cx > $self->{cx};
#  $self->{cy} = $cy if $cy > $self->{cy};


  # since selfloops count twice in connections(), but actually block only
  # one port, we can just count the edges here:
  my $connections = scalar keys %{$self->{edges}};

  # grow the node based on the general flow first VER, then HOR
  my $flow = $self->attribute('flow') || 90;

  my $first = "cy"; my $second = "cx";
  ($first,$second) = ($second,$first) if $flow == 0 || $flow == 180;
  while ( ($self->{cx} * 2 + $self->{cy} * 2) < $connections)
    {
    # find the minimum
    # XXX TODO: use "flow" attribute to choose Y or X preference
    my $grow = $first;		# first in Y direction
    $grow = $second if $self->{$second} < $self->{$first};
    $self->{$grow}++;
    }

  $self;
  }

sub is_multicelled
  {
  # return true if node consist of more than one cell
  my $self = shift;

  $self->{cx} + $self->{cy} <=> 2;	# 1 + 1 == 2: no, cx + xy != 2: yes
  }

#############################################################################
# accessor methods

sub title
  {
  # Returns a title of the node (or '', if none was set), which can be
  # used for mouse-over titles

  my $self = shift;

  my $title = $self->attribute('title');
  if (!defined $title)
    {
    my $autotitle = $self->attribute('autotitle');
    if (defined $autotitle)
      {
      $title = $self->{name};		# default
      # defined to avoid overriding "name" with the non-existant label attribute
      $title = $self->{att}->{label} if $autotitle eq 'label' && defined $self->{att}->{label};

      warn ("'$autotitle' not allowed for attribute 'autotitle' on node $self->{name}")
        if $autotitle !~ /^(name|label|none)\z/;
      }
    }
  $title = '' unless defined $title;
  $title;
  }

sub background
  {
  my $self = shift;

  my $bg = $self->attribute('background') || '';
  if ($bg eq 'inherit')
    {
    $bg = $self->{group}->attribute('background') if ref($self->{group});
    $bg = '' if $bg eq 'inherit';
    }
  $bg;
  }

sub x
  {
  my $self = shift;

  $self->{x};
  }

sub name
  {
  my $self = shift;

  $self->{name};
  }

sub label
  {
  my $self = shift;

  my $label = $self->{att}->{label}; $label = $self->{name} unless defined $label;
  $label = '' unless defined $label;
  $label;
  }

sub y
  {
  my $self = shift;

  $self->{y};
  }

sub pos
  {
  my $self = shift;

  ($self->{x}, $self->{y});
  }

sub offset
  {
  my $self = shift;

  ($self->{dx} || 0, $self->{dy} || 0);
  }

sub width
  {
  my $self = shift;

  $self->{w};
  }

sub height
  {
  my $self = shift;

  $self->{h};
  }

sub columns
  {
  my $self = shift;

  $self->{cx};
  }

sub rows
  {
  my $self = shift;

  $self->{cy};
  }

sub size
  {
  my $self = shift;

  ($self->{cx}, $self->{cy});
  }

sub shape
  {
  my $self = shift;

  my $shape = $self->attribute('shape') || 'rect';
  $shape;
  }

sub dimensions
  {
  # Returns the dimensions of the node/cell derived from the label (or name) in characters.
  my $self = shift;

  my $label = $self->{att}->{label}; $label = $self->{name} unless defined $label;
  $label = '' unless defined $label;

  $label =~ s/\\n/\n/g;

  my @lines = split /\n/, $label;
  my $w = 0; my $h = scalar @lines;
  foreach my $line (@lines)
    {
    $line =~ s/^\s+//; $line =~ s/\s+$//;		# rem spaces
    $w = length($line) if length($line) > $w;
    }
  ($w,$h);
  }

#############################################################################
# edges and connections

sub edges_to
  {
  # Return all the edge objects that start at this vertex and go to $other.
  my ($self, $other) = @_;

  # no graph, no dice
  return unless ref $self->{graph};

  my @edges;
  for my $edge (values %{$self->{edges}})
    {
    push @edges, $edge if $edge->{from} == $self && $edge->{to} == $other;
    }
  @edges;
  }

sub incoming
  {
  # return all edges that end at this node
  my $self = shift;

  # no graph, no dice
  return unless ref $self->{graph};

  if (!wantarray)
    {
    my $count = 0;
    for my $edge (values %{$self->{edges}})
      {
      $count++ if $edge->{to} == $self;
      }
    return $count;
    }

  my @edges;
  for my $edge (values %{$self->{edges}})
    {
    push @edges, $edge if $edge->{to} == $self;
    }
  @edges;
  }

sub outgoing
  {
  # return all edges that start at this node
  my $self = shift;

  # no graph, no dice
  return unless ref $self->{graph};

  if (!wantarray)
    {
    my $count = 0;
    for my $edge (values %{$self->{edges}})
      {
      $count++ if $edge->{from} == $self;
      }
    return $count;
    }

  my @edges;
  for my $edge (values %{$self->{edges}})
    {
    push @edges, $edge if $edge->{from} == $self;
    }
  @edges;
  }

sub connections
  {
  # return number of connections (incoming+outgoing)
  my $self = shift;

  return 0 unless defined $self->{graph};
 
  # We need to count the connections, because "[A]->[A]" creates
  # two connections on "A", but only one edge! 
  my $con = 0;
  for my $edge (values %{$self->{edges}})
    {
    $con ++ if $edge->{to} == $self;
    $con ++ if $edge->{from} == $self;
    }
  $con;
  }

sub sorted_successors
  {
  # return successors of the node sorted by their chain value
  # (e.g. successors with more successors first) 
  my $self = shift;

  my @suc = sort {
       scalar $b->successors() <=> scalar $a->successors() ||
       scalar $a->{name} cmp scalar $b->{name}
       } $self->successors();
  @suc;
  }

sub successors
  {
  # return all nodes (as objects) we are linked to
  my $self = shift;

  return () unless defined $self->{graph};

  my %suc;
  for my $edge (values %{$self->{edges}})
    {
    next unless $edge->{from} == $self;
    $suc{$edge->{to}->{id}} = $edge->{to};	# weed out doubles
    }
  values %suc;
  }

sub predecessors
  {
  # return all nodes (as objects) that link to us
  my $self = shift;

  return () unless defined $self->{graph};

  my %pre;
  for my $edge (values %{$self->{edges}})
    {
    next unless $edge->{to} == $self;
    $pre{$edge->{from}->{id}} = $edge->{from};	# weed out doubles
    }
  values %pre;
  }

#############################################################################
# class management

sub class
  {
  # return our full class name like "node.subclass" or "node"
  my $self = shift;

  $self->{class};
  }

sub sub_class
  {
  # get/set the subclass
  my $self = shift;

  if (defined $_[0])
    {
    $self->{class} =~ s/\..*//;		# nix subclass
    $self->{class} .= '.' . $_[0];	# append new one
    }
  $self->{class} =~ /\.(.*)/;
  $1;
  }

#############################################################################
# relatively placed nodes

sub origin
  {
  # Returns node that this node is relative to or undef, if not.
  my $self = shift;

  $self->{origin};
  }

sub relative_to
  {
  # Sets the new origin if passed a Graph::Easy::Node object.
  my ($self,$parent,$dx,$dy) = @_;

  if (!ref($parent) || !$parent->isa('Graph::Easy::Node'))
    {
    require Carp;
    Carp::confess("Can't set origin to non-node object $parent");
    }

  my $grandpa = $parent->find_grandparent();
  if ($grandpa == $self)
    {
    require Carp;
    Carp::confess( "Detected loop in origin-chain:"
                  ." tried to set origin of '$self->{name}' to my own grandchild $parent->{name}");
    }

  if (defined $self->{origin})
    {
    # unregister us with our old parent
    delete $self->{origin}->{children}->{$self->{id}};
    }
  $self->{origin} = $parent;
  $self->{dx} = $dx if defined $dx;
  $self->{dy} = $dy if defined $dy;

  # register us as a new child
  $parent->{children}->{$self->{id}} = $self;

  $self;
  }

sub find_grandparent
  {
  # For a node that has no origin (is not relative to another), returns
  # $self. For all others, follows the chain of origin back until we
  # hit a node without a parent. This code assumes there are no loops,
  # which origin() prevents from happening.
  my $cur = shift;

  my $ox = 0;
  my $oy = 0;

  while (defined($cur->{origin}))
    {
    $ox -= $cur->{dx};
    $oy -= $cur->{dy};
    $cur = $cur->{origin};
    }

  wantarray ? ($cur,$ox,$oy) : $cur;
  }

#############################################################################
# attributes

sub border_attribute
  {
  # Return "solid 1px red" from the individual border-(style|color|width)
  # attributes, mainly for HTML output.
  my ($self) = @_;

  my $style = $self->{att}->{'border-style'} || '';

  return $style if $style =~ /^(none|)\z/;

  my $width = $self->{att}->{'border-width'} || '';
  my $color = $self->{att}->{'border-color'} || '';

  Graph::Easy::_border_attribute($style, $width, $color);
  }

sub attribute
  {
  my ($self, $atr) = @_;

  warn ("Node::attribute() takes only one argument, did you mean set_attribute()?") if @_ > 2;

  return $self->{att}->{$atr} if exists $self->{att}->{$atr};

  my $g = $self->{graph};
  # if we do not belong to a graph, we cannot inherit attributes
  return unless ref($g) =~ /^Graph::Easy/;

  my $class = $self->{class};

  # See if we can inherit it from our groups:
  # XXX TODO: what about the order we search the groups in? undefined?
  for my $group (keys %{$self->{groups}})
    {
    my $att = $g->attribute ('group.' . $group, $atr);
    return $att if defined $att;
    }
  
  # try "node.class" first:
  my $att = $g->attribute ($class, $atr);

  my $c = $class; $c =~ s/\.(.*)//;		# remove subclass

  # try "node" next
  $att = $g->attribute ($c, $atr) unless defined $att;

  # XXX TODO: this should use $self->parent() instead of just graph

  # If neither our group nor our parent class had the attribute, try to
  # inherit it from "graph" as a last resort:

  $att = $g->attribute ('graph', $atr) if !defined $att && 
    $atr =~ /^(flow|linkbase|autolink|autotitle)\z/;

  $att;
  }

sub del_attribute
  {
  my ($self, $atr) = @_;

  delete $self->{att}->{$atr};
  $self;
  }
  
sub set_attribute
  {
  my ($self, $name, $v, $class) = @_;

  $name = 'undef' unless defined $name;
  $v = 'undef' unless defined $v;

  if (!defined $class)
    {
    # edge.cities => edge
    $class = $self->{class}; $class =~ s/\..*//; # remove subclass
    }

  my $val = $v;
  $val =~ s/^["'](.*)["']\z/$1/; 	# remove quotation marks
  $val =~ s/\\#/#/;			# reverse backslashed \#

  # decode %XX entities
  $val =~ s/%([a-fA-F0-9][a-fA-F0-9])/sprintf("%c",hex($1))/eg;

  my $g = $self->{graph};
  
  $g->{score} = undef if $g;	# invalidate layout to force a new layout

  my $strict = 0; $strict = $g->{strict} if $g;
  if ($strict)
    {
    my $v = $g->valid_attribute($name,$val,$class);

    if (ref($v) eq 'ARRAY')
      {
      $g->error("Error: '$name' is not a valid attribute for $class");
      return;
      }
    if (!defined $v)
      {
      $g->error("Error in attribute: '$val' is not a valid $name for $class");
      return;
      }
    $val = $v;
    }

  if ($name eq 'class')
    {
    $self->sub_class($val);
    return $self;
    }
  if ($name eq 'group')
    {
    $self->add_to_groups($val);
    return $self;
    }

  if ($name eq 'border')
    {
    my $c = $self->{att};

    my @rc = $g->split_border_attributes( $val );
    $c->{'border-style'} = $rc[0] if defined $rc[0];
    $c->{'border-width'} = $rc[1] if defined $rc[1];
    $c->{'border-color'} = $rc[2] if defined $rc[2];

    return $val;
    }

  if ($name =~ /^(rows|columns|size)\z/)
    {
    if ($name eq 'size')
      {
      $val =~ /^(\d+),(\d+)\z/;
      ($self->{cx}, $self->{cy}) = (abs(int($1)),abs(int($2)));
      ($self->{att}->{columns}, $self->{att}->{rows}) = ($self->{cx}, $self->{cy});
      }
    elsif ($name eq 'rows')
      {
      $self->{cy} = abs(int($val));
      $self->{att}->{rows} = $self->{cy};
      }
    else
      {
      $self->{cx} = abs(int($val));
      $self->{att}->{columns} = $self->{cx};
      }
    return $self;
    }

  if ($name =~ /^(origin|offset)\z/)
    {
    # Only the first autosplit node get the offset/origin
    return $self if exists $self->{autosplit} && !defined $self->{autosplit};

    if ($name eq 'origin')
      {
      # if it doesn't exist, add it
      my $org = $self->{graph}->add_node($val);
      $self->relative_to($org);
      }
    else
      {
      # offset
      # if it doesn't exist, add it
      my ($x,$y) = split/\s*,\s*/, $val;
      $x = int($x);
      $y = int($y);
      if ($x == 0 && $y == 0)
        {
        $g->error("Error in attribute: 'offset' is 0,0 in node $self->{name} with class '$class'");
        return;
        }
      $self->{dx} = $x;
      $self->{dy} = $y;
      }
    return $self;
    }

  $self->{att}->{$name} = $val;
  $self;
  }

sub set_attributes
  {
  my ($self, $atr, $index) = @_;
 
  foreach my $n (keys %$atr)
    {
    my $val = $atr->{$n};
    $val = $val->[$index] if ref($val) eq 'ARRAY' && defined $index;

    next if !defined $val;

#    print STDERR "# $val ($n) index $index\n";

    $n eq 'class' ? $self->sub_class($val) : $self->set_attribute($n, $val);
    }
  $self;
  }

BEGIN
  {
  *text_styles_as_css = \&Graph::Easy::text_styles_as_css;
  *text_styles = \&Graph::Easy::text_styles;
  *_font_size_in_pixels = \&Graph::Easy::_font_size_in_pixels;
  *link = \&Graph::Easy::link;
  }

#############################################################################

sub group
  {
  # return the group this object belongs to
  my $self = shift;

  $self->{group};
  }

sub add_to_group
  {
  my ($self,$group) = @_;

  my $graph = $self->{graph};				# shortcut

  # delete from old group if nec.
  $self->{group}->del_member($self) if ref $self->{group};

  # if passed a group name, create or find group object
  $group = $graph->add_group($group) if (!ref($group) && $graph);

  $group->add_member($self);

  $self;
  }

sub parent
  {
  # return parent object, either a group the node belongs to, or the graph
  my $self = shift;

  my $p = $self->{graph};

  if (keys (%{$self->{groups}}) > 0)
    {
    my $key;
    ($key,$p) = each %{$self->{groups}};
    }
  
  $p;
  }

1;
__END__

=head1 NAME

Graph::Easy::Node - Represents a node in a simple graph

=head1 SYNOPSIS

        use Graph::Easy::Node;

	my $bonn = Graph::Easy::Node->new('Bonn');

	$bonn->set_attribute('border', 'solid 1px black');

	my $berlin = Graph::Easy::Node->new( name => 'Berlin' );

=head1 DESCRIPTION

A C<Graph::Easy::Node> represents a node in a simple graph. Each
node has contents (a text, an image or another graph), and dimension plus
an origin. The origin is typically determined by a graph layouter module
like L<Graph::Easy>.

=head1 METHODS

        my $node = Graph::Easy::Node->new( name => 'node name' );
        my $node = Graph::Easy::Node->new( 'node name' );

Creates a new node. If you want to add the node to a Graph::Easy object,
then please use the following to create the node object:

	my $node = $graph->add_node('Node name');

You can then use C<< $node->set_attribute(); >>
or C<< $node->set_attributes(); >> to set the new Node's attributes.

=head2 new()

	my $node = Graph::Easy::Node->new('Name');

Create a new node with the name C<Name>.

=head2 error()

	$last_error = $node->error();

	$node->error($error);			# set new messags
	$node->error('');			# clear error

Returns the last error message, or '' for no error.

=head2 as_ascii()

	my $ascii = $node->as_ascii();

Return the node as a little box drawn in ASCII art as a string.

=head2 as_txt()

	my $txt = $node->as_txt();

Return the node in simple txt format, including attributes.

=head2 as_svg()

	my $svg = $node->as_svg();

Returns the node as Scalable Vector Graphic. The actual code for
that routine is defined L<Graph::Easy::As_svg.pm>.

=head2 as_graphviz()

	my $txt = $node->as_graphviz_txt();

Returns the node as graphviz compatible text which can be feed
to dot etc to create images.

=head2 as_pure_txt()

	my $txt = $node->as_pure_txt();

Return the node in simple txt format, without the attributes.

=head2 as_html()

	my $html = $node->as_html();

Return the node as HTML code.

=head2 attribute()

	$node->attribute('border-style');

Returns the respective attribute of the node or undef if it
was not set. If there is a default attribute for all nodes
of the specific class the node is in, then this will be returned.

=head2 attributes_as_txt

	my $txt = $node->attributes_as_txt();

Return the attributes of this node as text description.

=head2 set_attribute()

	$node->set_attribute('border-style', 'none');

Sets the specified attribute of this (and only this!) node to the
specified value.

=head2 del_attribute()

	$node->del_attribute('border-style');

Deletes the specified attribute of this (and only this!) node.

=head2 set_attributes()

	$node->set_attributes( $hash );

Sets all attributes specified in C<$hash> as key => value pairs in this
(and only this!) node.

=head2 border_attribute()

	my $border = $node->border_attribute();

Assembles the C<border-width>, C<border-color> and C<border-style> attributes
into a string like "solid 1px red".

=head2 text_styles()

        my $styles = $node->text_styles();
        if ($styles->{'italic'})
          {
          print 'is italic\n';
          }

Return a hash with the given text-style properties, aka 'underline', 'bold' etc.

=head2 find_grandparent()

	my $grandpa = $node->find_grandparent(); 

For a node that has no origin (is not relative to another), returns
C<$node>. For all others, follows the chain of origin back until
a node without a parent is found and returns this node.
This code assumes there are no loops, which C<origin()> prevents from
happening.

=head2 name()

	my $name = $node->name();

Return the name of the node.

=head2 label()

	my $label = $node->label();

Return the label of the node. If no label was set, returns the C<name>
of the node.

=head2 class()

	my $class = $node->class();

Returns the full class name like C<node.cities>. See also C<sub_class>.

=head2 sub_class()

	my $sub_class = $node->sub_class();

Returns the sub class name like C<cities>. See also C<class>.

=head2 background()

	my $bg = $node->background();

Returns the background color. This method honours group membership and
inheritance.

=head2 title()

	my $title = $node->title();

Returns a potential title that can be used for mouse-over effects.
If no title was set (or autogenerated), will return an empty string.

=head2 link()

	my $link = $node->link();

Returns the URL, build from the C<linkbase> and C<link> (or C<autolink>)
attributes.  If the node has no link associated with it, return an empty
string.

=head2 dimensions()

	my ($w,$h) = $node->dimensions();

Returns the dimensions of the node/cell derived from the label (or name) in characters.
Assumes the label/name has literal '\n' replaced by "\n".

=head2 size()

	my ($cx,$cy) = $node->size();

Returns the node size in cells.

=head2 contents()

	my $contents = $node->contents();

For nested nodes, returns the contents of the node.

=head2 width()

	my $width = $node->width();

Returns the width of the node. This is a unitless number.

=head2 height()

	my $height = $node->height();

Returns the height of the node. This is a unitless number.

=head2 columns()

	my $cols = $node->columns();

Returns the number of columns (in cells) that this node occupies.

=head2 rows()

	my $cols = $node->rows();

Returns the number of rows (in cells) that this node occupies.

=head2 is_multicelled()

	if ($node->is_multicelled())
	  {
	  ...
	  }

Returns true if the node consists of more than one cell. See als
L<rows()> and L<cols()>.

=head2 pos()

	my ($x,$y) = $node->pos();

Returns the position of the node. Initially, this is undef, and will be
set from C<Graph::Easy::layout>.

=head2 offset()

	my ($dx,$dy) = $node->offset();

Returns the position of the node relativ to the origin. Returns C<(0,0)> if
the origin node was not sset.

=head2 x()

	my $x = $node->x();

Returns the X position of the node. Initially, this is undef, and will be
set from C<Graph::Easy::layout>.

=head2 y()

	my $y = $node->y();

Returns the Y position of the node. Initially, this is undef, and will be
set from C<Graph::Easy::layout>.

=head2 id()

	my $id = $node->id();

Returns the node's unique ID number.

=head2 grow()

	$node->grow();

Grows the node in C<columns()> and C<rows()> until all the outgoing/incoming
connection fit at the borders.

=head2 connections()

	my $cnt = $node->connections();

Returns the number of connections to (incoming) and from (outgoing) this node.

=head2 predecessors()

	my @pre = $node->predecessors();

Returns all nodes (as objects) that link to us.

=head2 successors()

	my @suc = $node->successors();

Returns all nodes (as objects) that we are linking to.

=head2 sorted_successors()

	my @suc = $node->sorted_successors();

Return successors of the node sorted by their chain value
(e.g. successors with more successors first). 

=head2 edges_to()

	my @edges = $node->edges_to($other_node);

Returns all the edge objects that start at C<< $node >> and go to C<< $other_node >>.

=head2 incoming()

	my @edges = $node->incoming();

Return all edges that end at this node.

=head2 outgoing()

	my @edges = $node->outgoing();

Return all edges that start at this node.

=head2 add_to_group()

	$node->add_to_group( $group );

Put the node into this group.

=head2 group()

	my $group = $node->group();

Return the group this node belongs to, or undef.

=head2 parent()

	my $parent = $node->parent();

Returns the parent object of the node, which is either the group the node belongs
to, or the graph.

=head2 origin()

	my $origin_node = $node->origin();

Returns the node this node is relativ to, or undef otherwise.

=head2 relative_to()

	$node->relative_to($parent, $dx, $dy);

Sets itself relativ to C<$parent> with the offset C<$dx,$dy>.

=head2 place()

	if ($node->place($x,$y,$cells))
	  {
	  ...
	  }

Tries to place the node at position C<< ($x,$y) >> by checking that
C<<$cells->{"$x,$y"}>> is still free. If the node is relative
to any other node, follow back to the origin, and then
process all children of the origin in one go, and if possible,
places them all.

Returns true if the operation succeeded, otherwise false.

=head2 shape()

	my $shape = $node->shape();

Returns the shape of the node as string, defaulting to 'rect'. 

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
