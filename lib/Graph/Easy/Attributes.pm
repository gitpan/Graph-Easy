#############################################################################
# define and check attributes for a Graph::Easy textual description.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Attributes;

$VERSION = '0.08';

package Graph::Easy;

use strict;

#############################################################################
# color handling

my $color_names = {
  aliceblue             => '#f0f8ff',
  antiquewhite          => '#faebd7',
  aquamarine            => '#7fffd4',
  aqua                  => '#00ffff',
  azure                 => '#f0ffff',
  beige                 => '#f5f5dc',
  bisque                => '#ffe4c4',
  black                 => '#000000',
  blanchedalmond        => '#ffebcd',
  blue                  => '#0000ff',
  blueviolet            => '#8a2be2',
  brown                 => '#a52a2a',
  burlywood             => '#deb887',
  cadetblue             => '#5f9ea0',
  chartreuse            => '#7fff00',
  chocolate             => '#d2691e',
  coral                 => '#ff7f50',
  cornflowerblue        => '#6495ed',
  cornsilk              => '#fff8dc',
  crimson               => '#dc143c',
  cyan                  => '#00ffff',
  darkblue              => '#00008b',
  darkcyan              => '#008b8b',
  darkgoldenrod         => '#b8860b',
  darkgray              => '#a9a9a9',
  darkgreen             => '#006400',
  darkgrey              => '#a9a9a9',
  darkkhaki             => '#bdb76b',
  darkmagenta           => '#8b008b',
  darkolivegreen        => '#556b2f',
  darkorange            => '#ff8c00',
  darkorchid            => '#9932cc',
  darkred               => '#8b0000',
  darksalmon            => '#e9967a',
  darkseagreen          => '#8fbc8f',
  darkslateblue         => '#483d8b',
  darkslategray         => '#2f4f4f',
  darkslategrey         => '#2f4f4f',
  darkturquoise         => '#00ced1',
  darkviolet            => '#9400d3',
  deeppink              => '#ff1493',
  deepskyblue           => '#00bfff',
  dimgray               => '#696969',
  dodgerblue            => '#1e90ff',
  firebrick             => '#b22222',
  floralwhite           => '#fffaf0',
  forestgreen           => '#228b22',
  fuchsia               => '#ff00ff',
  gainsboro             => '#dcdcdc',
  ghostwhite            => '#f8f8ff',
  goldenrod             => '#daa520',
  gold                  => '#ffd700',
  gray                  => '#808080',
  green                 => '#008000',
  greenyellow           => '#adff2f',
  grey                  => '#808080',
  honeydew              => '#f0fff0',
  hotpink               => '#ff69b4',
  indianred             => '#cd5c5c',
  indigo                => '#4b0082',
  ivory                 => '#fffff0',
  khaki                 => '#f0e68c',
  lavenderblush         => '#fff0f5',
  lavender              => '#e6e6fa',
  lawngreen             => '#7cfc00',
  lemonchiffon          => '#fffacd',
  lightblue             => '#add8e6',
  lightcoral            => '#f08080',
  lightcyan             => '#e0ffff',
  lightgoldenrodyellow  => '#fafad2',
  lightgray             => '#d3d3d3',
  lightgreen            => '#90ee90',
  lightgrey             => '#d3d3d3',
  lightpink             => '#ffb6c1',
  lightsalmon           => '#ffa07a',
  lightseagreen         => '#20b2aa',
  lightskyblue          => '#87cefa',
  lightslategray        => '#778899',
  lightslategrey        => '#778899',
  lightsteelblue        => '#b0c4de',
  lightyellow           => '#ffffe0',
  limegreen             => '#32cd32',
  lime			=> '#00ff00',
  linen                 => '#faf0e6',
  magenta               => '#ff00ff',
  maroon                => '#800000',
  mediumaquamarine      => '#66cdaa',
  mediumblue            => '#0000cd',
  mediumorchid          => '#ba55d3',
  mediumpurple          => '#9370db',
  mediumseagreen        => '#3cb371',
  mediumslateblue       => '#7b68ee',
  mediumspringgreen     => '#00fa9a',
  mediumturquoise       => '#48d1cc',
  mediumvioletred       => '#c71585',
  midnightblue          => '#191970',
  mintcream             => '#f5fffa',
  mistyrose             => '#ffe4e1',
  moccasin              => '#ffe4b5',
  navajowhite           => '#ffdead',
  navy                  => '#000080',
  oldlace               => '#fdf5e6',
  olivedrab             => '#6b8e23',
  olive                 => '#808000',
  orangered             => '#ff4500',
  orange                => '#ffa500',
  orchid                => '#da70d6',
  palegoldenrod         => '#eee8aa',
  palegreen             => '#98fb98',
  paleturquoise         => '#afeeee',
  palevioletred         => '#db7093',
  papayawhip            => '#ffefd5',
  peachpuff             => '#ffdab9',
  peru                  => '#cd853f',
  pink                  => '#ffc0cb',
  plum                  => '#dda0dd',
  powderblue            => '#b0e0e6',
  purple                => '#800080',
  red                   => '#ff0000',
  rosybrown             => '#bc8f8f',
  royalblue             => '#4169e1',
  saddlebrown           => '#8b4513',
  salmon                => '#fa8072',
  sandybrown            => '#f4a460',
  seagreen              => '#2e8b57',
  seashell              => '#fff5ee',
  sienna                => '#a0522d',
  silver                => '#c0c0c0',
  skyblue               => '#87ceeb',
  slateblue             => '#6a5acd',
  slategray             => '#708090',
  slategrey             => '#708090',
  snow                  => '#fffafa',
  springgreen           => '#00ff7f',
  steelblue             => '#4682b4',
  tan                   => '#d2b48c',
  teal                  => '#008080',
  thistle               => '#d8bfd8',
  tomato                => '#ff6347',
  turquoise             => '#40e0d0',
  violet                => '#ee82ee',
  wheat                 => '#f5deb3',
  white                 => '#ffffff',
  whitesmoke            => '#f5f5f5',
  yellowgreen           => '#9acd32',
  yellow                => '#ffff00',
  };

