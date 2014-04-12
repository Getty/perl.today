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

column name => {
  data_type   => 'text',
  is_nullable => 0,
};

column url => {
  data_type   => 'text',
  is_nullable => 0,
};

# not shown if not given
column web_url => {
  data_type   => 'text',
  is_nullable => 1,
};

# using of web_url favicon.ico if not set
column icon_url => {
  data_type   => 'text',
  is_nullable => 1,
};

# workaround flag till introduction of categories
column jobs => {
  data_type     => 'int',
  is_nullable   => 0,
  default_value => 0,
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
    name       => { type => 'Text', required => 1, },
    feed_class => { type => 'Text', required => 1, },
    feed_args  => {
      type           => 'TextArea',
      inflate_method => sub { $_[0]->form->inflate_json( $_[1] ) },
      deflate_method => sub { $_[0]->form->deflate_json( $_[1] ) },
    },
  ];
}

=method C<feed_handler>

Fetch an instance of a C<PT::Feed::Handler::*> for the current feed.

  my $handler = $result->feed_handler();

The exact handler returned will be based on C<$feed_class>

=cut

sub feed_handler {
  my ($self) = @_;
  require PT::Feed;
  return PT::Feed->feed_handler( $self->feed_class, $self,
    %{ $self->feed_args } );
}

1;
