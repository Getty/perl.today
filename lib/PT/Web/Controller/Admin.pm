package PT::Web::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub base : Chained('/base') : PathPart('admin') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    unless ( $c->user && $c->user->admin ) {
        $c->response->redirect( $c->chained_uri( 'Root', 'index' ) );
        return $c->detach;
    }
    $c->breadcrumb_start('perl.today Administration');
}

sub index : Chained('base') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{title} = 'Administration';
}

__PACKAGE__->meta->make_immutable;

1;