my $color_values = {};

{
  # reverse mapping "#ff0000 => 'red'"
  for my $n (keys %$color_names)
    {
    $color_values->{ $color_names->{$n} } = $n;
    }
}

sub color_names
  {
  $color_values;
  }

sub color_name
  {
  my ($self,$color) = @_;

  $color_values->{$color} || $color;
  }

sub color_as_hex
  {
  # Turn "red" or rgb(255,0,0) or "#f00" into "#ff0000". Return undef for
  # invalid colors.
  my ($self, $color) = @_;

  # XXX TODO:
  # handle things like rgb(100%,50%,0.5)

  $color = lc($color);

  return $color_names->{$color} if exists $color_names->{$color};

  # rgb(255,0,0) => '#ff0000'
  $color = sprintf("#%02x%02x%02x", $1,$2,$3)
    if $color =~ /^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$/
    && $1 < 256 && $2 < 256 && $3 < 256;

  # turn #ff0 into #ffff00
  $color = "#$1$1$2$2$3$3" if $color =~ /^#([a-f0-9])([a-f0-9])([a-f[0-9])\z/;

  # check final color value to be #RRGGBB
  return undef unless $color =~ /^#[a-f0-9]{6}\z/;

  $color;
  }

sub angle
  {
  # check an angle for being valid, and turn "down" into "180" etc
  my ($self, $angle) = @_;

  $angle = 180 if $angle eq 'down';
  $angle = 0 if $angle eq 'up';
  $angle = 90 if $angle eq 'right';
  $angle = -90 if $angle eq 'left';

  return undef if $angle =~ /[^\d\.+-]/;

  $angle += 0;

  $angle %= 360 if abs($angle) > 360;

  $angle;
  }

sub text_style
  {
  # check whether the given list of text-style attributes is valid
  my ($self, $style) = @_;

  return $style if $style =~ /^(normal|none|)\z/;

  my @styles = split /\s+/, $style;
  
  return undef if grep(!/^(underline|overline|line-through|italic|bold)\z/, @styles);

  $style;
  }

sub text_styles
  {
  # return a hash with the defined text-styles checked
  my ($self) = @_;

  my $style = $self->attribute('text-style') || '';
  return { none => 1 } if $style =~ /^(normal|none)\z/;
  return { } if $style eq '';

  my $styles = {};
  for my $key ( split /\s+/, $style )
    {
    $styles->{$key} = 1;
    }
  $styles;
  }

