use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed;

# ABSTRACT: A Feed Fetching and Processing Loop

# AUTHORITY

use Moose;
use Module::Runtime qw( compose_module_name require_module );

=method C<feed_handler>

  my $handler = PT::Feed->feed_handler( $class, $url, %handler_args );

For instance, if C<$class> is C<RSS>, then this code expands to:

  require PT::Feed::Handler::RSS;
  return  PT::Feed::Handler::RSS->new(
      url => $url,
      %handler_args,
  );

=cut

sub feed_handler {
  my ( undef, $feed_class, $url, %args ) = @_;
  my $handler_name = compose_module_name( 'PT::Feed::Handler', $feed_class );
  require_module($handler_name);
  return $handler_name->new(
    url => $url,
    %args,
  );
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;

