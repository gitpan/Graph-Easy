#############################################################################
# Represents one node in a Graph::Easy
#
# (c) by Tels 2004-2006. Part of Graph::Easy
#############################################################################

package Graph::Easy::Node;

$VERSION = '0.27';

use Graph::Easy::Base;
@ISA = qw/Graph::Easy::Base/;

use strict;

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
 
  # These are undef (to save memory) until needed: 
  # $self->{children} = {};
  # $self->{dx} = 0;		# relative to no other node
  # $self->{dy} = 0;
  # $self->{origin} = 0;
  # $self->{group} = undef;
  
  $self;
  }

sub _border_styles
  {
  # return the four border styles (right, bottom, left, top)
  my $self = shift;

  my $border = $self->attribute('border-style') || 'none';
  my $width = $self->attribute('border-width') || '1';
  my $color = $self->color_attribute('border-color') || '#000000';

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
    my $style = $self->attribute('point-style') || 'star';
    if ($style eq 'invisible')
      {
      $self->{w} = 0; $self->{h} = 0; return; 
      }
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

  $self->_calc_size() unless defined $self->{cx};

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

sub _mark_as_placed
  {
  # for creating an action on the action stack we also need to recursively
  # mark all our children as already placed:
  my ($self) = @_;

  no warnings 'recursion';

  delete $self->{_todo};

  for my $child (values %{$self->{children}})
    {
    $child->_mark_as_placed();
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
    # compute place of children (depending on whether we are multicelled or not)

    my $dx = $child->{dx} > 0 ? $self->{cx} - 1 : 0;
    my $dy = $child->{dy} > 0 ? $self->{cy} - 1 : 0;

    my $rc = $child->_place_children($x + $dx + $child->{dx},$y + $dy + $child->{dy},$cells);
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

#  $self->_calc_size() unless defined $self->{cx};

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

        my $filler = 
	  Graph::Easy::Node::Cell->new ( node => $self, x => $sx, y => $sy );
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

  $self->_calc_size() unless defined $self->{cx};

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

sub _do_place
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

  $self->_calc_size() unless defined $self->{cx};

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

sub _wrapped_label
  {
  # returns the label wrapped automatically to use the least space
  my ($self, $name, $align) = @_;

  use Text::Wrap;

  # XXX TODO: handle "paragraphs"
  $name =~ s/\\(n|r|l|c)//;		# remove line splits 

  my $cols = $self->{w};
  if (!defined $cols)
    {
    # find out where to wrap
    $cols = int(sqrt(length($name)) * 1.4);
    $cols = 2 if $cols < 2;

    # print STDERR "# Wrapping: min-columns is $cols\n";
 
    # find longest word, and set columns to it if longer
    my $l;

    $name =~ s/([^-\s]+)/ $l = $1, $cols = length($1)+2 if length($1)+2 > $cols; $1; /eg;

    # print STDERR "# longest word is '$l'\n";
    }
  else
    {
    # XXX TODO: -2 if no border
    $cols -= 2;
    }


# $cols = length($1) if length($1) > $cols;

  $Text::Wrap::columns = $cols;

  $name = Text::Wrap::wrap('','',$name); 

  my @aligns;
  my $al = substr($align,0,1); 
  my @lines = split /\n/, $name;
  for my $i (0.. scalar @lines)
    {
    push @aligns, $al; 
    }
  (\@lines, \@aligns);
  }

sub _aligned_label
  {
  # returns the label lines and for each one the alignment l/r/c
  my ($self, $align, $wrap) = @_;

  $align = 'center' unless $align;
  $wrap = $self->attribute('text-wrap') || 'none' unless defined $wrap;

  my $name = $self->label();

  return $self->_wrapped_label($name,$align) unless $wrap eq 'none';

  my (@lines,@aligns);
  my $al = substr($align,0,1);
  my $last_align = $al;

  # split up each line from the front
  while ($name ne '')
    {
    $name =~ s/^(.*?([^\\]|))(\z|\\(n|r|l|c))//;
    my $part = $1;
    my $a = $3 || '\n';

    $part =~ s/\\\|/\|/g;		# \| => |
    $part =~ s/\\\\/\\/g;		# '\\' to '\'
    $part =~ s/^\s+//;			# remove spaces at front
    $part =~ s/\s+\z//;			# remove spaces at end
    $a =~ s/\\//;			# \n => n
    $a = $al if $a eq 'n';
    
    push @lines, $part;
    push @aligns, $last_align;

    $last_align = $a;
    }

  # XXX TODO: should remove empty lines at start/end?
  (\@lines, \@aligns);
  }

#############################################################################
# as_html conversion and helper functions related to that

my $remap = {
  node => {
    align => undef,
    background => undef,
    basename => undef,
    'border' => undef,
    'border-style' => undef,
    'border-width' => undef,
    'border-color' => undef,
    columns => undef,
    fill => 'background',
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
    align => 'text-align',
    autolink => undef,
    autotitle => undef,
    'font-size' => undef,
    font => 'font-family',
    flow => undef,
    format => undef,
    label => undef,
    link => undef,
    linkbase => undef,
    style => undef,
    'text-style' => undef,
    title => undef,
    'text-wrap' => \&Graph::Easy::_remap_text_wrap,
    },
  };

sub _extra_params
  {
  # return text with a leading " ", that will be appended to "td" when
  # generating HTML
  '';
  }

# XXX TODO: <span class="o">?
my $pod = {
  B => [ '<b>', '</b>' ],
  O => [ '<span style="text-decoration: overline">', '</span>' ],
  S => [ '<span style="text-decoration: line-through">', '</span>' ],
  U => [ '<span style="text-decoration: underline">', '</span>' ],
  C => [ '<code>', '</code>' ],
  I => [ '<i>', '</i>' ],
  };

sub _convert_pod
  {
  my ($self, $type, $text) = @_;

  my $t = $pod->{$type} or return $text;

  # "<b>" . "text" . "</b>"
  $t->[0] . $text . $t->[1];
  }

sub _label_as_html
  {
  # Build the text from the lines, by inserting <b> for each break
  # Also align each line, and if nec., convert B<bold> to <b>bold</b>.
  my ($self) = @_;

  my $align = $self->attribute('align') || $self->default_attribute('align') || 'center';
  my $text_wrap = $self->attribute('text-wrap') || 'none';

  my ($lines,$aligns);
  if ($text_wrap ne 'none')
    {
    # set "white-space: nowrap;" in CSS and ignore linebreaks in label
    $lines = [ $self->label() ];
    $aligns = [ substr($align,0,1) ];
    }
  else
    {
    ($lines,$aligns) = $self->_aligned_label($align,'none');
    }

  # Since there is no "float: center;" in CSS, we must set the general
  # text-align to center when we encounter any \c and the default is
  # left or right:

  my $switch_to_center = 0;
  if ($align ne 'center')
    {
    local $_;
    $switch_to_center = grep /^c/, @$aligns;
    }

  $align = 'center' if $switch_to_center;
  my $a = substr($align,0,1);			# center => c

  my $format = $self->attribute('format') || 'none';

  my $name = '';
  my $i = 0;
  while ($i < @$lines)
    {
    my $line = $lines->[$i];
    my $al = $aligns->[$i];

    # This code below will not handle B<bold\n and bolder> due to the
    # line break. Also, nesting does not work due to returned "<" and ">".

    if ($format eq 'pod')
      {
      # first inner-most, then go outer until there are none left
      $line =~ s/([BOSUCI])<([^<>]+)>/ $self->_convert_pod($1,$2);/eg
        while ($line =~ /[BOSUCI]<[^<>]+>/)
      }
    else
      { 
      $line =~ s/>/&gt;/g;			# quote >
      $line =~ s/</&lt;/g;			# quote <
      }
    $line =~ s/&/&amp;/g;			# quote &
    $line =~ s/\\\\/\\/g;			# "\\" to "\"

    # insert a span to align the line unless the default already covers it
    $line = '<span class="' . $al . '">' . $line . '</span>'
      if $a ne $al;
    $name .= "<br \/>" . $line;

    $i++;					# next line
    }
  $name =~ s/^<br \/>//;			# remove first <br> 

  ($name, $switch_to_center);
  }

sub as_html
  {
  my ($self) = @_;

  my $extra = $self->_extra_params();
  my $taga = "td$extra";
  my $tagb = 'td';

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
    return " <$taga colspan=$cs rowspan=$rs style=\"border: none; background: inherit;\"></$tagb>\n";
    }

  my $c = $class; $c =~ s/\./-/g;	# node.city => node-city

  my $html = " <$taga colspan=$cs rowspan=$rs";
  $html .= " class='$c'" if $c ne '';
   
  my $link = $self->link();

  my $title = $self->title();
  $title =~ s/'/&#27;/g;			# replace quotation marks

  $html .= " title='$title'" if $title ne '' && $shape ne 'img';	# add mouse-over title

  my ($name, $switch_to_center);

  if ($shape eq 'point')
    {
    require Graph::Easy::As_ascii;		# for _u8 and point-style

    local $self->{graph}->{_ascii_style} = 1;	# use utf-8
    $name = $self->_point_style( $self->attribute('point-style') || 'star' );
    }
  elsif ($shape eq 'img')
    {
    # take the label as the URL, but escape critical characters
    $name = $self->label();
    $name =~ s/\s/\+/g;				# space
    $name =~ s/'/%27/g;				# replace quotation marks
    $name =~ s/\n//g;				# remove newlines
    my $t = $title; $t = $name if $t eq ''; 
    $name = "<img src='$name' alt='$t' title='$t' border='0' />";
    }
  else
    {
    ($name,$switch_to_center) = $self->_label_as_html(); 
    }

  my $out = $self->{graph}->_remap_attributes( $self, $self->{att}, $remap, 'noquote', 'encode', 'remap_colors');

  $out->{'text-align'} = 'center' if $switch_to_center;

  if ($shape eq 'rounded')
    {
    $out->{'-moz-border-radius'} = '15px';
    $out->{'border-radius'} = '15px';
    }
  if ($shape eq 'ellipse')
    {
    $out->{'-moz-border-radius'} = '100%';
    $out->{'border-radius'} = '100%';
    }
  if ($shape eq 'circle')
    {
    my ($w, $h) = $self->dimensions();
    my $r = $w; $r = $h if $h > $w;
    my $size = ($r * 0.7) . 'em';
    $out->{'-moz-border-radius'} = '100%';
    $out->{'border-radius'} = '100%';
    $out->{width} = $size;
    $out->{height} = $size;
    }

  if (!$self->isa('Graph::Easy::Edge'))
    {
    my $bc = $self->attribute('border-color');
    my $bw = $self->attribute('border-width');
    my $bs = $self->attribute('border-style');

    $out->{border} = Graph::Easy::_border_attribute_as_html( $bs, $bw, $bc );
    my $c = $class;
    $c =~ s/\s+.*//;	# "group gt" => "group"
    my $DEF = $g->border_attribute ($c);

    $c =~ s/\..*//;	# remove subclasses
    $DEF = $g->border_attribute ($c) if !defined $DEF || $DEF eq '';
    $DEF = 'none' unless defined $DEF;

    delete $out->{border} if $out->{border} =~ /^\s*\z/ || $out->{border} eq $DEF;
    delete $out->{border} if $class eq 'node.anon' && $out->{border} eq 'none';
    }

  if ($class =~ /^group/)
    {
    delete $out->{border};
    my $group_class = $class; $group_class =~ s/\s.*//;	# "group gt" => "group"
    my @atr = qw/border-color border-width fill/;

    # only need the color for the label cell
    push @atr, 'color' if $self->{has_label};
    for my $b (@atr)
      {
      my $def = $g->attribute($group_class,$b) || '';
      my $v = $self->attribute($b) || '';
      my $n = $b; $n = 'background' if $b eq 'fill';
      $out->{$n} = $v unless $v eq '' || $v eq $def;
      }
    $name = '&nbsp;' unless $name ne '';
    }

  # "shape: none;" or point means no border, and background instead fill color
  if ($shape =~ /^(point|none)\z/)
    {
    my $bg = $self->color_attribute('background') || 'inherit'; 
    $out->{background} = $bg;
    $out->{border} = 'none';
    }

  my $style = '';
  for my $atr (sort keys %$out)
    {
    if ($link ne '')
      {
      # put certain styles not on the link, but on the TD
      next if $atr =~ /^(background|border|border-radius|width|height|-moz-border-radius)\z/;
      }
    $style .= "$atr: $out->{$atr}; ";
    }

  # bold, italic, underline etc. (but not for empty cells)
  $style .= $self->text_styles_as_css(1,1) if $name !~ /^(|&nbsp;)\z/;

  $style =~ s/;\s$//;				# remove '; ' at end
  $style =~ s/\s+/ /g;				# '  ' => ' '
  $style =~ s/^\s+//;				# remove ' ' at front

  my $end_tag = "</$tagb>\n";

  if ($link ne '')
    {
    # encode critical entities
    $link =~ s/\s/\+/g;				# space
    $link =~ s/'/%27/g;				# replace quotation marks

    # put certain styles like border and background on the table cell,
    # but the other styles on the link
    my $td_style = '';
    for my $s (qw/background border border-radius height width -moz-border-radius/)
      {
      $td_style .= "$s: $out->{$s};" if exists $out->{$s};
      }
    $td_style =~ s/;\z//;				# remove last ;
    $td_style = " style=\"$td_style\"" if $td_style;

    $html .= "$td_style><a href='$link'";	# put the style on "<a.."
    $end_tag = '</a>'.$end_tag;
    }
  $html .= " style=\"$style\"" if $style;
  $html .= ">$name";
  $html .= "$end_tag";

  $html;
  }

sub angle
  {
  # return the rotation of the node, dependend on the rotate attribute
  # (and if relative, on the flow)
  my $self = shift;

  my $angle = $self->{att}->{rotate} || 0;

  $angle = 180 if $angle =~ /^(south|down)\z/;
  $angle = 0 if $angle =~ /^(north|up)\z/;
  $angle = 270 if $angle eq 'west';
  $angle = 90 if $angle eq 'east';

  # convert relative angles
  if ($angle =~ /^([+-]\d+|left|right|back|front|forward)\z/)
    {
    my $base_rot = $self->flow();
    $angle = 0 if $angle =~ /^(front|forward)\z/;
    $angle = 180 if $angle eq 'back';
    $angle = -90 if $angle eq 'left';
    $angle = 90 if $angle eq 'right';
    $angle = $base_rot + $angle + 0;	# 0 points up, so front points right
    $angle += 360 while $angle < 0;
    }

  $self->_croak("Illegal node angle $angle") if $angle !~ /^\d+\z/;

  $angle %= 360 if $angle > 359;

  $angle;
  }

# for determining the absolute parent flow
my $p_flow =
  {
  'east' => 90,
  'west' => 270,
  'north' => 0,
  'south' => 180,
  'up' => 0,
  'down' => 180,
  'back' => 270,
  'left' => 270,
  'right' => 90,
  'front' => 90,
  'forward' => 90,
  };

sub _parent_flow_absolute
  {
  # make parent flow absolute
  my ($self, $def)  = @_;

  return '90' if ref($self) eq 'Graph::Easy';

  my $flow = $self->parent()->attribute('flow') || $def;

  return unless defined $flow;

  # in case of relative flow at parent, convert to absolute (right: east, left: west etc) 
  # so that "graph { flow: left; }" results in a westward flow
  my $f = $p_flow->{$flow}; $f = $flow unless defined $f;
  $f;
  }

sub flow
  {
  # Calculate the outgoing flow from the incoming flow and the flow at this
  # node (either from edge(s) or general flow). Returns an absolute flow:
  # See the online manual about flow for a reference and details.
  my $self = shift;

  no warnings 'recursion';

  return $self->{_cached_flow} if exists $self->{_cached_flow};

  # detected cycle, so break it
  return $self->{_cached_flow} = $self->_parent_flow_absolute('90') if exists $self->{_flow};

  local $self->{_flow} = undef;		# endless loops really ruin our day

  my $in;
  my $flow = $self->{att}->{flow};

  $flow = $self->_parent_flow_absolute() unless defined $flow;

  # if flow is absolute, return it early
  return $self->{_cached_flow} = $flow if defined $flow && $flow =~ /^(0|90|180|270)\z/;
  return $self->{_cached_flow} = Graph::Easy->_direction_as_number($flow)
    if defined $flow && $flow =~ /^(south|north|east|west|up|down)\z/;
  
  # for relative flows, compute the incoming flow as base flow

  # check all edges
  for my $e (values %{$self->{edges}})
    {
    # only count incoming edges
    next unless $e->{from} != $self && $e->{to} == $self;

    # if incoming edge has flow, we take this
    $in = $e->flow();
    # take the first match
    last if defined $in;
    }

  if (!defined $in)
    {
    # check all predecessors
    for my $e (values %{$self->{edges}})
      {
      my $pre = $e->{from};
      $pre = $e->{to} if $e->{bidirectional};
      if ($pre != $self)
        {
        $in = $pre->flow();
        # take the first match
        last if defined $in;
        }
      }
    }

  $in = $self->_parent_flow_absolute('90') unless defined $in;

  $flow = Graph::Easy->_direction_as_number($in) unless defined $flow;

#  print STDERR "# flow for $self->{name}: $in $flow\n";

  $self->{_cached_flow} = Graph::Easy->_flow_as_direction($in,$flow);

#  print STDERR " result $self->{_cached_flow}\n";

  $self->{_cached_flow};
  }

#############################################################################
# multi-celled nodes

sub _calc_size
  {
  # Calculate the base size in cells from the attributes (before grow())
  # Will return a hash that denotes in which direction the node should grow.
  my $self = shift;

  # default is 1,1
  my ($cx,$cy) = (1,1);

  # if specified "rows", or "columns" (and not "size"), then grow the node
  # only in the unspecified direction. Default is grow both.
  my $grow_sides = { cx => 1, cy => 1 };

  my $size = $self->attribute('size');
  if (!defined $size)
    {
    my $rows = $self->attribute('rows');
    my $cols = $self->attribute('columns');
    delete $grow_sides->{cy} if defined $rows && !defined $cols;
    delete $grow_sides->{cx} if defined $cols && !defined $rows;
    $cx = $cols if defined $cols;    
    $cy = $rows if defined $rows;    
    }
  else
    {
    ($cx,$cy) = split /\s*,\s*/, $size;
    }

  $self->{cx} = abs($cx || 1);
  $self->{cy} = abs($cy || 1);

  $grow_sides;
  }

sub grow
  {
  # Grows the node until it has sufficient cells for all incoming/outgoing
  # edges. The initial size will be based upon the attributes 'size' (or
  # 'rows' or 'columns', depending on which is set)
  my $self = shift;

  # grow() is called for every node before layout(), so uncache the flow
  delete $self->{_cached_flow};

  # XXX TODO: grow the node based on its label dimensions
#  my ($w,$h) = $self->dimensions();
#
#  my $cx = int(($w+2) / 5) || 1;
#  my $cy = int(($h) / 3) || 1;
#
#  $self->{cx} = $cx if $cx > $self->{cx};
#  $self->{cy} = $cy if $cy > $self->{cy};

  # satisfy the edge start/end port constraints:

  # We calculate a bitmap (vector) for each side, and mark each
  # used port. Edges that have an unspecified port will just be
  # counted.

  # bitmap for each side:
  my $vec = { north => '', south => '', east => '', west => '' };
  # number of edges constrained to one side, but without port number
  my $cnt = { north => 0, south => 0, east => 0, west => 0 };
  # number of edges constrained to one side, with port number
  my $portnr = { north => 0, south => 0, east => 0, west => 0 };
  # max number of ports for each side
  my $max = { north => 0, south => 0, east => 0, west => 0 };

  my @idx = ( [ 'start', 'from' ], [ 'end', 'to' ] );
  # number of slots we need to edges without port restrictions
  my $unspecified = 0;

  for my $e (values %{$self->{edges}})
    {
    # do always both ends, because self-loops can start AND end at this node:
    for my $end (0..1)
      {
      # if the edge starts/ends here
      if ($e->{$idx[$end]->[1]} == $self)		# from/to
	{
	my ($side, $nr) = $e->port($idx[$end]->[0]);	# start/end

	if (defined $side)
	  {
	  if (!defined $nr || $nr eq '')
	    {
	    # no port number specified, so just count
	    $cnt->{$side}++;
	    }
	  else
	    {
	    # mark the bit in the vector
	    # limit to four digits
	    $nr = 9999 if abs($nr) > 9999; 

	    # if slot was not used yet, count it
	    $portnr->{$side} ++ if vec($vec->{$side}, $nr, 1) == 0x0;

	    # calculate max number of ports
            $nr = abs($nr) - 1 if $nr < 0;		# 3 => 3, -3 => 2
            $nr++;					# 3 => 4, -3 => 3

	    # mark as used
	    vec($vec->{$side}, $nr - 1, 1) = 0x01;

	    $max->{$side} = $nr if $nr > $max->{$side};
	    }
          }
        else
          {
          $unspecified ++;
          }
        } # end if port is constrained
      } # end for start/end port
    } # end for all edges

  for my $e (values %{$self->{edges}})
    {
    # the loop above will count all self-loops twice when they are
    # unrestricted. So subtract these again. Restricted self-loops
    # might start at one port and end at another, and this case is
    # covered correctly by the code above.
    $unspecified -- if $e->{to} == $e->{from};
    }

  my $need = {};
  my $free = {};
  for my $side (qw/north south east west/)
    {
    # maximum number of ports we need to reserve, minus edges constrained
    # to unique ports: free ports on that side
    $free->{$side} = $max->{$side} - $portnr->{$side};
    $need->{$side} = $max->{$side};
    if ($free->{$side} < 2 * $cnt->{$side})
      {
      $need->{$side} += 2 * $cnt->{$side} - $free->{$side} - 1;
      } 
    }
  # now $need contains for each side the absolut min. number of ports we need

#  use Data::Dumper; 
#  print STDERR "# port contraints for $self->{name}:\n";
#  print STDERR "# count: ", Dumper($cnt), "# max: ", Dumper($max),"\n";
#  print STDERR "# ports: ", Dumper($portnr),"\n";
#  print STDERR "# need : ", Dumper($need),"\n";
#  print STDERR "# free : ", Dumper($free),"\n";
 
  # calculate min. size in X and Y direction
  my $min_x = $need->{north}; $min_x = $need->{south} if $need->{south} > $min_x;
  my $min_y = $need->{west}; $min_y = $need->{east} if $need->{east} > $min_y;

  my $grow_sides = $self->_calc_size();

  # increase the size if the minimum required size is not met
  $self->{cx} = $min_x if $min_x > $self->{cx};
  $self->{cy} = $min_y if $min_y > $self->{cy};

  # now grow the node based on the general flow first VER, then HOR
  my $flow = $self->flow();

  my $grow = 0;					# index into @grow_what
  my @grow_what = sort keys %$grow_sides;	# 'cx', 'cy' or 'cx' or 'cy'

  if (keys %$grow_sides > 1)
    {
    @grow_what = ( 'cy', 'cx' ) if $flow == 90 || $flow == 270;
    }

  while ( 3 < 5 )
    {
    # calculate whether we already found a space for all edges
    my $free_ports = 0;
    for my $side (qw/north south/)
      {
      $free_ports += 1 + int(($self->{cx} - $cnt->{$side} - $portnr->{$side}) / 2);
      }     
    for my $side (qw/east west/)
      {
      $free_ports += 1 + int(($self->{cy} - $cnt->{$side} - $portnr->{$side}) / 2);
      }
    last if $free_ports >= $unspecified;

    $self->{ $grow_what[$grow] } += 2;

    $grow ++; $grow = 0 if $grow >= @grow_what;
    }

  $self;
  }

sub is_multicelled
  {
  # return true if node consist of more than one cell
  my $self = shift;

  $self->_calc_size() unless defined $self->{cx};

  $self->{cx} + $self->{cy} <=> 2;	# 1 + 1 == 2: no, cx + xy != 2: yes
  }

sub is_anon
  {
  # normal nodes are not anon nodes (but "::Anon" are)
  0;
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
      $title = '';					# default is none

      if ($autotitle eq 'name')				# use name
	{
        $title = $self->{name};
	# edges do not have a name and fall back on their label
        $title = $self->{att}->{label} unless defined $title;
	}

      if ($autotitle eq 'label')
        {
        $title = $self->{name};				# fallback to name
        # defined to avoid overriding "name" with the non-existant label attribute
	# do not use label() here, but the "raw" label of the edge:
        my $label = $self->label(); $title = $label if defined $label;
        }

      $title = $self->link() if $autotitle eq 'link';
      }
    $title = '' unless defined $title;
    }
  $title;
  }

