package PT::DB::Result::UserEmail;
# ABSTRACT:

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use Digest::MD5 qw( md5_hex );
use namespace::autoclean;

table 'user_email';

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column users_id => {
  data_type => 'bigint',
  is_nullable => 0,
};

unique_column email => {
  data_type => 'text',
  is_nullable => 0,
};

column token => {
  data_type => 'text',
  is_nullable => 1,
};

column validated => {
  data_type => 'int',
  is_nullable => 0,
  default_value => 0,
};

column primary => {
  data_type => 'int',
  is_nullable => 0,
  default_value => 0,
};

column notes => {
  data_type => 'text',
  is_nullable => 1,
};

__PACKAGE__->add_data_created_updated;

belongs_to 'user', 'PT::DB::Result::User', 'users_id', { 
  on_delete => 'cascade',
};

###############################

sub request_validation {
  my ( $self ) = @_;
  return if $self->validated;
  unless ($self->token) {
    $self->token(md5_hex(int(rand(999_999_999))));
    $self->update;
  }
  $self->user->do(sub {
    $self->pt->postman->template_mail(
      $self->email,
      'Validate this email',
      'emailvalid',
      {
        validation_link =>
          $self->pt->config->web_base.'/my/emailvalidate/'.$self->user->id.'/'.$self->token,
      },
    );
  });
}

no Moose;
__PACKAGE__->meta->make_immutable;
