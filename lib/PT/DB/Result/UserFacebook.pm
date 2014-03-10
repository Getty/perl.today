package PT::DB::Result::UserFacebook;

# ABSTRACT:

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'user_facebook';

column id => {
  data_type         => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column users_id => {
  data_type   => 'bigint',
  is_nullable => 0,
};

column code => {
  data_type   => 'bigint',
  is_nullable => 0,
};

column notes => {
  data_type   => 'text',
  is_nullable => 1,
};

column access_tokens => {
  data_type        => 'text',
  is_nullable      => 0,
  serializer_class => 'JSON',
  default_value    => '{}',
};

__PACKAGE__->add_data_created_updated;

belongs_to 'user', 'PT::DB::Result::User', 'users_id',
    { on_delete => 'cascade', };

###############################

no Moose;
__PACKAGE__->meta->make_immutable;
