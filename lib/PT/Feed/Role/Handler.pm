use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed::Role::Handler;

# ABSTRACT: A thing that handles a feed

# AUTHORITY

use Moose::Role;

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

no Moose::Role;

1;

