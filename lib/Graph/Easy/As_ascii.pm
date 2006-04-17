#############################################################################
# Render Nodes/Edges/Cells as ASCII/Unicode box drawing art
#
# (c) by Tels 2004-2006. Part of Graph::Easy
#############################################################################

package Graph::Easy::As_ascii;

$VERSION = '0.14';

sub _u8
  {
  # Converts UTF-16 codepoints in hex (like "2500") into utf-8
  # XXX TODO:
  # It seems wastefull to load Encode just for converting static strings,
  # maybe we can work around that somehow, f.i. with "use utf8;".
  my ($utf16) = @_;

  require Encode;

  # in case of input like "ca", turn it into "25ca"
  $utf16 = '25' . $utf16 if length($utf16) == 2;

  # UTF-16BE must be in uppercase to make some older Encode versions happy
  Encode::decode('UTF-16BE', pack("H" . length($utf16), $utf16));
  }

#############################################################################
#############################################################################

package Graph::Easy::Edge::Cell;

use strict;

BEGIN
  {
  *_u8 = \&Graph::Easy::As_ascii::_u8;
  }

my $edge_styles = [ 
  {
  # style            hor, ver,   cross,	corner (SE, SW, NE, NW)
  'solid'	 => [ '--',  "|", '+', '+','+','+','+' ],	# simple line
  'double'	 => [ '==',  "H", "#", '#','#','#','#' ],	# double line
  'double-dash'	 => [ '= ',  '"', "#", '#','#','#','#' ],	# double dashed line
  'dotted'	 => [ '..',  ":", ':', '.','.','.','.' ],	# dotted
  'dashed'	 => [ '- ',  "'", '+', '+','+','+','+' ],	# dashed
  'dot-dash'	 => [ '.-',  "!", '+', '+','+','+','+' ],	# dot-dash
  'dot-dot-dash' => [ '..-', "!", '+', '+','+','+','+' ],	# dot-dot-dash
  'wave' 	 => [ '~~',  "}", '+', '*','*','*','*' ],	# wave
  'bold' 	 => [ '##',  "#", '#', '#','#','#','#' ],	# bold
  'bold-dash' 	 => [ '# ',  "#", '#', '#','#','#','#' ],	# bold-dash
  'wide' 	 => [ '##',  "#", '#', '#','#','#','#' ],	# wide
  'broad' 	 => [ '##',  "#", '#', '#','#','#','#' ],	# broad
  },
  {
  # style            hor, ver,   	    cross,     corner (SE, SW, NE, NW)
  'solid'	 => [ _u8('00'), _u8('02'), _u8('3c'),  _u8('0c'), _u8('10'), _u8('14'), _u8('18') ],
  'double'	 => [ _u8('50'), _u8('51'), _u8('6c'),  _u8('54'), _u8('57'), _u8('5a'), _u8('5d') ],
  'double-dash'	 => [ _u8('50').' ', _u8('2225'), _u8('6c'),  _u8('54'), _u8('57'), _u8('5a'), _u8('5d') ], # double dashed
  'dotted'	 => [ _u8('00b7'), ':',     _u8('3c'),  _u8('0c'), _u8('10'), _u8('14'), _u8('18') ], # dotted
  'dashed'	 => [ _u8('74'), _u8('75'), _u8('18'),  _u8('0c'), _u8('10'), _u8('75'), _u8('18') ], # dashed
  'dot-dash'	 => [ _u8('00b7').'-',  "!",   _u8('3c'),  _u8('0c'), _u8('10'), _u8('14'), _u8('18') ], # dot-dash
  'dot-dot-dash' => [ (_u8('00b7') x 2).'-', "!",  _u8('3c'),  _u8('0c'), _u8('10'), _u8('14'), _u8('18') ], # dot-dot-dash
  'wave' 	 => [ _u8('223c'), _u8('2240'),     _u8('3c'),  _u8('0c'), _u8('10'), _u8('14'), _u8('18') ], # wave
  'bold' 	 => [ _u8('01'), _u8('03'), _u8('4b'),  _u8('0f'), _u8('13'), _u8('17'), _u8('1b') ], # bold
  'bold-dash' 	 => [ _u8('01').' ', _u8('7b'), _u8('4b'),  _u8('0f'), _u8('13'), _u8('17'), _u8('1b') ], # bold-dash
  'broad' 	 => [ _u8('ac'), _u8('ae'), _u8('88'),  _u8('88'), _u8('88'), _u8('88'), _u8('88') ], # wide
  'wide' 	 => [ _u8('88'), _u8('88'), _u8('88'),  _u8('88'), _u8('88'), _u8('88'), _u8('88') ], # broad

# these two make it nec. to support multi-line styles for the vertical edge pieces
#  'broad-dash' 	 => [ _u8('fc'), _u8('fc'), _u8('fc'),  _u8('fc'), _u8('fc'), _u8('fc'), _u8('fc') ], # broad-dash
#  'wide-dash' 	 => [ (_u8('88')x 2) .'  ', _u8('88'), _u8('88'),  _u8('88'), _u8('88'), _u8('88'), _u8('88') ], # wide-dash
  },
  ];

