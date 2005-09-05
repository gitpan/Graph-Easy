#############################################################################
# Layout directed graphs as 2D boxes on a flat plane
#
# (c) by Tels 2004-2005.
#############################################################################

package Graph::Easy;

use 5.006001;
use Graph::Easy::Attributes;
use Graph::Easy::Edge;
use Graph::Easy::Group;
use Graph::Easy::Group::Cell qw/GROUP_MAX/;
use Graph::Easy::Layout;
use Graph::Easy::Node;
use Graph::Easy::Node::Anon;
use Graph::Easy::Node::Empty;
use Scalar::Util qw/weaken/;

$VERSION = '0.28';

use strict;

BEGIN 
  {
  # a few aliases for backwards compatibility
  *attribute = \&get_attribute; 
  *as_html_page = \&as_html_file;
  *as_graphviz_file = \&as_graphviz;
  *as_ascii_file = \&as_ascii;
  *as_txt_file = \&as_txt;
  }

#############################################################################
sub new
  {
  my $class = shift;

  my $self = bless {}, $class;

  my $args = $_[0];
  $args = { @_ } if ref($args) ne 'HASH';

  $self->_init($args);
  }

sub DESTROY
  {
  my $self = shift;

  # clean out pointers in child-objects so that they can safely be reused
  for my $n (values %{$self->{nodes}})
    {
    if (ref($n))
      {
      $n->{edges} = undef;
      $n->{graph} = undef;
      }
    }
  for my $e (values %{$self->{edges}})
    {
    if (ref($e))
      {
      $e->clear_cells();
      $e->{to} = undef;
      $e->{from} = undef;
      $e->{graph} = undef;
      }
    }
  }

