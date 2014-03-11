use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed::Handler::RSS;

# ABSTRACT: A handler for processing RSS feeds

# AUTHORITY

use Moose;
use XML::RSS;

with 'PT::Feed::Role::Handler';

sub _decode_rss {
  my ( $self, $string ) = @_;
  my $state = XML::RSS->new();
  $state->parse($string);
  return @{ $state->{'items'} };
}

=method C<on_http_response>

    ->on_http_response( $async_http_object, $feed_loop_object )

Triggers a get via the C<async_http_object>, then on HTTP response,
decodes it, and reports the found links to the database for addition.

=cut

sub on_http_response {
  my ( $self, $http_response, $feed_loop ) = @_;
  return unless $http_response->is_success;
  my $content = $http_response->decoded_content;
  my (@items) = $self->_decode_rss($content);
  for my $item (@items) {
    next unless $item->{'title'};
    next unless $item->{'link'};

#STDERR->printf("Got URI title=%s url=%s\n", $item->{'title'}, $item->{'link'} );
    $feed_loop->pt->add_feed_uri(
      feed  => $self->url,
      title => $item->{'title'},
      link  => $item->{'link'},
    );
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

