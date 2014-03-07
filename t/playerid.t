#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw/ tempdir /;
use PT::Test::Database;

my $testdir = tempdir;
$ENV{PT_TESTING} = $testdir;

# generate test database and run tests while doing so
my $test = PT::Test::Database->for_test($testdir);
$test->deploy;

done_testing();
