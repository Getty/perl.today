package PT::DB::Result::EventNotification;

# ABSTRACT: Notification of a specific user for a specific event

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'event_notification';

column id => {
  data_type         => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

column event_id => {
  data_type   => 'bigint',
  is_nullable => 0,
};

column sent => {
  data_type     => 'int',
  is_nullable   => 0,
  default_value => 0,
};

column sent => {
  data_type     => 'int',
  is_nullable   => 0,
  default_value => 0,
};

column seen => {
  data_type     => 'int',
  is_nullable   => 0,
  default_value => 0,
};

column event_notification_group_id => {
  data_type   => 'bigint',
  is_nullable => 0,
};

column user_notification_id => {
  data_type   => 'bigint',
  is_nullable => 0,
};

__PACKAGE__->add_created;

belongs_to 'event', 'PT::DB::Result::Event', 'event_id',
    { on_delete => 'cascade', };
belongs_to 'event_notification_group',
    'PT::DB::Result::EventNotificationGroup', 'event_notification_group_id',
    { on_delete => 'cascade', };
belongs_to 'user_notification', 'PT::DB::Result::UserNotification',
    'user_notification_id', { on_delete => 'cascade', };

__PACKAGE__->indices( event_notification_sent_idx => 'sent', );

###############################

no Moose;
__PACKAGE__->meta->make_immutable;
