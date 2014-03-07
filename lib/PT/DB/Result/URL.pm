package PT::DB::Result::URL;
# ABSTRACT: URL

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'url';

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column url => {
  data_type => 'text',
  is_nullable => 0,
};

column title => {
  data_type => 'text',
  is_nullable => 1,
};

__PACKAGE__->add_data_created_updated;

has_many 'user_urls', 'PT::DB::Result::UserURL', 'users_id', {
  cascade_delete => 1,
};

no Moose;
__PACKAGE__->meta->make_immutable;
