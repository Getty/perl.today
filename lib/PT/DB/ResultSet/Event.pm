package PT::DB::ResultSet::Event;

# ABSTRACT: Resultset class for event entries

use Moose;
extends 'PT::DB::ResultSet';
use namespace::autoclean;

sub prefetch_all {
  my ($self) = @_;
  return $self->search_rs(
    {},
    { prefetch =>
          [ qw( event_relates ), { %{ $self->prefetch_context_config }, } ],
    }
  );
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
