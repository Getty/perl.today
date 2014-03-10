#!/usr/bin/env perl

# ABSTRACT: Tidy/check End-Of-Lines

=head1 SYNOPIS

    tidy_eols.pl  # verify list is a sane list of things to mess with
    tidy_eols.pl --apply  # do it

=cut

use strict;
use warnings;
use utf8;

use Path::Tiny qw(path);
use FindBin;
use Path::Iterator::Rule;

my $root = path($FindBin::Bin)->parent;

my $rule = Path::Iterator::Rule->new();
$rule->skip_vcs;
$rule->skip(
  sub {
    return if not -d $_;
    if ( $_[1] =~ qr/^\.build$/ ) {
      *STDERR->print("\e[34mIgnoring \e[33m$_\e[34m ( .build )\e[0m\n");
      return 1;
    }
    if ( $_[1] =~ qr/^[A-Z].*-[0-9.]+(-TRIAL)?$/ ) {
      *STDERR->print(
        "\e[34mIgnoring \e[33m$_\e[34m ( dzil build tree )\e[0m\n");
      return 1;
    }

    return;
  }
);

$rule->file->nonempty;
$rule->file->not_binary;
$rule->file->or(
  $rule->new->line_match(qr/\s\n/),
  $rule->new->line_match(qr/\r\n/),
);
$rule->file->not_name('*.svg');
my $next = $rule->iter(
  $root => {
    follow_symlinks => 0,
    sorted          => 0,
  }
);

while ( my $file = $next->() ) {
  *STDERR->print("\e[31m$file\e[0m matched.");
  my $path = path($file);
  if ( $ARGV[0] and $ARGV[0] eq '--apply' ) {
    *STDERR->print("\e[32m Applied!");
    my $source = $path->slurp_raw();
    $source =~ s/\r\n$/\n/gmsx;
    $source =~ s/[ \t\r]+\n/\n/gmsx;
    $path->spew_raw($source);
  }
  *STDERR->print("\e[0m\n");
}