sub _edge_style
  {
  my ($self, $st) = @_;

  my $g = $self->{graph}->{_ascii_style} || 0;
  $st = $self->{style} unless defined $st;

  $edge_styles->[$g]->{ $st };
  }

  #    |       |        |        |        :        }       |     
  # ===+=== ###+### ....!.... ~~~+~~~ ----+---  ...+... .-.+.-.-
  #    |       |        |        |        :        {       |   

  my $cross_styles = [
    {
    'boldsolid'		=> '+',  
    'dashedsolid'	=> '+',  
    'dottedsolid'	=> '!',
    'dottedwave'	=> '+',  
    'doublesolid'	=> '+',  
    'dot-dashsolid'	=> '+',  
    'dot-dot-dashsolid'	=> '+',  
    'soliddotted'	=> '+',  
    'solidwave'		=> '+',  
    'soliddashed'	=> '+',  
    'soliddouble'	=> 'H',  
    'wavesolid'		=> '+',
    },
    {
    'boldsolid' 	=> _u8('3f'),
    'solidbold' 	=> _u8('42'),
    'doublesolid' 	=> _u8('6a'),
    'soliddouble' 	=> _u8('6b'),
    'dashedsolid' 	=> _u8('24'),
    'soliddashed' 	=> _u8('34'),
    'doubledashed' 	=> _u8('67'),
    'dasheddouble' 	=> _u8('62'),
    },
  ];

sub _arrow_style
  {
  my $self = shift;

  my $edge = $self->{edge};

  my $as = $edge->attribute('arrow-style') || 'open';
  $as = 'none' if $edge->{undirected};
  $as;
  }

sub _cross_style
  {
  my ($self, $st) = @_;

  my $g = $self->{graph}->{_ascii_style} || 0;

  $cross_styles->[$g]->{ $st };
  }

sub _insert_label
  {
  my ($self, $fb, $xs, $ys, $ws, $hs, $align_ver) = @_;

  # for edge labels, left is the default
  my $align = $self->{edge}->attribute('align') || 'left';
  
  my ($lines,$aligns) = $self->_aligned_label($align);

  $ys = $self->{h} - scalar @$lines + $ys if $ys < 0; 

  $ws ||= 0; $hs ||= 0;
  my $w = $self->{w} - $ws - $xs;
  my $h = $self->{h} - $hs - $ys;

  $self->_printfb_aligned ($fb, $xs, $ys, $w, $h, $lines, $aligns, $align_ver);
  }

sub _draw_hor
  {
  # draw a HOR edge piece
  my ($self, $fb) = @_;

  my $style = $self->_edge_style();
  
  my $w = $self->{w};
  # '-' => '-----', '.-' => '.-.-.-'
  # "(2 + ... )" to get space for the offset
  my $len = length($style->[0]); 
  my $line = $style->[0] x (2 + $w / $len); 

  # '.-.-.-' => '-.-.-' if $x % $ofs == 1 (e.g. on odd positions)
  my $ofs = $self->{rx} % $len;
  my $type = ($self->{type} & (~EDGE_MISC_MASK));
  substr($line,0,$ofs) = '' if $ofs != 0
    && ($type != EDGE_SHORT_E && $type != EDGE_SHORT_W);

  $line = substr($line, 0, $w) if length($line) > $w;

  # handle start/end point

  my $flags = $self->{type} & EDGE_FLAG_MASK;

  my $x = 0;				# offset for the edge line
  my $xs = 1;				# offset for the edge label
  my $xr = 0;				# right offset for label
  if (($flags & EDGE_START_W) != 0)
    {
    $x++; chop($line);			# ' ---'
    $xs++;
    }
  if (($flags & EDGE_START_E) != 0)
    {
    chop($line);			# '--- '
    }
  my $as = $self->_arrow_style();

  if (($flags & EDGE_END_E) != 0)
    {
    # '--> '
    chop($line);
    substr($line,-1,1) = $self->_arrow($as, ARROW_RIGHT) if $as ne 'none';
    $xr++;
    }
  if (($flags & EDGE_END_W) != 0)
    {
    # ' <--'
    substr($line,0,1) = ' ' if $as eq 'none';
    substr($line,0,2) = ' ' . $self->_arrow($as, ARROW_LEFT) if $as ne 'none';
    $xs++;
    }

  $self->_printfb_line ($fb, $x, $self->{h} - 2, $line);

  $self->_insert_label($fb, $xs, 0, $xs+$xr, 2, 'bottom' )  
   if ($self->{type} & EDGE_LABEL_CELL);

  }

sub _draw_ver
  {
  # draw a VER edge piece
  my ($self, $fb) = @_;

  my $style = $self->_edge_style();

  my $h = $self->{h};
  # '|' => '|||||', '{}' => '{}{}{}'
  my $line = $style->[1] x (1 + $h / length($style->[1]));
  $line = substr($line, 0, $h) if length($line) > $h;

  my $flags = $self->{type} & EDGE_FLAG_MASK;
  # XXX TODO: handle here start points
  # we get away with not handling them because in VER edges
  # starting points are currently invisible.

  my $as = $self->_arrow_style();
  if ($as ne 'none')
    {
    substr($line,0,1) = $self->_arrow($as,ARROW_UP)
      if (($flags & EDGE_END_N) != 0);
    substr($line,-1,1) = $self->_arrow($as,ARROW_DOWN)
      if (($flags & EDGE_END_S) != 0);
    }
  $self->_printfb_ver ($fb, 2, 0, $line);

  $self->_insert_label($fb, 4, 1, 4, 2, 'middle')
    if ($self->{type} & EDGE_LABEL_CELL);

  }