sub text_styles_as_css
  {
  my $self = shift;

  my $style = '';
  my $ts = $self->text_styles();

  $style .= " font-style: italic;" if $ts->{italic};
  $style .= " font-weight: bold;" if $ts->{bold};

  if ($ts->{underline} || $ts->{none} || $ts->{overline} || $ts->{'line-through'})
    {
    # XXX TODO: HTML does seem to allow only one of them
    my @s;
    foreach my $k (qw/underline overline line-through none/)
      {
      push @s, $k if $ts->{$k};
      }
    my $s = join(' ', @s);
    $style .= " text-decoration: $s;" if $s;
    }

  # XXX TODO: this will needless include the font-size if set via
  # "node { font-size: X }:
  my $fs = $self->attribute('font-size') || '';

  $style .= " font-size: $fs;" if $fs;

  $style;
  }

sub _font_size_in_pixels
  {
  my ($self, $em) = @_;
  
  my $fs = $self->attribute('font-size') || '';
  return $em if $fs eq '';

  if ($fs =~ /^([\d.]+)em\z/)
    {
    $fs = $1 * $em;
    }
  elsif ($fs =~ /^([\d.]+)%\z/)
    {
    $fs = ($1 / 100) * $em;
    }
#  # this is discouraged:
#  elsif ($fs =~ /^([\d.]+)px\z/)
#    {
#    $fs = $1;
#    }
  else
    {
    require Carp;
    Carp::croak ("Illegal font-size '$fs'");
    }
  $fs;
  }

sub direction_as_number
  {
  my ($self, $dir) = @_;

  $dir =~ s/^(east|right)\z/90/;
  $dir =~ s/^(south|down)\z/180/;
  $dir =~ s/^(west|left)\z/270/;
  $dir =~ s/^(north|up)\z/0/;

  $dir =~ /^(0|90|180|270)\z/ ? $dir : undef;
  }

#############################################################################
# attribute checking

# different types of attributes with pre-defined handling
sub ATTR_STRING		() { 0; }
sub ATTR_COLOR		() { 1; }
sub ATTR_ANGLE		() { 2; }

sub ATTR_DESC_SLOT	() { 0; }
sub ATTR_MATCH_SLOT	() { 1; }
sub ATTR_DEFAULT_SLOT	() { 2; }
sub ATTR_EXAMPLE_SLOT	() { 3; }
sub ATTR_TYPE_SLOT	() { 4; }
     
# Lists the attribute names along with
#   * a short description, 
#   * regexp or sub name to match valid attributes
#   * default value
#   * an short example value
#   * type
#   * graph examples

