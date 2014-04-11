#!/usr/bin/env perl

# PODNAME: pt_feed_processor.pl

# ABSTRACT: A Daemon that monitors feeds

use strict;
use warnings;
use utf8;

use FindBin;
use Path::Tiny qw( path );

my $root;

BEGIN {
  $root = path($FindBin::Bin)->parent;
}
use lib "$root/lib";

use PT;
use PT::Feed::Loop;
use PT::Log::Contextual qw();

my $loop = PT::Feed::Loop->new( pt => PT->new() );

$loop->run;
