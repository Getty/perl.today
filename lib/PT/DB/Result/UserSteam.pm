package PT::DB::Result::UserSteam;

# ABSTRACT:

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'user_steam';

column id => {
    data_type         => 'bigint',
    is_auto_increment => 1,
};
primary_key 'id';

column users_id => {
    data_type   => 'bigint',
    is_nullable => 0,
};

column steam_id => {
    data_type   => 'text',
    is_nullable => 0,
};

column notes => {
    data_type   => 'text',
    is_nullable => 1,
};

__PACKAGE__->add_data_created_updated;

belongs_to 'user', 'PT::DB::Result::User', 'users_id',
    { on_delete => 'cascade', };

###############################

no Moose;
__PACKAGE__->meta->make_immutable;