my $attributes = {
  all => {
    autolink => [
     "If set to something else than 'none', will use the appropriate attribute to automatically generate the L<link>. This attribute is inherited by nodes, edges and groups.",
     [ qw/ label title name none / ],
     'none',
     'title',
     ],

    autotitle => [
     "If set to something else than 'none', will use the appropriate attribute to automatically generate the L<title>. This attribute is inherited by nodes, edges and groups.",
     [ qw/ label name none / ],
     'none',
     'label',
     ],

    background => [
     "The background color, e.g. the color outside the shape. See the section about color names and values for reference.",
     undef,
     '"white" for the graph, "inherit" for edges, and undef and nodes',
     'rgb(255,0,0)',
     ATTR_COLOR,
     "[ Crimson ] { shape: circle; background: crimson; }\n -- Aqua Marine --> { background: #7fffd4; }\n [ Misty Rose ] { fill: rgb(255,228,221); }",
     ],

    "border-color" => [
     'The color of the L<border>. See the section about color names and values for reference.',
     undef,
     'black',
     'rgb(255,255,0)',
     ATTR_COLOR,
     ],
    'border-style' => [
     'The style of the L<border>.',
     [ qw/ none solid dotted dashed dot-dash dot-dot-dash bold double-dash double wave/ ],
     'solid',
     'dotted',
     ],
    'border-width' => [
     'The width of the L<border>.',
     qr/^\d+(px|em)?\z/,
     '1px',
     '2px',
     ],
    'border' => [
     'The border. Can be any combination of L<border-style>, L<border-color> and L<border-width>.',
     undef,
     '1px solid black',
     'dotted red',
     ],

    color => [
     'The foreground/text color. See the section about color names and values for reference.',
     undef,
     'black',
     'rgb(255,255,0)',
     ATTR_COLOR,
     "[ Crimson ] { color: crimson; }\n -> { color: blue; }\n [ Dark Orange ] { color: rgb(255,140,0); }",
     ],

    class => [
     'The subclass. See the section about class names for reference.',
     undef,
     '',
     'mynodeclass',
     ],

    fill => [
     "The fill color, e.g. the color inside the shape. See the section about color names and values for reference.",
     undef,
     '"white" for the graph and nodes, "inherit" for edges',
     'rgb(255,0,0)',
     ATTR_COLOR,
     "[ Crimson ]\n  {\n  shape: octagon;\n  background: crimson;\n  fill: red;\n  border-color: slategrey;\n  }\n-- Aqua Marine -->\n  {\n  arrow-style: filled;\n  fill: red;\n  }\n[ Two ]",
     ],

    'font-size' => [
     "The size of the label text, best expressed in I<em> (1.0em, 0.5em etc) or percent (100%, 50% etc)",
     undef,
     '"1.0" for the graph and nodes, "0.75" for edges',
     '50%',
     undef,
     "graph { font-size: 200%; label: Sample; }\n  [ Crimson ] { font-size: 1.5em; fill: darkred; }\n  -- Aqua Marine -->\n { font-size: 0.2em; }\n  [ Two ]",
     ],

    label => [
     "The text displayed as label. If not set, equals the name (for nodes) or no label (for edges, groups and the graph itself).",
     undef,
     '',
     'My label',
     ],

    linkbase => [
     'The base URL prepended to all generated links. This attribute is inherited by nodes, edges and groups. See the section about links for reference.',
     undef,
     '',
     'http://en.wikipedia.org/wiki/',
     ],

    link => [
     'The link part, appended onto L<linkbase>. See the section about links for reference.',
     undef,
     '',
     'Graph',
     undef,
     <<LINK_EOF
node {
  autolink: name;
  text-style: none;
  font-size: 1.1em;
  }
graph {
  linkbase: http://de.wikipedia.org/wiki/;
  }
edge {
  text-style: overline;
  }

[] --> [ Friedrichshafen ]
 -- Schiff --> { autolink: label; color: orange; title: Vrooom!; }
[ Immenstaad ] { color: green; } --> [ Hagnau ]
LINK_EOF
     ],

    title => [
     "The text displayed as mouse-over for nodes/edges, or as the title for the graph. No title will be generated unless L<autotitle> is set.",
     undef,
     '',
     'My title',
     ],

    'text-style' => [
     "The style of the label text. Either 'none', or any combination (separated with spaces) of 'underline', 'overline', 'bold', 'italic', 'line-through'. 'none' disables underlines on links.",
     'text_style',
     'none',
     'underline italic bold',
     undef,
     <<EOF
graph {
  font-size: 150%;
  label: Verbindung;
  text-style: bold italic;
  }
node {
  text-style: underline bold;
  fill: #ffd080;
  }
edge {
  text-style: italic bold overline;
  }

[ Meersburg ] { font-size: 2em; }
 -- Fähre --> { font-size: 1.2em; color: red; }
 [ Konstanz ]
EOF
     ],
   },

  node => {
    size => [
     'The size of the node in columns and rows.',
     qr/^\d+,\d+\z/,
     '1,1',
     '3,2',
     ],
    rows => [
     'The size of the node in rows. See also L<size>.',
     qr/^\d+\z/,
     '1',
     '3',
     ],
    columns => [
     'The size of the node in columns. See also L<size>.',
     qr/^\d+\z/,
     '1',
     '2',
     ],

    offset => [
     'The offset of this node from the L<origin> node, in columns and rows. Only used if you also set the L<origin> node.',
     qr/^[+-]?\d+\s*,\s*[+-]?\d+\z/,
     '0,0',
     '3,2',
     ],

    origin => [
     'The name of the node, that this node is relativ to. See also L<offset>.',
     undef,
     '',
     'Cluster A',
     ],

    flow => [
     "The general direction in which edges will leave this node first. One of 0, up, north, 90, east, right, 180, south, down, 270, west, left.",
     'direction_as_number',
     'right',
     'south',
     ],

    shape => [
     "The shape of the node. Nodes with shape 'point' (see L<point-style>) have a fixed size and do not display their label.",
       [ qw/ circle diamond ellipse hexagon house invisible invhouse invtrapezium invtriangle octagon parallelogram pentagon
             point triangle trapezium septagon rect rounded none/ ],
      'rect',
      'circle',
     ],

    rotate => [
     "The rotation of the node shape, clockwise from 0..359 degrees.",
       undef,
       '0',
       '180',
       ATTR_ANGLE,
     "[ Bonn ] { rotate: 45; } -- ICE --> \n [ Berlin ] { shape: triangle; rotate: 90; }",
     ],

    "point-style" => [
     "Controls the style of a node that has a L<shape> of 'point'.",
     [ qw/circle square dot cross star diamond/ ],
      'star',
      'square',
     ], 

    'border-style' => [
     'The style of the L<border>.',
     [ qw/none solid dotted dashed dot-dash dot-dot-dash bold double-dash double wave/ ],
     'solid',
     'dotted',
     ],
  }, # node

  graph => {
    'border-style' => [
      'The style of the L<border>.',
      [ qw/none solid dotted dashed dot-dash dot-dot-dash bold double-dash double wave/ ],
      'none',
      'dotted',
     ],

    flow => [
      "The graph's general flow direction. One of 0, up north, 90, east, right, 180, south, down, 270, west, left.",
      'direction_as_number',
      'right',
      'south',
     ],

    gid => [
      "A unique ID for the graph. Usefull if you want to include two graphs into one HTML page.",
      qr/^\d+\z/,
      '',
      '123',
     ],

    output => [
      "The desired output format. Only used when calling Graph::Easy::output(), or by mediawiki-graph.",
      [ qw/ascii html svg graphviz boxart/ ],
      '',
      'ascii',
     ],

    "label-pos" => [
      "The position of the graph label.",
      [ qw/top bottom/ ],
      'top',
      'bottom',
     ],

  }, # graph

  edge => {

    style => [
      'The line style of the edge. When set on the general edge class, this attribute changes only the style of all solid edges to the specified one.',
      [ qw/solid dotted dashed dot-dash dot-dot-dash bold double-dash double wave/ ],
      'solid',
      'dotted',
     ],

    "arrow-style" => [
      'The style of the arrow. Open arrows are vee-shaped and the bit inside the arrow has the color of the L<background>. Closed arrows are triangle shaped, with a background-color fill. Filled arrows are closed, too, but use the L<fill> color for the inside. An arrow-style of none creates undirected edges just like "[A] -- [B]" would do.',
      [ qw/none open closed filled/ ],
      'open',
      'closed',
      undef,
      "[ A ] -- open --> [ B ]\n -- closed --> { arrow-style: closed; } [ C ]\n -- filled --> { arrow-style: filled; } [ D ]\n -- filled --> { arrow-style: filled; fill: lime; } [ E ]\n -- none --> { arrow-style: none; } [ F ]",
     ],

    "label-color" => [
     'The text color for the label. If unspecified, will fall back to L<color>. See the section about color names and values for reference.',
     undef,
     'black',
     'rgb(255,255,0)',
     ATTR_COLOR,
     "[ Bonn ] -- ICE --> { label-color: blue; }\n [ Berlin ]",
     ],
   }, # edge

  group => {
    nodeclass => [
      'The class into which all nodes of this group are put.',
      undef,
      '',
      'cities',
     ],

    edgeclass => [
      'The class into which all edges defined in this group are put. This includes edges that run between two nodes belonging to the same group.',
      undef,
      '',
      'connections',
     ],

   }, # group

  }; # end of attribute definitions

