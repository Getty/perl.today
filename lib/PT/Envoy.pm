package PT::Envoy;

# ABSTRACT: Notification component

use Moose;
use DateTime;
use DateTime::Duration;

has pt => (
  isa      => 'PT',
  is       => 'ro',
  required => 1,
  weak_ref => 1,
);

sub format_datetime {
  shift->pt->db->storage->datetime_parser->format_datetime(shift);
}

has last_update => (
  isa       => 'DateTime',
  is        => 'rw',
  clearer   => 'clear_last_update',
  predicate => 'has_last_update',
);

sub update_own_notifications {
  my ($self) = @_;
  if ( $self->has_last_update ) {
    return
        unless $self->last_update
        < ( DateTime->now - DateTime::Duration->new( seconds => 30 ) );
  }
  $self->last_update( DateTime->now );
  return $self->update_notifications_where(
    pid          => $self->pt->config->pid,
    nid          => $self->pt->config->nid,
    'me.created' => {
      ">=" => $self->format_datetime(
        DateTime->now - DateTime::Duration->new( minutes => 2 )
      )
    },
  );
}

sub update_node_notifications {
  my ($self) = @_;
  return $self->update_notifications_where(
    nid          => $self->pt->config->nid,
    'me.created' => {
      "<" => $self->format_datetime(
        DateTime->now - DateTime::Duration->new( minutes => 2 )
      )
    }
  );
}

sub update_outdated_notifications {
  my ($self) = @_;
  return $self->update_notifications_where(
    'me.created' => {
      "<" => $self->format_datetime(
        DateTime->now - DateTime::Duration->new( minutes => 4 )
      )
    }
  );
}

# shortcut for deploy and test runs
sub update_all_notifications {
  my ($self) = @_;
  return $self->update_notifications_where();
}

sub update_notifications_where {
  my ( $self, %where ) = @_;
  $self->notify_events(
    $self->pt->rs('Event')->prefetch_all->search_rs( \%where )
        ->search( { notified => 0 } )->all );
}

sub unsent_notifications_cycle_users {
  my ( $self, $cycle ) = @_;
  $self->pt->rs('EventNotification')->search_rs(
    { 'me.sent'                 => 0,
      'user_notification.cycle' => $cycle,
    },
    { select => [ { distinct => 'user_notification.users_id' } ],
      as   => [qw( users_id )],
      join => [qw( user_notification )],
    }
  );
}

sub notify_events {
  my ( $self, @events ) = @_;
  for my $ev (@events) {
    $ev->notify;
  }
  return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
