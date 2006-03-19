#############################################################################
# Parse graphviz/dot text into a Graph::Easy object
#
# (c) by Tels 2005-2006.
#############################################################################

package Graph::Easy::Parser::Graphviz;

$VERSION = '0.02';
use base qw/Graph::Easy::Parser/;

use strict;

use constant NO_MULTIPLES => 1;

sub _init
  {
  my $self = shift;

  $self->SUPER::_init(@_);

  $self->{group_start} = '';
  $self->{attr_sep} = '=';

  $self;
  }

sub _unquote
  {
  my ($self, $name) = @_;

  $name = '' unless defined $name;

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
  qr/(^|[^\\])\/\//;
  }

sub _match_node
  {
  # Return a regexp that matches something like '"bonn"' or 'bonn' and returns
  # the inner text without (might leave some spaces and quotes)

  qr/\s*("[^"]*"|[a-zA-Z0-9]+[0-9]+)/;
  }

sub _match_group_start
  {
  qr/^\s*(?:digraph|graph)\s+([\w_]+)\s+\{/;
  }

sub _match_group_end
  {
  # return a regexp that matches something like " }".
  qr/\s*\}\s*/;
  }

sub _match_edge
  {
  # Matches an edge
  qr/\s*(->|--)/;
  }

sub _match_single_attribute
  {
  qr/^\s*(\w+)\s*=\s*([^,]+)\s*/;
  }

sub _match_attributes
  {
  # return a regexp that matches something like " [ color=red; ]" and returns
  # the inner text without the []
  qr/\s*\[\s*([^\]]+?)\s*\]/;
  }

sub _match_optional_attributes
  {
  # return a regexp that matches something like " [ color=red; ]" and returns
  # the inner text with the []
  qr/(\s*\[[^\]]+?\])?/;
  }

sub _clean_attributes
  {
  my ($self,$text) = @_;

  $text =~ s/^\s*\[\s*//;	# remove left-over "[" and spaces
  $text =~ s/\s*\]\s*\z//;	# remove left-over "]" and spaces

  $text;
  }

sub _build_match_stack
  {
  my $self = shift;

  my $qr_node  = $self->_match_node();
  my $qr_attr  = $self->_match_attributes();
  my $qr_oatr  = $self->_match_optional_attributes();
  my $qr_edge  = $self->_match_edge();
  my $qr_comma = $self->_match_comma();

  # simple remove these
  $self->_register_handler( qr/^\s*(digraph|graph)\s+$qr_node\s+\{/, undef );
  $self->_register_handler( qr/^\s*\}/, undef );

  # node [ color="red" ] etc 
  $self->_register_handler( qr/^(node|graph|edge)$qr_attr/,
    sub
      {
      my $self = shift;
      my $type = $1 || '';
      my $att = $self->_parse_attributes($2 || '', $type, NO_MULTIPLES );

      return undef unless defined $att;		# error in attributes?

      my $graph = $self->{graph};
      $graph->set_attributes ($type, $att);

      # forget stacks
      $self->{stack} = [];
      $self->{left_edge} = undef;
      $self->{left_stack} = [];
      } );

  $self->_register_attribute_handler($qr_attr);
  $self->_register_node_attribute_handler($qr_node,$qr_oatr);

  # Things like ' "Node" ' will be consumed before, so we do not need a case
  # for '"Bonn" -> "Berlin"'

  # node chain continued like "-> "Kassel" [ ... ]"
  $self->_register_handler( qr/^$qr_edge$qr_node$qr_oatr/,
    sub
      {
      my $self = shift;

      return if @{$self->{stack}} == 0;	# only match this if stack non-empty

      my $graph = $self->{graph};
      my $eg = $1;					# entire edge ("->" etc)
      my $n = $2;					# node name

      my $edge_un = 0; $edge_un = 1 if $eg eq '--';	# undirected edge?

      my $edge_atr = $self->_parse_attributes($3||'', 'edge');
      return undef if $self->{error};

      # the right side node(s) (multiple in case of autosplit)
      my $nodes_b = [ $self->_new_node ($self->{graph}, $n, $self->{group_stack}) ];

      my $style = $self->_link_lists( $self->{stack}, $nodes_b,
	'--', '', $edge_atr, 0, $edge_un);

      # remember the left side
      $self->{left_edge} = [ $style, '', $edge_atr, 0, $edge_un ];
      $self->{left_stack} = $self->{stack};

      # forget stack and remember the right side instead
      $self->{stack} = $nodes_b;

      } );

  $self;
  }

# undef => drop that attribute