sub _init
  {
  my ($self,$args) = @_;

  $self->{error} = '';
  $self->{debug} = 0;
  $self->{timeout} = 5;			# in seconds
  $self->{strict} = 1;			# check attributes strict?
  
  $self->{id} = '';
  $self->{groups} = {};

  # node objects, indexed by their unique name
  $self->{nodes} = {};
  # edge objects, indexed by unique ID
  $self->{edges} = {};

  $self->{output_format} = 'html';
  $self->{html_header} = '';
  $self->{html_footer} = '';
  $self->{html_style} = '';

  $self->{_astar_bias} = 0.001;

  $self->{att} = {
  node => {
    'border' => '1px solid black',
    'border-style' => 'solid',
    'border-width' => '1',
    'border-color' => 'black',
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
    'border-style' => 'none',
    background => 'inherit',
    padding => '0.2em',
    margin => '0.1em',
    'font-family' => 'monospaced, courier-new, courier, sans-serif',
    },
  group => { 
    'border' => '1px dashed black',
    'border-style' => 'dashed',
    'border-width' => '1',
    'border-color' => 'black',
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

  foreach my $k (keys %$args)
    {
    if ($k !~ /^(timeout|debug|strict)\z/)
      {
      $self->error ("Unknown option '$k'");
      }
    $self->{$k} = $args->{$k};
    }

  $self->{score} = undef;

  $self->randomize();

  $self;
  }

#############################################################################
# accessors

sub timeout
  {
  my $self = shift;

  $self->{timeout} = $_[0] if @_;
  $self->{timeout};
  }

sub debug
  {
  my $self = shift;

  $self->{debug} = $_[0] if @_;
  $self->{debug};
  }

sub strict
  {
  my $self = shift;

  $self->{strict} = $_[0] if @_;
  $self->{strict};
  }

sub is_simple_graph
  {
  # return true if the graph does not have multiedges
  my $self = shift;

  # check each node for multi-edges
  for my $n (values %{$self->{nodes}})
    {
    my %count;
    for my $e (values %{$n->{edges}})
      {
      my $id = "$e->{to}->{id},$e->{from}->{id}";
      return 0 if exists $count{$id};
      $count{$id} = undef;
      }
    }

  1;					# found none
  }

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

sub randomize
  {
  my $self = shift;

  srand();
  $self->{seed} = rand(2 ** 31);

  $self->{seed};
  }

sub seed
  {
  my $self = shift;

  $self->{seed} = $_[0] if @_ > 0;

  $self->{seed};
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

  my $n = $self->{nodes};

  return scalar keys %$n unless wantarray;	# shortcut

  values %$n;
  }

sub edges
  {
  # return all the edges as objects
  my ($self) = @_;

  my $e = $self->{edges};

  return scalar keys %$e unless wantarray;	# shortcut

  values %$e;
  }

sub sorted_nodes
  {
  # return all nodes as objects, sorted by $f1 or $f1 and $f2
  my ($self, $f1, $f2) = @_;

  return scalar $self->nodes() unless wantarray;	# shortcut

  $f1 = 'id' unless defined $f1;
  # sorting on a non-unique field alone will result in unpredictable
  # sorting order due to hashing
  $f2 = 'name' if !defined $f2 && $f1 !~ /^(name|id)$/;

  my $sort = sub { $a->{id} <=> $b->{id} };
  $sort = sub { $a->{$f1} <=> $b->{$f1} } if $f1;
  $sort = sub { $a->{$f1} cmp $b->{$f1} } if $f1 && $f1 =~ /^(name|title|label)$/;
  $sort = sub { $a->{$f1} <=> $b->{$f1} || $a->{$f2} <=> $b->{$f2} } if $f2;
  $sort = sub { $a->{$f1} <=> $b->{$f1} || $a->{$f2} cmp $b->{$f2} } if $f2 &&
           $f2 =~ /^(name|title|label)$/;

  my @nodes = values %{$self->{nodes}};

  # the 'return' here should not be removed
  return sort $sort @nodes;
  }

sub edge
  {
  # return an edge between two nodes as object
  my ($self, $x, $y) = @_;

  # turn objects into names (e.g. unique key)
  my $xn = $x; $xn = $x->{name} if ref $xn;
  my $yn = $y; $yn = $y->{name} if ref $yn;

  # turn plaintext scalars into objects 
  $x = $self->{nodes}->{$x} unless ref $x;
  $y = $self->{nodes}->{$y} unless ref $y;

  # node does not exist => edge does not exist
  return undef unless ref($x) && ref($y);

  my @ids = $x->edges_to($y);
  
  if (scalar @ids > 1)
    {
    # XXX TODO: make it return a list
    require Carp;
    Carp::croak ("There exist more than one edge from $x->{name} to $y->{name}");
    }
 
  $ids[0];				# first edge or undef for none
  }

sub node
  {
  # return node by name
  my $self = shift;
  my $name = shift || '';

  $self->{nodes}->{$name};
  }

#############################################################################
# attribute handling

sub border_attribute
  {
  # return "1px solid red" from the border-(style|color|width) attributes
  my ($self, $class) = @_;

  my $style = $self->attribute($class, 'border-style') || '';

  return $style if $style =~ /^(none|)\z/;

  my $width = $self->attribute($class, 'border-width') || '';
  my $color = $self->attribute($class, 'border-color') || '';

  $color = $self->color_name($color) unless $color eq '';

  $width = $width.'px' if $width =~ /^\s*\d+\s*\z/;
  $width = '' if $style eq 'double';

  my $val = join(" ", $width, $style, $color);
  $val =~ s/^\s+//;
  $val =~ s/\s+\z//;

  $val;
  }

sub get_attribute
  {
  # return the value of attribute $att from class $class
  my ($self, $class, $att) = @_;

  return $self->border_attribute($class) if $att eq 'border'; # virtual attribute

  return $self->{class} if $att eq 'class' && $class ne 'graph';

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

  # remove quotation marks
  $val =~ s/^["']//;
  $val =~ s/["']\z//;
  $val =~ s/\\#/#/;             # reverse backslashed \#

  # decode %XX entities
  $val =~ s/%([a-fA-F0-9][a-fA-F0-9])/sprintf("%c",hex($1))/eg;

  if ($self->{strict})
    {
    my $v = $self->valid_attribute($name,$val,$class);

    if (ref($v) eq 'ARRAY')
      {
      $self->error("Error: '$name' is not a valid attribute for $class");
      return;
      }
    if (!defined $v)
      {
      $self->error("Error in attribute: '$val' is not a valid $name for $class");
      return;
      }
    $val = $v;
    }

  $self->{score} = undef;	# invalidate layout to force a new layout

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

  if ($name eq 'border')
    {
    my $c = $self->{att}->{$class};

    ( $c->{'border-style'}, $c->{'border-width'}, $c->{'border-color'} ) = 
	Graph::Easy::Node->border_attributes( $val ); 

    return $val;
    }

  $self->{att}->{$class}->{$name} = $val;
  }

sub set_attributes
  {
  my ($self, $class, $att) = @_;

  # allowed classes and subclasses (except graph)
  if ($class !~ /^(node|group|edge|graph\z)/)
    {
    return $self->error ("Illegal class '$class' when setting attributes");
    }

  $self->{score} = undef;	# invalidate layout to force a new layout

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
    next if $a eq 'gid';
  
    if ($self->{strict})
      {
      my $v = $self->valid_attribute($a,$val,$class);

      if (!defined $v)
        {
        $self->error("Error in attribute: '$val' is not a valid $a for $class");
        return;
        }
      $val = $v;
      }

    $self->{att}->{$class}->{$a} = $val;
    } 
  $self;
  }

sub del_attribute ($$$)
  {
  my ($self, $class, $atr) = @_;

  delete $self->{att}->{$class}->{$atr};
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

sub _class_styles
  {
  # Create the style sheet with the class lists. This is used by both
  # css() and As_svg(). $skip is a qr// object that returns true for
  # attribute names to be skipped (e.g. excluded), and $map is a
  # HASH that contains mapping for attribute names for the output (only
  # used by As_svg()).
  # "$base" is the basename for classes (either "table.graph$id" if 
  # not defined, or whatever you pass in, like "" for svg).
  # $indent is a left-indenting spacer like "  ".
  # $overlay contains a HASH with attribute-value pairs to set as defaults.

  my ($self, $skip, $map, $base, $indent, $overlay) = @_;

  my $a = $self->{att};

  $indent = '' unless defined $indent;

#  my $a = $overlay;
#  $a = {} unless defined $a;

#  # Put all key/value pairs from att into overlay, overwriting possible
#  # existing default values 
#  foreach my $class (keys %$org_a)
#    {
#    my $ac = $a->{$class};
#    foreach my $k (keys %$org_a)
#      {
#      $ac->{$k} = $org_a->{$k};
#      }
#    }

  my $id = $self->{id};

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

  $base = "table.graph$id " unless defined $base;

  my $groups = $self->groups();				# do we have groups?

  my $css = '';
  foreach my $class (sort keys %$a)
    {
    next if keys %{$a->{$class}} == 0;			# skip empty ones

    my $c = $class; $c =~ s/\./-/g;			# node.city => node-city

    next if $class eq 'graph' and $base eq '';
    next if $class eq 'group' and $groups == 0;

    my $css_txt = '';
    my $cls = '';
    if ($class eq 'graph')
      {
      $css_txt .= "$indent$base\{\n";
      }
    else
      {
      if ($c !~ /\./)					# one of our primary ones
        {
        # generate also class list 			# like: "cities,node-rivers"
        $cls = join (",table.graph$id .$c-", sort keys %{ $class_list->{$c} });
        $cls = ", $base.$c-$cls" if $cls ne '';		# like: ",node-cities,node-rivers"
        }
      $css_txt .= "$indent$base.$c$cls {\n";
      }
    my $done = 0;
    foreach my $att (sort keys %{$a->{$class}})
      {
      # should be skipped?
      next if $att =~ /$skip/;

      $done++;						# how many did we really?
      my $val = $a->{$class}->{$att};
      # set for inner group cells "border: none"
      $val = 'none' if $att eq 'border' && $c eq 'group';
      $att = $map->{$att} if exists $map->{$att};	# change attribute name?
      $css_txt .= "$indent  $att: $val;\n";
      }
    $css_txt .= "$indent}\n";
    $css .= $css_txt if $done > 0;			# skip if no attributes at all
    }
  $css;
  }

sub _skip
  {
  # return the regexp that
  my ($self) = shift;

  # skip these for CSS
  qr/^(rows|column|size|offset|origin|label|linkbase|(auto)?(link|title)|nodeclass|shape|arrow-style|label-color|point-style|border-(color|style|width))\z/;
  }

sub css
  {
  my $self = shift;

  my $a = $self->{att};
  my $id = $self->{id};

  # for each primary class (node/group/edge) we need to find all subclasses,
  # and list them in the CSS, too. Otherwise "node-city" would not inherit
  # the attributes from "node".

  my $css = $self->_class_styles( $self->_skip(),
    {
    'fill' => 'background',
    } );

  my @groups = $self->groups();

  # Set attributes for all TDs that start with "group" (hyphen seperated,
  # so that group classes are something like "group-l-cities". The second rule
  # is for all TD without any class at all (these are the "filler" cells):
  $css .= <<CSS
table.graph##id## td[class|="group"] { padding: 0.2em; }
CSS
  if scalar @groups > 0;

  $css .= <<CSS
table.graph##id## td {
  padding: 2px;
  background: inherit;
  }
CSS
;

  # append va (vertical arrow (left/right), vertical empty
  $css .= <<CSS
table.graph##id## .va {
  vertical-align: bottom;
  line-height: 1.5em;
  width: 0.4em;
  }
table.graph##id## .ve {
  width: 0em;
  }
table.graph##id## .lh {
  font-size: 0.8em;
  padding-left: 0.2em;
  }
table.graph##id## .lv {
  font-size: 0.8em;
  padding-left: 0.5em;
  }