sub _attribute_entries
  {
  # for building the manual page
  $attributes;
  }

sub valid_attribute
  {
  # Check that an name/value pair is an valid attribute, return new
  # attribute if valid, undef for not valid.
  my ($self, $name, $value, $class) = @_;

  if (ref($value))
    {
    require Carp;
    Carp::confess ("Got reference $value as value, but expected scalar");
    }

  if (ref($name))
    {
    require Carp;
    Carp::confess ("Got reference $name as name, but expected scalar");
    }

  $class = 'all' unless defined $class;
  $class =~ s/\..*\z//;		# remove subclasses

  my $entry = $attributes->{all}->{$name} || $attributes->{$class}->{$name};

  return [] unless ref($entry);

  my $check = $entry->[1];

  $check = 'color_as_hex' if ($entry->[4] || ATTR_STRING) == ATTR_COLOR;
  $check = 'angle' if ($entry->[4] || ATTR_STRING) == ATTR_ANGLE;

  if (defined $check && !ref($check))
    {
    no strict 'refs';
    return $self->$check($value, $name);
    }
  elsif ($check)
    {
    if (ref($check) eq 'ARRAY')
      {
      # build a regexp from the list of words
      my $list = 'qr/^(' . join ('|', @$check) . ')\z/;';
      $entry->[1] = eval($list);
      $check = $entry->[1];
      }
    return $value =~ $check ? $value : undef;
    }

  # entry found, no specific check => anything goes as value
  $value;
  }

