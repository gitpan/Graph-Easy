#############################################################################
# Parse graphviz/dot text into a Graph::Easy object
#
# (c) by Tels 2005-2006.
#############################################################################

package Graph::Easy::Parser::Graphviz;

$VERSION = '0.08';
use base qw/Graph::Easy::Parser/;

use strict;
use utf8;
use constant NO_MULTIPLES => 1;

sub _init
  {
  my $self = shift;

  $self->SUPER::_init(@_);
  $self->{attr_sep} = '=';
  # remove " <p1> " from autosplit (shape=record) labels
  $self->{_qr_part_clean} = qr/\s*<([^>]*)>/;

  $self;
  }

sub reset
  {
  my $self = shift;

  $self->SUPER::reset(@_);

  # set some default attributes on the graph object, because graphviz has
  # different defaults as Graph::Easy
  my $g = $self->{graph};

  $g->set_attribute('colorscheme','x11');
  $g->set_attribute('flow','south');
  $g->set_attribute('edge','arrow-style', 'filled');

  $self->{scope_stack} = [];

  # allow some temp. values during parsing
  $g->_allow_special_attributes(
    {
    node => {
      shape => [
       "",
        [ qw/ circle diamond edge ellipse hexagon house invisible
		invhouse invtrapezium invtriangle octagon parallelogram pentagon
		point triangle trapezium septagon rect rounded none img record/ ],
       '',
       '',
       undef,
      ],
    },
    } );

  $g->{_warn_on_unknown_attributes} = 1;

  $self;
  }

