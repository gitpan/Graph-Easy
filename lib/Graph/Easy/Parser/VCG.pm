#############################################################################
# Parse VCG text into a Graph::Easy object
#
#############################################################################

package Graph::Easy::Parser::VCG;

$VERSION = '0.01';
use Graph::Easy::Parser::Graphviz;
@ISA = qw/Graph::Easy::Parser::Graphviz/;

use strict;
use utf8;
use constant NO_MULTIPLES => 1;

sub _init
  {
  my $self = shift;

  $self->SUPER::_init(@_);
  $self->{attr_sep} = '=';

  $self;
  }

my $vcg_color_by_name = {};

my $vcg_colors = [
  white 	=> 'white',
  blue  	=> 'blue',	
  red 		=> 'red',
  green		=> 'green',
  yellow	=> 'yellow',
  magenta	=> 'magenta',
  cyan		=> 'cyan',
  darkgrey	=> 'rgb(85,85,85)',
  darkblue	=> 'rgb(0,0,128)',
  darkred	=> 'rgb(128,0,0)',
  darkgreen	=> 'rgb(0,128,0)',
  darkyellow	=> 'rgb(128,128,0)',
  darkmagenta	=> 'rgb(128,0,128)',
  darkcyan	=> 'rgb(0,128,128)',
  gold		=> 'rgb(255,215,0)',
  lightgrey	=> 'rgb(170,170,170)',
  lightblue	=> 'rgb(128,128,255)',
  lightred 	=> 'rgb(255,128,128)',
  lightgreen    => 'rgb(128,255,128)',
  lightyellow   => 'rgb(255,255,128)',
  lightmagenta  => 'rgb(255,128,255)',
  lightcyan 	=> 'rgb(128,255,255)',
  lilac 	=> 'rgb(238,130,238)',
  turquoise 	=> 'rgb(64,224,208)',
  aquamarine 	=> 'rgb(127,255,212)',
  khaki 	=> 'rgb(240,230,140)',
  purple 	=> 'rgb(160,32,240)',
  yellowgreen 	=> 'rgb(154,205,50)',
  pink		=> 'rgb(255,192,203)',
  orange 	=> 'rgb(255,165,0)',
  orchid	=> 'rgb(218,112,214)',
  black 	=> 'black',
  ];

  {
  for (my $i = 0; $i < @$vcg_colors; $i+=2)
    {
    $vcg_color_by_name->{$vcg_colors->[$i]} = $vcg_colors->[$i+1];
    }
  }

sub reset
  {
  my $self = shift;

  Graph::Easy::Parser::reset($self, @_);

  my $g = $self->{_graph};
  $self->{scope_stack} = [];

  $g->{_vcg_color_map} = [];
  for (my $i = 0; $i < @$vcg_colors; $i+=2)
    {
    # set the first 32 colors as the default
    push @{$g->{_vcg_color_map}}, $vcg_colors->[$i+1];
    }

  # allow some temp. values during parsing
  $g->_allow_special_attributes(
    {
    edge => {
      source => [ "", undef, '', '', undef, ],
      target => [ "", undef, '', '', undef, ],
    },
    } );

  $g->{_warn_on_unknown_attributes} = 1;

  $self;
  }

sub _vcg_color_map_entry
  {
  my ($self, $index, $color) = @_;

  $color =~ /([0-9]+)\s+([0-9]+)\s+([0-9]+)/;
  $self->{_graph}->{_vcg_color_map}->[$index] = "rgb($1,$2,$3)";
  }

