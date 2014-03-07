package PT::Web::Model::PT;
# ABSTRACT: Adaptor model to connect PT to Catalyst

use Moose;
extends 'Catalyst::Model::Adaptor';

use Catalyst::Utils;

__PACKAGE__->config( class => 'PT' );

my $pt_test;

sub _create_instance {
  my ($self, $app, $rest) = @_;

  my $constructor = $self->{constructor} || 'new';
  my $arg = $self->prepare_arguments($app, $rest);

  if (defined $ENV{PT_TESTING} && $ENV{PT_TESTING}) {
    Catalyst::Utils::ensure_class_loaded("PT::Test::Database");
    return PT::Test::Database->for_test($ENV{PT_TESTING})->d;
  }

  my $adapted_class = $self->{class};

  return $adapted_class->$constructor($self->mangle_arguments($arg));
}

no Moose;
__PACKAGE__->meta->make_immutable;