# map "&tilde;" to "~" 
my %entities = (
  'amp'    => '&',
  'quot'   => '"',
  'lt'     => '<',
  'gt'     => '>',
  'nbsp'   => ' ',		# this is a non-break-space between '' here!
  'iexcl'  => '¡',
  'cent'   => '¢',
  'pound'  => '£',
  'curren' => '¤',
  'yen'    => '¥',
  'brvbar' => '¦',
  'sect'   => '§',
  'uml'    => '¨',
  'copy'   => '©',
  'ordf'   => 'ª',
  'ordf'   => 'ª',
  'laquo'  => '«',
  'not'    => '¬',
  'shy'    => "\x{00AD}",		# soft-hyphen
  'reg'    => '®',
  'macr'   => '¯',
  'deg'    => '°',
  'plusmn' => '±',
  'sup2'   => '²',
  'sup3'   => '³',
  'acute'  => '´',
  'micro'  => 'µ',
  'para'   => '¶',
  'midot'  => '·',
  'cedil'  => '¸',
  'sup1'   => '¹',
  'ordm'   => 'º',
  'raquo'  => '»',
  'frac14' => '¼',
  'frac12' => '½',
  'frac34' => '¾',
  'iquest' => '¿',
  'Agrave' => 'À',
  'Aacute' => 'Á',
  'Acirc'  => 'Â',
  'Atilde' => 'Ã',
  'Auml'   => 'Ä',
  'Aring'  => 'Å',
  'Aelig'  => 'Æ',
  'Ccedil' => 'Ç',
  'Egrave' => 'È',
  'Eacute' => 'É',
  'Ecirc'  => 'Ê',
  'Euml'   => 'Ë',
  'Igrave' => 'Ì',
  'Iacute' => 'Í',
  'Icirc'  => 'Î',
  'Iuml'   => 'Ï',
  'ETH'    => 'Ð',
  'Ntilde' => 'Ñ',
  'Ograve' => 'Ò',
  'Oacute' => 'Ó',
  'Ocirc'  => 'Ô',
  'Otilde' => 'Õ',
  'Ouml'   => 'Ö',
  'times'  => '×',
  'Oslash' => 'Ø',
  'Ugrave' => 'Ù',
  'Uacute' => 'Ù',
  'Ucirc'  => 'Û',
  'Uuml'   => 'Ü',
  'Yacute' => 'Ý',
  'THORN'  => 'Þ',
  'szlig'  => 'ß',
  'agrave' => 'à',
  'aacute' => 'á',
  'acirc'  => 'â',
  'atilde' => 'ã',
  'auml'   => 'ä',
  'aring'  => 'å',
  'aelig'  => 'æ',
  'ccedil' => 'ç',
  'egrave' => 'è',
  'eacute' => 'é',
  'ecirc'  => 'ê',
  'euml'   => 'ë',
  'igrave' => 'ì',
  'iacute' => 'í',
  'icirc'  => 'î',
  'iuml'   => 'ï',
  'eth'    => 'ð',
  'ntilde' => 'ñ',
  'ograve' => 'ò',
  'oacute' => 'ó',
  'ocirc'  => 'ô',
  'otilde' => 'õ',
  'ouml'   => 'ö',
  'divide' => '÷',
  'oslash' => 'ø',
  'ugrave' => 'ù',
  'uacute' => 'ú',
  'ucirc'  => 'û',
  'uuml'   => 'ü',
  'yacute' => 'ý',
  'thorn'  => 'þ',
  'yuml'   => 'ÿ',
  'Oelig'  => 'Œ',
  'oelig'  => 'œ',
  'Scaron' => 'Š',
  'scaron' => 'š',
  'Yuml'   => 'Ÿ',
  'fnof'   => 'ƒ',
  'circ'   => '^',
  'tilde'  => '~',
  'Alpha'  => 'Α',
  'Beta'   => 'Β',
  'Gamma'  => 'Γ',
  'Delta'  => 'Δ',
  'Epsilon'=> 'Ε',
  'Zeta'   => 'Ζ',
  'Eta'    => 'Η',
  'Theta'  => 'Θ',
  'Iota'   => 'Ι',
  'Kappa'  => 'Κ',
  'Lambda' => 'Λ',
  'Mu'     => 'Μ',
  'Nu'     => 'Ν',
  'Xi'     => 'Ξ',
  'Omicron'=> 'Ο',
  'Pi'     => 'Π',
  'Rho'    => 'Ρ',
  'Sigma'  => 'Σ',
  'Tau'    => 'Τ',
  'Upsilon'=> 'Υ',
  'Phi'    => 'Φ',
  'Chi'    => 'Χ',
  'Psi'    => 'Ψ',
  'Omega'  => 'Ω',
  'alpha'  => 'α',
  'beta'   => 'β',
  'gamma'  => 'γ',
  'delta'  => 'δ',
  'epsilon'=> 'ε',
  'zeta'   => 'ζ',
  'eta'    => 'η',
  'theta'  => 'θ',
  'iota'   => 'ι',
  'kappa'  => 'κ',
  'lambda' => 'λ',
  'mu'     => 'μ',
  'nu'     => 'ν',
  'xi'     => 'ξ',
  'omicron'=> 'ο',
  'pi'     => 'π',
  'rho'    => 'ρ',
  'sigma'  => 'σ',
  'tau'    => 'τ',
  'upsilon'=> 'υ',
  'phi'    => 'φ',
  'chi'    => 'χ',
  'psi'    => 'ψ',
  'omega'  => 'ω',
  'thetasym'=>'ϑ',
  'upsih'  => 'ϒ',
  'piv'    => 'ϖ',
  'ensp'   => "\x{2003}",	# normal wide space
  'emsp'   => "\x{2004}",	# wide space
  'thinsp' => "\x{2009}",	# very thin space
  'zwnj'   => "\x{200c}",	# zero-width-non-joiner
  'zwj'    => "\x{200d}",	# zero-width-joiner
  'lrm'    => "\x{200e}",	# left-to-right
  'rlm'    => "\x{200f}",	# right-to-left
  'ndash'  => '–',
  'mdash'  => '—',
  'lsquo'  => '‘',
  'rsquo'  => '’',
  'sbquo'  => '‚',
  'ldquo'  => '“',
  'rdquo'  => '”',
  'bdquo'  => '„',
  'dagger' => '†',
  'Dagger' => '‡',
  'bull'   => '•',
  'hellip' => '…',
  'permil' => '‰',
  'prime'  => '′',
  'Prime'  => '′',
  'lsaquo' => '‹',
  'rsaquo' => '›',
  'oline'  => '‾',
  'frasl'  => '⁄',
  'euro'   => '€',
  'image'  => 'ℑ',
  'weierp' => '℘',
  'real'   => 'ℜ',
  'trade'  => '™',
  'alefsym'=> 'ℵ',
  'larr'   => '←',
  'uarr'   => '↑',
  'rarr'   => '→',
  'darr'   => '↓',
  'harr'   => '↔',
  'crarr'  => '↵',
  'lArr'   => '⇐',
  'uArr'   => '⇑',
  'rArr'   => '⇒',
  'dArr'   => '⇓',
  'hArr'   => '⇔',
  'forall' => '∀',
  'part'   => '∂',
  'exist'  => '∃',
  'empty'  => '∅',
  'nabla'  => '∇',
  'isin'   => '∈',
  'notin'  => '∉',
  'ni'     => '∋',
  'prod'   => '∏',
  'sum'    => '∑',
  'minus'  => '−',
  'lowast' => '∗',
  'radic'  => '√',
  'prop'   => '∝',
  'infin'  => '∞',
  'ang'    => '∠',
  'and'    => '∧',
  'or'     => '∨',
  'cap'    => '∩',
  'cup'    => '∪',
  'int'    => '∫',
  'there4' => '∴',
  'sim'    => '∼',
  'cong'   => '≅',
  'asymp'  => '≃',
  'ne'     => '≠',
  'eq'     => '=',
  'le'     => '≤',
  'ge'     => '≥',
  'sub'    => '⊂',
  'sup'    => '⊃',
  'nsub'   => '⊄',
  'nsup'   => '⊅',
  'sube'   => '⊆',
  'supe'   => '⊇',
  'oplus'  => '⊕',
  'otimes' => '⊗',
  'perp'   => '⊥',
  'sdot'   => '⋅',
  'lceil'  => '⌈',
  'rceil'  => '⌉',
  'lfloor' => '⌊',
  'rfloor' => '⌋',
  'lang'   => '〈',
  'rang'   => '〉',
  'roz'    => '◊',
  'spades' => '♠',
  'clubs'  => '♣',
  'diamonds'=>'♦',
  'hearts' => '♥',
  );

