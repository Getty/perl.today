package PT::DB::ResultSet::User;

# ABSTRACT: Resultset class for user

use Moose;
extends 'PT::DB::ResultSet';
use Email::Valid;
use namespace::autoclean;

sub latest {
  my ($self) = @_;
  return $self->search( {}, { order_by => { desc => 'created' }, } );
}

sub find_by_username {
  my ( $self, $username ) = @_;
  if ( Email::Valid->address($username) ) {
    return $self->find_by_email($username);
  }
  else {
    my $user = $self->search(
      \[ 'LOWER(me.username) LIKE ?', [ plain_value => lc($username) ] ] )
        ->first;
    return $user if $user;
  }
  return;
}

sub find_by_facebook {
  my ( $self, $code ) = @_;
  my $user_facebook =
      $self->schema->rs('UserFacebook')->find( { code => $code, } );
  if ($user_facebook) {
    return $user_facebook->user;
  }
  return;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
