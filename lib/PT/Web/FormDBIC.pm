package PT::Web::FormDBIC;

use Moose;
extends 'PT::Web::Form';

with qw(
  HTML::FormHandler::TraitFor::Model::DBIC
);

no Moose;
__PACKAGE__->meta->make_immutable;
