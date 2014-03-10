package PT::Web::Controller::Incoming;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub base : Chained('/base') : PathPart('incoming') : CaptureArgs(0) {
  my ( $self, $c ) = @_;
  unless ( $c->user ) {
    $c->response->redirect( $c->chained_uri( 'Root', 'index' ) );
    return $c->detach;
  }
}

sub index : Chained('base') : PathPart('') : Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{title} = 'Incoming links';
}

__PACKAGE__->meta->make_immutable;

1;
