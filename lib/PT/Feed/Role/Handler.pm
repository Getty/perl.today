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

    on_http_response( $HTTP_RESPONSE_OBJECT, $PT_FEED_LOOP_OBJECT );

=cut

requires 'on_http_response';

=method C<trigger_http_update>

    $handler->trigger_http_update( $async_http_object, $PT_FEED_LOOP_OBJECT )

=cut

sub trigger_http_update {
  my ( $self, $async_http, $backing_store ) = @_;
  $async_http->do_request(
    uri         => URI->new( $self->url ),
    on_response => sub {
      my ($response) = @_;
      $self->on_http_response( $response, $backing_store );
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

