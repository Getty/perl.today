package PT::DB::Result::Comment;

# ABSTRACT: Comment result class

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

with qw(
    PT::DB::Role::UpDownVote
);

table 'comment';

sub u {
  my ($self) = @_;
  if ( my $context_obj = $self->get_context_obj ) {
    if ( $context_obj->can('u_comments') ) {
      my $u = $context_obj->u_comments;
      return $u if $u;
    }
    if ( $context_obj->can('u') ) {
      my $u = $context_obj->u;
      return $u if $u;
    }
  }
  return $self->u_comments;
}

sub u_comments { [ 'Forum', 'comment', $_[0]->id ] }

column id => {
  data_type         => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column users_id => {
  data_type   => 'bigint',
  is_nullable => 1,
};

column content => {
  data_type   => 'text',
  is_nullable => 0,
};

__PACKAGE__->add_context_relations;

column deleted => {
  data_type     => 'int',
  default_value => 0,
};

column parent_id => {
  data_type   => 'bigint',
  is_nullable => 1,
};

__PACKAGE__->add_data_created_updated;

sub root_comment { $_[0]->parent_id ? 0 : 1 }

belongs_to 'user', 'PT::DB::Result::User', 'users_id',
    { on_delete => 'no action', };

belongs_to 'parent', 'PT::DB::Result::Comment', 'parent_id',
    { join_type => 'left', };

has_many 'children', 'PT::DB::Result::Comment', 'parent_id';

__PACKAGE__->indices(
  comment_context_idx    => 'context',
  comment_context_id_idx => 'context_id',
  comment_created_idx    => 'created',
  comment_updated_idx    => 'updated',
);

sub comments { shift->children_rs }

after insert => sub {
  my ($self) = @_;
  $self->add_event('create');
  $self->user->add_context_notification( 'replies', $self );
};

after update => sub {
  my ($self) = @_;
  $self->add_event('update');
};

before delete => sub {
  my ($self) = @_;
  die "Can't kill a comment with children" if $self->children->count;
};

sub event_related {
  my ($self) = @_;
  my @related;
  if ( $self->parent_id ) {
    push @related, [ 'PT::DB::Result::Comment', $self->parent_id ];
  }
  if ( $self->context_resultset ) {
    push @related, [ $self->context, $self->context_id ];
    push @related, $self->get_context_obj->event_related
        if $self->get_context_obj->can('event_related');
  }
  return @related;
}

###############################

no Moose;
__PACKAGE__->meta->make_immutable;

1;
