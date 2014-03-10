package PT::Web::View::JSON;

# ABSTRACT: Standard Catalyst JSON view

use Moose;
use MooseX::NonMoose;
extends 'Catalyst::View::JSON';

__PACKAGE__->config(
  expose_stash => 'x',
  json_driver  => 'JSON::MaybeXS',
);

no Moose;
__PACKAGE__->meta->make_immutable;
