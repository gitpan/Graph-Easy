#############################################################################
# (c) by Tels 2004 - 2005. Part of Graph::Easy
#
#############################################################################

package Graph::Easy::Group::Cell;

use Graph::Easy::Node;

@ISA = qw/Graph::Easy::Node/;
$VERSION = '0.07';

use strict;

#############################################################################

# The different types for a group-cell:
sub GROUP_INNER	 	() { 0; }	# completely sourounded by group cells
sub GROUP_RIGHT	 	() { 1; }	# right border only
sub GROUP_LEFT	 	() { 2; }	# left border only
sub GROUP_TOP	 	() { 3; }	# top border only
sub GROUP_BOTTOM 	() { 4; }	# bottom border only
sub GROUP_ALL	 	() { 5; }	# completely sourounded by non-group cells

sub GROUP_BOTTOM_RIGHT	() { 6; }	# bottom and right border
sub GROUP_BOTTOM_LEFT	() { 7; }	# bottom and left border
sub GROUP_TOP_RIGHT	() { 8; }	# top and right border
sub GROUP_TOP_LEFT	() { 9; }	# top and left order

sub GROUP_MAX		() { 5; }	# max number

my $border_styles = 
  {
  # type		    top,	bottom, left,   right,	class
  GROUP_INNER()		=> [ 0,		0,	0,	0,	['gi'] ],
  GROUP_RIGHT()		=> [ 0,		0,	0,	1,	['gr'] ],
  GROUP_LEFT()		=> [ 0,		0,	1,	0,	['gl'] ],
  GROUP_TOP()		=> [ 1,		0,	0,	0,	['gt'] ],
  GROUP_BOTTOM()	=> [ 0,		1,	0,	0,	['gb'] ],
  GROUP_ALL()		=> [ 0,		0,	0,	0,	['ga'] ],
  GROUP_BOTTOM_RIGHT()	=> [ 0,		1,	0,	1,	['gb','gr'] ],
  GROUP_BOTTOM_LEFT()	=> [ 0,		1,	1,	0,	['gb','gl'] ],
  GROUP_TOP_RIGHT()	=> [ 1,		0,	0,	1,	['gt','gr'] ],
  GROUP_TOP_LEFT()	=> [ 1,		0,	1,	0,	['gt','gl'] ],
  };

my $border_name = [ 'top', 'bottom', 'left', 'right' ];

sub _css
  {
  my ($c, $id, $group, $border) = @_;

  my $css = '';

  for my $type (0 .. 5)
    {
    my $b = $border_styles->{$type};
  
    # If border eq 'none', this would needlessly repeat the "border: none"
    # from the general group class.
    next if $border eq 'none';

    my $cl = '.' . $b->[4]->[0]; # $cl .= "-$group" unless $group eq '';

    $css .= "table.graph$id $cl {";
    if ($type == GROUP_INNER)
      {
      $css .= " border: none;";			# shorter CSS
      }
    elsif ($type == GROUP_ALL)
      {
      $css .= " border-style: $border;";	# shorter CSS
      }
    else
      {
      for (my $i = 0; $i < 4; $i++)
        {
        $css .= ' border-' . $border_name->[$i] . "-style: $border;" if $b->[$i];
        }
      }
    $css .= "}\n";
    }

  $css;
  }

#############################################################################

sub _init
  {
  # generic init, override in subclasses
  my ($self,$args) = @_;
  
  $self->{class} = 'group';
  $self->{cell_class} = 'gi';
  $self->{name} = '';
  
  $self->{x} = 0;
  $self->{y} = 0;

  # XXX TODO check arguments
  foreach my $k (keys %$args)
    {
    $self->{$k} = $args->{$k};
    }
 
  if (defined $self->{group})
    {
    # register ourselves at this group
    $self->{group}->add_cell ($self);
    $self->{class} = $self->{group}->{class};
    $self->{class} = 'group' unless defined $self->{class};
    }
 
  $self;
  }

sub _set_type
  {
  # set the proper type of this cell based on the sourrounding cells
  my ($self, $cells) = @_;

  # +------+--------+-------+
  # | LT     TOP      RU    |
  # +      +        +       +
  # | LEFT   INNER    Right |
  # +      +        +       +
  # | LB     BOTTOM   RB    |
  # +------+--------+-------+

  my @coord = (
    [  0, -1, ' gt' ],
    [ +1,  0, ' gr' ],
    [  0, +1, ' gb' ],
    [ -1,  0, ' gl' ],
    );

  my ($sx,$sy) = ($self->{x},$self->{y});

  my $class = '';
  my $gr = $self->{group};
  foreach my $co (@coord)
    {
    my ($x,$y,$c) = @$co; $x += $sx; $y += $sy;
    my $cell = $cells->{"$x,$y"};

    # belongs to the same group?
    my $go = 0; $go = $cell->group() if UNIVERSAL::can($cell, 'group');

    $class .= $c unless defined $go && $gr == $go;
    }

  $class = ' ga' if $class eq ' gt gr gb gl';

  $self->{cell_class} = $class;

  $self;
  }

