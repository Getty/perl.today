package PT::DB::Result::EventRelate;
# ABSTRACT: A context relation of an event

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'event_relate';

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column event_id => {
  data_type => 'bigint',
  is_nullable => 0,
};
belongs_to 'event', 'PT::DB::Result::Event', 'event_id', {
  on_delete => 'cascade',
};

__PACKAGE__->add_context_relations;

__PACKAGE__->add_created;

__PACKAGE__->indices(
  event_related_context_idx => 'context',
  event_related_context_id_idx => 'context_id',
);

###############################

no Moose;
__PACKAGE__->meta->make_immutable;
