use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed::Loop;

# ABSTRACT: Core eventloop for Feed with IO::Async

# AUTHORITY

use Moose;
use IO::Async;
use IO::Async::Timer::Periodic;
use IO::Async::SSL;
use Net::Async::HTTP;
use PT::DB;
use PT::Feed::Handler::RSS;
use PT::Log::Contextual qw( log_debug log_trace );

=head1 SYNOPSIS

    my $pt   = PT->new();
    my $loop = PT::Feed::Loop->new(
        pt => $pt,
    );
    $loop->run;

=cut

has 'http_agent' => (
  is         => ro =>,
  lazy_build => 1,
);
has 'loop' => (
  is         => ro =>,
  lazy_build => 1,
);
has 'pt' => (
  is       => ro =>,
  required => 1,
);
has 'update_worker' => (
  is         => ro =>,
  lazy_build => 1,
);
has 'update_interval' => ( is => ro => default => sub {60}, );

sub _build_loop {
  my ($self) = @_;
  my $loop = IO::Async::Loop->new();
  $loop->add( $self->http_agent );
  $loop->add( $self->update_worker );
  return $loop;
}

sub _build_http_agent {
  my ($self) = @_;
  return Net::Async::HTTP->new();
}

sub _build_update_worker {
  my ($self) = @_;
  return IO::Async::Timer::Periodic->new(
    interval       => $self->update_interval,
    first_interval => 5,
    on_tick        => sub {
      log_debug {"Loop.Tick"};
      $self->do_update;
    },
  );
}

=method C<do_update>

Visits all items in the C<Feed> table and schedules an update event for each.

=cut

sub do_update {
  my ($self) = @_;
  my $rs = $self->pt->db->resultset('Feed')->search;
  while ( my $feed = $rs->next ) {
    my $handler = $feed->feed_handler;
    log_trace {
      sprintf "Trigger.Update feed.name=%s feed.url=%s", $feed->name,
          $feed->url;
    };
    $handler->trigger_http_update( $self->http_agent, $self );
  }
  return;
}

=method C<run>

Starts the eventloop

=cut

sub run {
  my ($self) = @_;
  log_trace {"Loop: Starting Periodic update ticker"};
  $self->update_worker->start;
  log_trace {"Loop: Starting Main Loop"};
  return $self->loop->run;
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;