sub _draw_cross
  {
  # draw a CROSS sections, or a joint (which is a 3/4 cross)
  my ($self, $fb) = @_;
  
  # vertical piece
  my $style = $self->_edge_style( $self->{style_ver} );

  my $invisible = 0;
  my $line;
  my $flags = $self->{type} & EDGE_FLAG_MASK;
  my $type = $self->{type} & EDGE_TYPE_MASK;
  my $as = $self->_arrow_style();
  my $y = $self->{h} - 2;

  print STDERR "# drawing cross at $self->{x},$self->{y} with flags $flags\n" if $self->{debug};

  if ($self->{style_ver} ne 'invisible')
    {
    my $h = $self->{h};
    # '|' => '|||||', '{}' => '{}{}{}'
    $line = $style->[1] x (2 + $h / length($style->[1])); 

    $line = substr($line, 0, $h) if length($line) > $h;

    if ($as ne 'none')
      {
      substr($line,0,1) = $self->_arrow($as,ARROW_UP) 
        if (($flags & EDGE_END_N) != 0);
      substr($line,-1,1) = $self->_arrow($as,ARROW_DOWN) 
        if (($flags & EDGE_END_S) != 0);
      }

    # create joints
    substr($line,0,$y) = ' ' x $y if $type == EDGE_S_E_W;
    substr($line,$y,2) = '  ' if $type == EDGE_N_E_W;

    $self->_printfb_ver ($fb, 2, 0, $line);
    }
  else { $invisible++; }

  # horizontal piece
  $style = $self->_edge_style();
  
  if ($self->{style} ne 'invisible')
    {
    my $w = $self->{w};
    # '-' => '-----', '.-' => '.-.-.-'
    my $len = length($style->[0]); 
    $line = $style->[0] x (2 + $w / $len); 
  
    # '.-.-.-' => '-.-.-' if $x % $ofs == 1 (e.g. on odd positions)
    my $ofs = $self->{rx} % $len;
    substr($line,0,$ofs) = '' if $ofs != 0;

    $line = substr($line, 0, $w) if length($line) > $w;
  
    my $x = 0;
    if (($flags & EDGE_START_W) != 0)
      {
      $x++; chop($line);			# ' ---'
      }
    if (($flags & EDGE_START_E) != 0)
      {
      chop($line);			# '--- '
      }
    if (($flags & EDGE_END_E) != 0)
      {
      # '--> '
      chop($line);
      substr($line,-1,1) = $self->_arrow($as, ARROW_RIGHT)
       if $as ne 'none';
      }
    if (($flags & EDGE_END_W) != 0)
      {
      # ' <--'
      substr($line,0,1) = ' ' if $as eq 'none';
      substr($line,0,2) = ' ' . $self->_arrow($as, ARROW_LEFT)
       if $as ne 'none';
      }

    substr($line,0,2) = '  ' if $type == EDGE_E_N_S;
    substr($line,2,$self->{w}-2) = ' ' x ($self->{w}-2) if $type == EDGE_W_N_S;

    $self->_printfb_line ($fb, $x, $y, $line);
    }
  else { $invisible++; }

  if (!$invisible)
    {
    # draw the crossing character only if both lines are visible
    my $cross = $style->[2];
    my $s = $self->{style} . $self->{style_ver};
    $cross = ($self->_cross_style($s) || $cross) if $self->{style_ver} ne $self->{style};

    $self->_printfb ($fb, 2, $y, $cross);
    }

  # done
  }

sub _draw_corner
  {
  # draw a corner (N_E, S_E etc)
  my ($self, $fb) = @_;

  my $type = $self->{type} & EDGE_TYPE_MASK;
  my $flags = $self->{type} & EDGE_FLAG_MASK;

  ############
  #   ........
  # 0 :      :
  # 1 :      :    label would appear here
  # 2 :  +---:    (w-3) = 3 chars wide
  # 3 :  |   :    always 1 char high
  #   .......:
  #    012345 

  # draw the vertical piece
 
  # get the style
  my $style = $self->_edge_style();
 
  my $h = 1; my $y = $self->{h} -1; 
  if ($type == EDGE_N_E || $type == EDGE_N_W)
    {
    $h = $self->{h} - 2; $y = 0; 
    }
  # '|' => '|||||', '{}' => '{}{}{}'
  my $line = $style->[1] x (1 + $h / length($style->[1])); 
  $line = substr($line, 0, $h) if length($line) > $h;

  my $as = $self->_arrow_style();
  if ($as ne 'none')
    {
    substr($line,0,1) = $self->_arrow($as, ARROW_UP)
      if (($flags & EDGE_END_N) != 0);
    substr($line,-1,1) = $self->_arrow($as, ARROW_DOWN)
      if (($flags & EDGE_END_S) != 0);
    }

  $self->_printfb_ver ($fb, 2, $y, $line);

  # horizontal piece
  my $w = $self->{w} - 3; $y = $self->{h} - 2; my $x = 3;
  if ($type == EDGE_N_W || $type == EDGE_S_W)
    {
    $w = 2; $x = 0; 
    }

  # '-' => '-----', '.-' => '.-.-.-'
  my $len = length($style->[0]); 
  $line = $style->[0] x (2 + $w / $len); 
  
  # '.-.-.-' => '-.-.-' if $x % $ofs == 1 (e.g. on odd positions)
  my $ofs = ($x + $self->{rx}) % $len;
  substr($line,0,$ofs) = '' if $ofs != 0;

  $line = substr($line, 0, $w) if length($line) > $w;
  
  if ((($flags & EDGE_END_E) != 0) && ($as ne 'none'))
    {
    substr($line,-1,1) = $self->_arrow($as, ARROW_RIGHT);
    }
  if (($flags & EDGE_END_W) != 0)
    {
    substr($line,0,1) = ' ' if $as eq 'none';
    substr($line,0,2) = ' ' . $self->_arrow($as, ARROW_LEFT) if $as ne 'none';
    }

  $self->_printfb_line ($fb, $x, $y, $line);

  my $idx = 3; 		# corner (SE, SW, NE, NW)
  $idx = 4 if $type == EDGE_S_W;
  $idx = 5 if $type == EDGE_N_E;
  $idx = 6 if $type == EDGE_N_W;

  # insert the corner character
  $self->_printfb ($fb, 2, $y, $style->[$idx]);
  }

