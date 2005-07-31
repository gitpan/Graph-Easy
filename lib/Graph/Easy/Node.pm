#############################################################################
# Represents one node in a Graph::Easy
#
# (c) by Tels 2004-2005. Part of Graph::Easy
#############################################################################

package Graph::Easy::Node;

$VERSION = '0.11';

use strict;

#############################################################################

# Name of attribute under which the pointer to each Node/Edge object is stored
# If you change this, change it also in Easy.pm!
sub OBJ () { 'obj' };

{
  # protected vars
  my $id = 0;
  sub new_id { $id++; }
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

  $self->_init($args);
  }

sub _init
  {
  # Generic init routine, to be overriden in subclasses.
  my ($self,$args) = @_;
  
  $self->{id} = new_id();
  $self->{name} = 'Node #' . $self->{id};
  
  # attributes
  $self->{att} = { };
  $self->{class} = 'node';		# default class

  $self->{contains} = undef;
  $self->{origin} = undef;	# not relative to any other node
  $self->{dx} = 0;		# relative to no other node
  $self->{dy} = 0;
 
  # XXX TODO check arguments (and better handling)
  foreach my $k (keys %$args)
    {
    $self->{$k} = $args->{$k};
    $self->{att}->{$k} = $args->{$k} if $k eq 'label';
    }
  
  $self->{error} = '';

  # w can only be computed once we know our graph and our border style, so postpone it
  $self->{h} = 1 + 2 if !defined $self->{h};
  
  $self->{x} = 0;
  $self->{y} = 0;
 
  # size of node in cells (are != 1 for multi-celled nodes)
  $self->{cx} = 1;
  $self->{cy} = 1;
 
  # XXX TODO: these could be left undef (to save memory) until needed 
  $self->{out} = {};
  $self->{in} = {};
  $self->{groups} = {};
  
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

  my ($w,$h) = $self->dimensions();
  my $border = $self->attribute('border-style') || 'none';
  if ($border eq 'none')
    {
    $self->{w} = $w + 2;
    $self->{h} = $h + 2;
    }
  else
    {
    $self->{w} = $w + 4;
    $self->{h} = $h + 2;
    }
  }

sub unplace
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
  $self;
  }

sub place
  {
  # Tries to place the node at position ($x,$y) by checking that
  # $cells->{"$x,$y"} is still free. If the node belongs to a cluster,
  # checks all nodes of the cluster (and when all of them can be
  # placed simultanously, does so).
  # Returns true if the operation succeeded, otherwise false.
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

  # belongs to a cluster => check all nodes
  if (exists $self->{cluster} && defined $self->{cluster})
    {
    # The coordinates of the origin node. Because 'dx' and 'dy' give
    # our distance from the origin, we can compute the origin by doing
    # "$x - $dx"
    my $ox = $x - $self->{dx};
    my $oy = $y - $self->{dy};
    
    my @nodes = $self->{cluster}->nodes();
    foreach my $node (@nodes)
      {
      my $x = $node->{dx} + $ox;
      my $y = $node->{dy} + $oy;
#      print STDERR "# checking $x,$y against $node->{name}\n";
      return 0 if exists $cells->{"$x,$y"};	# cell already blocked

      if ($node->{cx} + $node->{cy} > 2)	# one of them > 1!
        {
        for my $ax (1..$node->{cx})
          {
          my $sx = $x + $ax - 1;
          for my $ay (1..$node->{cy})
            {
            # node cannot be placed here
	    my $sy = $y + $ay - 1;
            return 0 if exists $cells->{"$sx,$sy"};
            }
          }
        } # end handling of multi-celled node
      }

    # place all the other nodes 
    foreach my $node (@nodes)
      {
      my $x = $node->{dx} + $ox;
      my $y = $node->{dy} + $oy;
      $node->{x} = $x;
      $node->{y} = $y;
      $cells->{"$x,$y"} = $node;

      if ($node->{cx} + $node->{cy} > 2)	# one of them > 1!
        {
        for my $ax (1..$node->{cx})
          {
          my $sx = $x + $ax - 1;
          for my $ay (1..$node->{cy})
            {
            next if $ax == 1 && $ay == 1;	# skip left-upper most cell
	    my $sy = $y + $ay - 1;
	    # We might even get away with creating only one filler cell
	    # although then it's "x" and "y" values would be "wrong".
            my $filler = Graph::Easy::Node::Cell->new ( node => $node );
            $filler->{x} = $sx;
            $filler->{y} = $sy;
            $cells->{"$sx,$sy"} = $filler;
            }
          }
        } # end handling of multi-celled node
      }
    # we return early here, because $self was already handled above
    return 1;
    }

  # place this node at the requested position
  $self->{x} = $x;
  $self->{y} = $y;
  $cells->{"$x,$y"} = $self;

  # a multi-celled node will be stored like this:
  # [ node   ] [ filler ]
  # [ filler ] [ filler ]
  # [ filler ] [ filler ] etc.
 
  if ($self->{cx} + $self->{cy} > 2)	# one of them > 1!
    {
    for my $ax (1..$self->{cx})
      {
      my $sx = $x + $ax - 1;
      for my $ay (1..$self->{cy})
        {
        next if $ax == 1 && $ay == 1;	# skip left-upper most cell
        my $sy = $y + $ay - 1;
        # We might even get away with creating only one filler cell
        # although then it's "x" and "y" values would be "wrong".
        my $filler = Graph::Easy::Node::Cell->new ( node => $self );
        $filler->{x} = $sx;
        $filler->{y} = $sy;
        $cells->{"$sx,$sy"} = $filler;
        }
      }
    } # end handling of multi-celled node

  1;							# success
  }