sub background
  {
  # get the background for this group/edge cell, honouring group membership.
  my $self = shift;

  my $bg = $self->color_attribute('background') || 'inherit';

  if ($bg eq 'inherit')
    {
    # if part of a group, the groups fill is the members background.
    $bg = ($self->{group}->color_attribute('fill')||'inherit')
      if ref $self->{group};
    return '' if $bg eq 'inherit';
    }

  $bg;
  }

sub label
  {
  my $self = shift;

  my $label = $self->attribute('label');
  # for autosplit nodes, use their auto-label first (unless already got 
  # a label from the class):
  $label = $self->{autosplit_label} unless defined $label;
  $label = $self->{name} unless defined $label;

  return '' unless defined $label;

  if ($label ne '')
    {
    my $autolabel = $self->attribute('autolabel');
    if (defined $autolabel)
      {
      # restrict label length?
      my ($what, $len) = split /\s*,\s*/, $autolabel;
      # restrict to sane values
      $len = abs($len || 0); $len = 9999 if $len > 9999;
      if (length($label) > $len)
        {
        $len = int($len / 2) - 3; $len = 0 if $len < 0;
        $label = substr($label, 0, $len) . ' ... ' . substr($label, -$len, $len);
        }
      }
    }
  $label;
  }

sub name
  {
  my $self = shift;

  $self->{name};
  }

