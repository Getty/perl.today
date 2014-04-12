use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed::Handler::Atom;

# ABSTRACT: A handler for processing Atom feeds

# AUTHORITY

use Moose;
use XML::Atom::Feed;
use PT::Log::Contextual qw( log_trace log_debug log_info );

with 'PT::Feed::Role::Handler';

sub _decode_atom {
  my ( $self, $string ) = @_;
  my $state = XML::Atom::Feed->new( \$string );
  return $state->entries;
}

=method C<on_http_success>

    ->on_http_success( $async_http_object, $feed_loop_object )

Triggers a get via the C<async_http_object>, then on HTTP response,
decodes it, and reports the found links to the database for addition.

=cut

sub on_http_success {
  my ( $self, $http_response, $feed_loop ) = @_;
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
    $self->add_url( $feed_loop->pt, $item->title, $item->link->href );
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