#############################################################################

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

sub _framebuffer
  {
  # generate an actual framebuffer consisting of spaces
  my ($self, $w, $h) = @_;

  print STDERR "# trying to generate framebuffer of undefined width for $self->{name}\n",
               join (": ", caller(),"\n") if !defined $w;

  my @fb;
  my $line = ' ' x $w;
  for my $y (1..$h)
    {
    push @fb, $line;
    }
  \@fb;
  }

sub _printfb
  {
  # Print (potential a multiline) text into a framebuffer
  # Caller MUST ensure proper size of FB, for speed reasons,
  # we do not check whether text fits!
  my ($self, $fb, $x, $y, @lines) = @_;

  # [0] = '0123456789...'
  # [1] = '0123456789...' etc

  for my $l (@lines)
    {
    substr ( $fb->[$y], $x, length($l)) = $l; $y++;
    }
  }

 # the array contains for each style:
 # upper left edge
 # upper right edge
 # lower right edge
 # lower left edge
 # hor style
 # ver style (multiple characters possible)

my $border_styles  = {
  solid =>		[ '+', '+', '+', '+', '-',   [ '|'      ] ],
  dotted =>		[ '.', '.', '.', '.', '.',   [ ':'      ] ],
  dashed =>		[ '+', '+', '+', '+', '- ',  [ "'"      ] ],
  'dot-dash' =>		[ '+', '+', '+', '+', '.-',  [ '!'      ] ],
  'dot-dot-dash' =>	[ '+', '+', '+', '+', '..-', [ '|', ':' ] ],
  bold =>		[ '#', '#', '#', '#', '#',   [ '#'      ] ],
  double =>		[ '#', '#', '#', '#', '=',   [ 'H'      ] ],
  'double-dash' =>	[ '#', '#', '#', '#', '= ',  [ '"'      ] ],
  wave =>		[ '+', '+', '+', '+', '~',   [ '{', '}' ] ],
  };

