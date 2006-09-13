
# We need at least Perl 5.8.1 for proper Unicode support
require 5.8.1;
use strict;

# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# The name of your distribution
name		'Graph-Easy';

# Get most of the details from the primary module
all_from	'lib/Graph/Easy.pm';

requires	'Scalar::Util'	=> 1.13;

recommends	'Graph::Easy::As_svg'	=> 0.21;

build_requires	'Test::More'	=> 0.42;

license		'gpl';		# v2.0 only 

author		'Tels <nospam-abuse@bloodgate.com>';

# Do not index these
no_index	directory	=> 'examples';
no_index	directory	=> 'bench';
no_index	directory	=> 'todos';

# Generate the Makefile
WriteAll;
