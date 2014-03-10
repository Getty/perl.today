package PT::DB;

# ABSTRACT: DBIx::Class schema

use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Schema';
use Cache::FileCache;
use Carp;

__PACKAGE__->load_namespaces( default_resultset_class => 'ResultSet', );

use namespace::autoclean;

$ENV{DBIC_NULLABLE_KEY_NOWARN} = 1;

has _pt => (
  isa => 'PT',
  is  => 'rw',
);
sub pt { shift->_pt }

sub rs { shift->resultset(@_) }

sub connect {
  my ( $self, $pt ) = @_;
  $pt = $self->pt if ref $self;
  my $schema = $self->next::method(
    $pt->config->db_dsn(),      $pt->config->db_user(),
    $pt->config->db_password(), $pt->config->db_params(),
  );
  $schema->_pt($pt);
  $schema->default_resultset_attributes( { cache_object => $pt->cache, } );
  return $schema;
}

has no_events => (
  isa     => 'Bool',
  is      => 'rw',
  default => sub {0},
);

sub without_events {
  my ( $self, $code ) = @_;
  die "without_events need coderef" unless ref $code eq 'CODE';
  my $change_it = $self->no_events ? 0 : 1;
  $self->no_events(1) if $change_it;
  eval { $code->(); };
  $self->no_events(0) if $change_it;
  croak $@ if $@;
  return;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
