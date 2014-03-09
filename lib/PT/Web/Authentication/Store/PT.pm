package PT::Web::Authentication::Store::PT;
# ABSTRACT: Using a PT class as authentication store on Catalyst

use Moose;
use Scalar::Util qw( blessed );
use PT::Config;

has realm => (
  is => 'rw',
);

has _app => (
  is => 'rw',
);
sub c { shift->_app }

sub BUILDARGS {
  my ( $class, $config, $app, $realm ) = @_;

  my %options;
  
  $options{_app} = $app;
  $options{realm} = $realm;

  return \%options;
}

sub from_session {
  my ( $self, $c, $id ) = @_;
  return $id if ref $id;
  $c->pt->rs('User')->find($id);
}

sub find_user {
  my ( $self, $userinfo ) = @_;

  my $username;
  if ($self->realm->name eq 'username') {
    $username = delete $userinfo->{'username'};
    warn "can't handle other user attributes so far" if %{$userinfo};   
  } elsif ($self->realm->name eq 'facebook') {
    $username = delete $userinfo->{'token'};
    warn "can't handle other user attributes on facebook" if %{$userinfo};
  } elsif ($self->realm->name eq 'twitter') {

  }

  return unless $username;
  return $self->c->pt->find_user($self->realm->name,$username);
}

1;