my $remap = {
  'node' => {
    'color' => 'border-color',
    'distortion' => undef,
    'fixedsize' => undef,
    'group' => undef,
    'height' => undef,
    'layer' => undef,
    'margin' => undef,
#    'orientation' => \&_graphviz_remap_node_orientation,
#    'peripheries' => \&_graphviz_remap_node_peripheries,
    'pin' => undef,
    'pos' => undef,
    'rects' => undef,
    'regular' => undef,
    'root' => undef,
    'sides' => undef,
    'shapefile' => undef,
#    'shape' => \&_graphviz_remap_node_shape,
    'width' => undef,
    },

  'edge' => {
    'arrow-size' => undef,
#     'arrow-head' => \&_graphviz_remap_arrow_style,
    'arrow-tail' => undef,
     # important for color lists like "red:red" => double edge
#     'color' => \&_graphviz_remap_edge_color,
#     'dir' => \&_graphviz_remap_edge_dir,
    'decorate' => undef,
    'constraint' => undef,
    'headclip' => undef,
    'headhref' => undef,
    'headurl' => undef,
    'headport' => undef,
    'headlabel' => undef,
    'headport' => undef,
    'headtarget' => undef,
    'headtooltip' => undef,
    'href' => 'link',
    'labelangle' => undef,
    'labeldistance' => undef,
    'labelfloat' => undef,
    'labelfontcolor' => 'label-color',
    'labelfontname' => 'font',
    'labelfontsize' => 'fontsize',
    'layer' => undef,
    'len' => undef,
    'lhead' => undef,
    'ltail' => undef,
#    'minlen' => \&_graphviz_remap_edge_minlen,
    'pos' => undef,
    'samehead' => undef,
    'sametail' => undef,
#    'style' => \&_graphviz_remap_edge_style,

    'tailclip' => undef,
    'tailhref' => undef,
    'tailurl' => undef,
    'tailport' => undef,
    'taillabel' => undef,
    'tailport' => undef,
    'tailtarget' => undef,
    'tailtooltip' => undef,
    'weight' => undef,
    },

  'graph' => {
    'damping' => undef,
    'K' => undef,
    'bb' => undef,
    'center' => undef,
    'charset' => undef,
    'clusterrank' => undef,
    'compound' => undef,
    'concentrate' => undef,
    'defaultdist' => undef,
    'dim' => undef,
    'dpi' => undef,
    'epsilon' => undef,
    'esep' => undef,
    'fontpath' => undef,
#    'labeljust' => \&_graphviz_remap_graph_labeljust,
#    'labelloc' => \&_graphviz_remap_graph_labelloc,
    'landscape' => undef,
    'layers' => undef,
    'layersep' => undef,
    'levelsgap' => undef,
    'margin' => undef,
    'mclimit' => undef,
    'mindist' => undef,
    'mode' => undef,
    'model' => undef,
    'nodesep' => undef,
    'normalize' => undef,
    'nslimit' => undef,
    'nslimit1' => undef,
    'ordering' => undef,
    'orientation' => undef,
    'outputorder' => undef,
    'overlap' => undef,
    'pack' => undef,
    'packmode' => undef,
    'page' => undef,
    'pencolor' => 'border-color',
    'quantum' => undef,
    'rankdir' => undef,
    'ranksep' => undef,
    'remincross' => undef,
    'resolution' => undef,
    'root' => undef,
    'rotate' => undef,
    'sampepoints' => undef,
    'searchsize' => undef,
    'sep' => undef,
    'sep' => undef,
    'size' => undef,
    'splines' => undef,
    'start' => undef,
    'stylesheet' => undef,
    'viewport' => undef,
    'voro-margin' => undef,
    'truecolor' => undef,
    },

  'group' => {
#    'labeljust' => \&_graphviz_remap_graph_labeljust,
#    'labelloc' => \&_graphviz_remap_graph_labelloc,
    'pencolor' => 'border-color',
    'K' => undef,
    },

  'all' => {
    'colorscheme' => undef,
    'comment' => undef,
    'bgcolor' => 'background',
    'fillcolor' => 'fill',
    'fontsize' => 'font-size',
    'fontcolor' => 'color',
    'fontname' => 'font',
    'label' => \&_graphviz_remap_label,
    'lp' => undef,
    'nojustify' => undef,
    'url' => 'link',
    'showboxes' => undef,
    'target' => undef,
    'tooltip' => 'title',
    },
  };

sub _remap_attributes
  {
  my ($self, $att, $class) = @_;

  # unquote attributes (especially colors)
  for my $val (values %$att)
    {
    $val =~ s/^"//;
    $val =~ s/"\z//;
    }

  $self->{graph}->_remap_attributes($class, $att, $remap, 'noquote', undef, undef);
  }

1;
__END__

=head1 NAME

Graph::Easy::Parser::Graphviz - Parse graphviz text into Graph::Easy

=head1 SYNOPSIS

        # creating a graph from a textual description

        use Graph::Easy::Parser::Graphviz;
        my $parser = Graph::Easy::Parser::Graphviz->new();

        my $graph = $parser->from_text(
                "digraph Graph {\" .
                ' Bonn -> "Berlin"' . "\n}\n" );
        );
        print $graph->as_ascii();
        
	print $parser->from_file('mygraph.dot')->as_ascii();

=head1 DESCRIPTION

C<Graph::Easy::Parser::Graphviz> parses the text format from graphviz and
constructs a C<Graph::Easy> object from it.

The resulting object can than be used to layout and output the graph.

Please see the Grapviz manual for a full description of the syntax rules.

=head2 Output

The output will be a L<Graph::Easy|Graph::Easy> object (unless overrriden
with C<use_class()>), see the documentation for Graph::Easy what you can do
with it.

=head1 METHODS

C<Graph::Easy::Parser::Graphviz> supports the same methods
that its parent class C<Graph::Easy::Parser>:

=head2 new()

	use Graph::Easy::Parser::Graphviz;
	my $parser = Graph::Easy::Parser::Graphviz->new();

Creates a new parser object. The only valid parameter is debug,
when set to true it will enable debug output to STDERR:

	my $parser = Graph::Easy::Parser::Graphviz->new( debug => 1 );
	$parser->from_text('digraph G { A -> B }');

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
	my $graph = Graph::Easy::Parser->from_file( $filename );

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

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>.

=head1 AUTHOR

Copyright (C) 2005 - 2006 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
