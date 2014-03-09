package PT::Web::Controller::AdminFeed;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub base :Chained('/admin/base') :PathPart('feed') :CaptureArgs(0) {
  my ( $self, $c ) = @_;
  unless ($c->user->admin) {
    $c->response->redirect($c->chained_uri('Root','index'));
    return $c->detach;
  }
  $c->breadcrumb_add('Feeds',['AdminFeed','index']);
}

sub index :Chained('base') :PathPart('') :Args(0) {
  my ( $self, $c ) = @_;
 $c->stash->{title} = 'Feeds';
}

__PACKAGE__->meta->make_immutable;

1;
