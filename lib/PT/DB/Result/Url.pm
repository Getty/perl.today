package PT::DB::Result::Url;

# ABSTRACT: URL

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'url';

column id => {
  data_type         => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column url => {
  data_type   => 'text',
  is_nullable => 0,
};

column title => {
  data_type   => 'text',
  is_nullable => 1,
};

column content_type => {
  data_type   => 'text',
  is_nullable => 1,
};

column content_timestamp => {
  data_type   => 'timestamp with time zone',
  is_nullable => 1,
};

has_many 'url_feeds', 'PT::DB::Result::UrlFeed', 'url_id',
    { cascade_delete => 0, };

__PACKAGE__->add_data_created_updated;

no Moose;
__PACKAGE__->meta->make_immutable;