sub _set_label
  {
  my $self = shift;

  $self->{has_label} = 1;
 
  $self->{name} = $self->{group}->label();
  }

sub attribute
  {
  my $self = shift;

  $self->{group}->attribute(@_);
  }

#############################################################################
# conversion to ASCII or HTML

sub as_ascii
  {
  my ($self, $x,$y) = @_;

  my $fb = $self->_framebuffer($self->{w}, $self->{h});

  my $border_style = $self->{group}->attribute('border-style') || 'dashed';
  my $EM = 14;
  my $border_width = Graph::Easy::_border_width_in_pixels($self->{group},$EM);

  # convert overly broad borders to the correct style
  $border_style = 'bold' if $border_width > 2;
  $border_style = 'broad' if $border_width > $EM * 0.2 && $border_width < $EM * 0.75;
  $border_style = 'wide' if $border_width >= $EM * 0.75;

  if ($border_style ne 'none')
    {

    #########################################################################
    # draw our border into the framebuffer

    my $c = $self->{cell_class};

    my $b_top = $border_style;
    my $b_left = $border_style;
    my $b_right = $border_style; 
    my $b_bottom = $border_style;
    if ($c !~ 'ga')
      {
      $b_top = 'none' unless $c =~ /gt/;
      $b_left = 'none' unless $c =~ /gl/;
      $b_right = 'none' unless $c =~ /gr/;
      $b_bottom = 'none' unless $c =~ /gb/;
      }

    $self->_draw_border($fb, $b_right, $b_bottom, $b_left, $b_top, $x, $y);
    }

  if (exists $self->{has_label})
    {
    # include our label
    my @pieces = $self->_formatted_label();
    $self->_printfb ($fb, 0, $self->{h} - @pieces - 1, @pieces) if @pieces > 0;
    }

  join ("\n", @$fb);
  }

sub class
  {
  my $self = shift;

  $self->{class} . $self->{cell_class};
  }

#############################################################################

# for rendering this cell as ASCII/Boxart, we need to correct our width based
# on whether we have a border or not. But this is only known after parsing is
# complete.

sub _correct_size
  {
  my ($self,$format) = @_;

  if (!defined $self->{w})
    {
    my $border = $self->{group}->attribute('border-style') || 'dashed';
    $self->{w} = 0;
    $self->{h} = 0;
    # label needs space
    $self->{h} = 1 if $self->{has_label};
    if ($border ne 'none')
      {
      # class "gt", "gb", "gr" or "gr" will be compressed away
      # (e.g. only edge cells will be existant)
      if (exists $self->{has_label} || ($self->{cell_class} =~ /g[rltb] /))
	{
	$self->{w} = 2;
	$self->{h} = 2;
	}
      elsif ($self->{cell_class} =~ /^ g[rl]\z/)
	{
	$self->{w} = 2;
	}
      elsif ($self->{cell_class} =~ /^ g[bt]\z/)
	{
	$self->{h} = 2;
	}
      }
    }
  if (exists $self->{has_label})
    {
    my ($w,$h) = $self->dimensions();
    $self->{h} += $h;
    $self->{w} += $w;
    }
  }

1;
__END__

=head1 NAME

Graph::Easy::Group::Cell - A cell in a group

=head1 SYNOPSIS

        use Graph::Easy;

	my $ssl = Graph::Easy::Edge->new( );

	$ssl->set_attributes(
		label => 'encrypted connection',
		style => '-->',
		color => 'red',
	);

	$graph = Graph::Easy->new();

	$graph->add_edge('source', 'destination', $ssl);

	print $graph->as_ascii();

=head1 DESCRIPTION

A C<Graph::Easy::Group::Cell> represents a cell of a group.

Group cells can have a background and, if they are on the outside, a border.

There should be no need to use this package directly.

=head1 METHODS

=head2 error()

	$last_error = $group->error();

	$group->error($error);			# set new messags
	$group->error('');			# clear error

Returns the last error message, or '' for no error.

=head2 as_ascii()

	my $ascii = $cell->as_ascii();

Returns the cell as a little ascii representation.

=head2 as_html()

	my $html = $cell->as_html($tag,$id);

Returns the cell as HTML code.

=head2 label()

	my $label = $cell->label();

Returns the name (also known as 'label') of the cell.

=head2 class()

	my $class = $cell->class();

Returns the classname(s) of this cell, like:

	group-cities gr gb

for a cell with a bottom (gb) and right (gr) border in the class C<cities>.

=head1 EXPORT

None.

=head1 TODO

=over 2

=item Labels

=item Borders

=back

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for more details.

=cut
