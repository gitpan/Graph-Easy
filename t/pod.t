#!/usr/bin/perl -w

use Test::More;
use strict;

BEGIN
   {
   plan tests => 16;
   chdir 't' if -d 't';
   use lib '../lib';
   };

SKIP:
  {
  skip( 'Test::Pod not installed on this system', 1 )
    unless do
      {
      eval qq{
      use Test::Pod
      };
      $@ ? 0 : 1;
      };
  pod_file_ok( '../lib/Graph/Easy.pm' );
  pod_file_ok( '../lib/Graph/Easy/Layout.pm' );
  pod_file_ok( '../lib/Graph/Easy/Layout/Scout.pm' );
  pod_file_ok( '../lib/Graph/Easy/Layout/Path.pm' );
  pod_file_ok( '../lib/Graph/Easy/Node.pm' );
  pod_file_ok( '../lib/Graph/Easy/Edge.pm' );
  pod_file_ok( '../lib/Graph/Easy/Group.pm' );
  pod_file_ok( '../lib/Graph/Easy/Parser.pm' );
  pod_file_ok( '../lib/Graph/Easy/Attributes.pm' );
  pod_file_ok( '../lib/Graph/Easy/As_ascii.pm' );
  pod_file_ok( '../lib/Graph/Easy/As_txt.pm' );
  pod_file_ok( '../lib/Graph/Easy/As_graphviz.pm' );
  pod_file_ok( '../lib/Graph/Easy/Edge/Cell.pm' );
  pod_file_ok( '../lib/Graph/Easy/Node/Anon.pm' );
  pod_file_ok( '../lib/Graph/Easy/Node/Cell.pm' );
  pod_file_ok( '../lib/Graph/Easy/Group/Cell.pm' );
  }
