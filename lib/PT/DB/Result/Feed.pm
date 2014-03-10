package PT::DB::Result::Feed;

# ABSTRACT: Feed

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'feed';

column id => {
  data_type         => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column url => {
  data_type   => 'text',
  is_nullable => 0,
};

column feed_class => {
  data_type   => 'text',
  is_nullable => 0,
};

column feed_args => {
  data_type        => 'text',
  is_nullable      => 0,
  serializer_class => 'JSON',
  default_value    => '{}',
};

__PACKAGE__->add_data_created_updated;

sub field_list {
  my ($self) = @_;
  [ url        => $self->field_url,
    feed_class => { type => 'Text', required => 1, },
    feed_args  => {
      type           => 'TextArea',
      inflate_method => sub { $_[0]->form->inflate_json( $_[1] ) },
      deflate_method => sub { $_[0]->form->deflate_json( $_[1] ) },
    },
  ];
}

1;
