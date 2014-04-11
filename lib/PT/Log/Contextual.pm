use 5.010;    # state
use strict;
use warnings;
use utf8;

package PT::Log::Contextual;

# ABSTRACT: Default implying baseclass for Log::Contexual

# AUTHORITY

use parent 'Log::Contextual';

use constant LOG_KEY => 'PT_LOG_LEVEL';

my %user_levels;
my @all_levels =
    qw( trace debug info notice warning error critical alert emergency );

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

sub arg_default_logger {
  my ( $self, $logger ) = @_;
  return $logger if $logger;
  return state $simple_logger = do {
    require Log::Contextual::SimpleLogger;
    Log::Contextual::SimpleLogger->new( { levels => $wanted_levels } );
  };
}

sub arg_levels {
  return [@all_levels];
}

1;

