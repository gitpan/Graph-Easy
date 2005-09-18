#############################################################################
# Render Nodes/Edges/Cells as ASCII art
#
# (c) by Tels 2004-2005. Part of Graph::Easy
#############################################################################

package Graph::Easy::ASCII;

$VERSION = '0.02';

package Graph::Easy::Node;

use strict;

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

sub _printfb_aligned
  {
  my ($self,$fb, $x1,$y1, $x2,$y2, $lines, $align_ver, $align_hor) = @_;
    
  my $w = $x2 - $x1;
  my $h = $y2 - $y1;

  my $y = $y1 + ($h / 2) - (scalar @$lines / 2); 
  my $x = int($x1 + ($w / 2));

  for my $l (@$lines)
    {
    my $xi = int($x - length($l) / 2);
    $self->_printfb_line($fb, $xi, $y, $l);
    $y++;
    }
  }

sub _printfb_line
  {
  # Print a textline into a framebuffer
  # Caller MUST ensure proper size of FB, for speed reasons,
  # we do not check wether text fits!
  my ($self, $fb, $x, $y, $l) = @_;

  # [0] = '0123456789...'
  # [1] = '0123456789...' etc

  substr ($fb->[$y], $x, length($l)) = $l; $y++;
  }

sub _printfb
  {
  # Print (potential a multiline) text into a framebuffer
  # Caller MUST ensure proper size of FB, for speed reasons,
  # we do not check wether text fits!
  my ($self, $fb, $x, $y, @lines) = @_;

  # [0] = '0123456789...'
  # [1] = '0123456789...' etc

  for my $l (@lines)
    {

#    # XXX DEBUG:
#    if ( $x + length($l) > length($fb->[$y]))
#      {
#      require Carp;
#      Carp::confess("substr outside framebuffer");
#      }

    substr ($fb->[$y], $x, length($l)) = $l; $y++;
    }
  }

sub _printfb_ver
  {
  # Print a string vertical into a framebuffer.
  # Caller MUST ensure proper size of FB, for speed reasons,
  # we do not check wether text fits!
  my ($self, $fb, $x, $y, $line) = @_;

  # this more than twice as fast as:
  #  "@pieces = split//,$line; _printfb(...)"

  my $y1 = $y + length($line);
  substr ($fb->[$y1], $x, 1) = chop($line) while ($y1-- > $y);
  }

 # for ASCII:

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
  none =>		[ ' ', ' ', ' ', ' ', ' ',   [ ' '      ] ],
  };