sub _draw_loop_hor
  {
  my ($self, $fb) = @_;

  my $type = $self->{type} & EDGE_TYPE_MASK;
  my $flags = $self->{type} & EDGE_FLAG_MASK;

  ############
  #   ..........
  # 0 :        :
  # 1 :        :    label would appear here
  # 2 :  +--+  :    (w-6) = 2 chars wide
  # 3 :  |  v  :    1 char high
  #   .........:
  #    01234567 

  ############
  #   ..........
  # 0 :  |  ^  :    ver is h-2 chars high	
  # 1 :  |  |  :    label would appear here
  # 2 :  +--+  :    (w-6) = 2 chars wide
  # 3 :        :
  #   .........:
  #    01234567 

  # draw the vertical pieces
 
  # get the style
  my $style = $self->_edge_style();
 
  my $h = 1; my $y = $self->{h} - 1; 
  if ($type == EDGE_S_W_N)
    {
    $h = $self->{h} - 2; $y = 0; 
    }
  # '|' => '|||||', '{}' => '{}{}{}'
  my $line = $style->[1] x (1 + $h / length($style->[1])); 
  $line = substr($line, 0, $h) if length($line) > $h;
  
  my $as = $self->_arrow_style();

  if ($self->{edge}->{bidirectional} && $as ne 'none')
    {
    substr($line,0,1)  = $self->_arrow($as, ARROW_UP) if (($flags & EDGE_END_N) != 0);
    substr($line,-1,1) = $self->_arrow($as, ARROW_DOWN) if (($flags & EDGE_END_S) != 0);
    }
  $self->_printfb_ver ($fb, $self->{w}-3, $y, $line);

  if ($as ne 'none')
    {
    substr($line,0,1)  = $self->_arrow($as, ARROW_UP) if (($flags & EDGE_END_N) != 0);
    substr($line,-1,1) = $self->_arrow($as, ARROW_DOWN) if (($flags & EDGE_END_S) != 0);
    }
  $self->_printfb_ver ($fb, 2, $y, $line);

  # horizontal piece
  my $w = $self->{w} - 6; $y = $self->{h} - 2; my $x = 3;

  # '-' => '-----', '.-' => '.-.-.-'
  my $len = length($style->[0]); 
  $line = $style->[0] x (2 + $w / $len); 
  
  # '.-.-.-' => '-.-.-' if $x % $ofs == 1 (e.g. on odd positions)
  my $ofs = ($x + $self->{rx}) % $len;
  substr($line,0,$ofs) = '' if $ofs != 0;

  $line = substr($line, 0, $w) if length($line) > $w;
  
  $self->_printfb_line ($fb, $x, $y, $line);
  
  my $corner_idx = 3; $corner_idx = 5 if $type == EDGE_S_W_N;

  # insert the corner characters
  $self->_printfb ($fb, 2, $y, $style->[$corner_idx]);
  $self->_printfb ($fb, $self->{w}-3, $y, $style->[$corner_idx+1]);

  my $align = 'bottom'; $align = 'top' if $type == EDGE_S_W_N;
  $self->_insert_label($fb, 4, 0, 4, 2, $align)
  if ($self->{type} & EDGE_LABEL_CELL);

  # done
  }

