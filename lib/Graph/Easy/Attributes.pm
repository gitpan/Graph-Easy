#############################################################################
# define and check attributes for a Graph::Easy textual description.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Attributes;

use strict;
use vars qw/$VERSION/;

$VERSION = '0.02';

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

sub color_as_hex
  {
  # Turn "red" or rgb(255,0,0) or "#f00" into "#ff0000". Return undef for
  # invalid colors.
  my ($self, $color) = @_;

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

#############################################################################
# attribute checking

sub valid_attribute
  {
  # Check that an name/value pair is an valid attribute, return new
  # attribute if valid, undef for not valid.
  my ($self,$name,$value, $class) = @_;

  # check color:
  if ($name =~ /^(background|color|border-color)\z/)
    {
    return $self->color_as_hex($value);
    }

  if ($name eq 'border-shape')
    {
    return unless $value =~
      /^(none|solid|dotted|dashed|dot-dash|dot-dot-dash|bold|double-dash|double|wave)\z/;
    }

  if ($class eq 'edge')
    {
    if ($name eq 'style')
      {
      return unless $value =~
        /^(solid|dotted|dashed|dot-dash|dot-dot-dash|bold|double-dash|double|wave)\z/;
      }

    return $value;	# pass through for now

    } # end edge attributes

  if ($class eq 'node')
    {
    if ($name eq 'shape')
      {
      # different shapes:
      return undef if $value !~
       /^(
        circle|
        diamond|
        egg|
        ellipse|
        hexagon|
        house|
        invisible|
        invhouse|
        invtrapezium|
        invtriangle|
        octagon|
        parallelogram|
        pentagon|
        point|
        polygon|
        triangle|
        trapezium|
        septagon|
        tripleoctagon|
        # simple box
        box|
        rect|
        rectangle|
        rounded|
        # these are shape rect, border none
        plaintext|
        none
       )\z/x;

	# these are not (yet?) supported:
	 # Mdiamond|
	 # Msquare|
	 # Mcircle|
	 # doublecircle|
	 # doubleoctagon|
       }
    if ($name eq 'point-style')
      {
      # different point-styles
      return undef if $value !~
       /^(
        circle|		# * (filled circle)
        square|		# #
        ring|		# o
        dot|		# .
	cross|		# +
	star|		# *
	none		# 
       )\z/x;
       }
    } # end node attributes

  # anything else is passed along for now
  $value;
  }

1;
__END__
=head1 NAME

Graph::Easy::Attributes - Define and check attributes for Graph::Easy

=head1 SYNOPSIS

	use Graph::Easy::Attributes;

	my $hexred   = Graph::Easy::Attributes->color_as_hex( 'red' );
	print Graph::Easy::Attributes->valid_attribute( 'color', 'red' );

=head1 DESCRIPTION

C<Graph::Easy::Attributes> contains the definitions of valid attribute names
and values for L<Graph::Easy|Graph::Easy>. It is used by both the parser
and by Graph::Easy to check attributes. You shouldn't use it directly.

=head1 METHODS

=head2 valid_attribute()

	my $new_value = Graph::Easy::Attributes->valid_attribute( $name, $value );

	if (!defined $new_value)
	  {
	  # throw error
          die ("'$value' is not valid for attribute '$name'");
	  }

Check that a C<$name,$value> pair is a valid attribute and return a new value.

The return value can differ from the passed in value, f.i.:

	print Graph::Easy::Attributes->valid_attribute( 'color', 'red' );

This would print '#ff0000';
	
=head2 color_as_hex()

	my $hexred   = Graph::Easy::Attributes->color_as_hex( 'red' );
	my $hexblue  = Graph::Easy::Attributes->color_as_hex( '#0000ff' );
	my $hexcyan  = Graph::Easy::Attributes->color_as_hex( '#f0f' );
	my $hexgreen = Graph::Easy::Attributes->color_as_hex( 'rgb(0,255,0)' );

Takes a valid color name or definition (hex, short hex, or RGB) and returns the
color in hex like C<#ff00ff>.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
