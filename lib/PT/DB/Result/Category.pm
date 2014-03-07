package PT::DB::Result::Category;
# ABSTRACT:

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'category';

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column parent_id => {
  data_type => 'bigint',
  is_nullable => 1,
};

column tree_path => {
  data_type => 'text',
  is_nullable => 1,
  is_serializable => 0,  
};

column pos => {
  data_type => 'int',
  is_nullable => 0,
};

column name => {
  data_type => 'text',
  is_nullable => 0,
  is_serializable => 1,
};

__PACKAGE__->add_data_created_updated;

belongs_to 'parent', 'PT::DB::Result::Category', 'parent_id', { 
  on_delete => 'cascade',
  join_type => 'left',
};

has_many 'children', 'PT::DB::Result::Category', 'parent_id', {
  cascade_delete => 1,
};

before [qw( update )] => sub {
  my ( $self ) = @_;
  $self->set_tree_path;
};

sub set_tree_path {
  my ( $self ) = @_;
  if ($self->parent_id) {
    $self->tree_path($self->parent->tree_path.$self->id.',');
  } else {
    $self->tree_path(','.$self->id.',');
  }
};

no Moose;
__PACKAGE__->meta->make_immutable;