sub _draw_loop_ver
  {
  my ($self, $fb) = @_;

  my $type = $self->{type} & EDGE_TYPE_MASK;
  my $flags = $self->{type} & EDGE_FLAG_MASK;

  ############
  #   ........
  # 0 :      :  label would appear here
  # 1 :  +-- :
  # 2 :  |   :
  # 3 :  +-> :
  #   .......:
  #    012345 

  #   ........
  # 0 :      :  label would appear here
  # 1 : --+  :
  # 2 :   |  :
  # 3 : <-+  :
  #   .......:
  #    012345 

  ###########################################################################
  # draw the vertical piece
 
  # get the style
  my $style = $self->_edge_style();
 
  my $h = 1; my $y = $self->{h} - 3; 
  # '|' => '|||||', '{}' => '{}{}{}'
  my $line = $style->[1] x (1 + $h / length($style->[1])); 
  $line = substr($line, 0, $h) if length($line) > $h;

  my $x = 2; $x = $self->{w}-3 if ($type == EDGE_E_S_W);
  $self->_printfb_ver ($fb, $x, $y, $line);

  ###########################################################################
  # horizontal pieces

  my $w = $self->{w} - 3; $y = $self->{h} - 4;
  $x = 2; $x = 1 if ($type == EDGE_E_S_W);

  # '-' => '-----', '.-' => '.-.-.-'
  my $len = length($style->[0]); 
  $line = $style->[0] x (2 + $w / $len); 
  
  # '.-.-.-' => '-.-.-' if $x % $ofs == 1 (e.g. on odd positions)
  my $ofs = ($x + $self->{rx}) % $len;
  substr($line,0,$ofs) = '' if $ofs != 0;

  $line = substr($line, 0, $w) if length($line) > $w;

  my $as = $self->_arrow_style();
 
  if ($self->{edge}->{bidirectional} && $as ne 'none')
    {
    substr($line,0,1)  = $self->_arrow($as, ARROW_LEFT) if (($flags & EDGE_END_W) != 0);
    substr($line,-1,1) = $self->_arrow($as, ARROW_RIGHT) if (($flags & EDGE_END_E) != 0);
    }

  $self->_printfb_line ($fb, $x, $y, $line);

  if ($as ne 'none')
    {
    substr($line,0,1)  = $self->_arrow($as, ARROW_LEFT) if (($flags & EDGE_END_W) != 0);
    substr($line,-1,1) = $self->_arrow($as, ARROW_RIGHT) if (($flags & EDGE_END_E) != 0);
    }
  
  $self->_printfb_line ($fb, $x, $self->{h} - 2, $line);

  $x = 2; $x = $self->{w}-3 if ($type == EDGE_E_S_W);

  my $corner_idx = 3; $corner_idx = 4 if $type == EDGE_E_S_W;

  # insert the corner characters
  $self->_printfb ($fb, $x, $y, $style->[$corner_idx]);
  $self->_printfb ($fb, $x, $self->{h}-2, $style->[$corner_idx+2]);

  $x = 4; $x = 3 if ($type == EDGE_E_S_W);
  $self->_insert_label($fb, $x, 0, $x, 4, 'bottom')
    if ($self->{type} & EDGE_LABEL_CELL);

  # done
  }

# which method to call for which edge type
my $draw_dispatch =
  {
  EDGE_HOR() => '_draw_hor',
  EDGE_VER() => '_draw_ver',

  EDGE_S_E() => '_draw_corner', 
  EDGE_S_W() => '_draw_corner',
  EDGE_N_E() => '_draw_corner',
  EDGE_N_W() => '_draw_corner',

  EDGE_CROSS() => '_draw_cross',
  EDGE_W_N_S() => '_draw_cross',
  EDGE_E_N_S() => '_draw_cross',
  EDGE_N_E_W() => '_draw_cross',
  EDGE_S_E_W() => '_draw_cross',

  EDGE_N_W_S() => '_draw_loop_hor',
  EDGE_S_W_N() => '_draw_loop_hor',

  EDGE_E_S_W() => '_draw_loop_ver',
  EDGE_W_S_E() => '_draw_loop_ver',
  };

sub _draw_label
  {
  # This routine is cunningly named _draw_label, because it actually
  # draws the edge line(s). The label text will be drawn by the individual
  # routines called below.
  my ($self, $fb, $x, $y) = @_;

  my $type = $self->{type} & EDGE_TYPE_MASK;

  # for cross sections, we maybe need to draw one of the parts:
  return if ($self->attribute('style') || '') eq 'invisible' && $type ne EDGE_CROSS;

  my $m = $draw_dispatch->{$type};

  $self->_croak("Unknown edge type $type") unless defined $m;

  # store the coordinates of our upper-left corner (for seamless rendering)
  $self->{rx} = $x || 0; $self->{ry} = $y || 0;
  $self->$m($fb);
  delete $self->{rx}; delete $self->{ry};	# no longer needed
  }

#############################################################################
#############################################################################

package Graph::Easy::Node;

use strict;

