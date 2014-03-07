package PT::DB::Result::CommentVote;
# ABSTRACT: A vote of a user on a comment

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'comment_vote';

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column users_id => {
  data_type => 'bigint',
  is_nullable => 0,
};

column comment_id => {
  data_type => 'bigint',
  is_nullable => 0,
};

__PACKAGE__->add_created;

unique_constraint(
  comment_users => [qw/ comment_id users_id /]
);

belongs_to 'user', 'PT::DB::Result::User', 'users_id', {
  on_delete => 'cascade',
};
belongs_to 'comment', 'PT::DB::Result::Comment', 'comment_id', {
  on_delete => 'cascade',
};

after insert => sub {
  my ( $self ) = @_;
  $self->add_event('create');
};

sub event_related {
  my ( $self ) = @_;
  my @related;
  push @related, ['PT::DB::Result::Comment', $self->comment_id];
  return @related;
}

no Moose;
__PACKAGE__->meta->make_immutable;
