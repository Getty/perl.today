#!/usr/bin/env perl

# ABSTRACT: A Daemon that monitors feeds

use strict;
use warnings;
use utf8;

use FindBin;
use Path::Tiny qw( path );
use Log::Contextual::SimpleLogger;
use Log::Contextual qw(set_logger);

my $emap = {
  'warning' => [qw( warning error critical alert emergency )],
  'notice'  => [qw( notice warning error critical alert emergency )],
  'info'    => [qw( info notice warning error critical alert emergency )],
  'debug' => [qw( debug info notice warning error critical alert emergency )],
  'trace' =>
      [qw( trace debug info notice warning error critical alert emergency )],
};

my $tracelevel = 'warning';
if ( $ENV{PT_FEED_DEBUG} and exists $emap->{ $ENV{PT_FEED_DEBUG} } ) {
  $tracelevel = $ENV{PT_FEED_DEBUG};
}

my $minilogger =
    Log::Contextual::SimpleLogger->new( { levels => $emap->{$tracelevel} } );
set_logger($minilogger);
my $root;

BEGIN {
  $root = path($FindBin::Bin)->parent;
}
use lib "$root/lib";

use PT;
use PT::Feed::Loop;

my $loop = PT::Feed::Loop->new( pt => PT->new() );

$loop->run;