BEGIN
  {
  *{_u8} = \&Graph::Easy::As_ascii::_u8;
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

sub _printfb_aligned
  {
  my ($self,$fb, $x1,$y1, $w,$h, $lines, $aligns, $align_ver) = @_;

  $align_ver = 'center' unless $align_ver;

  my $y = $y1 + ($h / 2) - (scalar @$lines / 2);
  $y = $y1 if $align_ver eq 'top';
  $y = $h - scalar @$lines if $align_ver eq 'bottom';

  my $xc = ($w / 2);

  my $i = 0;
  while ($i < @$lines)
    {
    # get the line and her alignment
    my ($l,$al) = ($lines->[$i],$aligns->[$i]);

    my $x = 0;			# left is default

    $x = $xc - length($l) / 2 if $al eq 'c';
    $x = $w - length($l) if $al eq 'r';

    # now print the line (inlined print_fb_line for speed)
    substr ($fb->[int($y+$i+$y1)], int($x+$x1), length($l)) = $l;

    $i++;
    }
  }

sub _printfb_line
  {
  # Print one textline into a framebuffer
  # Caller MUST ensure proper size of FB, for speed reasons,
  # we do not check whether text fits!
  my ($self, $fb, $x, $y, $l) = @_;

  # [0] = '0123456789...'

  substr ($fb->[$y], $x, length($l)) = $l;
  }

sub _printfb
  {
  # Print (potential a multiline) text into a framebuffer
  # Caller MUST ensure proper size of FB, for speed reasons,
  # we do not check whether the text fits!
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
  # we do not check whether text fits!
  my ($self, $fb, $x, $y, $line) = @_;

  # this more than twice as fast as:
  #  "@pieces = split//,$line; _printfb(...)"

  my $y1 = $y + length($line);
  substr ($fb->[$y1], $x, 1) = chop($line) while ($y1-- > $y);
  }

 # for ASCII and box drawing:

 # the array contains for each style:
 # upper left edge
 # upper right edge
 # lower right edge
 # lower left edge
 # hor style (top edge)
 # hor style (bottom side)
 # ver style (right side) (multiple characters possible)
 # ver style (left side) (multiple characters possible)
 # T crossing (see drawing below)
 # T to right
 # T to left
 # T to top
 # T shape (to bottom)
 
 #
 # +-----4-----4------+
 # |     |     |      |
 # |     |     |      |
 # |     |     |      |
 # 1-----0-----3------2		1 = T to right, 2 = T to left, 3 T to top
 # |     |			0 = cross, 4 = T shape
 # |     |
 # |     |
 # +-----+

my $border_styles = 
  [
  {
  solid =>		[ '+', '+', '+', '+', '-',   '-',   [ '|'      ], [ '|'     ], '+', '+', '+', '+', '+' ],
  dotted =>		[ '.', '.', ':', ':', '.',   '.',   [ ':'      ], [ ':'     ], '.', '.', '.', '.', '.' ],
  dashed =>		[ '+', '+', '+', '+', '- ',  '- ',  [ "'"      ], [ "'"     ], '+', '+', '+', '+', '+' ],
  'dot-dash' =>		[ '+', '+', '+', '+', '.-',  '.-',  [ '!'      ], [ '!'     ], '+', '+', '+', '+', '+' ],
  'dot-dot-dash' =>	[ '+', '+', '+', '+', '..-', '..-', [ '|', ':' ], [ '|',':' ], '+', '+', '+', '+', '+' ],
  bold =>		[ '#', '#', '#', '#', '#',   '#',   [ '#'      ], [ '#'     ], '#', '#', '#', '#', '#' ],
  'bold-dash' =>	[ '#', '#', '#', '#', '# ',  '# ',  ['#',' '   ], [ '#',' ' ], '#', '#', '#', '#', '#' ],
  double =>		[ '#', '#', '#', '#', '=',   '=',   [ 'H'      ], [ 'H'     ], '#', '#', '#', '#', '#' ],
  'double-dash' =>	[ '#', '#', '#', '#', '= ',  '= ',  [ '"'      ], [ '"'     ], '#', '#', '#', '#', '#' ],
  wave =>		[ '+', '+', '+', '+', '~',   '~',   [ '{', '}' ], [ '{','}' ], '+', '+', '+', '+', '+' ],
  broad =>		[ '#', '#', '#', '#', '#',   '#',   [ '#'      ], [ '#'     ], '#', '#', '#', '#', '#' ],
  wide =>		[ '#', '#', '#', '#', '#',   '#',   [ '#'      ], [ '#'     ], '#', '#', '#', '#', '#' ],
  none =>		[ ' ', ' ', ' ', ' ', ' ',   ' ',   [ ' '      ], [ ' '     ], ' ', ' ', ' ', ' ', ' ' ],
  },
  {
  solid =>		[ _u8('0c'), _u8('10'), _u8('18'), _u8('14'), _u8('00'), _u8('00'),     [ _u8('02') ], [ _u8('02') ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  double =>		[ _u8('54'), _u8('57'), _u8('5d'), _u8('5a'), _u8('50'), _u8('50'),     [ _u8('51') ], [ _u8('51') ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  dotted =>		[ _u8('0c'), _u8('10'), _u8('18'), _u8('14'), _u8('22ef'), _u8('22ef'), [ _u8('22ee') ], [ _u8('22ee') ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  dashed =>		[ _u8('0c'), _u8('10'), _u8('18'), _u8('14'), _u8('2212'), _u8('2212'), [ _u8('4e') ], [ _u8('4e') ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  'dot-dash' =>		[ _u8('0c'), _u8('10'), _u8('18'), _u8('14'), _u8('00b7').'-', _u8('00b7').'-', ['!'], ['!'], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  'dot-dot-dash' =>	[ _u8('0c'), _u8('10'), _u8('18'), _u8('14'), (_u8('00b7') x 2) .'-', (_u8('00b7') x 2) .'-', [ _u8('02'), ':' ], [ _u8('02'), ':' ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  bold =>		[ _u8('0f'), _u8('13'), _u8('1b'), _u8('17'), _u8('01'), _u8('01'), [ _u8('03') ], [ _u8('03') ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  'bold-dash' =>	[ _u8('0f'), _u8('13'), _u8('1b'), _u8('17'), _u8('01').' ', _u8('01').' ', [ _u8('7b') ], [ _u8('7b') ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  'double-dash' =>	[ _u8('54'), _u8('57'), _u8('5d'), _u8('5a'), _u8('50').' ', _u8('50').' ', [ _u8('2225') ], [ _u8('2225') ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  wave =>		[ _u8('0c'), _u8('10'), _u8('18'), _u8('14'), _u8('223c'),  _u8('223c'), [ _u8('2240') ], [ _u8('2240') ], _u8('3c'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  broad =>		[ _u8('9b'), _u8('9c'), _u8('9f'), _u8('99'), _u8('80'), _u8('84'), [ _u8('8c') ], [ _u8('90') ], _u8('84'), _u8('1c'), _u8('24'), _u8('34'), _u8('2c') ],
  wide =>		[ _u8('88'), _u8('88'), _u8('88'), _u8('88'), _u8('88'), _u8('88'), [ _u8('88') ], [ _u8('88') ], _u8('88'), _u8('88'), _u8('88'), _u8('88'), _u8('88') ],
  none =>		[ ' ', ' ', ' ', ' ', ' ', ' ',  [ ' '      ], [ ' ' ], 		    ' ', ' ', ' ', ' ', ' ', ],
  },
  ];

 # for boxart and rounded corners on node-borders:
 # upper left edge
 # upper right edge
 # lower right edge
 # lower left edge

my $rounded_edges =
  [
  _u8('6d'), _u8('6e'), _u8('6f'), _u8('70'),
  ]; 

 # ASCII and box art: the different point styles

my $point_styles = 
  [
  {
  'star' => '*',
  'square' => '#',
  'dot' => '.',
  'circle' => 'o', 	# unfortunately, we do not have a filled o
  'cross' => '+',
  'diamond' => '<>',
  'x' => 'X',
  'invisible' => '',
  },
  {
  'star' => _u8('2605'),
  'square' => _u8('a0'),
  'dot' => _u8('00b7'),
  'circle' => _u8('cf'),
  'cross' => '+',
  'diamond' => _u8('c6'),
  'x' => _u8('73'),
  'invisible' => '',
  },
  ];  

sub _point_style
  {
  my ($self, $style) = @_;

  my $g = $self->{graph}->{_ascii_style} || 0;
  $point_styles->[$g]->{$style};
  }

sub _border_style
  {
  my ($self, $style, $type) = @_;

  # make a copy so that we can modify it
  my $g = $self->{graph}->{_ascii_style} || 0;
  my $s = [ @{ $border_styles->[ $g ]->{$style} } ];

  die ("Unknown $type border style '$style'") if @$s == 0;

  my $shape = $self->attribute('shape') || '';
  return $s unless $shape eq 'rounded';

  # if shape: rounded, overlay the rounded edge pieces
  splice (@$s, 0, 4, @$rounded_edges)
    if $style =~ /^(solid|dotted|dashed|dot-dash|dot-dot-dash)\z/;

  # '####' => ' ### '
  splice (@$s, 0, 4, (' ', ' ', ' ', ' '))
    if $g == 0 || $style =~ /^(bold|wide|broad|double|double-dash|bold-dash)\z/;

  $s;
  }

#############################################################################
# arrow styles in ASCII and boxart, in the order "right", "left", "up", "down":

my $arrow_styles = 
  [
  {
    open => [ '>', '<', '^', 'v', ],
    closed => [ '>', '<', '^', 'v', ],
    filled => [ '>', '<', '^', 'v', ],
  },
  {
    # Using '2227' and '2228' for up/down does have problems with many Fonts
    # not shwoing these characters. So we use "^" and "v", even though they
    # do not look as "good".
    open => [ '>', '<', '^', 'v', ],
    filled => [ _u8('25b6'), _u8('25c0'), _u8('25b2'), _u8('25bc') ],
    closed => [ _u8('25b7'), _u8('25c1'), _u8('25b3'), _u8('25bd') ],
  },
  ];

sub _arrow
  {
  # return an arror, depending on style and direction
  my ($self, $style, $dir) = @_;

  my $g = $self->{graph}->{_ascii_style} || 0;
  $arrow_styles->[$g]->{$style}->[$dir];
  }

sub _unicode_arrow
  {
  # return an arror in unicode, depending on style and direction
  my ($self, $style, $dir) = @_;

  $arrow_styles->[1]->{$style}->[$dir];
  }

my $arrow_dir = {
  '&gt;' => 0,
  '&lt;' => 1,
  '^' => 2,
  'v' => 3,
  };

sub _arrow_to_dir
  {
  # return an arror in unicode, depending on style and direction
  my ($self, $style) = @_;

  $arrow_dir->{$style} || 0;
  }

#############################################################################

#
# +---4---4---4---+
# |   |   |   |   |
# |   |   |   |   |
# |   |   |   |   |
# 1---0---3---0---2	1 = T to right, 2 = T to left, 3 T to top
# |   |       |   |	0 = cross, 4 = T shape
# |   |       |   |
# |   |       |   |
# +---+       +---+

sub _draw_border
  {
  # draws a border into the framebuffer
  my ($self, $fb, $do_right, $do_bottom, $do_left, $do_top, $x, $y) = @_;

  return if $do_right.$do_left.$do_bottom.$do_top eq 'nonenonenonenone';

  my $g = $self->{graph};

  my $w = $self->{w};
  if ($do_top ne 'none')
    {
    my $style = $self->_border_style($do_top, 'top');

    # top-left corner piece is only there if we have a left border
    my $tl = $style->[0]; $tl = '' if $do_left eq 'none';

    # generate the top border
    my $top = $style->[4] x (($self->{w}) / length($style->[4]) + 1);

    my $len = length($style->[4]); 

    # for seamless rendering
    if (defined $x)
      {
      my $ofs = $x % $len;
      substr($top,0,$ofs) = '' if $ofs != 0;
      }

    # insert left upper corner (if it is there)
    substr($top,0,1) = $tl if $tl ne '';

    $top = substr($top,0,$w) if length($top) > $w;
    
    # top-right corner piece is only there if we have a right border
    substr($top,-1,1) = $style->[1] if $do_right ne 'none';

    # if the border must be collapsed, modify top-right edge piece:
    if ($self->{border_collapse_right})
      {
      # place "4" (see drawing above)
      substr($top,-1,1) = $style->[10];
      }

    # insert top row into FB
    $self->_printfb( $fb, 0,0, $top);
    }

  if ($do_bottom ne 'none')
    {
    my $style = $self->_border_style($do_bottom, 'bottom');

    # bottom-left corner piece is only there if we have a left border
    my $bl = $style->[3]; $bl = '' if $do_left eq 'none';

    # the bottom row '+--------+' etc
    my $bottom = $style->[5] x (($self->{w}) / length($style->[5]) + 1);

    my $len = length($style->[5]);
 
    # for seamless rendering
    if (defined $x)
      {
      my $ofs = $x % $len;
      substr($bottom,0,$ofs) = '' if $ofs != 0;
      }

    # insert left bottom corner (if it is there)
    substr($bottom,0,1) = $bl if $bl ne '';

    $bottom = substr($bottom,0,$w) if length($bottom) > $w;

    # bottom-right corner piece is only there if we have a right border
    substr($bottom,-1,1) = $style->[2] if $do_right ne 'none';

    # if the border must be collapsed, modify bottom-right edge piece:
    if ($self->{border_collapse_right} || $self->{border_collapse_bottom})
      {
      if ($self->{rightbelow_count} > 0)
        {
        # place a cross or T piece (see drawing above)
        my $piece = 8;	# cross
        # inverted T
        $piece = 11 if $self->{rightbelow_count} < 2 && !$self->{have_below};
        $piece = 10 if $self->{rightbelow_count} < 2 && !$self->{have_right};
        substr($bottom,-1,1) = $style->[$piece];
        }
      }

    # insert bottom row into FB
    $self->_printfb( $fb, 0,$self->{h}-1, $bottom);
    }

  return if $do_right.$do_left eq 'nonenone';	# both none => done

  my $style = $self->_border_style($do_left, 'left');
  my $left = $style->[6];
  my $lc = scalar @{ $style->[6] } - 1;		# count of characters

  $style = $self->_border_style($do_right, 'right');
  my $right = $style->[7];
  my $rc = scalar @{ $style->[7] } - 1;		# count of characters

  my (@left, @right);
  my $l = 0; my $r = 0;				# start with first character
  my $s = 1; $s = 0 if $do_top eq 'none';

  my $h = $self->{h} - 2;
  $h ++ if defined $x && $do_bottom eq 'none';	# for seamless rendering
  for ($s..$h)
    {
    push @left, $left->[$l]; $l ++; $l = 0 if $l > $lc;
    push @right, $right->[$r]; $r ++; $r = 0 if $r > $rc;
    }
  # insert left/right columns into FB
  $self->_printfb( $fb, 0, $s, @left) unless $do_left eq 'none';
  $self->_printfb( $fb, $w-1, $s, @right) unless $do_right eq 'none';

  $self;
  }
 
sub _draw_label
  {
  # draw the node label into the framebuffer
  my ($self, $fb, $x, $y) = @_;

  my $shape = $self->attribute('shape') || 'rect';

  if ($shape eq 'point')
    {
    # point-shaped nodes do not show their label in ASCII
    my $style = $self->attribute('point-style') || 'star';
    my $l = $self->_point_style($style);

    $self->_printfb_line ($fb, 2, $self->{h} - 2, $l) if $l;
    return;
    }

  #        +----
  #        | Label  
  # 2,1: ----^

  my $w = $self->{w} - 4; my $xs = 2;
  my $h = $self->{h} - 2; my $ys = 0.5;
  my $border = $self->attribute('border-style') || '';
  if ($border eq 'none')
    {
    $w += 2; $h += 2;
    $xs = 1; $ys = 0;
    }

  my $align = $self->attribute('align') || 'center';
  $self->_printfb_aligned ($fb, $xs, $ys, $w, $h, $self->_aligned_label($align));
  }

sub as_ascii
  {
  # renders a node like:
  # +--------+    ..........    ""
  # | A node | or : A node : or " --> "
  # +--------+    ..........    "" 
  my ($self, $x,$y) = @_;

  my $shape = $self->attribute('shape') || 'rect';

  # invisible nodes, or very small ones
  return '' if $shape eq 'invisible' || $self->{w} == 0 || $self->{h} == 0;

  my $fb = $self->_framebuffer($self->{w}, $self->{h});

  # point-shaped nodes do not have a border
  if ($shape !~ /^(point|none)\z/)
    {
    my $border_style = $self->attribute('border-style') || 'solid';
    my $EM = 14;
    my $border_width = Graph::Easy::_border_width_in_pixels($self,$EM);

    # convert overly broad borders to the correct style
    $border_style = 'bold' if $border_width > 2;
    $border_style = 'broad' if $border_width > $EM * 0.2 && $border_width < $EM * 0.75;
    $border_style = 'wide' if $border_width >= $EM * 0.75;

    my $style = $border_style;

    #########################################################################
    # draw our border into the framebuffer

    if ($style ne 'none')
      {
      my $b_top = $style; $b_top = 'none' if $self->{no_border_top};
      my $b_left = $style; $b_left = 'none' if $self->{no_border_left};
      my $b_right = $style; $b_right = 'none' if $self->{no_border_right};
      my $b_bottom = $style; $b_bottom = 'none' if $self->{no_border_bottom};

      $self->_draw_border($fb, $b_right, $b_bottom, $b_left, $b_top);
      }
    }

  ###########################################################################
  # "draw" the label into the framebuffer (e.g. the edge and the label text)

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

Copyright (C) 2004 - 2006 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