sub _draw_border
  {
  # draws a border into the framebuffer
  my ($self, $fb, $do_right, $do_bottom, $do_left, $do_top) = @_;

  return if $do_right.$do_left.$do_bottom.$do_top eq 'nonenonenonenone';

  if ($do_top ne 'none')
    {
    # make a copy of the style, so that we can modify it for partial borders
    my $style = [ @{ $border_styles->{$do_top} } ];
    die ("Unknown top border style '$do_top'") if @$style == 0;

    # generate the top border
    my $top = $style->[0] . $style->[4] x (($self->{w}-1) / length($style->[4]));
    chop($top) if length($top) >= $self->{w};
    $top .= $style->[1];
    # insert top row into FB
    $self->_printfb( $fb, 0,0, $top);
    }

  if ($do_bottom ne 'none')
    {
    # make a copy of the style, so that we can modify it for partial borders
    my $style = [ @{ $border_styles->{$do_bottom} } ];
    die ("Unknown bottom border style '$do_bottom'") if @$style == 0;

    # the bottom row '+--------+' etc
    my $bottom = $style->[3] . $style->[4] x (($self->{w}-1) / length($style->[4]));
    chop($bottom) if length($bottom) >= $self->{w};
    $bottom .= $style->[2];
    # insert bottom row into FB
    $self->_printfb( $fb, 0,$self->{h}-1, $bottom);
    }

  return if $do_right.$do_left eq 'nonenone';	# both none => done

  # make a copy of the style, so that we can modify it for partial borders
  my $style = [ @{ $border_styles->{$do_left} } ];
  die ("Unknown left border style '$do_left'") if @$style == 0;
  my $left = $style->[5];
  my $lc = scalar @{ $style->[5] } - 1;		# count of characters

  # make a copy of the style, so that we can modify it for partial borders
  $style = [ @{ $border_styles->{$do_right} } ];
  die ("Unknown left border style '$do_right'") if @$style == 0;
  my $right = $style->[5];
  my $rc = scalar @{ $style->[5] } - 1;		# count of characters

  my (@left, @right);
  my $l = 0; my $r = 0;				# start with first character
  for (1..$self->{h}-2)
    {
    push @left, $left->[$l]; $l ++; $l = 0 if $l > $lc;
    push @right, $right->[$r]; $r ++; $r = 0 if $r > $rc;
    }
  # insert left/right columns into FB
  $self->_printfb( $fb, 0,1, @left) unless $do_left eq 'none';
  $self->_printfb( $fb, $self->{w}-1, 1, @right) unless $do_right eq 'none';

  $self;
  }

sub _draw_label
  {
  # insert the label into the framebuffer
  my ($self, $fb) = @_;

  my @lines = $self->_formatted_label();

  #        +----
  #        | Label  
  # 2,1: ----^

  # XXX TODO: center label? align left/right/center/top/bottom?
  #my $border = $self->attribute('border-style') || 'none';
  #my $y = 1; $y = 0 if $border eq 'none';

  $self->_printfb ($fb, 2, 1, @lines);
  }

sub as_ascii
  {
  # renders a node like:
  # +--------+    ..........    ""
  # | A node | or : A node : or " --> "
  # +--------+    ..........    "" 
  my ($self) = @_;

  # invisible nodes
  return "" if ($self->attribute('shape')||'') eq 'invisible';

  my $border_style = $self->attribute('border-style') || 'solid';
  my $border_width = $self->attribute('border-width') || '1';

  # XXX TODO: borders for groups in ASCII output
  $border_style = 'none' if ref($self) =~ /Group/;

  # "3px" => "bold"
  $border_style = 'bold' if $border_width > 2;

  my $fb = $self->_framebuffer($self->{w}, $self->{h});

  my $style = $border_style;

  # draw our border into the framebuffer
  # XXX TODO: different styles for the different borders
  $self->_draw_border($fb, $style, $style, $style, $style) unless $style eq 'none';

  # "draw" the label into the framebuffer
  $self->_draw_label($fb);
  
  join ("\n", @$fb);
  }

sub error
  {
  my $self = shift;

  $self->{error} = $_[0] if defined $_[0];
  $self->{error};
  }

sub attributes_as_txt
  {
  # return the attributes of this node as text description
  my $self = shift;

  my $att = '';
  my $class = $self->class();
  my $a = $self->{att};
  my $g = $self->{graph};

  # XXX TODO: could use remap_attributes()
  for my $atr (sort keys %$a)
    {
    # attribute not defined
    next if !defined $a->{$atr};

    next if $atr =~ /^border/;			# handled special

    # attribute defined, but same as default
    if (defined $g)
      {
      my $DEF = $g->attribute ($class, $atr);
      next if defined $DEF && $a->{$atr} eq $DEF;
      }

    my $val = $a->{$atr};
    # encode critical characters
    $val =~ s/([;\x00-\x1f])/sprintf("%%%02x",ord($1))/eg;

    $att .= "$atr: $val; ";
    }

  my $border = $self->border_attribute() || '';

  if (defined $g)
    {
    my $DEF = $g->border_attribute ($class);
    $border = '' if $border eq $DEF;
    }
  $att .= "border: $border; " if $border ne '';

  # include our subclass as attribute
  $att .= "class: $1; " if $class =~ /\.(\w+)/;
  
  # generate attribute text if nec. 
  $att = ' { ' . $att . '}' if $att ne '';

  $att;
  }

