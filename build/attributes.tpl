<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
 <head>
 <title>Graph::Easy - Manual - Attributes</title>
 <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
 <meta name="MSSmartTagsPreventParsing" content="TRUE">
 <meta http-equiv="imagetoolbar" content="no">
 <link rel="stylesheet" type="text/css" href="../base.css">
 <link rel="stylesheet" type="text/css" href="manual.css">
 <style type="text/css">
   <!-- 
    h4 { margin-bottom: 0em; padding-left: 1em; }
   -->
 </style>
</head>
<body bgcolor=white text=black>

<a name="top"></a>

<div class="menu">

  <p class="menu"><a class="menu" href="index.html" title="Back to the manual index">Index</a></p>
  <p style="height: 0.2em">&nbsp;</p>
  <p class="menuext"><a class="menuext" href="overview.html" title="How everything fits together">Overview</a></p>
  <p class="menuext"><a class="menuext" href="layouter.html" title="How the layouter works">Layouter</a></p>
  <p class="menuext"><a class="menuext" href="hinting.html" title="Generating specific layouts">Hinting</a></p>
  <p class="menuext"><a class="menuext" href="a-star.html" title="A* algorithm (pathfinding)">A*</a></p>
  <p class="menuext"><a class="menuext" href="output.html" title="Output formats and their limitations">Output</a></p>
  <p class="menuext"><a class="menuext" href="syntax.html" title="Syntax rules for the text format">Syntax</a></p>
  <p class="menucur"><a class="menucur" href="attributes.html" title="All possible attributes for graphs, nodes and edges">Attributes</a></p>
  <p class="menuind"><a class="menuind" href="att_graphs.html" title="Graph attributes">Graphs</a></p>
  <p class="menuind"><a class="menuind" href="att_nodes.html" title="Node attributes">Nodes</a></p>
  <p class="menuind"><a class="menuind" href="att_edges.html" title="Edge attributes">Edges</a></p>
  <p class="menuind"><a class="menuind" href="att_groups.html" title="Group attributes">Groups</a></p>
  <p class="menuind"><a class="menuind" href="#class_names" title="Classes and their names">Classes</a></p>
  <p class="menuind"><a class="menuind" href="#links" title="Links and URLs">Links</a></p>
  <p class="menuind"><a class="menuind" href="#color_names_and_values" title="Color names and values">Colors</a></p>

</div>

<div class="right">

<h1>Graph::Easy - Manual</h1>

<h2>Attributes</h2>

<div class="text">

<p>
If you haven't done so, please read the <a href="overview.html">Overview</a> first.
</p>

<p>
This chapter describes all the possible attributes for graphs, nodes and edges.
It is generated automatically from the definitions in <code>Graph::Easy::Attributes</code>.
</p>

<a name="Graphs">
<h3>Graphs</h3>
</a>

##graph##

<a name="Nodes">
<h3>Nodes</h3>
</a>

##node##

<a name="Edges">
<h3>Edges</h3>
</a>

##edge##

<a name="Groups">
<h3>Groups</h3>
</a>

##group##

<hr>

<a name="class_names">
<h3>Class names</h3>
</a>

<p>
Each of the primary classes <code>node</code>, <code>edge</code> and <code>group</code>
can have an arbitrary number of sub-classes.
</p>

<p>
Subclass names are restricted to <code>[a-z]</code> (lower ascii letters A to Z) and the <code>_</code>
(underscore). Each subclass can have its own set of attributes.
<br>
Objects with their <code>class</code>-attributea set will use the attributes from the appropriate
subclass.
If an attribute was not defined there, they will inherit the attribute from their primary
class. In the following example the left node will have green text, the right one
will have red text. Both nodes will have a beige interieur: 
</p>

<pre class="graphtext">
node { color: green; fill: beige; }
node.cities { color: red; }

[ Green ] --> [ Red ] { class: cities; }
</pre>

