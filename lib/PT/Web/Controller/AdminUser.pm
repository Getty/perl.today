package PT::Web::Controller::AdminUser;
use Moose;
use namespace::autoclean;

BEGIN { extends 'PT::Web::ControllerBase::CRUD'; }

sub base :Chained('/admin/base') :PathPart('user') :CaptureArgs(0) {
  my ( $self, $c ) = @_;
  $c->stash->{object_key} = 'id';
  $c->stash->{object_name_attr} = 'username';
  $c->stash->{object_name} = 'user';
  $c->stash->{object_title} = 'User';
  $c->stash->{object_title_list} = 'Users';
  $c->stash->{resultset} = $c->pt->rs('User');
  $c->stash->{crud_captures} = [];
  $c->stash->{buttons} = [];
  $c->stash->{columns} = [
    'ID' => 'id',
    'Username' => 'username',
  ];
  $c->stash->{title} = 'Administration '.$c->stash->{object_title_list};
  $c->breadcrumb_add('Users',['AdminUser','index']);
}

__PACKAGE__->meta->make_immutable;
