#############################################################################
# Layout directed graphs as 2D boxes on a flat plane
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy;

use 5.006001;
use Graph::Easy::Cluster;
use Graph::Easy::Edge;
use Graph::Easy::Group;
use Graph::Easy::Group::Cell qw/GROUP_MAX/;
use Graph::Easy::Layout;
use Graph::Easy::Node;
use Graph::Easy::Node::Anon;
use Graph 0.65;
use Graph::Directed;

$VERSION = '0.18';

use strict;

# Name of attribute under which the pointer to each Node/Edge object is stored
# If you change this, change it also in Node.pm!
sub OBJ () { 'obj' };

#############################################################################
sub new
  {
  my $class = shift;

  my $self = bless {}, $class;

  my $args = $_[0];
  $args = { @_ } if ref($args) ne 'HASH';

  $self->_init($args);
  }

sub _init
  {
  my ($self,$args) = @_;

  $self->{error} = '';
  $self->{debug} = 0;
  
  $self->{id} = '';
  $self->{groups} = {};

  $self->{output_format} = 'html';
  $self->{html_header} = '';
  $self->{html_footer} = '';
  $self->{html_style} = '';

  $self->{att} = {
  node => {
    border => '1px solid black',
    background => 'white',
    padding => '0.2em',
    'padding-left' => '0.3em',
    'padding-right' => '0.3em',
    margin => '0.1em',
    'text-align' => 'center',
    },
  graph => { 
    border => 'none',
    background => 'inherit',
    margin => '0.5em',
    padding => '0.5em',
    linkbase => '/wiki/index.php/',
    },
  edge => { 
    border => 'none',
    background => 'inherit',
    padding => '0.2em',
    margin => '0.1em',
    'text-align' => 'center',
    'font-family' => 'monospaced, courier-new, courier, sans-serif',
    # close the holes in the lines:
    'line-height' => '0.7em',
    'letter-spacing' => '-0.36em',
    # add padding to the right since letter-spacing contracts the right side
    'padding-right' => '0.5em',
    'width' => '1.8em',
    },
  group => { 
    border => '1px dashed black',
    background => '#a0d0ff',
    padding => '0.2em',
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

  # create our internal graph object
  $self->{graph} = Graph::Directed->new( multiedged => 1 );
  
  foreach my $k (keys %$args)
    {
#    if ($k !~ /^(|debug)\z/)
#      {
#      $self->error ("Unknown option '$k'");
#      }
    $self->{$k} = $args->{$k};
    }

  $self->{score} = undef;

  $self;
  }

#############################################################################
# accessors

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

sub error
  {
  my $self = shift;

  $self->{error} = $_[0] if defined $_[0];
  $self->{error};
  }

sub nodes
  {
  # return all nodes as objects
  my ($self) = @_;

  my $g = $self->{graph};

  my @V = $g->vertices();
  
  return scalar @V unless wantarray;		# shortcut

  my @nodes = ();
  foreach my $k (@V)
    {
    push @nodes, $g->get_vertex_attribute( $k, OBJ );
    }
  @nodes;
  }

sub edges
  {
  # return all the edges as objects
  my ($self) = @_;

  my $g = $self->{graph};

  my @E = $g->edges();

  return scalar @E unless wantarray;		# shortcut

  my @edges = ();
  foreach my $k (@E)
    {
    my @ids = $g->get_multiedge_ids(@$k);
    foreach my $id (@ids)
      {
      push @edges, $g->get_edge_attribute_by_id( @$k, $id, OBJ );
      }
    }
  @edges;
  }

sub sorted_nodes
  {
  # return all nodes as objects, sorted by their id
  my ($self) = @_;

  my @nodes = sort { $a->{id} <=> $b->{id} } $self->nodes();
  @nodes;
  }

sub edge
  {
  # return an edge between two nodes as object
  my ($self, $x, $y) = @_;

  print join(" ", caller()), "\n";

  # turn objects into names (e.g. unique key)
  $x = $x->{name} if ref $x;
  $y = $y->{name} if ref $y;

  my @ids = $self->{graph}->get_multiedge_ids($x, $y);

  if (scalar @ids > 1)
    {
    require Carp;
    Carp::croak ("There exist more than one edge from $x->{name} to $y->{name}");
    }
  #$self->{graph}->get_edge_attribute( $x, $y, OBJ );
  $self->{graph}->get_edge_attribute_by_id( $x, $y, $ids[0], OBJ );
  }

sub node
  {
  # return node by name
  my $self = shift;
  my $name = shift || '';

  $self->{graph}->get_vertex_attribute( $name, OBJ );
  }

sub attribute
  {
  # return the value of attribute $att from class $class
  my ($self, $class, $att) = @_;

  my $a = $self->{att};
  return undef unless exists $a->{$class} && exists $a->{$class}->{$att};
  $a->{$class}->{$att};
  }

sub set_attribute
  {
  my ($self, $class, $name, $val) = @_;

  $name = 'undef' unless defined $name;
  $val = 'undef' unless defined $val;

  # allowed classes and subclasses (except graph)
  if ($class !~ /^(node|group|edge|graph\z)/)
    {
    return $self->error ("Illegal class '$class' when trying to set attribute '$name' to '$val'");
    }

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

  $self->{att}->{$class}->{$name} = $val;

  return $val;
  }

sub set_attributes
  {
  my ($self, $class, $att) = @_;

  # allowed classes and subclasses (except graph)
  if ($class !~ /^(node|group|edge|graph\z)/)
    {
    return $self->error ("Illegal class '$class' when setting attributes");
    }

  # handle special attribute 'gid' like in "graph { gid: 123; }"
  if ($class eq 'graph' && exists $att->{gid})
    {
    $self->{id} = $att->{gid};
    }

  # create class
  $self->{att}->{$class} = {} unless ref($self->{att}->{$class}) eq 'HASH';

  foreach my $a (keys %$att)
    {
    my $val = $att->{$a}; $val =~ s/\\#/#/;		# "\#808080" => "#808080"
    $self->{att}->{$class}->{$a} = $val;
    } 
  $self;
  }

#############################################################################
#############################################################################
# output (as_ascii, as_html) routines; as_txt is in As_txt.pm

sub output_format
  {
  # set the outputformat
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
  if (!$self->can($method))  
    {
    require Carp;
    Carp::croak("Cannot find a method to generate '$self->{output_format}'");
    }
  $self->$method();
  }

sub css
  {
  my $self = shift;

  my $a = $self->{att};
  my $css = '';
  my $id = $self->{id};

  # for each primary class (node/group/edge) we need to find all subclasses,
  # and list them in the CSS, too. Otherwise "node-city" would not inherit
  # the attributes from "node".

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

  foreach my $class (sort keys %$a)
    {
    next if keys %{$a->{$class}} == 0;			# skip empty ones

    my $c = $class; $c =~ s/\./-/g;			# node.city => node-city

    my $css_txt = '';
    my $cls = '';
    if ($class eq 'graph')
      {
      $css_txt .= "table.graph$id {\n";
      }
    else
      {
      if ($c !~ /\./)					# one of our primary ones
        {
        # generate also class list 			# like: "cities,node-rivers"
        $cls = join (",table.graph$id .$c-", sort keys %{ $class_list->{$c} });
        $cls = ", table.graph$id .$c-$cls" if $cls ne '';		# like: ",node-cities,node-rivers"
        }
      $css_txt .= "table.graph$id .$c$cls {\n";
      }
    my $done = 0;
    foreach my $att (sort keys %{$a->{$class}})
      {
      # skip these for CSS
      next if 
	$att =~ /^(label|linkbase|(auto)?(link|title)|nodeclass|shape)\z/;

      $done++;						# how many did we really?
      my $val = $a->{$class}->{$att};
      # set for inner group cells "border: none"
      $val = 'none' if $att eq 'border' && $c eq 'group';
      $css_txt .= "  $att: $val;\n";
      }
    $css_txt .= "}\n";
    $css .= $css_txt if $done > 0;			# skip if no attributes at all
    }

  # XXX TODO: we could skip this if we do not have anon nodes
  # XXX TODO: this should make anon nodes invisible, but somehow doesn't
  # work
  $css .= "table.graph .node-anon { display: none; }\n";

  # Set attributes for all TDs that start with "group" (hyphen seperated,
  # so that group classes are something like "group-l-cities". The second rule
  # is for all TD without any class at all (these are the "filler" cells):
  $css .= <<CSS
table.graph##id## td[class|="group"] { padding: 0.2em; }
table.graph##id## td {
  padding: 2px;
  background: inherit;
  }
CSS
;

  # append CSS for group cells (only if we actually have groups)
  my @groups = $self->groups();

  if (@groups > 0)
    {
    # important for Mozilla/Gecko
    $css .= "table.graph$id { border-collapse: collapse; }\n";

    foreach my $group (@groups)
      {
      # could include only the ones we actually need
      my $border = $group->attribute('border'); 
      my $class = $group->{class}; $class =~ s/.*\.//;	# leave only subclass
      for (my $i = 1; $i <= GROUP_MAX; $i++)
	{
        $css .= Graph::Easy::Group::Cell->_css($self->{id}, $i, $class, $border); 
	}
      }
    my $border = $self->attribute('group','border'); 
    for (my $i = 1; $i <= GROUP_MAX; $i++)
      {
      $css .= Graph::Easy::Group::Cell->_css($self->{id}, $i, '', $border); 
      }
    }

  # append CSS for lines/labes (only if we actually have edges with labels)
  my @edges = $self->edges();

  my $have_labels = 0;
  for my $edge (@edges)
    {
    my $label = $edge->label();
    $have_labels = 1, last if defined $label && $label ne '';
    }

  # isnsert edgev
  $css =~ s/.edge/.edge, table.graph##id## .edgev, table.graph##id## .edgel/ if $have_labels != 0;

  $css .= <<CSS
table.graph##id## .edgev {
  text-align: left;
}
table.graph##id## .edgel {
  width: auto;
}
table.graph##id## .label, table.graph##id## .line {
  padding: 0em;
  margin: 0em;
  position: relative;
  top: -0.2em;
}
table.graph##id## .label, table.graph##id## .labelv { 
  font-size: 0.7em;
  letter-spacing: 0em;
}
table.graph##id## .labelv {
  position: relative;
  top: -1.5em;
  left: 0.5em;
}
CSS
  if $have_labels != 0;

  $css =~ s/##id##/$id/g;

  $css;
  }