<img src="img/example5.png" border=0 title="Example of classes" style="float: left; margin-left: 1em;">

<div class="clear"></div>

<a name="links">
<h3>Links and URLs</h3>
</a>

<p>
Links are constructed from two parts, by concating the <code>linkbase</code> attribute and
the <code>link</code> attribute:
</p>

<pre class="graphtext">
node { linkbase: http://www.bloodgate.com/perl/; }

[ Graph ] { link: graph/; }
 --> [ Manual ] { link: graph/manual/; }
</pre>

<map id="NAME" name="NAME">
<area shape="rect" href="http://www.bloodgate.com/perl/graph/" title="Graph" alt="Graph" coords="17,7,89,54" />
<area shape="rect" href="http://www.bloodgate.com/perl/graph/manual/" title="Manual" alt="Manual" coords="137,7,209,54" />
</map>

<img USEMAP="#NAME" src="img/example6.png" border=0 title="Example of links" style="float: left; margin-left: 1em;">

<p class="clear">
<code>linkbase</code> is ignored unless you also have <code>link</code> or <code>autolink</code>.
You can use <code>autolink</code> to automatically set the link attribute to the
name, label, or titel of the object:
</p>

<pre class="graphtext">
node { linkbase: http://www.bloodgate.com/perl/; autolink: name; }

[ graph ] --> [ graph/manual ]
</pre>

<map id="NAME2" name="NAME2">
<area shape="rect" href="http://www.bloodgate.com/perl/graph" title="graph" alt="graph" coords="17,7,89,54" />
<area shape="rect" href="http://www.bloodgate.com/perl/graph/manual" title="graph/manual" alt="graph/manual" coords="137,7,244,54" />
</map>

<img USEMAP="#NAME2" src="img/example7.png" border=0 title="Example of links" style="float: left; margin-left: 1em;">

<p class="clear">
Note that <code>link</code> has precedence over <code>autolink</code>, the latter
will not override a <code>link</code> attribute on the object itself.
<br>
Also, <code>linnkbase</code> is only prepended for relativ links, e.g. ones that do not
start with <code>/[a-z]{3,4}://</code>. In the following example the first node
will not have the name autolinked, and the second node will ignore the linkbase:
</p>

<pre class="graphtext">
node { linkbase: http://www.bloodgate.com/perl/; autolink: name; }

[ graph ] { link: index.html; } 
  --> [ graph/manual ] { link: http://bloodgate.com; }
</pre>

<map id="GRAPH_0" name="GRAPH_0">
<area shape="rect" href="http://www.bloodgate.com/perl/index.html" title="graph" alt="graph" coords="17,7,89,54" />
<area shape="rect" href="http://bloodgate.com" title="graph/manual" alt="graph/manual" coords="137,7,244,54" />
</map>

<img USEMAP="#GRAPH_0" src="img/example8.png" border=0 title="Example of links" style="float: left; margin-left: 1em;">

<div class="clear"></div>

<a name="color_names_and_values">
<h3>Color Names and Values</h3>
</a>

<p>
Here is a list of the color names recognized by Graph::Easy and their
corrosponding color values. Note that this list is exactly the same as
the <a href="http://www.w3.org/TR/SVG/types.html#ColorKeywords">one published</a> by
<a href="">W3C</a>. So do not blame me for silly things
like <font style="color: white; background: darkseagreen">darkseagreen</font>
being lighter than <font style="color: white; background: seagreen">seagreen</font>...
</p>

<p>&nbsp;</p>

##colors##

<p>
For all other colors you can use one of the following notations:
</p>

<ul>
  <li>Hex: <code>#ff0080</code>
  <li>RGB: <code>rgb(255,0,128)</code>
</ul>

</div>

<div class="footer">
Page created automatically at <span class="date">##time##</span> in ##took##. Contact: <a href="/mail.html">Tels</a>.
</div>

</div> <!-- end of right cell -->

</body>
</html>
