#!/usr/bin/env perl

# ABSTRACT: Shorthand to tidy only things that have been changed lately

use strict;
use warnings;
use utf8;

=head1 SYNOPSIS

    perltidy.pl # everything modified in git gets tidied

=cut

# `dzil perltidy` is just too bloody slow
#
# This will tidy all dirty files, and _ONLY_ dirty files
#
use Git::Wrapper;
use FindBin;
use Path::Tiny qw(path);
use File::Copy;

my $root       = path($FindBin::Bin)->parent;
my $perltidyrc = $root->child('.perltidyrc');
my $git        = Git::Wrapper->new($root);
my $stats      = $git->status;

my @dirty = ( $stats->get('added'), $stats->get('changed') );

sub tidy_vanilla {
  local @ARGV = ();
  require Perl::Tidy;
  return sub {
    local @ARGV = ();
    Perl::Tidy::perltidy(@_);
  };
}

for my $status (@dirty) {
  my $file     = $root->child( $status->from );
  my $tidy     = tidy_vanilla;
  my $tidyfile = $file . '.tdy';
  printf qq[Tidying %s\n], $file;
  if ( my $pid = fork() ) {
    waitpid $pid, 0;
    die sprintf 'Child exited with nonzero status: %s', $?
        if $? > 0;
    File::Copy::move( $tidyfile, $file );
    next;
  }
  $tidy->(
    source      => "$file",
    destination => "$tidyfile",
    ( $perltidyrc ? ( perltidyrc => "$perltidyrc" ) : () ),
  );
  exit 0;
}
