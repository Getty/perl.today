package PT::DB::Result::Vote;
# ABSTRACT: Vote result class

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'vote';

sub u { 
  my ( $self ) = @_;
  if ( my $context_obj = $self->get_context_obj ) {
    if ($context_obj->can('u_votes')) {
      my $u = $context_obj->u_votes;
      return $u if $u;
    }
    if ($context_obj->can('u')) {
      my $u = $context_obj->u;
      return $u if $u;
    }
  }
  return;
}

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column users_id => {
  data_type => 'bigint',
  is_nullable => 1,
};

column vote => {
  data_type => 'int',
  is_nullable => 0,
  default_value => 1,
};

__PACKAGE__->add_context_relations;

__PACKAGE__->add_created_updated;

unique_column [qw(
  users_id context context_id
)];

belongs_to 'user', 'PT::DB::Result::User', 'users_id', {
  on_delete => 'no action',
};

__PACKAGE__->indices(
  vote_context_idx => 'context',
  vote_context_id_idx => 'context_id',
  vote_created_idx => 'created',
  vote_updated_idx => 'updated',
);

after insert => sub {
  my ( $self ) = @_;
  $self->add_event('create');
};

after update => sub {
  my ( $self ) = @_;
  $self->add_event('update');
};

sub event_related {
  my ( $self ) = @_;
  my @related;
  if ( $self->context_resultset ) {
    push @related, [$self->context, $self->context_id];
    push @related, $self->get_context_obj->event_related if $self->get_context_obj->can('event_related');
  }
  return @related;
}

###############################

no Moose;
__PACKAGE__->meta->make_immutable;

1;