sub _draw_border
  {
  # draws a border into the framebuffer
  my ($self, $fb, $do_right, $do_bottom, $do_left, $do_top) = @_;

  return if $do_right.$do_left.$do_bottom.$do_top eq 'nonenonenonenone';

  my $w = $self->{w};
  if ($do_top ne 'none')
    {
    # make a copy of the style, so that we can modify it for partial borders
    my $style = [ @{ $border_styles->{$do_top} } ];
    die ("Unknown top border style '$do_top'") if @$style == 0;

    # top-left corner piece is only there if we have a left border
    my $tl = $style->[0]; $tl = '' if $do_left eq 'none';

    # generate the top border
    my $top = $tl . $style->[4] x (($self->{w}) / length($style->[4]) + 1);

    $top = substr($top,0,$w) if length($top) > $w;
    
    # top-right corner piece is only there if we have a right border
    substr($top,-1,1) = $style->[1] if $do_right ne 'none';

    # insert top row into FB
    $self->_printfb( $fb, 0,0, $top);
    }

  if ($do_bottom ne 'none')
    {
    # make a copy of the style, so that we can modify it for partial borders
    my $style = [ @{ $border_styles->{$do_bottom} } ];
    die ("Unknown bottom border style '$do_bottom'") if @$style == 0;

    # bottom-left corner piece is only there if we have a left border
    my $bl = $style->[0]; $bl = '' if $do_left eq 'none';

    # the bottom row '+--------+' etc
    my $bottom = $bl . $style->[4] x (($self->{w}) / length($style->[4]) + 1);

    $bottom = substr($bottom,0,$w) if length($bottom) > $w;

    # bottom-right corner piece is only there if we have a right border
    substr($bottom,-1,1) = $style->[1] if $do_right ne 'none';

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
  my $s = 1; $s = 0 if $do_top eq 'none';
  for ($s..$self->{h}-2)
    {
    push @left, $left->[$l]; $l ++; $l = 0 if $l > $lc;
    push @right, $right->[$r]; $r ++; $r = 0 if $r > $rc;
    }
  # insert left/right columns into FB
  $self->_printfb( $fb, 0, $s, @left) unless $do_left eq 'none';
  $self->_printfb( $fb, $w-1, $s, @right) unless $do_right eq 'none';

  $self;
  }
 
# ASCII: the different point styles

my $point_styles = {
  'star' => '*',
  'square' => '#',
  'dot' => '.',
  'circle' => 'o', 	# unfortunately, we do not have a filled o
  'cross' => '+',
  'diamond' => '<>',
  };  


sub _draw_label
  {
  # insert the label into the framebuffer
  my ($self, $fb) = @_;

  my $shape = $self->attribute('shape') || 'rect';

  my @lines; 
  if ($shape eq 'point')
    {
    # point-shaped nodes do not show their label in ASCII
    my $style = $self->attribute('point-style') || 'point';
    @lines = ($point_styles->{$style} || '*');
    }
  else
    {
    @lines = $self->_formatted_label();
    }

  #        +----
  #        | Label  
  # 2,1: ----^

  #my $border = $self->attribute('border-style') || 'none';
  #my $y = 1; $y = 0 if $border eq 'none';

  my $y = int( ($self->{h} - @lines) / 2);
  my $max = length($lines[0] || '');
  for my $l (@lines) { $max = length($l) if length($l) > $max; }
  my $x = int( ($self->{w} - $max) / 2);

  $self->_printfb ($fb, $x, $y, @lines);
  }

sub as_ascii
  {
  # renders a node like:
  # +--------+    ..........    ""
  # | A node | or : A node : or " --> "
  # +--------+    ..........    "" 
  my ($self, $x,$y) = @_;

  my $shape = $self->attribute('shape') || 'rect';

  # invisible nodes
  return '' if $shape eq 'invisible';

  my $fb = $self->_framebuffer($self->{w}, $self->{h});

  # point-shaped nodes do not have a border
  if ($shape ne 'point')
    {
    my $border_style = $self->attribute('border-style') || 'solid';
    my $border_width = $self->attribute('border-width') || '1';

    # XXX TODO: borders for groups in ASCII output
    $border_style = 'none' if ref($self) =~ /Group/;

    # "3px" => "bold"
    $border_style = 'bold' if $border_width > 2;

    my $style = $border_style;

    #########################################################################
    # draw our border into the framebuffer

    my $b_top = $style; $b_top = 'none' if $self->{no_border_top};
    my $b_left = $style; $b_left = 'none' if $self->{no_border_left};

    # XXX TODO: different styles for the different borders
    $self->_draw_border($fb, $style, $style, $b_left, $b_top)
      unless $style eq 'none';
    }

  ###########################################################################
  # "draw" the label into the framebuffer

  $self->_draw_label($fb, $x, $y);
  
  join ("\n", @$fb);
  }

1;
__END__

=head1 NAME

Graph::Easy::As_ascii - Generate ASCII art

=head1 SYNOPSIS

        use Graph::Easy;

	my $graph = Graph::Easy->new();

	$graph->add_edge('Bonn', 'Berlin');

	print $graph->as_ascii();

=head1 DESCRIPTION

C<Graph::Easy::As_ascii> contains the code to render Nodes/Edges as
ASCII art. It is used by Graph::Easy automatically, and there should
be no need to use it directly.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