table.graph##id## .eb {
  height: 1em;
  line-height: 0.5em;
  }
table.graph##id## .el {
  width: 0.5em;
  }
table.graph##id## .v, table.graph##id## .hat, table.graph##id## .he {
  text-align: left;
  height: 0.5em;
  line-height: 0.6em;
  }
table.graph##id## .hat {
  padding-top: 0.5em;
  line-height: 0.2em;
  }
CSS
;

  # append CSS for group cells (only if we actually have groups)

  $css .= "table.graph$id { empty-cells: show; }\n";

  if (@groups > 0)
    {
    foreach my $group (@groups)
      {
      # could include only the ones we actually need
      my $border = $group->attribute('border-style') || 'none'; 
      my $class = $group->{class}; $class =~ s/.*\.//;	# leave only subclass
      for (my $i = 1; $i <= GROUP_MAX; $i++)
	{
        $css .= Graph::Easy::Group::Cell->_css($self->{id}, $i, $class, $border); 
	}
      }
    my $border = $self->attribute('group','border-style') || 'none'; 
    for (my $i = 1; $i <= GROUP_MAX; $i++)
      {
      $css .= Graph::Easy::Group::Cell->_css($self->{id}, $i, '', $border); 
      }
    }

  # replace the id with either '' or '123', depending on our ID
  $css =~ s/##id##/$id/g;

  $css;
  }

