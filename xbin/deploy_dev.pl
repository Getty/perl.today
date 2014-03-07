#!/usr/bin/env perl

$|=1;

use FindBin;
use lib $FindBin::Dir . "/../lib"; 

use strict;
use warnings;

use PT;
use PT::Test::Database;
use File::Path qw( make_path remove_tree );
use String::ProgressBar;
use POSIX;
use DBI;

use Getopt::Long;

my $config = PT::Config->new;

my $kill;
my $start;

GetOptions (
  "kill"  => \$kill,
  "start" => \$start,
);

if ($kill) {
  remove_tree($config->rootdir_path);
  # TODO: replace parsing of dsn using regex with some CPAN module, DRY
  my $db = $1;
  my $userarg = length($config->db_user) ? "-U ".$config->db_user : "";
  print "Truncating database...\n";
  system("dropdb ".$userarg." ".$config->db_name);
  if ( !WIFEXITED(${^CHILD_ERROR_NATIVE}) ) {
    my $dsn = $config->db_dsn;
    $dsn =~ s/(database|dbname)=[\w\d]+/$1=postgres/;
    my $dbh = DBI->connect(
      $dsn, $config->db_user, $config->db_password
    );
    $dbh->do("DROP DATABASE ".$config->db_name) or die $dbh->errstr;
    $dbh->do("CREATE DATABASE ".$config->db_name) or die $dbh->errstr;
  } else {
    system("createdb ".$userarg." ".$config->db_name);
  }
} elsif (-d $config->rootdir_path) {
  die "environment exist, use --kill to kill it!";
}

print "\n";
print "Generating development environment, this may take a while...\n";
print "============================================================\n";
print "\n";
print "Deploying fresh environment into ".$config->rootdir_path."\n";
print "Deploying database structure to dsn '".$config->db_dsn."'\n";
print "\n";

my $pt = PT->new({ config => $config });

my $pr; 

my $pt_test = PT::Test::Database->new($pt,0,sub {
  print "\n";
  print "Filling database with test data and updating notifications...\n";
  print "(It will halt for a bit in the middle to gather all events)\n";
  print "\n";
  $pr = String::ProgressBar->new(
    max => shift,
    length => 60,
    bar => '#',
    show_rotation => 1,
    print_return => 0,
  );
  $pr->write;
},sub {
  $pr->update(shift);
  $pr->write;
});
$pt_test->deploy;

print "\n";
print "done\n";
print "\n";
print "everything done... You can start the development webserver with:\n\n";
print "  bin/pt_web_server.pl -r -d\n\n";
