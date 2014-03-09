package PT::Web::Controller::AdminFeed;
use Moose;
use namespace::autoclean;

BEGIN { extends 'PT::Web::ControllerBase::CRUD'; }

sub base :Chained('/admin/base') :PathPart('feed') :CaptureArgs(0) {
  my ( $self, $c ) = @_;
  $c->stash->{object_key} = 'id';
  $c->stash->{object_name_attr} = 'url';
  $c->stash->{object_name} = 'feed';
  $c->stash->{object_title} = 'Feed';
  $c->stash->{object_title_list} = 'Feeds';
  $c->stash->{resultset} = $c->pt->rs('Feed');
  $c->stash->{crud_captures} = [];
  $c->stash->{buttons} = [{
    label => 'Test feed',
    u => sub {['AdminFeed','test',$_[0]->id]},
  }];
  $c->stash->{columns} = [
    'ID' => 'id',
    'URL' => 'url',
    'Class' => 'feed_class',
  ];
  $c->stash->{title} = 'Administration '.$c->stash->{object_title_list};
  $c->breadcrumb_add('Feeds',['AdminFeed','index']);
}

sub test :Chained('item') :Args(0) {
  my ( $self ) = @_;
}

__PACKAGE__->meta->make_immutable;