sub _unquote
  {
  my ($self, $name) = @_;

  $name = '' unless defined $name;

  # string concat
  # "foo" + " bar" => "foo bar"
#  print STDERR "# name='$name'\n" and
  $name =~ s/^
    "((?:\\"|[^"])*)"			# "foo"
    \s*\+\s*"((?:\\"|[^"])*)"		# followed by ' + "bar"'
    /"$1$2"/x
  while $name =~ /^
    "(?:\\"|[^"])*"			# "foo"
    \s*\+\s*"(?:\\"|[^"])*"		# followed by ' + "bar"'
    /x;

  # map "&!;" to "!"
  $name =~ s/&(.);/$1/g;

  # map "&amp;" to "&"
  $name =~ s/&([^;]+);/$entities{$1} || '';/eg;

  # "foo bar" => foo bar
  $name =~ s/^"\s*//; 		# remove left-over quotes
  $name =~ s/\s*"\z//; 

  # unquote special chars
  $name =~ s/\\([\[\(\{\}\]\)#"])/$1/g;

  $name;
  }

sub _clean_line
  { 
  # do some cleanups on a line before handling it
  my ($self,$line) = @_;

  chomp($line);

  # collapse white space at start
  $line =~ s/^\s+//;
  # line ending in "\" means a continuation
  $line =~ s/\\\z//;

  $line;
  }

sub _line_insert
  {
  # "a1 -> a2\na3 -> a4" => "a1 -> a2 a3 -> a4"
  ' ';
  }

#############################################################################

sub _match_boolean
  {
  # not used yet, match a boolean value
  qr/(true|false|\d+)/;
  }

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
  qr#\s*/\*.*?\*/#;
  }

sub _match_optional_multi_line_comment
  {
  # match a multi line comment

  # "/* * comment * */" or ""
  qr#(?:\s*/\*.*?\*/|)#;
  }

sub _match_name
  {
  # Return a regexp that matches something like '"bonn"' or 'bonn'.

  # "node", "graph", "edge", "digraph", "subgraph" and "strict" are reserved:
  qr/\s*
    (
      "(?:\\"|[^"])*"			# "foo"
      (?:\s*\+\s*"(?:\\"|[^"])*")*	# followed by 0 or more ' + "bar"'
    |
     (?!(?i:node|edge|digraph|subgraph|graph|strict)\s)[\w]+
    )/xi;
  }

sub _match_node
  {
  # Return a regexp that matches something like '"bonn"' or 'bonn' or 'bonn:f1'
  my $self = shift;

  my $qr_n = $self->_match_name();

  #    "bonn"      Bonn, Bonn0, Bonn_0, node_0 etc                                 "Bonn":f1, "Bonn":"f1"
  qr/$qr_n(?::$qr_n)?/;
  }

sub _match_group_start
  {
  my $self = shift;
  my $qr_n = $self->_match_name();

  qr/\s*(?:strict\s+)?(?:(?i)digraph|subgraph|graph)\s+$qr_n\s*\{/i;
  }

sub _match_pseudo_group_start
  {
  qr/\s*\{/;
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
  qr/^\s*(\w+)\s*=\s*		# the attribute name (label=")
    (
      "(?:\\"|[^"])*"			# "foo"
      (?:\s*\+\s*"(?:\\"|[^"])*")*	# followed by 0 or more ' + "bar"'
    |
      [^,\]\}\n\s;]+			# or simple 'fooobar'
    )
    [,\]\n\}\s;]?\s*/x;		# possible ",", "\n" etc.
  }

sub _match_special_attribute
  {
  # match boolean attributes, these can appear without a value
  qr/^\s*(
  center|
  compound|
  concentrate|
  constraint|
  decorate|
  diredgeconstraints|
  fixedsize|
  headclip|
  labelfloat|
  landscape|
  mosek|
  nojustify|
  normalize|
  overlap|
  pack|
  pin|
  regular|
  remincross|
  root|
  splines|
  tailclip|
  truecolor
  )[,;\s]?\s*/x;
  }

sub _match_attributes
  {
  # return a regexp that matches something like " [ color=red; ]" and returns
  # the inner text without the []
  qr/\s*\[\s*((?:\\\]|"(?:\\"|[^"])*"|[^\]])+?)\s*\];?/;
  }

sub _match_graph_attribute
  {
  # return a regexp that matches something like " color=red; " for attributes
  # that apply to a graph/subgraph
  qr/^\s*(\w+\s*=\s*("[^"]+"|[^;\n\s]+))([;\n\s]\s*|\z)/;
  }

sub _match_optional_attributes
  {
  # return a regexp that matches something like " [ color=red; ]" and returns
  # the inner text with the []
  qr/(\s*\[\s*((?:\\\]|"(?:\\"|[^"])*"|[^\]])+?)\s*\])?;?/;
  }

sub _clean_attributes
  {
  my ($self,$text) = @_;

  $text =~ s/^\s*\[\s*//;		# remove left-over "[" and spaces
  $text =~ s/\s*;?\s*\]\s*\z//;		# remove left-over "]" and spaces

  $text;
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

sub _add_group_match
  {
  # register handlers for group start/end
  my $self = shift;

  my $qr_pseudo_group_start = $self->_match_pseudo_group_start();
  my $qr_group_start = $self->_match_group_start();
  my $qr_group_end   = $self->_match_group_end();
  my $qr_edge  = $self->_match_edge();
  my $qr_ocmt  = $self->_match_optional_multi_line_comment();

  # "subgraph G {"
  $self->_register_handler( qr/^$qr_group_start/,
    sub
      {
      my $self = shift;
      my $graph = $self->{graph};
      my $gn = $self->_unquote($1);
      print STDERR "# Parser: found subcluster '$gn'\n" if $self->{debug};
      push @{$self->{group_stack}}, $graph->add_group($gn);
      $self->_new_scope( 1 );
      1;
      } );
  
  # "{ "
  $self->_register_handler( qr/^$qr_pseudo_group_start/,
    sub
      {
      my $self = shift;
      $self->_new_scope();
      # forget the left side
      $self->{left_edge} = undef;
      $self->{left_stack} = [ ];
      1;
      } );

  # "} -> " group/cluster/scope end with an edge
  $self->_register_handler( qr/^$qr_group_end$qr_ocmt$qr_edge/,
    sub
      {
      my $self = shift;
 
      my $scope = pop @{$self->{scope_stack}};
      return $self->parse_error(0) if !defined $scope;

      if ($scope->{_is_group} && @{$self->{group_stack}})
        {
        print STDERR "# Parser: end subcluster '$self->{group_stack}->[-1]->{name}'\n" if $self->{debug};
        pop @{$self->{group_stack}};
        }
      1;
      }, 
    sub
      {
      my ($self, $line) = @_;
      $line =~ qr/^$qr_group_end$qr_edge/;
      $1 . ' ';
      } );

  # "}" group/cluster/scope end
  $self->_register_handler( qr/^$qr_group_end/,
    sub
      {
      my $self = shift;
 
      my $scope = pop @{$self->{scope_stack}};
      return $self->parse_error(0) if !defined $scope;

      if ($scope->{_is_group} && @{$self->{group_stack}})
        {
        print STDERR "# Parser: end subcluster '$self->{group_stack}->[-1]->{name}'\n" if $self->{debug};
        pop @{$self->{group_stack}};
        }
      # always reset the stack
      $self->{stack} = [ ];
      1;
      } );
  }

sub _edge_style
  {
  # To convert "--" or "->" we simple do nothing, since the edge style in
  # Graphviz can only be set via the attribute "style"
  my ($self, $ed) = @_;

  'solid';
  }

sub _new_nodes
  {
  my ($self, $name, $group_stack, $att, $port, $stack) = @_;

  $port = '' unless defined $port;
  my @rc = ();
  # "name1" => "name1"
  if ($port ne '')
    {
    # create a special node
    $name =~ s/^"//; $name =~ s/"\z//;
    $port =~ s/^"//; $port =~ s/"\z//;
    # XXX TODO: find unique name?
    @rc = $self->_new_node ($self->{graph}, "$name:$port", $group_stack, $att, $stack);
    my $node = $rc[0];
    $node->{_graphviz_portlet} = $port;
    $node->{_graphviz_basename} = $name;
    }
  else
    {
    @rc = $self->_new_node ($self->{graph}, $name, $group_stack, $att, $stack);
    }
  @rc;
  }

sub _build_match_stack
  {
  my $self = shift;

  my $qr_node  = $self->_match_node();
  my $qr_name  = $self->_match_name();
  my $qr_cmt   = $self->_match_multi_line_comment();
  my $qr_ocmt  = $self->_match_optional_multi_line_comment();
  my $qr_attr  = $self->_match_attributes();
  my $qr_gatr  = $self->_match_graph_attribute();
  my $qr_oatr  = $self->_match_optional_attributes();
  my $qr_edge  = $self->_match_edge();
  my $qr_pgr = $self->_match_pseudo_group_start();

  # remove multi line comments /* comment */
  $self->_register_handler( qr/^$qr_cmt/, undef );
  
  # remove single line comment // comment
  $self->_register_handler( qr/^\s*\/\/.*/, undef );
  
  # simple remove the graph start, but remember that we did this
  $self->_register_handler( qr/^\s*((?i)strict\s+)?((?i)digraph|graph)\s+$qr_ocmt$qr_node\s*$qr_ocmt\{/, 
    sub 
      {
      my $self = shift;
      $self->{_graphviz_graph_name} = $3; 
      $self->_new_scope(1);
      1;
      } );

  # end-of-statement
  $self->_register_handler( qr/^\s*;/, undef );

  # cluster/subgraph "subgraph G { .. }"
  # scope (dummy group): "{ .. }" 
  # scope/group/subgraph end: "}"
  $self->_add_group_match();

  # node [ color="red" ] etc.
  # The "(?i)" makes the keywords match case-insensitive. 
  $self->_register_handler( qr/^\s*((?i)node|graph|edge)$qr_ocmt$qr_attr/,
    sub
      {
      my $self = shift;
      my $type = lc($1 || '');
      my $att = $self->_parse_attributes($2 || '', $type, NO_MULTIPLES );
      return undef unless defined $att;		# error in attributes?

      if ($type ne 'graph')
	{
	# apply the attributes to the current scope
	my $scope = $self->{scope_stack}->[-1];
        $scope->{$type} = {} unless ref $scope->{$type};
	my $s = $scope->{$type};
	for my $k (keys %$att)
	  {
          $s->{$k} = $att->{$k}; 
	  }
	}
      else
	{
	my $graph = $self->{graph};
	$graph->set_attributes ($type, $att);
	}

      # forget stacks
      $self->{stack} = [];
      $self->{left_edge} = undef;
      $self->{left_stack} = [];
      1;
      } );

  # color=red; (for graphs or subgraphs)
  $self->_register_attribute_handler($qr_gatr, 'parent');
  # [ color=red; ] (for nodes/edges)
  $self->_register_attribute_handler($qr_attr);

  # node chain continued like "-> { "Kassel" ... "
  $self->_register_handler( qr/^$qr_edge$qr_ocmt$qr_pgr$qr_ocmt$qr_node/,
    sub
      {
      my $self = shift;

      return if @{$self->{stack}} == 0;	# only match this if stack non-empty

      my $graph = $self->{graph};
      my $eg = $1;					# entire edge ("->" etc)
      my $n = $2;					# node name
      my $port = $3;

      # XXX TODO: what about "1" -- "2" [ dir: both; ]?
      my $edge_un = 0; $edge_un = 1 if $eg eq '--';	# undirected edge?

      # need to defer edge attribute parsing until the edge exists
      # if inside a scope, set the scope attributes, too:
      my $scope = $self->{scope_stack}->[-1] || {};
      my $edge_atr = $scope->{edge} || {};

      # the right side node(s) (multiple in case of autosplit)
      my $nodes_b = [ $self->_new_nodes ($n, $self->{group_stack}, {}, $port) ];

      my $style = $self->_link_lists( $self->{stack}, $nodes_b,
	'--', '', $edge_atr, 0, $edge_un);

      # create a new scope
      $self->_new_scope();

      # remember the left side
      $self->{left_edge} = [ $style, '', $edge_atr, 0, $edge_un ];
      $self->{left_stack} = $self->{stack};

      # forget stack and remember the right side instead
      $self->{stack} = $nodes_b;

      1;
      } );

  # "Berlin"
  $self->_register_handler( qr/^$qr_node/,
    sub
      {
      my $self = shift;
      my $graph = $self->{graph};

      # only match this inside a "{ }" (normal, non-group) scope
      return if exists $self->{scope_stack}->[-1]->{_is_group};

      my $n1 = $1;
      my $port = $2;
      push @{$self->{stack}},
        $self->_new_nodes ($n1, $self->{group_stack}, {}, $port, $self->{stack}); 

      if (defined $self->{left_edge})
        {
        my $e = $self->{use_class}->{edge};
        my ($style, $edge_label, $edge_atr, $edge_bd, $edge_un) = @{$self->{left_edge}};

        foreach my $node (@{$self->{left_stack}})
          {
          my $edge = $e->new( { style => $style, name => $edge_label } );

	  # if inside a scope, set the scope attributes, too:
	  my $scope = $self->{scope_stack}->[-1];
          $edge->set_attributes($scope->{edge}) if $scope;

	  # override with the local attributes 
	  # 'string' => [ 'string' ]
	  # [ { hash }, 'string' ] => [ { hash }, 'string' ]
	  my $e = $edge_atr; $e = [ $edge_atr ] unless ref($e) eq 'ARRAY';

	  for my $a (@$e)
	    {
	    if (ref $a)
	    {
	    $edge->set_attributes($a);
	    }
	  else
	    {
	    # deferred parsing with the object as param:
	    my $out = $self->_parse_attributes($a, $edge, NO_MULTIPLES);
            return undef unless defined $out;		# error in attributes?
	    $edge->set_attributes($out);
	    }
	  }

          # "<--->": bidirectional
          $edge->bidirectional(1) if $edge_bd;
          $edge->undirected(1) if $edge_un;
          $graph->add_edge ( $node, $self->{stack}->[-1], $edge );
          }
        }
      1;
      } );

  # "Berlin" [ color=red ] or "Bonn":"a" [ color=red ]
  $self->_register_handler( qr/^$qr_node$qr_oatr/,
    sub
      {
      my $self = shift;
      my $name = $1;
      my $port = $2;

      $self->{stack} = [ $self->_new_nodes ($name, $self->{group_stack}, {}, $port) ];

      # defer attribute parsing until object exists
      my $node = $self->{stack}->[0];
      my $a1 = $self->_parse_attributes($3||'', $node);
      return undef if $self->{error};
      $node->set_attributes($a1);

      # forget left stack
      $self->{left_edge} = undef;
      $self->{left_stack} = [];
      1;
      } );

  # Things like ' "Node" ' will be consumed before, so we do not need a case
  # for '"Bonn" -> "Berlin"'

  # node chain continued like "-> "Kassel" [ ... ]"
  $self->_register_handler( qr/^$qr_edge$qr_ocmt$qr_node$qr_ocmt$qr_oatr/,
    sub
      {
      my $self = shift;

      return if @{$self->{stack}} == 0;	# only match this if stack non-empty

      my $graph = $self->{graph};
      my $eg = $1;					# entire edge ("->" etc)
      my $n = $2;					# node name
      my $port = $3;

      # XXX TODO: what about "1" -- "2" [ dir: both; ]?
      my $edge_un = 0; $edge_un = 1 if $eg eq '--';	# undirected edge?

      # need to defer edge attribute parsing until the edge exists
      my $edge_atr = $4||'';
      my $scope = $self->{scope_stack}->[-1] || {};

      $edge_atr = [ $edge_atr, $scope->{edge} || {} ];

      # the right side nodes:
      my $nodes_b = [ $self->_new_nodes ($n, $self->{group_stack}, {}, $port) ];

      my $style = $self->_link_lists( $self->{stack}, $nodes_b,
	'--', '', $edge_atr, 0, $edge_un);

      # remember the left side
      $self->{left_edge} = [ $style, '', $edge_atr, 0, $edge_un ];
      $self->{left_stack} = $self->{stack};

      # forget stack and remember the right side instead
      $self->{stack} = $nodes_b;
      1;
      } );

  $self;
  }

sub _add_node
  {
  # add a node to the graph, overridable by subclasses
  my ($self, $graph, $name) = @_;

  # "a -- clusterB" should not create a spurious node named "clusterB"
  my @groups = $graph->groups();
  for my $g (@groups)
    {
    return $g if $g->{name} eq $name;
    }

  my $node = $graph->node($name);
 
  if (!defined $node)
    {
    $node = $graph->add_node($name);		# add

    # apply attributes from the current scope (only for new nodes)
    my $scope = $self->{scope_stack}->[-1];
    $self->error("Scope stack is empty!") unless defined $scope;
  
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

my $remap = {
  'node' => {
    'distortion' => undef,

    'fixedsize' => undef,
    'group' => undef,
    'height' => undef,

    # XXX TODO: ignore non-node attributes set in a scope
    'dir' => undef,
    # a lot of example files have this spurious attribute
    #'kind' => undef,

    'layer' => undef,
    'margin' => undef,
    'orientation' => \&_from_graphviz_node_orientation,
    'peripheries' => \&_from_graphviz_node_peripheries,
    'pin' => undef,
    'pos' => undef,
    # XXX TODO: rank=0 should make that node the root node
    'rank' => undef,
    'rects' => undef,
    'regular' => undef,
    'root' => undef,
    'sides' => undef,
    'shapefile' => undef,
    'shape' => \&_from_graphviz_node_shape,
    'skew' => undef,
    'style' => \&_from_graphviz_style,
    'width' => undef,
    'z' => undef,
    },

  'edge' => {
    'arrowsize' => undef,
    'arrowhead' => \&_from_graphviz_arrow_style,
    'arrowtail' => undef,
     # important for color lists like "red:red" => double edge
    'color' => \&_from_graphviz_edge_color,
    'constraint' => undef,
    'dir' => \&_from_graphviz_edge_dir,
    'decorate' => undef,
    'f' => undef,
    'headclip' => undef,
    'headhref' => undef,
    'headurl' => undef,
    'headport' => undef,
    'headlabel' => undef,
    'headport' => undef,
    'headtarget' => undef,
    'headtooltip' => undef,
    'labelangle' => undef,
    'labeldistance' => undef,
    'labelfloat' => undef,
    'labelfontcolor' => \&_from_graphviz_color,
    'labelfontname' => 'font',
    'labelfontsize' => 'font-size',
    'layer' => undef,
    'len' => undef,
    'lhead' => undef,
    'ltail' => undef,
    'minlen' => \&_from_graphviz_edge_minlen,
    'pos' => undef,
    'samehead' => undef,
    'samearrowhead' => undef,
    'sametail' => undef,
    'style' => \&_from_graphviz_edge_style,
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
    'labeljust' => \&_from_graphviz_graph_labeljust,
    'labelloc' => \&_from_graphviz_graph_labelloc,
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
    'rankdir' => \&_from_graphviz_graph_rankdir,
    'ranksep' => undef,
    'ratio' => undef,
    'remincross' => undef,
    'resolution' => undef,
    'rotate' => undef,
    'samplepoints' => undef,
    'searchsize' => undef,
    'sep' => undef,
    'sep' => undef,
    'size' => undef,
    'splines' => undef,
    'start' => undef,
    'style' => \&_from_graphviz_style,
    'stylesheet' => undef,
    'truecolor' => undef,
    'viewport' => undef,
    'voro-margin' => undef,
    },

  'group' => {
#    'labeljust' => \&_graphviz_remap_graph_labeljust,
#    'labelloc' => \&_graphviz_remap_graph_labelloc,
    'pencolor' => \&_from_graphviz_color,
    'style' => \&_from_graphviz_style,
    'K' => undef,
    },

  'all' => {
    'color' => \&_from_graphviz_color,
    'colorscheme' => undef,
    'comment' => undef,
    'bgcolor' => \&_from_graphviz_color,
    'fillcolor' => \&_from_graphviz_color,
    'fontsize' => \&_from_graphviz_font_size,
    'fontcolor' => \&_from_graphviz_color,
    'fontname' => 'font',
    'lp' => undef,
    'nojustify' => undef,
    'rank' => undef,
    'showboxes' => undef,
    'target' => undef,
    'tooltip' => 'title',
    'URL' => 'link',
    'href' => 'link',
    },
  };

my $rankdir = {
  'LR' => 'east',
  'RL' => 'west',
  'TB' => 'south',
  'BT' => 'north',
  };

sub _from_graphviz_graph_rankdir
  {
  my ($self, $name, $dir) = @_;

  my $d = $rankdir->{$dir} || 'east';

  ('flow', $d);
  }

my $shapes = {
  box => 'rect',
  polygon => 'rect',
  egg => 'rect',
  rectangle => 'rect',
  mdiamond => 'diamond',
  msquare => 'rect',
  plaintext => 'none',
  none => 'none',
  };

sub _from_graphviz_node_shape
  {
  my ($self, $name, $shape) = @_;

  my @rc;
  my $s = lc($shape);
  if ($s =~ /^(triple|double)/)
    {
    $s =~ s/^(triple|double)//;
    push @rc, ('border-style','double');
    }

  # map the name to what Graph::Easy expects (ellipse stays as ellipse f.i.)
  $s = $shapes->{$s} || $s;

  (@rc, $name, $s);
  }

sub _from_graphviz_style
  {
  my ($self, $name, $style, $class) = @_;

  my @styles = split /\s*,\s*/, $style;

  my $is_node = 0;
  $is_node = 1 if ref($class) && !$class->isa('Graph::Easy::Group');
  $is_node = 1 if !ref($class) && defined $class && $class eq 'node';

  my @rc;
  for my $s (@styles)
    {
    @rc = ('shape', 'rounded') if $s eq 'rounded';
    @rc = ('shape', 'invisible') if $s eq 'invis';
    @rc = ('border', 'black ' . $1) if $s =~ /^(bold|dotted|dashed)\z/;
    if ($is_node != 0)
      {	
      @rc = ('shape', 'rect') if $s eq 'filled';
      }
    }

  @rc;
  }

sub _from_graphviz_node_orientation
  {
  my ($self, $name, $o) = @_;

  my $r = int($o);
  
  return (undef,undef) if $r == 0;

  # 1.0 => 1
  ('rotate', $r);
  }

sub _from_graphviz_node_peripheries
  {
  my ($self, $name, $cnt) = @_;

  return (undef,undef) if $cnt < 2;

  # peripheries = 2 => double border
  ('border-style', 'double');
  }

sub _from_graphviz_edge_minlen
  {
  my ($self, $name, $len) = @_;

  # 1 => 1, 2 => 3, 3 => 5 etc
  $len = $len * 2 - 1;
  ($name, $len);
  }

sub _from_graphviz_font_size
  {
  my ($self, $f, $size) = @_;

  # 20 => 20px
  $size = $size . 'px' if $size =~ /^\d+\z/;

  ('font-size', $size);
  }

sub _from_graphviz_graph_labelloc
  {
  my ($self, $l, $loc) = @_;

  $loc = 'top' if $loc eq 't'; 
  $loc = 'bottom' if $loc eq 'b';

  ('label-pos', $loc);
  }

sub _from_graphviz_edge_dir
  {
  my ($self, $name, $dir, $edge) = @_;

  # Modify the edge, depending on dir
  if (ref($edge))
    {
    # "forward" is the default and ignored
    $edge->flip() if $dir eq 'back';
    $edge->bidirectional(1) if $dir eq 'both';
    $edge->undirected(1) if $dir eq 'none';
    }

  (undef, undef);
  }

sub _from_graphviz_edge_style
  {
  my ($self, $name, $style, $object) = @_;

  # input: solid dashed dotted bold invis
  $style = 'invisible' if $style eq 'invis';

  ($name, $style);
  }

sub _from_graphviz_arrow_style
  {
  my ($self, $name, $shape, $object) = @_;

  my $style = 'open';

  $style = 'closed' if $shape =~ /^(empty|onormal)\z/;
  $style = 'filled' if $shape eq 'normal' || $shape eq 'normalnormal';
  $style = 'open' if $shape eq 'vee' || $shape eq 'veevee';
  $style = 'none' if $shape eq 'none' || $shape eq 'nonenone';

  ('arrow-style', $style);
  }

my $color_map = {
  fontcolor => 'color',
  bgcolor => 'background',
  fillcolor => 'fill',
  pencolor => 'border-color',
  labelfontcolor => 'label-color',
  color => 'color',
  };

sub _from_graphviz_color
  {
  # remape the color name and value
  my ($self, $name, $color) = @_;

  # "0.1 0.4 0.5" => "rgb(0.1,0.4,0.5)"
  if ($color =~ /\s/)
    {
    $color =~ s/\s/,/g; $color = 'rgb(' . $color . ')';
    }

  # XXX TODO: #ff00005f => #ff0000
  $color = $1 if $color =~ /^(#......)..\z/;

  ($color_map->{$name}, $color);
  }

sub _from_graphviz_edge_color
  {
  # remape the color name and value
  my ($self, $name, $color) = @_;

  my @colors = split /:/, $color;

  for my $c (@colors)
    {
    $c = Graph::Easy::Parser::Graphviz::_from_graphviz_color($self,$name,$c);
    }

  my @rc;
  if (@colors > 1)
    {
    # 'red:blue' => "style: double; color: red"
    push @rc, 'style', 'double';
    }

  (@rc, $color_map->{$name}, $colors[0]);
  }

sub _from_graphviz_graph_labeljust
  {
  my ($self, $name, $l, $object) = @_;

  # input: "l" "r" or "c", output "left", "right" or "center"
  my $a = 'center';
  $a = 'left' if $l eq 'l';
  $a = 'right' if $l eq 'r';

  ('align', $a);
  }

#############################################################################

sub _remap_attributes
  {
  my ($self, $att, $object) = @_;

  if ($self->{debug})
    {
    my $o = ''; $o = " for $object" if $object;
    print STDERR "# remapping attributes '$att'$o\n";
    }

  $self->{graph}->_remap_attributes($object, $att, $remap, 'noquote', undef, undef);
  }

#############################################################################

sub _parser_cleanup
  {
  # After initial parsing, do cleanup, e.g. autosplit nodes with shape record,
  # re-connect edges to the parts etc.
  my ($self) = @_;

  print STDERR "# Parser cleanup pass\n" if $self->{debug};

  my $g = $self->{graph};
  my @nodes = $g->nodes();

  # for all nodes that have a shape of "record", break down their label into
  # parts and create  these as autosplit nodes
  for my $n (@nodes)
    {
    my $shape = $n->attribute('shape') || 'rect';
    my $label = $n->label();
    if ($shape eq 'record' && $label =~ /\|/)
      {
      my $att = {};
      # create basename only when node name differes from label
      $att->{basename} = $n->{name};
      if ($n->{name} ne $label)
	{
	$att->{basename} = $n->{name};
	}
      # XXX TODO: autosplit needs to handle nesing like "{}".

      # Replace "{ ... | ... |  ... }" with "...|| ... || ...." as a cheat
      # to fix one common case
      if ($label =~ /^\s*\{[^\{\}]+\}\s*\z/)
	{
        $label =~ s/[\{\}]//g;	# {..|..} => ..|..
        $label =~ s/\|/\|\|/g	# ..|.. => ..||..
	  # if the graph flows left->right or right->left
	  if (($g->attribute('flow') || 'east') =~ /^(east|west)/);
	}
      my @rc = $self->_autosplit_node($g, $label, $att, 0 );
      my $group = $n->group();
      $n->del_attribute('label');

      my $qr_clean = $self->{_qr_part_clean};
      # clean the base name of ports:
      #  "<f1> test | <f2> test" => "test|test"
      $rc[0]->{autosplit} =~ s/(^|\|)$qr_clean/$1/g;
      $rc[0]->{att}->{basename} =~ s/(^|\|)$qr_clean/$1/g;
      $rc[0]->{autosplit} =~ s/^\s*//;
      $rc[0]->{att}->{basename} =~ s/^\s*//;
      # '| |' => '|  |' to avoid empty parts via as_txt() => as_ascii()
      $rc[0]->{autosplit} =~ s/\|\s\|/\|  \|/g;
      $rc[0]->{att}->{basename} =~ s/\|\s\|/\|  \|/g;
      $rc[0]->{autosplit} =~ s/\|\s\|/\|  \|/g;
      $rc[0]->{att}->{basename} =~ s/\|\s\|/\|  \|/g;
      delete $rc[0]->{att}->{basename} if $rc[0]->{att}->{basename} eq $rc[0]->{autosplit};

      for my $n1 (@rc)
	{
	$n1->add_to_group($group) if $group;
	$n1->set_attributes($n->{att});
	# remove the temp. "shape=record"
	$n1->del_attribute('shape');
	}

      # If the helper node has edges, reconnect them to the first
      # part of the autosplit node (dot seems to render them arbitrarily
      # on the autosplit node):

      for my $e (values %{$n->{edges}})
	{
        $e->start_at($rc[0]) if $e->{from} == $n;
        $e->end_at($rc[0]) if $e->{to} == $n;
	}
      # remove the temp. and spurious node
      $g->del_node($n);
      }
    }

  # During parsing, "bonn:f1" -> "berlin:f2" results in "bonn:f1" and
  # "berlin:f2" as nodes, plus an edge connecting them

  # We find all of these nodes, move the edges to the freshly created
  # autosplit parts above, then delete the superflous temporary nodes.

  # if we looked up "Bonn:f1", remember it here to save time
  my $node_cache = {};

  my @edges = $g->edges();
  @nodes = $g->nodes();		# get a fresh list of nodes after split
  for my $e (@edges)
    {
    # do this for both the from and to side of the edge:
    for my $side ('from','to')
      {
      my $n = $e->{$side};
      next unless defined $n->{_graphviz_portlet};

      my $port = $n->{_graphviz_portlet};
      my $base = $n->{_graphviz_basename};

      my $node = $node_cache->{"$base:$port"};

      if (!defined $node)
	{
	# go thru all nodes and for see if we find one with the right port name
	for my $na (@nodes)
	  {
	  next unless exists $na->{autosplit_portname} && exists $na->{autosplit_basename};
	  next unless $na->{autosplit_basename} eq $base;
	  next unless $na->{autosplit_portname} eq $port;
	  # cache result
          $node_cache->{"$base:$port"} = $na;
          $node = $na;
	  }
	}

      if (!defined $node)
	{
	# Still not defined? uhoh...
	$self->error("Cannot fine autosplit node for $base:$port on edge $e->{id}");
 	}

      if ($side eq 'from')
	{
  	print STDERR "# Setting new edge start point to $node->{name}\n" if $self->{debug};
	$e->start_at($node);
	}
      else
	{
  	print STDERR "# Setting new edge end point to $node->{name}\n" if $self->{debug};
	$e->end_at($node);
	}

      } # end for side "from" and "to"
    # we have reconnected this edge
    }

  # after reconnecting all edges, we can delete temp. nodes: 
  for my $n (@nodes)
    {
    $g->del_node($n) if exists $n->{_graphviz_portlet};
    }

  @nodes = $g->nodes();

  # convert "\N" to "self->{name}", \G => graph name
  for my $n (@nodes)
    {
    for my $w (qw/label title link/)
      {
      no strict 'refs'; 
      my $str = $n->$w();
      my $changed = 0;
      if ($str =~ /\\N/)
	{
	my $name = $n->{name};
	$str =~ s/\\N/$name/g;
	$changed++;
	}
      if ($str =~ /\\G/)
	{
	my $name = $self->{_graphviz_graph_name};
	$str =~ s/\\G/$name/g;
	$changed++;
	}
      $n->set_attribute($w,$str) if $changed > 0;
      }
    }
  # convert "\G" for the graph
  for my $w (qw/label title link/)
    {
    no strict 'refs'; 
    my $str = $g->$w();
    if ($str =~ /\\G/)
      {
      my $name = $self->{_graphviz_graph_name};
      $str =~ s/\\G/$name/g;
      $g->set_attribute($w,$str);
      }
    }
  
  # convert "\E" to "Bonn->Berlin", handle \G, \H and \T, too
  for my $e (@edges)
    {
    for my $w (qw/label title link/)
      {
      no strict 'refs'; 
      my $str = $e->$w();
      my $changed = 0;
      if ($str =~ /\\E/)
	{
        my $es = '->'; $es = '--' if $e->undirected();
	my $name = $e->{from}->{name} . $es . $e->{to}->{name};
	$str =~ s/\\E/$name/g;
	$changed++;
	}
      if ($str =~ /\\G/)
	{
	my $name = $self->{_graphviz_graph_name};
	$str =~ s/\\G/$name/g;
	$changed++;
	}
      if ($str =~ /\\H/)
	{
	my $name = $e->{from}->{name};
	$str =~ s/\\H/$name/g;
	$changed++;
	}
      if ($str =~ /\\T/)
	{
	my $name = $e->{to}->{name};
	$str =~ s/\\T/$name/g;
	$changed++;
	}
      $e->set_attribute($w,$str) if $changed > 0;
      }
    }

  $g->_drop_special_attributes();
  $g->{_warn_on_unknown_attributes} = 0;	# reset to die again

  $self;
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
                "digraph MyGraph { \n" .
	 	"	Bonn -> \"Berlin\" \n }"
        );
        print $graph->as_ascii();

	print $parser->from_file('mygraph.dot')->as_ascii();

=head1 DESCRIPTION

C<Graph::Easy::Parser::Graphviz> parses the text format from the DOT language
use by Graphviz and constructs a C<Graph::Easy> object from it.

The resulting object can than be used to layout and output the graph
in various formats.

Please see the Graphviz manual for a full description of the syntax
rules of the DOT language.

=head2 Output

The output will be a L<Graph::Easy|Graph::Easy> object (unless overrriden
with C<use_class()>), see the documentation for Graph::Easy what you can do
with it.

=head1 METHODS

C<Graph::Easy::Parser::Graphviz> supports the same methods
as its parent class C<Graph::Easy::Parser>:

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

=head1 CAVEATS

The parser has problems with the following things:

=over 12

=item encoding and charset attribute

The parser assumes the input to be C<utf-8>. Input files in <code>Latin1</code>
are not parsed properly, even when they have the charset attribute set.

=item table syntax

Labels that contain the HTML table syntax (e.g. are limited by '<' and '>'
opposed to '"') are not parsed yet.

=item shape=record

Nodes with shape record are only parsed properly when the label does not
contain groups delimited by "{" and "}", so the following is parsed
wrongly:

	node1 [ shape=record, label="A|{B|C}" ]

=item default shape

The default shape for a node is 'rect', opposed to 'circle' as dot renders
nodes.

=item attributes

Some attributes are B<not> remapped properly to what Graph::Easy expects, thus
losing information, either because Graph::Easy doesn't support this feature
yet, or because the mapping is incomplete.

Some attributes meant only for nodes or edges etc. might be incorrectly applied
to other objects, resulting in unnec. warnings while parsing.

Attributes not valid in the original DOT language are silently ignored by dot,
but result in a warning when parsing under Graph::Easy. This helps catching all
these pesky misspellings, but it's not yet possible to disable these warnings.

=back

=head1 EXPORT

Exports nothing.

=head1 SEE ALSO

L<Graph::Easy>, L<Graph::Reader::Dot>.

=head1 AUTHOR

Copyright (C) 2005 - 2006 by Tels L<http://bloodgate.com>

See the LICENSE file for information.

=cut