sub html_page_header
  {
  # return the HTML header for as_html_file()
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
  # return the HTML footer for as_html_file()
  my $self = shift;

  "\n</body></html>\n";
  }

sub as_html_file
  {
  my $self = shift;

  $self->layout() unless defined $self->{score};

  $self->html_page_header() . $self->as_html() . $self->html_page_footer();
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
 
  $html .= "\n<table class=\"graph$id\" cellpadding=0 cellspacing=0";
  $html .= " style=\"$self->{html_style}\"" if $self->{html_style};
  $html .= ">\n";

  my $caption = $self->attribute('graph','label');
  if (defined $caption && $caption ne '')
    {
    my $bg = $self->attribute('graph','background');
    $bg = '' if !defined $bg;
    $bg = " style='background: $bg'" if $bg ne '';
    $html .= "<caption$bg>$caption</caption>\n"
    }
 
  # now run through all rows, and for each of them through all columns 
  for my $y (sort { ($a||0) <=> ($b||0) } keys %$rows)
    {

    # four rows at a time
    my $rs = [ [], [], [], [] ];

    # for all possible columns
    for my $x (sort { $a <=> $b } keys %$cols)
      {
      if (!exists $rows->{$y}->{$x})
	{
	push @{$rs->[0]}, undef;
	next;
	}
      my $node = $rows->{$y}->{$x};

      my $h = $node->as_html();

      if (ref($h) eq 'ARRAY')
        {
        my $i = 0;
        # print STDERR '# expected 4 rows, but got ' . scalar @$h if @$h != 4;
        for my $hh (@$h)
          {
          push @{$rs->[$i++]}, $hh;
          }
        }
      else
        {
        push @{$rs->[0]}, $h;
#        push @{$rs->[1]}, undef;
#        push @{$rs->[2]}, undef;
#        push @{$rs->[3]}, undef;
        }
      }

    ######################################################################
    # remove trailing empty tag-pairs, then replace undef with empty tags

    for my $row (@$rs)
      {
      pop @$row while (@$row > 0 && !defined $row->[-1]);
      foreach (@$row)
        {
        $_ = " <td colspan=4 rowspan=4></td>\n" unless defined $_;
        }
      }

    # now combine equal columns to shorten output
    for my $row (@$rs)
      {
      # append row to output
      my $i = 0;
      while ($i < @$row)
        {
        # count all sucessive equal ones
        my $j = $i + 1;
        while ($j < @$row && $row->[$j] eq $row->[$i]) { $j++; }
        if ($j > $i + 1)
          {
          my $cnt = $j - $i - 1;
          # throw away
          splice (@$row, $i + 1, $cnt);
          # insert empty colspan if not already there
          $row->[$i] =~ s/<td/<td colspan=0/ unless $row->[$i] =~ /colspan/;
          # replace
          $row->[$i] =~ s/colspan=(\d+)/'colspan='.($1+$cnt*4)/e;
          }
        $i++;
        }
      }

    ######################################################################
    
    for my $row (@$rs)
      {
      # append row to output
      my $r = join('',@$row);
      # make empty rows to "<tr></tr>"
      $r =~ s/^( \n)+\z//;
      # non empty rows get "\n</tr>"
      $r = "\n" . $r if length($r) > 0;

      $html .= '<tr>' . $r . "</tr>\n\n";
      }
    }

  $html .= "</table>\n" . $self->{html_footer} . "\n";
 
  $html;
  } 

############################################################################# 
  
