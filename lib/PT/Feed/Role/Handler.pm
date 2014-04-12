use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed::Role::Handler;

# ABSTRACT: A thing that handles a feed

# AUTHORITY

use Moose::Role;
use PT::Log::Contextual qw( log_trace log_debug log_info );

has 'feed' => (
  isa      => 'PT::DB::Result::Feed',
  is       => ro =>,
  required => 1,
  handles  => { url => 'url', },
);

=requires C<on_http_response>

    on_http_success( $HTTP_RESPONSE_OBJECT, $PT_FEED_LOOP_OBJECT );

=cut

requires 'on_http_success';

=method C<on_http_response>

  on_http_response( $HTTP_RESPONSE_OBJECT, $PT_FEED_LOOP_OBJECT );

Dispatches to C<on_http_success> if C<$HTTP_RESPONSE_OBJECT> is successful.

Otherwise C<log_info> and skip processing.

=cut

sub on_http_response {
  my ( $self, $http_response, $feed_loop ) = @_;
  my $is_success = $http_response->is_success;
  log_trace {
    sprintf
        "Handler.on_http_response: feed=[%s] class=[%s] url=[%s] success=[%s]",
        $self->feed->name,
        $self->feed->feed_class,
        $self->feed->url,
        ( $is_success ? 1 : 0 );
  };
  if ( not $is_success ) {
    log_info {
      sprintf
          "Handler.on_http_response: HTTP Request Failed. feed=[%s] class=[%s] url=[%s] status=[%s]",
          $self->feed->name,
          $self->feed->feed_class,
          $self->feed->url,
          $http_response->status_line;
    };
    return;
  }
  return $self->on_http_success( $http_response, $feed_loop );
}

=method C<trigger_http_update>

    $handler->trigger_http_update( $async_http_object, $PT_FEED_LOOP_OBJECT )

=cut

sub trigger_http_update {
  my ( $self, $async_http, $feed_loop ) = @_;
  $async_http->do_request(
    uri         => URI->new( $self->url ),
    on_response => sub {
      my ($response) = @_;
      $self->on_http_response( $response, $feed_loop );
    },
  );
}

=method C<add_url>

Utility method to be called from C<on_http_response> to signal
that this feed has items.

=cut

sub add_url {
  my ( $self, $pt, $title, $url ) = @_;
  return unless $title;
  return unless $url;
  log_trace {
    sprintf "Handler.add_url: feed=[%s] class=[%s] title=[%s] url=[%s]",
        $self->feed->name,
        $self->feed->feed_class,
        $title,
        $url;
  };
  $pt->add_feed_uri(
    feed  => $self->feed,
    title => $title,
    link  => $url,
  );
  return;
}

no Moose::Role;

1;

