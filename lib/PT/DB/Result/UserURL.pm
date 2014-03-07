package PT::DB::Result::UserURL;
# ABSTRACT:

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'user_url';

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column users_id => {
  data_type => 'bigint',
  is_nullable => 0,
};

column url_id => {
  data_type => 'bigint',
  is_nullable => 0,
};

column title => {
  data_type => 'text',
  is_nullable => 0,
};

__PACKAGE__->add_created_updated;

belongs_to 'url', 'PT::DB::Result::URL', 'url_id', { 
  on_delete => 'cascade',
};

###############################

no Moose;
__PACKAGE__->meta->make_immutable;