sub as_ascii
  {
  # convert the graph to pretty ASCII art
  my ($self) = shift;

  require Graph::Easy::As_ascii;

  $self->layout() unless defined $self->{score};

  # generate for each cell the width/height etc
  my ($rows,$cols,$max_x,$max_y,$cells) = $self->_prepare_layout('ascii');

  # generate the actual framebuffer for the output
  my $fb = Graph::Easy::Node->_framebuffer($max_x, $max_y);

  print STDERR "# Allocating framebuffer $max_x x $max_y\n" if $self->{debug};

  # draw all cells into framebuffer
  foreach my $v (@$cells)
    {
    next if ref($v) =~ /::Node::Cell/;		# skip empty cells

    # get as ASCII box
    my $x = $cols->{ $v->{x} };
    my $y = $rows->{ $v->{y} };
    my @lines = split /\n/, $v->as_ascii($x,$y);
    # get position from cell
    for my $i (0 .. scalar @lines-1)
      {
      next if length($lines[$i]) == 0;
      # XXX TODO: framebuffer shouldn't be to small!
      $fb->[$y+$i] = ' ' x $max_x if !defined $fb->[$y+$i];
      substr($fb->[$y+$i], $x, length($lines[$i])) = $lines[$i]; 
      }
    }

  for my $y (0..$max_y)
    {
    $fb->[$y] = '' unless defined $fb->[$y];
    $fb->[$y] =~ s/\s+\z//;		# remove trailing whitespace
    }
  my $out = join("\n", @$fb) . "\n";

  $out =~ s/\n+\z/\n/;		# remove trailing empty lines

  $out;				# return output
  }

sub as_ascii_html
  {
  # Convert the graph to pretty ASCII art, then return it as a HTML chunk
  # suitable to be embedded into an HTML page. Does not yet do colors.
  my ($self) = @_;

  "<pre>\n" . $self->as_ascii() . "\n<pre>\n";
  }

#############################################################################

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
  my @V;

  # the last column/row
  my $mx = -100000; my $my = -100000;

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

sub as_svg_file
  {
  require Graph::Easy::As_svg;

  _as_svg( $_[0], { standalone => 1 } );
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
  
  $edge = Graph::Easy::Edge->new() unless defined $edge;

  if (exists ($self->{edges}->{$edge->{id}}))
    {
    require Carp;
    Carp::confess("Adding an edge object twice is not possible");
    }
  my $nodes = $self->{nodes};

  my $xn = $x; my $yn = $y;
  $xn = $x->{name} if ref($x);
  $yn = $y->{name} if ref($y);

  # convert plain scalars to Node objects if nec.
  $x = $nodes->{$xn} if exists $nodes->{$xn};		# first look them up
  $y = $nodes->{$yn} if exists $nodes->{$yn};

  $x = Graph::Easy::Node->new( $x ) unless ref $x;	# if this fails, create
  $y = $x if !ref($y) && $y eq $xn;			# make add_edge('A','A') work
  $y = Graph::Easy::Node->new( $y ) unless ref $y;

  print STDERR "# add_edge '$x->{name}' ($x->{id}) -> '$y->{name}' ($y->{id}) (edge $edge->{id})\n" if $self->{debug};

  # register the nodes and the edge with our graph object
  $x->{graph} = $self;
  $y->{graph} = $self;
  $edge->{graph} = $self;
  # and weaken the references
  {
    no warnings; # dont warn on already weak references
    weaken($x->{graph});
    weaken($y->{graph});
    weaken($edge->{graph});
  }

  # Store at the edge from where to where it goes for easier reference
  $edge->{from} = $x;
  $edge->{to} = $y;
 
  # store the edge at the nodes, too
  $x->{edges}->{$edge->{id}} = $edge;
  $y->{edges}->{$edge->{id}} = $edge;

  # index nodes by their name so that we can find $x from $x->{name} fast
  $nodes->{$x->{name}} = $x;
  $nodes->{$y->{name}} = $y;

  # index edges by "id1,id2,edgeid" so we can find them fast
  $self->{edges}->{$edge->{id}} = $edge;

  $self->{score} = undef;			# invalidate last layout

  wantarray ? ($x,$y,$edge) : $edge;
  }

sub add_node
  {
  my ($self,$x) = @_;

  my $n = $x; $n = ($x->{name}||'') if ref($x);

  my $no = $self->{nodes};

  return $no->{$n} if exists $no->{$n};

  $x = Graph::Easy::Node->new( $x ) unless ref $x;

  # store the node
  $no->{$n} = $x;

  # register node with ourself and weaken the reference
  $x->{graph} = $self;
  {
    no warnings; # dont warn on already weak references
    weaken($x->{graph});
  }

  $self->{score} = undef;			# invalidate last layout

  $x;
  }