sub html_page_header
  {
  my $self = shift;
  
  my $html = <<HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
 <head>
 <style type="text/css">
 <!--
 ##CSS##
  -->
 </style>
 </head>
<body bgcolor=white text=black>
HTML
;

  $html =~ s/##CSS##/$self->css()/e;

  $html;
  }

sub html_page_footer
  {
  my $self = shift;

  "\n</body></html>\n";
  }

sub as_html_page
  {
  my $self = shift;

  $self->layout() unless defined $self->{score};

  my $html = $self->html_page_header() . $self->as_html() . $self->html_page_footer();

  $html;
  }

#############################################################################
 
sub as_html
  {
  # convert the graph to HTML+CSS
  my ($self) = shift;

  $self->layout() unless defined $self->{score};

  my $html = "\n" . $self->{html_header};
 
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
 
  $html .= "\n<table class=\"graph$id\" cellpadding=4px cellspacing=0";
  $html .= " style=\"$self->{html_style}\"" if $self->{html_style};
  $html .= ">\n";

  my $tag = $self->{html_tag} || 'td';

  # now run through all rows, and for each of them through all columns 
  for my $y (sort { ($a||0) <=> ($b||0) } keys %$rows)
    {

    $html .= " <tr>\n";

    my @row = ();

    # for all possible columns
    for my $x (sort { $a <=> $b } keys %$cols)
      {
      if (!exists $rows->{$y}->{$x})
	{
	push @row, undef;
	next;
	}
      my $node = $rows->{$y}->{$x};
      push @row, "  " . $node->as_html('td',$id);
      }

    ######################################################################
    # remove trailing empty tag-pairs (but not if we have groups, because
    # firefox treats non-existing cells different than empty cells. 
    if ($groups == 0)
      {
      pop @row while (@row > 0 && !defined $row[-1]);
      }
    else
      {
      push @row, undef while (@row < $max_cells);
      }

    # replace undef with empty tags
    foreach (@row)
      {
      $_ = "  <$tag><\/$tag>\n" unless defined $_;
      }

    # now combine equal columns
    my $i = 0;
    while ($i < @row)
      {
      # count all sucessive equal ones
      my $j = $i + 1;
      while ($j < @row && $row[$j] eq $row[$i]) { $j++; }
      if ($j > $i + 1)
        {
        my $cnt = $j - $i - 1;
        # throw away
        splice (@row, $i + 1, $cnt); $cnt++;
        # replace
        $row[$i] =~ s/<$tag/<$tag colspan=$cnt/;
        }
      $i++;
      }
    ######################################################################
    
    # append row to output
    $html .= join('',@row) . " </tr>\n";
    }

  # Append an empty row - otherwise the distance from the last element/node to
  # the graph border is at the bottom and right less than at the top and left.
  
  $max_cells += 2;				# one more at the right
  $html .= " <tr><td colspan=$max_cells></td></tr>\n";

  $html .= "</table>\n" . $self->{html_footer} . "\n";
  
  $html;
  } 