sub as_pure_txt
  {
  my $self = shift;
  
  my $name = $self->{name};

  # quote special chars in name
  $name =~ s/([\[\]\|\{\}\#])/\\$1/g;

  '[ ' .  $name . ' ]';
  }

sub as_txt
  {
  my $self = shift;

  my $name = $self->{name};

  # quote special chars in name
  $name =~ s/([\[\]\|\{\}\#])/\\$1/g;

  '[ ' .  $name . ' ]' . $self->attributes_as_txt();
  }

sub as_html
  {
  my ($self, $tag, $id, $noquote) = @_;

  $tag = 'td' unless defined $tag && $tag ne '';
  $id = '' unless defined $id;
  my $a = $self->{att};

  # return yourself as HTML
  my $shape = $self->attribute('shape') || '';

  # shape: invisible; must result in an empty cell
  if ($shape eq 'invisible')
    {
    return "<$tag style=\"border: none; background: inherit;\"></$tag>";
    }

  my $class = $self->class();
  my $c = $class; $c =~ s/\./-/g;	# node.city => node-city
  my $html = "<$tag";
  $html .= " class='$c'" if $class ne '';

  my $name = $self->label(); 

  if (!$noquote)
    {
#    $name = $self->{att}->{label}; $name = $self->{name} unless defined $name;

    $name =~ s/&/&amp;/g;			# quote &
    $name =~ s/>/&gt;/g;			# quote >
    $name =~ s/</&lt;/g;			# quote <

    $name =~ s/([^\\])\\n/$1\n/g;		# "\\n" to "\n" (but not "\\\n")
    $name =~ s/\n/<br>/g;			# |\n|\nv => |<br>|<br>v
    $name =~ s/^\s*<br>//;			# remove empty leading line
    $name =~ s/<br>/<br \/>/g;			# correct <br>
    }

  my $style = '';

  $style .= "-moz-border-radius: 10%; " if $shape eq 'rounded';
  $style .= "-moz-border-radius: 100%; " if $shape eq 'ellipse';
  if ($shape eq 'circle')
    {
    my ($w, $h) = $self->dimensions();
    my $r = $w; $r = $h if $h > $w;
    my $size = ($r * 0.7) . 'em';
    $style .= "-moz-border-radius: 100%; height: $size; width: $size; ";
    }

  for my $atr (sort keys %$a)
    {
    # attribute not defined
    next if !defined $a->{$atr};

    # skip these:
    next if $atr =~
	/^(label|linkbase|link|autolink|autotitle|title|shape)\z/;

    # attribute defined, but same as default (or node not in a graph)
#    if (!defined $self->{graph})
#      {
#      print STDERR "Node $self->{name} is not associated with a graph!\n";
#      }
    next unless ref($self->{graph}) =~ /Graph/;
    
    my $DEF = $self->{graph}->attribute ($class, $atr);
    next if defined $DEF && $a->{$atr} eq $DEF;

    $style .= "$atr: $a->{$atr}; ";
    }
  $style =~ s/;\s$//;				# remove '; ' at end
  $html .= " style=\"$style\"" if $style;

  my $title = $self->title();

  if ($title ne '')
    {
    $title =~ s/"/&#22;/g;			# replace quotation marks
    $html .= " title=\"$title\"";		# cell with mouse-over title
    }

  my $link = $self->attribute('link');
  my $autolink = $self->attribute('autolink');
  if (!defined $link && defined $autolink)
    {
    $link = $self->{name} if $autolink eq 'name';
    # defined to avoid overriding "name" with the non-existant label attribute
    $link = $self->{att}->{label} if $autolink eq 'label' && defined $self->{att}->{label};
    $link = $self->{name} if $autolink eq 'label' && !defined $self->{att}->{label};

    warn ("'$autolink' not allowed for attribute 'autolink' on node $self->{name}")
      if $autolink !~ /^(name|label|none)\z/;
    }
  $link = '' unless defined $link;

  # only if link is relative, prepend base
  if ($link ne '' && $link !~ /^\w+:\/\//)
    {
    my $base = $self->attribute('linkbase');
    $link = $base . $link if defined $base;
    }

  if ($link ne '')
    {
    # decode %XX entities
    $link =~ s/%([a-fA-F0-9][a-fA-F0-9])/sprintf("%c",hex($1))/eg;
    # encode critical entities
    $link =~ s/\s/\+/g;			# space
    $html .= "> <a href='$link'>$name</a> </$tag>\n";
    }
  else
    {
    $html .= ">$name</$tag>\n";
    }
  $html;
  }

#############################################################################
# multi-celled nodes

sub grow
  {
  # grows the node until it has sufficient cells for all incoming/outgoing
  # edges
  my $self = shift;

  my $connections = $self->connections();

#  my $direction = $self->attribute('direction') || 90;

  while ( ($self->{cx} * 2 + $self->{cy} * 2) < $connections)
    {
    # find the minimum
    # XXX TODO: use "direction" attribute to choose Y or X preference
    my $grow = 'cy';		# first in Y direction
    $grow = 'cx' if $self->{cx} < $self->{cy};
    $self->{$grow}++;
    }

  # XXX TODO: grow the node based on it's label dimensions
  my ($w,$h) = $self->dimensions();

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

sub x
  {
  my $self = shift;

  $self->{x};
  }

sub contains
  {
  my $self = shift;

  $self->{contains};
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

sub relpos
  {
  my $self = shift;

  ($self->{dx}, $self->{dy});
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

sub shape
  {
  my $self = shift;

  my $shape = $self->attribute('shape') || 'rect';
  $shape =~ s/^(rectangle|box)\z/rect/;                 # rectangle, box => rect
  $shape;
  }

sub dimensions
  {
  # Returns the dimensions of the node/cell derived from the label (or name) in characters.
  my $self = shift;

  my $label = $self->{att}->{label}; $label = $self->{name} unless defined $label;

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

sub edges_to
  {
  # Return all the edge objects that start at this vertex and go to $other.
  my ($self, $other) = @_;

  my $g = $self->{graph}->{graph};
  my @ids = $g->get_multiedge_ids( $self->{name}, $other->{name} );

  return scalar @ids unless wantarray;			# short cut

  my @E;
  foreach my $id (@ids)
    {
    push @E, $g->get_edge_attribute_by_id( $self->{name}, $other->{name}, $id, OBJ);
    }
  @E;
  }

sub connections
  {
  # return number of connections (incoming+outgoing)
  my $self = shift;

  return 0 unless defined $self->{graph};

  my $g = $self->{graph}->{graph};
  return 0 unless defined $g;

  # It is not enough to just add successors+predecessors, because
  # in a multi-edges graph "A -> B; A -> B", A has one successor,
  # but two connections!

  # XXX TODO find out, whether Graph has a method that returns this.

  my $con = 0;
  my $n = $self->{name};

#  print " suc: ", scalar $g->successors( $n ), " pre: ", scalar $g->predecessors( $n ), "\n";

  my @nodes = $g->successors( $n );
  for my $s (@nodes)
    {

    my $c = scalar $g->get_multiedge_ids( $n, $s );
    my @C = $g->get_multiedge_ids( $n, $s );
#    print "ids $n => $s: ", join (" ",@C), " count $c\n";

    $con += scalar $g->get_multiedge_ids( $n, $s );
    }
  @nodes = $g->predecessors( $n );
  for my $s (@nodes)
    {
    $con += scalar $g->get_multiedge_ids( $s, $n );

    my $c = scalar $g->get_multiedge_ids( $s, $n );
    my @C = $g->get_multiedge_ids( $s, $n );
#    print "ids $s => $n: ", join (" ",@C), " count $c\n";
    }
  $con;
  }

sub sorted_successors
  {
  # return successors of the node sorted by their successor count
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

  my $g = $self->{graph}->{graph};
  return () unless defined $g;

  my @s = $g->successors( $self->{name} );

  my @N;
  foreach my $su (@s)
    {
    push @N, $g->get_vertex_attribute( $su, OBJ );
    }
  @N;
  }

sub predecessors
  {
  # return all nodes (as objects) that link to us
  my $self = shift;

  return () unless defined $self->{graph};
  my $g = $self->{graph}->{graph};
  return () unless defined $g;

  my @p = $g->predecessors( $self->{name} );

  my @N;
  foreach my $pr (@p)
    {
    push @N, $g->get_vertex_attribute( $pr, OBJ );
    }
  @N;
  }

sub class
  {
  my $self = shift;

  $self->{class};
  }

sub sub_class
  {
  my $self = shift;

  if (defined $_[0])
    {
    $self->{class} =~ s/\..*//;		# nix subclass
    $self->{class} .= '.' . $_[0];	# append new one
    }
  $self->{class} =~ /\.(.*)/;
  $1;
  }

sub origin
  {
  # Returns node that this node is relative to (or undef, if not part of
  # any cluster)
  my $self = shift;

  if ($_[0])
    {
    $self->{origin} = shift;
    }

  $self->{origin};
  }

#############################################################################
# attributes

sub border_attribute
  {
  # return "1px solid red" from the border-(style|color|width) attributes
  my ($self) = @_;

  my $style = $self->{att}->{'border-style'} || '';

  return $style if $style =~ /^(none|)\z/;

  my $width = $self->{att}->{'border-width'} || '';
  my $color = $self->{att}->{'border-color'} || '';

  $width = $width.'px' if $width =~ /^\d+\z/;

  my $val = join(" ", $width, $style, $color);
  $val =~ s/^\s+//;
  $val =~ s/\s+\z//;

  $val;
  }

sub attribute
  {
  my ($self, $atr) = @_;

  warn ("Node::attribute() takes only one argument, did you mean set_attribute()?") if @_ > 2;

  return $self->{att}->{$atr} if exists $self->{att}->{$atr};

  my $g = $self->{graph};
  # if we do not belong to a graph, we cannot inherit attributes
  return unless defined $g;

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

  # If neither our group nor our parent class had the attribute, try to
  # inherit it from "graph" as a last resort:
  $att = $g->attribute ('graph', $atr) unless defined $att;

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
  my ($self, $atr, $v) = @_;
  
  warn ("Illegal attribute 'name' in Node::set_attribute()") if $atr eq 'name';
 
  my $val = $v;
  # remove quotation marks
  $val =~ s/^["']//;
  $val =~ s/["']\z//;
  $val =~ s/\\#/#/;		# reverse backslashed \#

  # decode %XX entities
  $val =~ s/%([a-fA-F0-9][a-fA-F0-9])/sprintf("%c",hex($1))/eg;

  if ($atr eq 'class')
    {
    $self->sub_class($val);
    return $self;
    }
  if ($atr eq 'group')
    {
    $self->add_to_groups($val);
    return $self;
    }

  if ($atr eq 'border')
    {
    my $c = $self->{att};

    ( $c->{'border-style'}, $c->{'border-width'}, $c->{'border-color'} ) =
        $self->border_attributes( $val );

    return $val;
    }

  $self->{att}->{$atr} = $val;
  $self;
  }

sub set_attributes
  {
  my ($self, $atr) = @_;
  
  foreach my $n (keys %$atr)
    {
    $n eq 'class' ? $self->sub_class($atr->{$n}) : $self->set_attribute($n, $atr->{$n});
    }
  $self;
  }

sub border_attributes
  {
  # split "1px solid black" or "red dotted" into style, width and color
  my ($self,$border) = @_;

  # extract style
  my $style;
  $border =~ s/(solid|dotted|dot-dash|dot-dot-dash|dashed|double-dash|double|bold|none|wave)/ $style = $1; ''/eg;

  $style ||= 'solid';

  # extract width
  $border =~ s/(\d+(px|em))//g;

  my $width = $1 || '1';
  $width =~ s/\D+//g;				# leave only digits
  $width = 0 if $style eq 'none';

  $border =~ s/\s+//g;				# rem unnec. spaces

#  print STDERR "border: ($val) style '$style' color '$border' width '$width'\n";

  # XXX TODO: more strict checks on possible values
  ($style,$width,$border || 0);			# left over must be color
  }

#############################################################################

sub groups
  {
  # in scalar context, return number of groups this node belongs to
  # in list context, returns all groups as list of objects, sorted by their
  # name
  my ($self) = @_;

  if (wantarray)
    {
    my @groups;
    for my $g (sort keys %{$self->{groups}})
      {
      push @groups, $self->{groups}->{$g};
      }
    return @groups;
    }
  scalar keys %{$self->{groups}};
  }

sub group
  {
  # return group with name $name
  my ($self, $group) = @_;

  $self->{groups}->{$group};
  }

sub add_to_groups
  {
  my ($self,@groups) = @_;

  my $graph = $self->{graph};				# shortcut

  for my $group (@groups)
    {
    # if passed a group name, create or find group object
    if (!ref($group) && $graph)
      {
      my $g = $graph->group($group);
      $g = Graph::Easy::Group->new( { name => $group } ) unless defined $g;
      $group = $g;
      }
    # store the group, indexed by name (to avoid double entries)
    $self->{groups}->{ $group->{name} } = $group;
    $group->add_node($self);
    }
  $self;
  }

#############################################################################
# cluster handling

sub add_to_cluster
  {
  # add the node to the specified cluster
  my ($self,$cluster) = @_;

  my $graph = $self->{graph};				# shortcut

  # if passed a cluster name, create or find cluster object
  if (!ref($cluster) && $graph)
    {
    my $g = $graph->cluster($cluster);
    $g = Graph::Easy::Cluster->new( { name => $cluster } ) unless defined $g;
    $cluster = $g;
    }

  # store the cluster
  $self->{cluster} = $cluster;
  $cluster->add_node($self);
  $self;
  }

sub cluster
  {
  # set/get the cluster
  my ($self) = shift;

  $self->{cluster} = shift if $_[0];
  
  # return the cluster
  $self->{cluster};
  }

1;
__END__

=head1 NAME

Graph::Easy::Node - Represents a node in a simple graph

=head1 SYNOPSIS

        use Graph::Easy::Node;

	my $bonn = Graph::Easy::Node->new(
		name => 'Bonn',
		border => 'solid 1px black',
	);
	my $berlin = Graph::Easy::Node->new(
		name => 'Berlin',
	)

=head1 DESCRIPTION

A C<Graph::Easy::Node> represents a node in a simple graph. Each
node has contents (a text, an image or another graph), and dimension plus
an origin. The origin is typically determined by a graph layouter module
like L<Graph::Easy>.

=head1 METHODS

        my $node = Graph::Easy::Group->new( $options );

Create a new node. C<$options> are the possible options:

	name		Name of the node
	border		Border style and color

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

	my $html = $node->as_html($tag, $id, $noquote);

Return the node in HTML. The C<$tag> is the optional name of the HTML
tag to surround the node name with. C<$id> is an optional ID that is
tagged onto the classname for the CSS. If the last parameter, C<$noquote>,
is true, then the node's name will not be quoted/encoded for HTML output.
This is usefull if it's name is already quoted.

Example:

	print $node->as_html('span');

Would print something like:

	<span class="node"> Bonn </span>

While:

	print $node->as_html('td');

Would print something like:

	<td class="node"> Bonn </td>

The following:

	print $node->as_html('span', '12');

Would print something like:

	<span class="node12"> Bonn </span>

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

=head2 name()

	my $name = $node->name();

Return the name of the node.

=head2 label()

	my $label = $node->label();

Return the label of the node. If no label was set, returns the C<name>
of the node.

=head2 title()

	my $title = $node->title();

Returns a potential title that can be used for mouse-over effects.
If no title was set (or autogenerated), will return an empty string.

=head2 dimensions()

	my ($w,$h) = $node->dimensions();

Returns the dimensions of the node/cell derived from the label (or name) in characters.
Assumes the label/name has literal '\n' replaced by "\n".

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

=head2 relpos()

	my ($dx,$dy) = $node->relpos();

Returns the position of the node relativ to the origin. For the origin node
itself (see L<origin()> or for nodes not belonging to any cluster, returns
C<<0,0>>.

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

=head2 edges_to()

	my @edges = $node->edges_to($other_node);

Returns all the edge objects that start at C<< $node >> and go to C<< $other_node >>.

=head2 add_to_groups()

	$node->add_to_groups( @groupd );

Add the node to multiple groups at once.

=head2 groups()

	my @groups = $node->groups();

In scalar context, return number of groups this node belongs to.
In list context, returns all groups as list of objects, sorted by their
name.

=head2 group()

	$node->group('groupname');

Returns the group with the specified name if the node belongs to that group,
othrwise undef.

=head2 cluster()

	my $cluster = $node->cluster();

	$node->cluster('clustername');
	$node->cluster($cluster);

Get or set the cluster that this node belongs to.

=head2 add_to_cluster()

	$node->add_to_cluster($cluster);

Add the node to the specified cluster. C<$cluster> is either the cluster
name, or a reference pointing to a L<Graph::Easy::Cluster> object.

=head2 place()

	if ($node->place($x,$y,$cells))
	  {
	  ...
	  }

Tries to place the node at position C<< ($x,$y) >> by checking that
C<<$cells->{"$x,$y"}>> is still free. If the node belongs to a cluster,
checks all nodes of the cluster and when all of them can be
placed without a problem, does so.

Returns true if the operation succeeded, otherwise false.

=head2 shape()

	my $shape = $node->shape();

Returns the shape of the node as string, defaulting to 'rect'. Both
'rectangle' and 'box' as node shapes will result in 'rect' as return
value.

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
