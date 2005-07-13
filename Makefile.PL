use 5.006001;
use ExtUtils::MakeMaker;
use strict;

sub MY::metafile {
  package MY;
  my $self = shift;
  if (!eval { require YAML; 1 })
  {
    warn ("YAML not installed, 'make dist' will not override 'META.yml'.");
    return $self->SUPER::metafile_target(@_);
  };

  my $node = new YAML::Node {};

  $node->{name}                 = $self->{DISTNAME};
  $node->{version}              = $self->{VERSION};
  $node->{version_from}         = $self->{VERSION_FROM};
  $node->{license}              = 'gpl';
  $node->{distribution_type}    = 'module';
  $node->{generated_by}         = "$self->{DISTNAME} version $self->{VERSION}";
  $node->{installdirs}          = 'site';
  $node->{requires}             = $self->{PREREQ_PM};

  my $dump = YAML::Dump( $node );

  $dump =~ s/^(.*)$/\t\$(NOECHO) \$(ECHO) "$1" >>META.yml/gm;
  $dump =~ s/>>META\.yml/>META.yml/;

  return "metafile:\n$dump";
}

eval { require Graph::Easy::As_svg; };

my $ver = $Graph::Easy::As_svg::VERSION;

if (!defined $ver)
  {
  print "\n************\nWARNING: ";
  print "You do not seem to have Graph::Easy::As_svg installed.\n";
  print "         SVG output is not possible until you install it afterwards.\n\n";
  }

if (defined $ver && $ver <= 0.05)
  {
  print "\n************\nWARNING: ";
  print "Your Graph::Easy::As_svg version is outdated.\n";
  print "         Please upgrade it after installing this package.\n\n";
  }

WriteMakefile(
    NAME		=> 'Graph::Easy',
    VERSION_FROM	=> 'lib/Graph/Easy.pm', # finds $VERSION
    PREREQ_PM		=> {
	Graph => 0.65,
	},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Graph/Easy.pm', # retrieve abstract from module
       AUTHOR         => 'Tels <nospam-abuse@bloodgate.com>') : ()),
);
