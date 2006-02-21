
# Load the Module::Install bundled in ./inc/
use inc::Module::Install;
    
# The name of your distribution
name		'Graph-Easy';
    
# Get most of the details from the primary module
all_from	'lib/Graph/Easy.pm';
   
requires	'Scalar::Util'	=> 1.13;
requires	'Heap'		=> 0.71;

recommends	'Graph::Easy::As_svg'	=> 0.18;

build_requires	'Test::More'	=> 0.42;
   
license		'gpl';		# v2.0 only 

author		'Tels <nospam-abuse@bloodgate.com>';

# Do not index these
no_index	directory	=> 'examples',
		directory	=> 'bench',
		directory	=> 'todos';
    
# Auto-install all dependencies from CPAN
auto_install;
    
# Generate the Makefile
WriteAll;
