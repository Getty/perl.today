use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed::Handler::RSS;

# ABSTRACT: A handler for processing RSS feeds

# AUTHORITY

use Moose;
use XML::RSS;
use PT::Log::Contextual qw( log_trace log_debug log_info );

with 'PT::Feed::Role::Handler';

sub _decode_rss {
  my ( $self, $string ) = @_;
  my $state = XML::RSS->new();
  $state->parse($string);
  return @{ $state->{'items'} };
}

=method C<on_http_success>

    ->on_http_success( $async_http_object, $feed_loop_object )

Triggers a get via the C<async_http_object>, then on HTTP response,
decodes it, and reports the found links to the database for addition.

=cut

sub on_http_success {
  my ( $self, $http_response, $feed_loop ) = @_;
  my $content = $http_response->decoded_content;
  my (@items) = $self->_decode_rss($content);
  log_trace {
    sprintf 'Handler.RSS.response for %s got %s items', $self->url,
        scalar @items;
  };
  if ( not @items ) {
    log_info {
      sprintf 'Handler.RSS.response got no items for %s', $self->url;
    };
    return;
  }
  for my $item (@items) {
    $self->add_url( $feed_loop->pt, $item->{'title'}, $item->{'link'} );
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