############################################################################# 

sub as_ascii
  {
  # convert the graph to pretty ASCII art
  my ($self) = shift;

  if (!defined $self->{score})
    {
    $self->layout();
    }
    
  my ($rows,$cols,$max_x,$max_y,$cells) = $self->_prepare_layout('ascii');

  # generate the actual framebuffer
  my @fb = ();
  for my $y (0..$max_y+1)
    {
    $fb[$y] = ' ' x $max_x;
    }

  print STDERR "# Allocating framebuffer $max_x x $max_y\n" if $self->{debug};

  # insert all cells into it
  foreach my $v (@$cells)
    {
    # get as ASCII box
    my @lines = split /\n/, $v->as_ascii();
    # get position from cell
    my $x = $cols->{ $v->{x} };
    my $y = $rows->{ $v->{y} };
    for my $i (0 .. scalar @lines-1)
      {
      next if length($lines[$i]) == 0;
      # XXX TODO: framebuffer shouldn't be to small!
      $fb[$y+$i] = ' ' x $max_x if !defined $fb[$y+$i];
      substr($fb[$y+$i], $x, length($lines[$i])) = $lines[$i]; 
      }
    }

  my $out = '';
  for my $y (0..$max_y+1)
    {
    my $line = $fb[$y];
    $line =~ s/\s+\z//;		# remove trailing whitespace
    $out .= $line . "\n";
    }

  $out =~ s/\n+\z/\n/;		# remove trailing empty lines

  $out;				# return output
  }

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

  # Technically, we also need to "compress" away non-existant columns/rows
  # We achive that by simply rendering them with size 0, so they become
  # invisible.

  my $cells = $self->{cells};
  my $rows = {};
  my $cols = {};
  my @V;

  # the last column/row
  my $mx = -10000; my $my = -10000;

  # find all x and y occurances to sort them by row/columns
  for my $k (keys %$cells)
    {
    my ($x,$y) = split/,/, $k;
    my $cell = $cells->{$k};

    # Get all possible nodes from $cell (instead of nodes) because
    # this also includes edge/group cells, too.
    push @V, $cell;

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
  foreach my $v (@V)
    {

    # X and Y are col/row, so translate them to real pos
    my $x = $cols->{ $v->{x} };
    my $y = $rows->{ $v->{y} };

    # Also set correct the width/height of each cell to be the maximum
    # width/height of that colum and store the previous size in 'minw'
    # and 'minh', respectively. 

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

  # return what we found out:

  ($rows,$cols,$max_x,$max_y, \@V);
  }

#############################################################################
# as_txt, as_graphviz and as_svg

sub as_graphviz
  {
  require Graph::Easy::As_graphviz;

  _as_graphviz(@_);
  }

sub as_svg
  {
  require Graph::Easy::As_svg;

  _as_svg(@_);
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
  
  my $g = $self->{graph};

  print STDERR " add_edge $x->{name} -> $y->{name}\n" if $self->{debug};

  $edge = Graph::Easy::Edge->new() unless defined $edge;

  # add edge from X to Y and get the ID of the edge
  my $edge_id = $g->add_edge_get_id( $x->{name}, $y->{name} );

  # work around bug in Graph v0.65 returning something else instead of '0'
  # on first call
  $edge_id = '0' if ref($edge_id);

  # store the ID with the $edge object so that we can get at it later
  # register the nodes and the edge with our graph object
  $x->{graph} = $self;
  $y->{graph} = $self;
  $edge->{graph} = $self;
  $edge->{from} = $x;
  $edge->{to} = $y;
  $edge->{graph_id} = $edge_id;

  # store obj pointers so that we can get them back later
  $g->set_vertex_attribute( $x->{name}, OBJ, $x);
  $g->set_vertex_attribute( $y->{name}, OBJ, $y);

  # store the $edge obj ptr with the graph 
  $g->set_edge_attribute_by_id( $x->{name}, $y->{name}, $edge_id, OBJ, $edge);

  $self->{score} = undef;			# invalidate last layout

  $self;
  }

sub add_node
  {
  my ($self,$x) = @_;

  my $g = $self->{graph};

  $g->add_vertex( $x->{name} );
  $g->set_vertex_attribute( $x->{name}, OBJ, $x);

  $self->{score} = undef;			# invalidate last layout
  
  # register the node with our graph object
  $x->{graph} = $self;

  $self;
  }

#############################################################################
# group management

sub add_group
  {
  # add a group object
  my ($self,$group) = @_;

  # index under the group name for easier lookup
  $self->{groups}->{ $group->{name} } = $group;

  # register group with ourself  
  $group->{graph} = $self;
 
  $self;
  }

sub del_group
  {
  # delete group
  my ($self,$group) = @_;

  delete $self->{groups}->{ $group->{name} };
 
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

#############################################################################
# cluster management

sub add_cluster
  {
  # add a cluster object
  my ($self,$cluster) = @_;

  # index under the cluster name for easier lookup
  $self->{clusters}->{ $cluster->{name} } = $cluster;

  # register cluster with ourself  
  $cluster->{graph} = $self;
 
  $self;
  }

sub del_cluster
  {
  # delete cluster
  my ($self,$cluster) = @_;

  delete $self->{clusters}->{ $cluster->{name} };
 
  $self;
  }

sub cluster
  {
  # return cluster by name
  my ($self,$name) = @_;

  $self->{clusters}->{ $name };
  }

sub clusters
  {
  # return number of clusters (or clusters as object list)
  my ($self) = @_;

  if (wantarray)
    {
    my @clusters;
    for my $g (sort keys %{$self->{clusters}})
      {
      push @clusters, $self->{clusters}->{$g};
      }
    return @clusters;
    }
  scalar keys %{$self->{clusters}};
  }

1;
__END__
=head1 NAME

Graph::Easy - Render graphs as ASCII, HTML, SVG or Graphviz

=head1 SYNOPSIS

	use Graph::Easy;
	
	my $graph = Graph::Easy->new();

	my $bonn = Graph::Easy::Node->new(
		name => 'Bonn',
		border => 'solid 1px black',
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

	# raw HTML section
	print $graph->as_html( );

	# complete HTML page (with CSS)
	print $graph->as_html_page( );

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

	# SVG:
	print $graph->as_svg( );

	# Graphviz:
	my $graphviz = $graph->as_graphviz();
	`dot -o graph.png $graphviz`;

=head1 DESCRIPTION

C<Graph::Easy> lets you generate graphs consisting of various shaped
boxes connected with arrows.

It works on a grid (manhattan layout), and thus the output is
most usefull for flow charts, network diagrams, or hirarchy trees.

=head2 Input

Apart from driving the module with Perl code, you can also use
C<Graph::Easy::Parser> to parse simple graph descriptions like:

	[ Bonn ]      --> [ Berlin ]
	[ Frankfurt ] <=> [ Dresden ]
	[ Bonn ]      --> [ Frankfurt ]

See L<EXAMPLES> for how this might be rendered.

=head2 Output

The output can be done in various styles:

=over 2

=item ASCII ART

Uses things like C<+>, C<-> C<< < >> and C<|> to render the boxes.

=item BOX ART

Uses the extended ASCII characters to draw seamless boxes.

=item HTML

HTML tables with CSS making everything "pretty".

=back

=head1 EXAMPLES

The following examples are given in the simple text format that is understood
by L<Graph::Easy::Parser|Graph::Easy::Parser>.

If you see no ASCII/HTML graph output in the following examples, then your
C<pod2html> or C<pod2txt> converter did not recognize the special graph
paragraphs.

You can use the converters in C<examples/> like C<pod2txt> and C<pod2html>
in this distribution to generate a pretty page with nice graph "drawings" from
this document.

You can also see many different examples at:

L<http://bloodgate.com/perl/graph/>

=head2 One node

The most simple graph (apart from the empty one :) is a graph consisting of
only one node:

=begin graph

	[ Dresden ]

=end graph

=head2 Two nodes

A simple graph consisting of two nodes, linked together by a directed edge:

=begin graph

	[ Bonn ] -> [ Berlin ]

=end graph

=head2 Three nodes

A graph consisting of three nodes, and both are linked from the first:

=begin graph

	[ Bonn ] -> [ Berlin ]
	[ Bonn ] -> [ Hamburg ]

=end graph

=head2 Two not connected graphs

A graph consisting of two seperate parts, both of them not connected
to each other:

=begin graph

	[ Bonn ] -> [ Berlin ]
	[ Freiburg ] -> [ Hamburg ]

=end graph

=head2 Three nodes, interlinked

A graph consisting of three nodes, and two of the are connected from
the first node:

=begin graph

	[ Bonn ] -> [ Berlin ]
	[ Berlin ] -> [ Hamburg ]
	[ Bonn ] -> [ Hamburg ]

=end graph

=head2 Different edge styles

A graph consisting of a couple of nodes, linked with the
different possible edge styles.

=begin graph

	[ Bonn ] <-> [ Berlin ]        # bidirectional
	[ Berlin ] ==> [ Rostock ]     # double
	[ Hamburg ] ..> [ Altona ]     # dotted
	[ Dresden ] - > [ Bautzen ]    # dashed
	[ Magdeburg ] <=> [ Ulm ]      # bidrectional, double etc

=end graph

More examples at:

L<http://bloodgate.com/perl/graph/>

=head1 METHODS

C<Graph::Easy> supports the following methods:

=head2 new()

        use Graph::Easy;

        my $graph = Graph::Easy->new( );
        
Creates a new, empty C<Graph::Easy> object.

Takes optinal a hash reference with a list of options. The following are
valid options:

	debug			if true, enables debug output

=head2 attribute()

	my $value = $graph->attribute( $class, $name );

Return the value of attribute C<$name> from class C<$class>.

Example:

	my $color = $graph->attribute( 'node', 'color' );

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
	$graph->seed($seed);
	$graph->layout();

=head2 error()

	my $error = $graph->error();

Returns the last error. Optionally, takes an error message to be set.

	$graph->error( 'Expected Foo, but found Bar.' );

=head2 layout()

Creates the internal structures to layout the graph. This will be done
behind the scenes of you call any of the C<as_FOO> methods. 

=head2 as_ascii()

	print $graph->as_ascii();

Return the graph layout in ASCII art.

=head2 as_html()

	print $graph->as_html();

Return the graph layout as HTML section. See L<css()> to get the
CSS section to go with that HTML code. If you want a complete HTML page
then use L<as_html_page()>.

=head2 as_html_page()

	print $graph->as_html_page();

Return the graph layout as HTML complete with headers, CSS section and
footer. Can be viewed in the browser of your choice.

=head2 html_page_header()

	my $header = $graph->html_page_header();

Return the header of an HTML page. Used together with L<html_page_footer>
by L<as_html_page> to construct a complete HTML page.

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
is more a dump of the grpah, then a certain layout.

=head2 add_edge()

	$graph->add_edge( $x, $y, $edge);
	$graph->add_edge( $x, $y);

Add an edge between nodes X and Y. The optional edge object defines
the style of the edge, if not present, a default object will be used.

C<$x> and C<$y> should be objects of L<Graph::Easy::Node|Graph::Easy::Node>,
while C<$edge> should be L<Graph::Easy::Edge|Graph::Easy::Edge>.
 
=head2 add_vertex()

	$graph->add_vertex( $x );

Add a single node X to the graph. C<$x> should be a C<Graph::Easy::Node>.

=head2 vertices()

	my $vertices = $graph->vertices();

In scalar context, returns the number of nodes/vertices the graph has.
In list context returns a list of all vertices (as their unique keys). See
also L<nodes()>.

=head2 nodes()

	my $nodes = $graph->nodes();

In scalar context, returns the number of nodes/vertices the graph has.
In list context returns a list of all the node objects (as reference).

=head2 sorted_nodes()

	my $nodes = $graph->sorted_nodes();

In scalar context, returns the number of nodes/vertices the graph has.
In list context returns a list of all the node objects (as reference),
sorted by their internal ID number (e.g. the order they have been
inserted).

=head2 node()

	my $node = $graph->node('node name');

Return node by name (case sensitive). Returns undef of the node couldn't be found.

=head2 edge()

	my $edge = $graph->edge( $node1, $node2 );

Return edge object between nodes C<$node1> and C<$node2>. Both nodes can be
either names or C<Graph::Easy::Node> objects.

=head2 id()

	my $graph_id = $graph->id();
	$graph->id('123');

Returns the id of the graph. You can also set a new ID with this routine. The
default is ''.

The graph's ID is used to generate unique CSS classes for each graph, in the
case you want to have more than one graph in an HTML page.

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Layout::Aesthetic>, L<Graph> and L<Graph::Easy::Parser>.

There is also an very old, unrelated project from ca. 1995, which does something similiar.
See L<http://rw4.cs.uni-sb.de/users/sander/html/gsvcg1.html>.

Testcases and more examples under:

L<http://bloodgate.com/perl/graph/>.

=head1 LIMITATIONS

This module is a proof-of-concept and has currently some serious limitations.
Hopefully further development will lift these.

=head2 Syntax

See L<http://bloodgate.com/perl/graph/> for limits of the syntax. Mostly this
are limitations in the parser, which cannot yet handle the following features:

=over 2

=item nesting (graph-in-a-node)

=item node lists

Node lists only work on the left side of an expression. E.g. the first line
works, the second and third do not:

	[ Bonn ], [ Hof ] -> [ Berlin ]
	[ Frankfurt ] -> [ Hamburg ], [ Dresden ]
	[ Cottbus ], [ Kamenz ] -> [ Plauen ], [ Bamberg ]

=back

=head2 Double edges

It is not yet possible to have more than one edge going from Node A to Node B
as in the following picture:

	             +---------+
	  +--------> | Koblenz | <--+
	  |	     +---------+    |
	  |		|	    |
	  |		v	    |
	+------+     +--------+     |
	| Bonn | --> | Berlin |     |
	+------+     +--------+     |
	  |			    |
	  +-------------------------+

=head2 Paths

=over 2

=item No crossing

Currently edges (paths from node to node) cannot cross each other.

=item No double bends

All nodes must be either in straight line of sight (up, down, left or right) of
each other or connectable by a path with at most two bends, like shown here:

	+------+     +--------+
	| Bonn | --> | Berlin |
	+------+     +--------+
	  |            |
	  |            |
	  |            v
	  |          +---------+
	  +--------> | Potsdam |
	             +---------+

	+------+     +--------+      +--------+
	| Bonn | --> | Berlin | -- > | Kassel |
	+------+     +--------+      +--------+
	  |		|		^
	  |		|		|
	  |		v		|
	  |          +--------+		|
	  |	     | Ulm    |		|
	  |          +--------+		|
	  |				|
	  +-----------------------------+

Thus the following graph output is not yet possible:

	             +---------+
	  +--------> | Koblenz | <---------------+
	  |	     +---------+		 |
	  |		|			 |
	  |		|			 |
	  |		v			 |
	+------+     +--------+      +--------+  |
	| Bonn | --> | Berlin | -- > | Kassel |  |
	+------+     +--------+      +--------+	 |
	  |		^			 |
	  |		|			 |
	  v		|			 |
	+------+     +---------+      		 |
	| Ulm  | --> | Bautzen | 		 |
	+------+     +---------+ 		 |
	  |					 |
	  |					 |
	  +--------------------------------------+


For that to work a general path-finding algorithm like C<< A* >> must
be implemented.

=item No joints

Currently it is not possible that an edge joins another edge like this:

	+------+     +--------+     +-----------+
	| Bonn | --> | Berlin | --> | Magdeburg |
	+------+     +--------+     +-----------+
	  |            |	      |
	  |            |	      |
	  |            |	      v
	  |            v	    +---------+
	  +-----------------------> | Potsdam |
	             		    +---------+

This means each node can have at most 4 edges leading to or from it.

=item No optimizations

The layouter will generate sometimes non-optimal layouts like this:

	+------+     +--------+      +--------+
	| Bonn | --> | Berlin | -- > | Kassel |
	+------+     +--------+      +--------+
	  |				^
	  |				|
	  |				|
	  |				|
	  +-----------------------------+

The layout above should really be converted to this:

	+------+     +--------+
	| Bonn | --> | Berlin |
	+------+     +--------+
	  |            |
	  |            |
	  |            v
	  |          +---------+
	  +--------> | Kassel  |
	             +---------+

Other non-optimal layouts like this one will also appear sometimes:

	+------+     +--------+
	| Bonn | --> | Berlin |
	+------+     +--------+
	               ^
	               |
	               |
	+---------+    |
	| Kassel  | ---+
	+---------+

A second-stage optimizer that simplifies these layouts does not yet exist.

=back

All the flaws with the edges can be corrected easily, but there was simple
not enough time for that yet.

=head2 Node-Size

A node is currently always one cell big. Overly broad/wide nodes, or nodes
with multiple lines shoud occupy more than one cell. This would also
enable them to have more than 4 incoming/outgoing edges.

=head2 Placement

Currently the node placement is dependend on the order the nodes were
inserted into the graph. In reality it should start with nodes having
no or little incoming edges and then progress to nodes with more 
incoming edges.

=head2 Grouping

The output of the graphs in ASCII does not yet include the group
information.

=head2 Other formats

Formats other than ASCII and HTML are not yet complete in their
implementation. If you notice any bugs or defiencies, please
drop me a note!

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms of the GPL version 2.
See the LICENSE file for information.

=head1 NAME CHANGE

The package is formerly know as C<Graph::Simple>. The name was changed
for two reeasons:

=over 2

=item *

In graph theory, a C<simple> graph is a special type of graph. This software,
however, supports any graph type.

=item *

Creating graphs shouldbe easy, but the created graphs can also be quite complex.

=back

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

=cut
