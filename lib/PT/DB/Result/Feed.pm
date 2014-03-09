package PT::DB::Result::Feed;
# ABSTRACT: Feed

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'feed';

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column url => {
  data_type => 'text',
  is_nullable => 0,
};

column feed_class => {
  data_type => 'text',
  is_nullable => 0,
};

column feed_args => {
  data_type => 'text',
  is_nullable => 0,
  default_value => '{}',
};

__PACKAGE__->add_data_created_updated;

no Moose;
__PACKAGE__->meta->make_immutable;