sub _unquote
  {
  my ($self, $name) = @_;

  $name = '' unless defined $name;

  # "foo bar" => foo bar
  $name =~ s/^"\s*//; 		# remove left-over quotes
  $name =~ s/\s*"\z//; 

  # unquote special chars
  $name =~ s/\\([\[\(\{\}\]\)#"])/$1/g;

  $name;
  }

#############################################################################

sub _match_comment
  {
  # match the start of a comment

  # // comment
  qr#(:[^\\]|)//#;
  }

sub _match_multi_line_comment
  {
  # match a multi line comment

  # /* * comment * */
  qr#(?:\s*/\*.*?\*/\s*)+#;
  }

sub _match_optional_multi_line_comment
  {
  # match a multi line comment

  # "/* * comment * */" or /* a */ /* b */ or ""
  qr#(?:(?:\s*/\*.*?\*/\s*)*|\s+)#;
  }

sub _match_node
  {
  # Return a regexp that matches something like '"bonn"' or 'bonn' or 'bonn:f1'
  my $self = shift;

  my $attr = $self->_match_attributes();

  # Examples: "node: { title: "a" }"
  qr/\s*node:\s*$attr/;
  }

sub _match_edge
  {
  # Matches an edge
  my $self = shift;

  my $attr = $self->_match_attributes();

  # Examples: "edge: { sourcename: "a" targetname: "b" }"
  #           "backedge: { sourcename: "a" targetname: "b" }"
  qr/\s*(|near|bentnear|back)edge:\s*$attr/;
  }

sub _match_single_attribute
  {

  qr/\s*(?:(\w+|colorentry\s+[0-9]{1,2}))\s*:\s*
    (
      "(?:\\"|[^"])*"				# "foo"
    |
      [0-9]{1,3}\s+[0-9]{1,3}\s+[0-9]{1,3}	# "128 128 64" for color entries
    |
      \{[^\}]+\}				# or {..}
    |
      [^<][^,\]\}\n\s;]*			# or simple 'fooobar'
    )
    \s*/x;					# possible trailing whitespace
  }

sub _match_class_attribute
  {
  # match something like "edge.color: 10"

  qr/\s*(edge|node)\.(\w+)\s*:\s*	# the attribute name (label:")
    (
      "(?:\\"|[^"])*"		# "foo"
    |
      [^<][^,\]\}\n\s]*		# or simple 'fooobar'
    )
    \s*/x;			# possible whitespace
  }

sub _match_attributes
  {
  # return a regexp that matches something like " { color=red; }" and returns
  # the inner text without the {}

  my $qr_att = _match_single_attribute();
  my $qr_cmt = _match_multi_line_comment();
 
  qr/\s*\{\s*((?:$qr_att|$qr_cmt)*)\s*\}/;
  }

sub _match_graph_attribute
  {
  # return a regexp that matches something like " color: red " for attributes
  # that apply to a graph/subgraph
  qr/^\s*(
    (
     colorentry\s+[0-9]{1,2}:\s+[0-9]+\s+[0-9]+\s+[0-9]+
     |
     (?!(node|edge|nearedge|bentnearedge|graph))	# not one of these
     \w+\s*:\s*("(?:\\"|[^"])*"|[^\n\s]+)
    )
   )([\n\s]\s*|\z)/x;
  }

sub _clean_attributes
  {
  my ($self,$text) = @_;

  $text =~ s/^\s*\{\s*//;		# remove left-over "{" and spaces
  $text =~ s/\s*;?\s*\}\s*\z//;		# remove left-over "}" and spaces

  $text;
  }

sub _match_group_end
  {
  # return a regexp that matches something like " }"
  qr/\s*\}\s*\s*/;
  }

#############################################################################

sub _new_scope
  {
  # create a new scope, with attributes from current scope
  my ($self, $is_group) = @_;

  my $scope = {};

  if (@{$self->{scope_stack}} > 0)
    {
    my $old_scope = $self->{scope_stack}->[-1];

    # make a copy of the old scope's attribtues
    for my $t (keys %$old_scope)
      {
      next if $t =~ /^_/;
      my $s = $old_scope->{$t};
      $scope->{$t} = {} unless ref $scope->{$t}; my $sc = $scope->{$t};
      for my $k (keys %$s)
        {
        # skip things like "_is_group"
        $sc->{$k} = $s->{$k} unless $k =~ /^_/;
        }
      }
    }
  $scope->{_is_group} = 1 if defined $is_group;

  push @{$self->{scope_stack}}, $scope;

  $scope;
  }

sub _edge_style
  {
  # To convert "--" or "->" we simple do nothing, since the edge style in
  # VCG can only be set via the attributes (if at all)
  my ($self, $ed) = @_;

  'solid';
  }

