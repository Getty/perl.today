package PT::DB::Result::Session;

# ABSTRACT: Sessions

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'session';

column id => {
    data_type   => 'text',
    is_nullable => 0,
};
primary_key 'id';

column session_data => {
    data_type   => 'text',
    is_nullable => 1,
};

column expires => {
    data_type   => 'bigint',
    is_nullable => 1,
};

no Moose;
__PACKAGE__->meta->make_immutable;
