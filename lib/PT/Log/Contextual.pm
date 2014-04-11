use 5.010;    # state
use strict;
use warnings;
use utf8;

package PT::Log::Contextual;

# ABSTRACT: Default implying baseclass for Log::Contexual

# AUTHORITY

use parent 'Log::Contextual';

=head1 SYNOPSIS

  use PT::Log::Contextual qw( log_info log_debug log_trace );

  ...

  log_debug {  "message"  };
  log_trace {  "trace"  };

  ...
  perl foo.pl          # message doesn't log
  PT_LOG_LEVEL="debug" perl foo.pl # message logs, trace doesn't
  PT_LOG_LEVEL="trace" perl foo.pl # message logs, trace logs
  PT_LOG_LEVEL="info"  perl foo.pl # no logs from debug/trace

See L<< C<Log::Contextual>|Log::Contextual >> for details.

=cut

use constant LOG_KEY => 'PT_LOG_LEVEL';

my %user_levels;
my @all_levels =
    qw( trace debug info notice warning error critical alert emergency );

# This creates a diamond tree of levels
# so trace => all
#    debug => all - trace
#    info  => all - trace and debug etc.
for my $level (@all_levels) {
  for my $user_level ( keys %user_levels ) {
    push @{ $user_levels{$user_level} }, $level;
  }
  $user_levels{$level} = [$level];
}

my $wanted_user_level = 'notice';

if ( exists $ENV{ LOG_KEY() } ) {
  my $env_wants = lc $ENV{ LOG_KEY() };
  last unless exists $user_levels{$env_wants};
  $wanted_user_level = $env_wants;
}

my $wanted_levels = $user_levels{$wanted_user_level};

=method C<arg_default_logger>

Provides a L<< C<Log::Contextual::SimpleLogger>|Log::Contextual::SimpleLogger >> instance
that logs all levels at and above the C<< $ENV{PT_LOG_LEVEL} >> log level.

Defaults to logging at and above C<notice> level.

=cut

sub arg_default_logger {
  my ( $self, $logger ) = @_;
  return $logger if $logger;
  return state $simple_logger = do {
    require Log::Contextual::SimpleLogger;
    Log::Contextual::SimpleLogger->new( { levels => $wanted_levels } );
  };
}

=method C<arg_levels>

Defines the default list of levels:

   trace debug info notice warning error critical alert emergency

=cut

sub arg_levels {
  return [@all_levels];
}

1;

