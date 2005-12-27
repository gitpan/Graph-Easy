#############################################################################
# Grid-management and layout preperation.
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy::Layout::Grid;

use vars qw/$VERSION/;

$VERSION = '0.03';

#############################################################################
#############################################################################

package Graph::Easy;

sub _prepare_layout
  {
  # this method is used by as_ascii() and as_svg() to find out the
  # sizes and placement of the different cells (edges, nodes etc).
  my ($self,$format) = @_;

  # Find out for each row and colum how big they are:
  #   +--------+-----+------+
  #   | Berlin | --> | Bonn | 
  #   +--------+-----+------+
  # results in:
  #        w,  h,  x,  y
  # 0,0 => 10, 3,  0,  0
  # 1,0 => 7,  3,  10, 0
  # 2,0 => 8,  3,  16, 0

  # Technically, we also need to "compress" away non-existant columns/rows.
  # We achive that by simply rendering them with size 0, so they become
  # practically invisible.

  my $cells = $self->{cells};
  my $rows = {};
  my $cols = {};

  # the last column/row
  my $mx = -100000; my $my = -100000;

  # find all x and y occurances to sort them by row/columns
  for my $cell (values %$cells)
    {
    my ($x,$y) = ($cell->{x}, $cell->{y});

    # Set the minimum cell size:
    {
      no strict 'refs';

      my $method = '_correct_size_' . $format;
      $method = '_correct_size' unless $cell->can($method);
      $cell->$method();
    }

    my $w = $cell->{w};
    my $h = $cell->{h};

    # record maximum size for that col/row
    $rows->{$y} = $h if $h >= ($rows->{$y} || 0);
    $cols->{$x} = $w if $w >= ($cols->{$x} || 0);

    $mx = $x if $x > $mx;
    $my = $y if $y > $my;
    } 

  # insert a dummy row/column with size=0 as last
  $rows->{$my+1} = 0;
  $cols->{$mx+1} = 0;

  # Now run through all rows/columns and get their absolute pos by taking all
  # previous ones into account.
  my $pos = 0;
  for my $y (sort { $a <=> $b } keys %$rows)
    {
    my $s = $rows->{$y};
    $rows->{$y} = $pos;			# first is 0, second is $rows[1] etc
    $pos += $s;
    }
  $pos = 0;
  for my $x (sort { $a <=> $b } keys %$cols)
    {
    my $s = $cols->{$x};
    $cols->{$x} = $pos;
    $pos += $s;
    }

  # find out max. dimensions for framebuffer
  my $max_y = 0; my $max_x = 0;

  for my $v (values %$cells)
    {
    next if ($v->{cx}||1) + ($v->{cy}||1) != 2;

    # X and Y are col/row, so translate them to real pos
    my $x = $cols->{ $v->{x} };
    my $y = $rows->{ $v->{y} };

    # Also set correct the width/height of each cell to be the maximum
    # width/height of that colum and store the previous size in 'minw'
    # and 'minh', respectively. Skip multi-celled nodes for later. 

    $v->{minw} = $v->{w};
    $v->{minh} = $v->{h};

    # find next col/row
    my $nx = $v->{x} + 1;
    my $next_col = $cols->{ $nx };
    my $ny = $v->{y} + 1;
    my $next_row = $rows->{ $ny };

    $next_col = $cols->{ ++$nx } while (!defined $next_col);
    $next_row = $rows->{ ++$ny } while (!defined $next_row);

    $v->{w} = $next_col - $x;
    $v->{h} = $next_row - $y;

    my $m = $y + $v->{h} - 1;
    $max_y = $m if $m > $max_y;
    $m = $x + $v->{w} - 1;
    $max_x = $m if $m > $max_x;
    }

  # repeat the previous step, now for multi-celled nodes
  # Looping over nodes should be faster
  foreach my $v (values %{$self->{nodes}})
    {
    next unless defined $v->{x} && (($v->{cx}||1) + ($v->{cy}||1) > 2);

    # X and Y are col/row, so translate them to real pos
    my $x = $cols->{ $v->{x} };
    my $y = $rows->{ $v->{y} };

    $v->{minw} = $v->{w};
    $v->{minh} = $v->{h};

    # find next col/row
    my $nx = $v->{x} + $v->{cx};
    my $next_col = $cols->{ $nx };
    my $ny = $v->{y} + $v->{cy};
    my $next_row = $rows->{ $ny };

    $next_col = $cols->{ ++$nx } while (!defined $next_col);
    $next_row = $rows->{ ++$ny } while (!defined $next_row);

    $v->{w} = $next_col - $x;
    $v->{h} = $next_row - $y;

    my $m = $y + $v->{h} - 1;
    $max_y = $m if $m > $max_y;
    $m = $x + $v->{w} - 1;
    $max_x = $m if $m > $max_x;
    }

  # return what we found out:
  ($rows,$cols,$max_x,$max_y);
  }

1;
__END__

=head1 NAME

Graph::Easy::Layout::Grid - Grid management and size calculation

=head1 SYNOPSIS

	use Graph::Easy;
	
	my $graph = Graph::Easy->new();

	my $bonn = Graph::Easy::Node->new(
		name => 'Bonn',
	);
	my $berlin = Graph::Easy::Node->new(
		name => 'Berlin',
	);

	$graph->add_edge ($bonn, $berlin);

	$graph->layout();

	print $graph->as_ascii( );

	# prints:

	# +------+     +--------+
	# | Bonn | --> | Berlin |
	# +------+     +--------+

=head1 DESCRIPTION

C<Graph::Easy::Layout::Grid> contains routines that calculate cell sizes
on the grid, which is necessary for ASCII, boxart and SVG output.

Used automatically by Graph::Easy.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 METHODS

This module injects the following methods into Graph::Easy:

=head2 _prepare_layout()

  	my ($rows,$cols,$max_x,$max_y, \@V) = $graph->_prepare_layout();

Returns two hashes (C<$rows> and C<$cols>), containing the columns and rows
of the layout with their nec. sizes (in chars) plus the maximum
framebuffer size nec. for this layout. Also returns reference of
a list of all cells to be rendered.

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>.

See the LICENSE file for information.

=cut