###########################################################################
###########################################################################

sub _remap_attributes
  {
  # Take a hash with:
  # {
  #   class => {
  #     color => 'red'
  #   }
  # }
  # and remap it according to the given remap hash (similiar structured).
  # Also encode/quote the value. Suppresses default attributes.
  my ($self, $object, $att, $remap, $noquote, $color_remap ) = @_;

  my $out = {};

  my $class = $object; $class = $object->{class} if ref($object);
  $class =~ s/\..*//;				# remove subclass

  my $r = $remap->{$class};
  my $ra = $remap->{all};
  my $ral = $remap->{always};
  my $def = $self->{def_att}->{$class};

  # This loop does also handle the individual "border-color" attributes.
  # If the output should contain only "border", but not "border-color", the
  # caller must filter them out.

  # do attributes plus the ones in "always", but don't do attributes twice 
  my @keys = keys %$att;
  for my $k (keys %$ral)
    {
    push @keys, $k unless exists $att->{$k};
    }

  for my $atr (@keys)
    {
    my $val = $att->{$atr};

    # Only for objects (not for classes like "node"), and not if
    # always says we need to always call the CODE handler:

    if (!ref($object) && !exists $ral->{$atr})
      {
      # attribute not defined
      next if !defined $val || $val eq '' ||
      # or $remap says we should suppress it
         (exists $r->{$atr} && !defined $r->{$atr}) ||
         (exists $ra->{$atr} && !defined $ra->{$atr});
      }
    # suppress default attributes
    next if defined $def->{$atr} && $val eq $def->{$atr};

    if ($color_remap)
      {
      # look up whether attribute is a color
      my $entry = $attributes->{all}->{$atr} || $attributes->{$class}->{$atr};
      # if yes, convert to name
      $val = $self->color_name($val)
        if ($entry->[ ATTR_TYPE_SLOT ]||ATTR_STRING) == ATTR_COLOR;
      }

    # if given a code ref, call it to remap name and/or value
    if (exists $r->{$atr} || exists $ra->{$atr})
      {
      my $rc = $r->{$atr}; $rc = $ra->{$atr} unless defined $rc;
      if (ref($rc) eq 'CODE')
        {
        ($atr,$val) = &{$rc}($self,$atr,$val,$object);
        }
      else
        {
        # otherwise, rename the attribute name if nec.
        $atr = $rc;
        }
      }

    next if !defined $atr || !defined $val || $val eq '';

    # encode critical characters (including ")
    $val =~ s/([;"\x00-\x1f])/sprintf("%%%02x",ord($1))/eg if !$noquote;
    # quote if nec.
    $val = '"' . $val . '"' if !$noquote;

    $out->{$atr} = $val;
    }
  $out;
  }


1;
__END__

=head1 NAME

Graph::Easy::Attributes - Define and check attributes for Graph::Easy

=head1 SYNOPSIS

	use Graph::Easy;

	my $hexred = Graph::Easy->color_as_hex( 'red' );
	print Graph::Easy->valid_attribute( 'color', 'red', 'graph' );

=head1 DESCRIPTION

C<Graph::Easy::Attributes> contains the definitions of valid attribute names
and values for L<Graph::Easy|Graph::Easy>. It is used by both the parser
and by Graph::Easy to check attributes for being valid and well-formed. 

There should be no need to use it directly.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
