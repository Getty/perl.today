use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed::Handler::Atom;

# ABSTRACT: A handler for processing Atom feeds

# AUTHORITY

use Moose;
use XML::Atom::Feed;
use Log::Contextual qw( log_trace log_debug log_info );

with 'PT::Feed::Role::Handler';

sub _decode_atom {
  my ( $self, $string ) = @_;
  my $state = XML::Atom::Feed->new( \$string );
  return $state->entries;
}

=method C<on_http_response>

    ->on_http_response( $async_http_object, $feed_loop_object )

Triggers a get via the C<async_http_object>, then on HTTP response,
decodes it, and reports the found links to the database for addition.

=cut

sub on_http_response {
  my ( $self, $http_response, $feed_loop ) = @_;
  log_trace {
    sprintf 'Handler.Atom.response for %s = %s', $self->url,
        $http_response->is_success ? 1 : 0;
  };
  if ( not $http_response->is_success ) {
    log_info {
      sprintf 'Handler.Atom.response got no response for %s', $self->url;
    };
  }
  return unless $http_response->is_success;
  my $content = $http_response->decoded_content;
  my (@items) = $self->_decode_atom($content);
  log_trace {
    sprintf 'Handler.Atom.response for %s got %s items', $self->url,
        scalar @items;
  };
  if ( not @items ) {
    log_info {
      sprintf 'Handler.Atom.response got no items for %s', $self->url;
    };
    return;
  }
  for my $item (@items) {
    next unless $item->title;
    next unless $item->link->href;

    log_trace {
      sprintf 'Handler.Atom.response.add_feed_uri feed=%s title=%s url=%s',
          $self->url,
          $item->title,
          $item->link->href;
    };
    $feed_loop->pt->add_feed_uri(
      feed  => $self->url,
      title => $item->title,
      link  => $item->link->href,
    );
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