#############################################################################
# group management

sub add_group
  {
  # add a group object
  my ($self,$group) = @_;

  # index under the group name for easier lookup
  $self->{groups}->{ $group->{name} } = $group;

  # register group with ourself and weaken the reference
  $group->{graph} = $self;
  {
    no warnings; # dont warn on already weak references
    weaken($group->{graph});
  } 
  $self->{score} = undef;			# invalidate last layout

  $self;
  }

sub del_group
  {
  # delete group
  my ($self,$group) = @_;

  delete $self->{groups}->{ $group->{name} };
 
  $self->{score} = undef;			# invalidate last layout

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

1;
__END__
=head1 NAME

Graph::Easy - Render graphs as ASCII, HTML, SVG or Graphviz

=head1 SYNOPSIS

	use Graph::Easy;
	
	my $graph = Graph::Easy->new();

	$graph->add_edge ('Bonn', 'Berlin');

	print $graph->as_ascii( );

	# prints:

	# +------+     +--------+
	# | Bonn | --> | Berlin |
	# +------+     +--------+

	# slightly more verbose way:

	my $graph = Graph::Easy->new();

	my $bonn = Graph::Easy->add_node('Bonn');
	$bonn->set_attribute('border', 'solid 1px black')

	my $berlin = $graph->add_node('Berlin');

	$graph->add_edge ($bonn, $berlin);

	print $graph->as_ascii( );

	# adding edges with attributes:

        my $edge = Graph::Easy::Edge->new();
	$edge->set_attributes(
                label => 'train',
                style => 'dotted',
                color => 'red',
        );

	# now with the optional edge object
	$graph->add_edge ($bonn, $berlin, $edge);

	# raw HTML section
	print $graph->as_html( );

	# complete HTML page (with CSS)
	print $graph->as_html_file( );

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

	# SVG (possible after you installed Graph::Easy::As_svg):
	print $graph->as_svg( );

	# Graphviz:
	my $graphviz = $graph->as_graphviz();
	`dot -Tpng -o graph.png $graphviz`;

=head1 DESCRIPTION

C<Graph::Easy> lets you generate graphs consisting of various shaped
nodes connected by edges (with optional labels).

It works on a grid (manhattan layout), and thus the output is
most usefull for flow charts, network diagrams, or hierarchy trees.

=head2 Input

Apart from driving the module with Perl code, you can also use
C<Graph::Easy::Parser> to parse graph descriptions like:

	[ Bonn ]      --> [ Berlin ]
	[ Frankfurt ] <=> [ Dresden ]
	[ Bonn ]      --> [ Frankfurt ]

See L<EXAMPLES|EXAMPLES> for how this might be rendered.

=head2 Creating graphs

First, create a graph object:

	my $graph = Graph::Easy->new();

Then add a node to it:

	my $node = $graph->add_node('Koblenz');

Don't worry, adding the node again will do nothing:

	$node = $graph->add_node('Koblenz');

You can get back a node by its name with C<node()>:

	$node = $graph->node('Koblenz');

You can either add another node:

	my $second = $graph->node('Frankfurt');

Or add an edge straight-away:

	my ($first,$second,$edge) = $graph->add_edge('Mainz','Ulm');

Adding the edge the second time creates another edge from 'Mainz' to 'Ulm':

	my $other_edge;
	 ($first,$second,$other_edge) = $graph->add_edge('Mainz','Ulm');

You can even add a self-loop:

	$graph->add_edge('Bremen','Bremen');

=head2 Output

The output can be done in various styles:

=over 2

=item ASCII ART

Uses things like C<+>, C<-> C<< < >> and C<|> to render the boxes.

=item HTML

HTML tables with CSS making everything "pretty".

=item SVG

Creates a Scalable Vector Graphics output.

=item Graphviz

Creates graphviz code that can be feed to 'dot', 'neato' or similiar programs.

=back

=head1 EXAMPLES

The following examples are given in the simple text format that is understood
by L<Graph::Easy::Parser|Graph::Easy::Parser>.

You can also see many more examples at:

L<http://bloodgate.com/perl/graph/>

=head2 One node

The most simple graph (apart from the empty one :) is a graph consisting of
only one node:

	[ Dresden ]

=head2 Two nodes

A simple graph consisting of two nodes, linked together by a directed edge:

	[ Bonn ] -> [ Berlin ]

=head2 Three nodes

A graph consisting of three nodes, and both are linked from the first:

	[ Bonn ] -> [ Berlin ]
	[ Bonn ] -> [ Hamburg ]

=head2 Three nodes in a chain

A graph consisting of three nodes, showing that you can chain connections together:

	[ Bonn ] -> [ Berlin ] -> [ Hamburg ]

=head2 Two not connected graphs

A graph consisting of two seperate parts, both of them not connected
to each other:

	[ Bonn ] -> [ Berlin ]
	[ Freiburg ] -> [ Hamburg ]

=head2 Three nodes, interlinked

A graph consisting of three nodes, and two of the are connected from
the first node:

	[ Bonn ] -> [ Berlin ]
	[ Berlin ] -> [ Hamburg ]
	[ Bonn ] -> [ Hamburg ]

=head2 Different edge styles

A graph consisting of a couple of nodes, linked with the
different possible edge styles.

	[ Bonn ] <-> [ Berlin ]		# bidirectional
	[ Berlin ] ==> [ Rostock ]	# double
	[ Hamburg ] ..> [ Altona ]	# dotted
	[ Dresden ] - > [ Bautzen ]	# dashed
	[ Leipzig ] ~~> [ Kirchhain ]	# wave
	[ Hof ] .-> [ Chemnitz ]	# dot-dash
	[ Magdeburg ] <=> [ Ulm ]	# bidrectional, double etc
	[ Magdeburg ] -- [ Ulm ]	# arrow-less edge

More examples at: L<http://bloodgate.com/perl/graph/>

=head1 METHODS

C<Graph::Easy> supports the following methods:

=head2 new()

        use Graph::Easy;

        my $graph = Graph::Easy->new( );
        
Creates a new, empty C<Graph::Easy> object.

Takes optinal a hash reference with a list of options. The following are
valid options:

	debug			if true, enables debug output

=head2 error()

	my $error = $graph->error();

Returns the last error or '' for none.
Optionally, takes an error message to be set.

	$graph->error( 'Expected Foo, but found Bar.' );

=head2 add_edge()

	my ($first, $second, $edge) = $graph->add_edge( 'node 1', 'node 2');
	my $edge = $graph->add_edge( $x, $y, $edge);
	$graph->add_edge( $x, $y);

Add an edge between nodes X and Y. The optional edge object defines
the style of the edge, if not present, a default object will be used.

When called in scalar context, will return C<$edge>. In array/list context
it will return the two nodes and the edge object.

C<$x> and C<$y> should be either plain scalars with the names of
the nodes, or objects of L<Graph::Easy::Node|Graph::Easy::Node>,
while the optional C<$edge> should be L<Graph::Easy::Edge|Graph::Easy::Edge>.

Note: C<Graph::Easy> graphs are multi-edged, and adding the same edge
twice will result in two edges going from C<$x> to C<$y>!

You can use C<edge()> to check whether an edge from X to Y already exists
in the graph.
 
=head2 add_node()

	my $node = $graph->add_node( 'Node 1' );
	$graph->add_node( $x );

Add a single node X to the graph. C<$x> should be either a
C<Graph::Easy::Node> object, or a unique name for the node. Will do
nothing if the node already exists in the graph.

It returns an C<Graph::Easy::Node> object.

=head2 get_attribute()

	my $value = $graph->get_attribute( $class, $name );

Return the value of attribute C<$name> from class C<$class>.

Example:

	my $color = $graph->attribute( 'node', 'color' );

=head2 attribute()

	my $value = $graph->attribute( $class, $name );

C<attribute> is an alias for L<get_attribute>.

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

=head2 timeout()

	print $graph->timeout(), " seconds timeout for layouts.\n";
	$graph->timeout(12);

Get/set the timeut for layouts in seconds. If the layout process did not
finish after that time, it will be stopped and a warning will be printed.

=head2 strict()

	print "Graph has strict checking\n" if $graph->strict();
	$graph->strict(undef);		# disable strict attribute checks

Get/set the strict option. When set to a true value, all attribute names and
values will be strictly checked and unknown/invalid one will be rejected.

This option is on by default.

=head2 layout()

	$graph->layout();

Creates the internal structures to layout the graph. Usually you need
not to call this method, because it will be done automatically when you
call any of the C<as_FOO> methods below.

See also: C<timeout()>.

=head2 as_ascii()

	print $graph->as_ascii();

Return the graph layout in ASCII art.

=head2 as_ascii_html()

	print $graph->as_ascii_html();

Return the graph layout in ASCII art, suitable to be embedded into an HTML
page. Basically wraps the output from L<as_ascii()> into C<< <pre> </pre> >>.

=head2 as_html()

	print $graph->as_html();

Return the graph layout as HTML section. See L<css()> to get the
CSS section to go with that HTML code. If you want a complete HTML page
then use L<as_html_file()>.

=head2 as_html_file()

	print $graph->as_html_file();

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
is more a dump of the graph, than a certain layout.

=head2 nodes()

	my $nodes = $graph->nodes();

In scalar context, returns the number of nodes/vertices the graph has.
In list context returns a list of all the node objects (as reference).

=head2 sorted_nodes()

	my $nodes =
	 $graph->sorted_nodes( );		# default sort on 'id'
	my $nodes = 
	 $graph->sorted_nodes( 'name' );	# sort on 'name'
	my $nodes = 
	 $graph->sorted_nodes( 'layer', 'id' );	# sort on 'layer', then on 'id'

In scalar context, returns the number of nodes/vertices the graph has.
In list context returns a list of all the node objects (as reference),
sorted by their attribute(s) given as arguments. The default is 'id',
e.g. their internal ID number, which amounts more or less to the order
they have been inserted.

=head2 node()

	my $node = $graph->node('node name');

Return node by unique name (case sensitive). Returns undef if the node
does not exist in the graph.

=head2 edge()

	my $edge = $graph->edge( $x, $y );

Returns the edge object between nodes C<$x> and C<$y>. Both C<$x> and C<$y>
can be either scalars with names or C<Graph::Easy::Node> objects.

Returns undef if the edge does not yet exist.

If there exist more than one edge from C<$x> to C<$y>, then only the
first edge object will be returned.

=head2 id()

	my $graph_id = $graph->id();
	$graph->id('123');

Returns the id of the graph. You can also set a new ID with this routine. The
default is ''.

The graph's ID is used to generate unique CSS classes for each graph, in the
case you want to have more than one graph in an HTML page.

=head2 seed()

	my $seed = $graph->seed();
	$graph->seed(2);

Get/set the random seed for the graph object. See L<randomize()>
for a method to set a random seed.

The seed is used to create random numbers for the layouter. For
the same graph, the same seed will always lead to the same layout.

=head2 randomize()

	$graph->randomize();

Set a random seed for the graph object. See L<seed()>.

=head2 debug()

	my $debug = $graph->debug();	# get
	$graph->debug(1);		# enable
	$graph->debug(0);		# disable

Enable, disable or read out the debug status. When the debug status is true,
additional debug messages will be printed on STDERR.

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
	if ($seed ne $graph->seed())
	  {
	  $graph->seed($seed);
	  $graph->layout();
	  }
	# output graph:
	print $graph->as_ascii();		# or as_html() etc

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy::As_svg>, L<Graph::Layout::Aesthetic>, L<Graph> and L<Graph::Easy::Parser>.

There is also an very old, unrelated project from ca. 1995, which does something similiar.
See L<http://rw4.cs.uni-sb.de/users/sander/html/gsvcg1.html>.

Testcases and more examples under:

L<http://bloodgate.com/perl/graph/>.

=head1 LIMITATIONS

This module is a proof-of-concept and has currently some limitations.
Hopefully further development will lift these.

=head2 Scoring

Scoring is not yet implemented, each generated graph will be the same regardless
of the random seed.

=head2 Syntax

See L<http://bloodgate.com/perl/graph/> for limits of the syntax. Mostly this
are limitations in the parser, which cannot yet handle the following features:

=over 2

=item nesting (graph-in-a-graph)

=item node lists

Node lists only work on the left side of an expression. E.g. the first line
works, the second and third do not:

	[ Bonn ], [ Hof ] -> [ Berlin ]
	[ Frankfurt ] -> [ Hamburg ], [ Dresden ]
	[ Cottbus ], [ Kamenz ] -> [ Plauen ], [ Bamberg ]

=item scopes

=back

=head2 Paths

=over 2

=item Too bendy paths

The A* algorithm sometimes creates unnecessary bends in a path. A tweak which
will prevent would be decreasing the value of an already open node, but
this has not yet been implemented.

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

=item No optimizations

Non-optimal layouts like this one might appear from time to time:

	+------+     +--------+
	| Bonn | --> | Berlin |
	+------+     +--------+
	               ^
	               |
	               |
	+---------+    |
	| Kassel  | ---+
	+---------+

A second-stage optimizer that simplifies these layouts is not yet implemented.

In addition the general placement/processing strategy as well as the local
strategy might be improved.

=back

=head2 Output formats

Some output formats are not yet complete in their
implementation. Please see the online manual at
L<http://bloodgate.com/perl/graph/manual> under "Output" for
details.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms of the GPL version 2.
See the LICENSE file for information.

=head1 NAME CHANGE

The package was formerly known as C<Graph::Simple>. The name was changed
for two reasons:

=over 2

=item *

In graph theory, a C<simple> graph is a special type of graph. This software,
however, supports more than simple graphs.

=item *

Creating graphs should be easy even when the graphs are quite complex.

=back

=head1 AUTHOR

Copyright (C) 2004 - 2005 by Tels L<http://bloodgate.com>

=cut
