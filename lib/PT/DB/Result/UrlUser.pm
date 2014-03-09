package PT::DB::Result::UrlUser;
# ABSTRACT:

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'url_user';

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column url_id => {
  data_type => 'bigint',
  is_nullable => 0,
};

column user_id => {
  data_type => 'bigint',
  is_nullable => 0,
};

column title => {
  data_type => 'text',
  is_nullable => 1,
};

column description => {
  data_type => 'text',
  is_nullable => 1,
};

__PACKAGE__->add_data_created_updated;

belongs_to 'url', 'PT::DB::Result::Url', 'url_id';
belongs_to 'user', 'PT::DB::Result::Feed', 'user_id';

###############################

no Moose;
__PACKAGE__->meta->make_immutable;