sub x
  {
  my $self = shift;

  $self->{x};
  }

sub y
  {
  my $self = shift;

  $self->{y};
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

sub origin
  {
  # Returns node that this node is relative to or undef, if not.
  my $self = shift;

  $self->{origin};
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

sub columns
  {
  my $self = shift;

  $self->_calc_size() unless defined $self->{cx};

  $self->{cx};
  }

sub rows
  {
  my $self = shift;

  $self->_calc_size() unless defined $self->{cy};

  $self->{cy};
  }

sub size
  {
  my $self = shift;

  $self->_calc_size() unless defined $self->{cx};

  ($self->{cx}, $self->{cy});
  }

sub shape
  {
  my $self = shift;

  my $shape;
  $shape = $self->{att}->{shape} if exists $self->{att}->{shape};
  $shape = $self->attribute('shape') || 'rect' unless defined $shape;
  $shape;
  }

sub dimensions
  {
  # Returns the minimum dimensions of the node/cell derived from the
  # label or name, in characters.
  my $self = shift;

  my ($lines,$aligns) = $self->_aligned_label();

  my $w = 0; my $h = scalar @$lines;
  foreach my $line (@$lines)
    {
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

sub edges_at_port
  {
  # return all edges that share the same given port
  my ($self, $attr, $side, $port) = @_;

  # Must be "start" or "end"
  return () unless $attr =~ /^(start|end)\z/;

  $self->_croak('side not defined') unless defined $side;
  $self->_croak('port not defined') unless defined $port;

  my @edges;
  for my $e (values %{$self->{edges}})
    {
    # skip edges ending here if we look at start
    next if $e->{to} eq $self && $attr eq 'start';
    # skip edges starting here if we look at end
    next if $e->{from} eq $self && $attr eq 'end';

    my ($s_p,@ss_p) = $e->port($attr);	
    next unless defined $s_p;

    # same side and same port number?
    push @edges, $e 
      if $s_p eq $side && @ss_p == 1 && $ss_p[0] eq $port;
    }

  @edges;
  }

sub shared_edges
  {
  # return all edges that share one port with another edge
  my ($self) = @_;

  my @edges;
  for my $e (values %{$self->{edges}})
    {
    my ($s_p,@ss_p) = $e->port('start');
    push @edges, $e if defined $s_p;
    my ($e_p,@ee_p) = $e->port('end');
    push @edges, $e if defined $e_p;
    }
  @edges;
  }

sub nodes_sharing_start
  {
  # return all nodes that share an edge start with an
  # edge from that node
  my ($self, $side, @port) = @_;

  my @edges = $self->edges_at_port('start',$side,@port);

  my $nodes;
  for my $e (@edges)
    {
    # ignore self-loops
    my $to = $e->{to};
    next if $to == $self;

    # remove duplicates
    $nodes->{ $to->{name} } = $to;
    }

  (values %$nodes);
  }

sub nodes_sharing_end
  {
  # return all nodes that share an edge end with an
  # edge from that node
  my ($self, $side, @port) = @_;

  my @edges = $self->edges_at_port('end',$side,@port);

  my $nodes;
  for my $e (@edges)
    {
    # ignore self-loops
    my $from = $e->{from};
    next if $from == $self;

    # remove duplicates
    $nodes->{ $from->{name} } = $from;
    }

  (values %$nodes);
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

sub has_predecessors
  {
  # return true if node has incoming edges (even from itself)
  my $self = shift;

  return undef unless defined $self->{graph};

  for my $edge (values %{$self->{edges}})
    {
    return 1 if $edge->{to} == $self;		# found one
    }
  0;						# found none
  }

#############################################################################
# relatively placed nodes

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

  if (wantarray)
    {
    my $ox = 0;
    my $oy = 0;
    while (defined($cur->{origin}))
      {
      $ox -= $cur->{dx};
      $oy -= $cur->{dy};
      $cur = $cur->{origin};
      }
    return ($cur,$ox,$oy);
    }

  while (defined($cur->{origin}))
    {
    $cur = $cur->{origin};
    }
  
  $cur;
  }

#############################################################################
# attributes

sub color_attribute
  {
  # Just like get_attribute(), but for colors, and returns them as hex,
  # using the current colorscheme.
  my ($self, $att) = @_;

  my $color = $self->attribute($att); $color = '' unless defined $color;

  if ($color ne '' && $color !~ /^#/)
    {
    my $scheme = $self->attribute('colorscheme') || 'w3c';
    $scheme = $self->{graph}->attribute('graph','colorscheme') if $scheme eq 'inherit';

    $color = Graph::Easy->color_as_hex($color, $scheme);
    }
  $color;
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

  # try "node.class" first:
  my $att = $g->attribute ($class, $atr);

  my $c = $class; $c =~ s/\.(.*)//;		# remove subclass

  # try "node" next
  $att = $g->attribute ($c, $atr) unless defined $att;

  # XXX TODO: this should use $self->parent() instead of just graph

  # If neither our group nor our parent class had the attribute, try to
  # inherit it from "graph" as a last resort:

  $att = $g->attribute ('graph', $atr) if !defined $att && 
    $atr =~ /^(flow|linkbase|autolink|autotitle|autolabel)\z/;

  $att;
  }

sub default_attribute
  {
  my ($self, $name) = @_;

  my $graph = $self->{graph}; $graph = $self if ref($self) eq 'Graph::Easy';

  my $class = $self->{class} || 'graph';

  # for Edge/Cell.pm
  $class = $self->{edge}->{class} if ref($self->{edge});
 
  return undef unless exists $graph->{att}->{$class};

  my $att = $graph->{att}->{ $class };

  $att->{$name};
  }

sub del_attribute
  {
  my ($self, $atr) = @_;

  delete $self->{_cached_flow};
  delete $self->{att}->{$atr};
  $self;
  }

sub set_attribute
  {
  my ($self, $name, $v, $class) = @_;

  delete $self->{_cached_flow};

  $name = 'undef' unless defined $name;
  $v = 'undef' unless defined $v;

  if (!defined $class)
    {
    # edge.cities => edge
    $class = $self->{class}; $class =~ s/\..*//; # remove subclass
    }

  # remove quotation marks, but not for titles, labels etc
  my $val = Graph::Easy->unquote_attribute($class,$name,$v);

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
    return $val;
    }
  elsif ($name eq 'group')
    {
    $self->add_to_group($val);
    return $val;
    }
  elsif ($name eq 'border')
    {
    my $c = $self->{att};

    my @rc = $g->split_border_attributes( $val );
    $c->{'border-style'} = $rc[0] if defined $rc[0];
    $c->{'border-width'} = $rc[1] if defined $rc[1];
    $c->{'border-color'} = $rc[2] if defined $rc[2];

    return $val;
    }

  if ($name =~ /^(columns|rows|size)\z/)
    {
    if ($name eq 'size')
      {
      $val =~ /^(\d+)\s*,\s*(\d+)\z/;
      my ($cx, $cy) = (abs(int($1)),abs(int($2)));
      ($self->{att}->{columns}, $self->{att}->{rows}) = ($cx, $cy);
      }
    else
      {
      $self->{att}->{$name} = abs(int($val));
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

    next if !defined $val || $val eq '';

    $n eq 'class' ? $self->sub_class($val) : $self->set_attribute($n, $val);
    }
  $self;
  }

BEGIN
  {
  *text_styles_as_css = \&Graph::Easy::text_styles_as_css;
  *text_styles = \&Graph::Easy::text_styles;
  *_font_size_in_pixels = \&Graph::Easy::_font_size_in_pixels;
  *get_color_attribute = \&color_attribute;
  *link = \&Graph::Easy::link;
  *border_attribute = \&Graph::Easy::border_attribute;
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
  # return parent object, either the group the node belongs to, or the graph
  my $self = shift;

  my $p = $self->{graph};

  $p = $self->{group} if ref($self->{group});

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

Apart from the methods of the base class C<Graph::Easy::Base>, a
C<Graph::Easy::Node> has the following methods:

=head2 new()

        my $node = Graph::Easy::Node->new( name => 'node name' );
        my $node = Graph::Easy::Node->new( 'node name' );

Creates a new node. If you want to add the node to a Graph::Easy object,
then please use the following to create the node object:

	my $node = $graph->add_node('Node name');

You can then use C<< $node->set_attribute(); >>
or C<< $node->set_attributes(); >> to set the new Node's attributes.

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

=head2 default_attribute()

	my $def = $node->default_attribute('color');

Returns the default value for the given attribute in the class
of the object, or the empty string if no default could be found.

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

=head2 color_attribute()

	# returns f.i. #ff0000
	my $color = $node->get_color_attribute( 'fill' );

Just like get_attribute(), but only for colors, and returns them as hex,
using the current colorscheme.

=head2 get_color_attribute()

Is an alias to C<color_attribute()>.

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

=head2 is_anon()

	if ($node->is_anon())
	  {
	  ...
	  }

Returns true if the node is an anonymous node. False for C<Graph::Easy::Node>
objects, and true for C<Graph::Easy::Node::Anon>.

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

=head2 has_predecessors()

	if ($node->has_predecessors())
	  {
	  ...
	  }

Returns true if the node has one or more predecessors. Will return true for
nodes with selfloops.

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

=head2 shared_edges()

	my @edges = $node->shared_edges();

Return a list of all edges starting/ending at this node, that share a port
with another edge.

=head2 nodes_sharing_start()

	my @nodes = $node->nodes_sharing_start($side, $port);

Return a list of unique nodes that share a start point with an edge
from this node, on the specified side (absolut) and port number.

=head2 nodes_sharing_end()

	my @nodes = $node->nodes_sharing_end($side, $port);

Return a list of unique nodes that share an end point with an edge
from this node, on the specified side (absolut) and port number.

=head2 edges_at_port()

	my @edges = $node->edges_to('start', 'south', '0');

Returns all the edge objects that share the same C<start> or C<end>
port at the specified side and port number. The side must be
one of C<south>, C<north>, C<west> or C<east>. The port number
must be positive.

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

=head2 shape()

	my $shape = $node->shape();

Returns the shape of the node as string, defaulting to 'rect'. 

=head2 angle()

	my $angle = $self->rotation();

Return the node's rotation, based on the C<rotate> attribute, and
in case this is relative, on the node's flow.

=head2 flow()

	my $flow = $node->flow();

Returns the outgoing flow for this node as absolute direction in degrees.

The value is computed from the incoming flow (or the general flow as
default) and the flow attribute of this node.

=head2 _extra_params()

	my $extra_params = $node->_extra_params();

The return value of that method is added as extra params to the
HTML tag for a node when as_html() is called. Returns the empty
string by default, and can be overriden in subclasses. See also
C<use_class()>.

Overriden method should return a text with a leading space, or the
empty string.

Example:

	package Graph::Easy::MyNode;
	use base qw/Graph::Easy::Node/;

	sub _extra_params
	  {
	  my $self = shift;

	  ' ' . 'onmouseover="alert(\'' . $self->name() . '\');"'; 
	  }

	1;

=head1 EXPORT

None by default.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
