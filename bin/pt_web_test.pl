#!/usr/bin/env perl

# PODNAME: pt_web_test.pl

# ABSTRACT: Catalyst Test

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run( 'PT::Web', 'Test' );

1;

=head1 SYNOPSIS

pt_web_test.pl [options] uri

 Options:
   --help    display this help and exits

 Examples:
   pt_web_test.pl http://localhost/some_action
   pt_web_test.pl /some_action

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst action from the command line.