sub _build_match_stack
  {
  my $self = shift;

  my $qr_node  = $self->_match_node();
  my $qr_cmt   = $self->_match_multi_line_comment();
  my $qr_ocmt  = $self->_match_optional_multi_line_comment();
  my $qr_attr  = $self->_match_attributes();
  my $qr_gatr  = $self->_match_graph_attribute();
  my $qr_oatr  = $self->_match_optional_attributes();
  my $qr_edge  = $self->_match_edge();
  my $qr_class = $self->_match_class_attribute();
  my $qr_grend = $self->_match_group_end();

  # remove multi line comments /* comment */
  $self->_register_handler( qr/^$qr_cmt/, undef );
  
  # remove single line comment // comment
  $self->_register_handler( qr/^\s*\/\/.*/, undef );
  
  # simple remove the graph start, but remember that we did this
  $self->_register_handler( qr/^\s*graph:\s*\{/i, 
    sub 
      {
      my $self = shift;
      $self->{_vcg_graph_name} = 'unnamed'; 
      $self->_new_scope(1);
      1;
      } );

#  # end-of-statement
#  $self->_register_handler( qr/^\s*;/, undef );

  # subgraph "graph: { .. }"
  # subgraph end: "}"
#  $self->_add_group_match();

  # edge.color: 10
  $self->_register_handler( $qr_class,
    sub {
      my $self = shift;
      my $type = $1;
      my $name = $2;
      my $val = $3;

      my $att = $self->{_graph}->_remap_attributes($type, { $name => $val }, $self->_remap(), 'noquote', undef, undef);

      $self->{_graph}->set_attributes ($type, $att);
      1;
      });

  # node: { ... }
  # The "(?i)" makes the keywords match case-insensitive. 
  $self->_register_handler( qr/^\s*node:$qr_ocmt$qr_attr/,
    sub {
      my $self = shift;
      my $att = $self->_parse_attributes($1 || '', 'node', NO_MULTIPLES );
      return undef unless defined $att;		# error in attributes?

      my $name = $att->{title}; delete $att->{title};

#      print STDERR "Found node with name $name\n";

      my $node = $self->_new_node($self->{_graph}, $name, [], $att, []);
      $node->set_attributes ($att);
      1;
      } );

  # edge: { ... }
  # The "(?i)" makes the keywords match case-insensitive. 
  $self->_register_handler( qr/^\s*$qr_edge/,
    sub {
      my $self = shift;
      my $type = $1 || 'edge';
      my $txt = $2 || '';
      $type = "edge" if $type =~ /edge/;	# bentnearedge => edge
      my $att = $self->_parse_attributes($txt, 'edge', NO_MULTIPLES );
      return undef unless defined $att;		# error in attributes?

      my $from = $att->{source}; delete $att->{source};
      my $to = $att->{target}; delete $att->{target};

 #     print STDERR "Found edge ($type) from $from to $to\n";

      my $edge = $self->{_graph}->add_edge ($from, $to);
      $edge->set_attributes ($att);
      1;
      } );

  # "}" # graph end
  $self->_register_handler( qr/^$qr_grend/,
    sub
      {
      my $self = shift;

      my $scope = pop @{$self->{scope_stack}};
      return $self->parse_error(0) if !defined $scope;

      1;
      } );

  # color: red (for graphs or subgraphs)
  $self->_register_attribute_handler($qr_gatr, 'parent');

  $self;
  }

sub _new_node
  {
  # add a node to the graph, overridable by subclasses
  my ($self, $graph, $name, $group_stack, $att, $stack) = @_;

  # "a -- clusterB" should not create a spurious node named "clusterB"
#  my @groups = $graph->groups();
#  for my $g (@groups)
#    {
#    return $g if $g->{name} eq $name;
#    }

#  print STDERR "add_node $name\n";

  my $node = $graph->node($name);
 
  if (!defined $node)
    {
    $node = $graph->add_node($name);		# add

    # apply attributes from the current scope (only for new nodes)
    my $scope = $self->{scope_stack}->[-1];
    return $self->error("Scope stack is empty!") unless defined $scope;
  
    my $is_group = $scope->{_is_group};
    delete $scope->{_is_group};
    $node->set_attributes($scope->{node});
    $scope->{_is_group} = $is_group if $is_group;
    }

  $node;
  }

#############################################################################
# attribute remapping

# undef => drop that attribute
# not listed attributes are simple copied unmodified

my $vcg_remap = {
  'node' => {
    textcolor => \&_node_color_from_vcg,
    color => \&_node_color_from_vcg,
    bordercolor => \&_node_color_from_vcg,
    level => 'rank',
    'horizontal_order' => undef,
    shape => \&_vcg_node_shape,
    'vertical_order' => undef,
    },

  'edge' => {
    sourcename => 'source',
    targetname => 'target',
    source => 'source',
    target => 'target',
    textcolor => \&_edge_color_from_vcg,
    color => \&_edge_color_from_vcg,
    linestyle => 'style',
    anchor => undef,
    priority => undef,
    thickness => undef, 		# remap to broad etc.
    arrowcolor => undef,
    backarrowcolor => undef,
    horizontal_order => undef,
    arrowsize => undef,
    class => undef,
    },

  'graph' => {
    x => undef,
    y => undef,
    xmax => undef,
    ymax => undef,
    xspace => undef,
    yspace => undef,
    xlspace => undef,
    ylspace => undef,
    splines => undef,
    layoutalgorithm => undef,
    smanhattan_edges => undef,
    manhattan_edges => undef,
    layout_downfactor => undef,
    layout_upfactor => undef,
    layout_nearfactor => undef,
    title => 'label',
    },

  'group' => {
    },

  'all' => {
    loc => undef,
    folding => undef,
    scaling => undef,
    shrink => undef,
    stretch => undef,
    width => undef,
    height => undef,
    },
  };

sub _remap { $vcg_remap; }

my $vcg_edge_color_remap = {
  textcolor => 'labelcolor',
  };

my $vcg_node_color_remap = {
  textcolor => 'color',
  color => 'fill',
  };

sub _edge_color_from_vcg
  {
  # remap "darkyellow" to "rgb(128 128 0)"
  my ($graph, $name, $color) = @_;

#  print STDERR "edge $name $color\n";
#  print STDERR ($vcg_edge_color_remap->{$name} || $name, " ", $vcg_color_by_name->{$color} || $color), "\n";

  my $c = $vcg_color_by_name->{$color} || $color;
  $c = $graph->{_vcg_color_map}->[$c] if $c =~ /^[0-9]+\z/ && $c < 256;

  ($vcg_edge_color_remap->{$name} || $name, $c);
  }

sub _node_color_from_vcg
  {
  # remap "darkyellow" to "rgb(128 128 0)"
  my ($graph, $name, $color) = @_;

#  print STDERR "node $name $color\n";
#  print STDERR ($vcg_node_color_remap->{$name} || $name, " ", $vcg_color_by_name->{$color} || $color), "\n";

  my $c = $vcg_color_by_name->{$color} || $color;
  $c = $graph->{_vcg_color_map}->[$c] if $c =~ /^[0-9]+\z/ && $c < 256;

  ($vcg_node_color_remap->{$name} || $name, $c);
  }

my $shapes = {
  box => 'rect',
  rhomb => 'diamond',
  triangle => 'triangle',
  ellipse => 'ellipse',
  };

sub _vcg_node_shape
  {
  my ($self, $name, $shape) = @_;

  my @rc;
  my $s = lc($shape);

  # map the name to what Graph::Easy expects (ellipse stays as ellipse but
  # everything unknown gets converted to rect)
  $s = $shapes->{$s} || 'rect';

  (@rc, $name, $s);
  }

#############################################################################

sub _remap_attributes
  {
  my ($self, $att, $object, $r) = @_;

  # handle the "colorentry 00" entries:
  for my $key (keys %$att)
    {
    if ($key =~ /^colorentry ([0-9]+)/)
      {
      # put the color into the current color map
      $self->_vcg_color_map_entry($1, $att->{$key});
      delete $att->{$key}; 
      }
    }
  $self->SUPER::_remap_attributes($att,$object,$r);
  }

#############################################################################

sub _parser_cleanup
  {
  # After initial parsing, do cleanup.
  my ($self) = @_;

  my $g = $self->{_graph};
  $g->{_warn_on_unknown_attributes} = 0;	# reset to die again

  delete $g->{_vcg_color_map};

  $self;
  }

1;
__END__

=head1 NAME

Graph::Easy::Parser::VCG - Parse VCG or GDL text into Graph::Easy

=head1 SYNOPSIS

        # creating a graph from a textual description

        use Graph::Easy::Parser::VCG;
        my $parser = Graph::Easy::Parser::VCG->new();

        my $graph = $parser->from_text(
                "graph: { \n" .
	 	"	node: { title: "Bonn" }\n" .
	 	"	node: { title: "Berlin" }\n" .
	 	"	edge: { sourcename: "Bonn" targetname: "Berlin" }\n" .
		"}\n"
        );
        print $graph->as_ascii();

	print $parser->from_file('mygraph.vcg')->as_ascii();

=head1 DESCRIPTION

C<Graph::Easy::Parser::VCG> parses the text format from the VCG or GDL
(Graph Description Language) use by tools like GCC and AiSee, and
constructs a C<Graph::Easy> object from it.

The resulting object can than be used to layout and output the graph
in various formats.

=head2 Output

The output will be a L<Graph::Easy|Graph::Easy> object (unless overrriden
with C<use_class()>), see the documentation for Graph::Easy what you can do
with it.

=head1 METHODS

C<Graph::Easy::Parser::VCG> supports the same methods
as its parent class C<Graph::Easy::Parser>:

=head2 new()

	use Graph::Easy::Parser::VCG;
	my $parser = Graph::Easy::Parser::VCG->new();

Creates a new parser object. There are two valid parameters:

	debug
	fatal_errors

Both take either a false or a true value.

	my $parser = Graph::Easy::Parser::VCG->new( debug => 1 );
	$parser->from_text('graph: { }');

=head2 reset()

	$parser->reset();

Reset the status of the parser, clear errors etc. Automatically called
when you call any of the C<from_XXX()> methods below.

=head2 use_class()

	$parser->use_class('node', 'Graph::Easy::MyNode');

Override the class to be used to constructs objects while parsing.

See L<Graph::Easy::Parser> for further information.

=head2 from_text()

	my $graph = $parser->from_text( $text );

Create a L<Graph::Easy|Graph::Easy> object from the textual description in C<$text>.

Returns undef for error, you can find out what the error was
with L<error()>.

This method will reset any previous error, and thus the C<$parser> object
can be re-used to parse different texts by just calling C<from_text()>
multiple times.

=head2 from_file()

	my $graph = $parser->from_file( $filename );
	my $graph = Graph::Easy::Parser::VCG->from_file( $filename );

Creates a L<Graph::Easy|Graph::Easy> object from the textual description in the file
C<$filename>.

The second calling style will create a temporary parser object,
parse the file and return the resulting C<Graph::Easy> object.

Returns undef for error, you can find out what the error was
with L<error()> when using the first calling style.

=head2 error()

	my $error = $parser->error();

Returns the last error, or the empty string if no error occured.

=head2 parse_error()

	$parser->parse_error( $msg_nr, @params);

Sets an error message from a message number and replaces embedded
templates like C<##param1##> with the passed parameters.

=head1 CAVEATS

The parser has problems with the following things:

=over 12

=item attributes

Some attributes are B<not> remapped properly to what Graph::Easy expects, thus
losing information, either because Graph::Easy doesn't support this feature
yet, or because the mapping is incomplete.

=item comments

Comments written in the source code itself are discarded. If you want to have
comments on the graph, clusters, nodes or edges, use the attribute C<comment>.
These are correctly read in and stored, and then output into the different
formats, too.

=back

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>, L<Graph::Write::VCG>.

=head1 AUTHOR

Copyright (C) 2005 - 2007 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
