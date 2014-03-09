package PT::DB::Result::User;
# ABSTRACT: Result class of a user in the DB

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use Digest::MD5 qw( md5_hex );
use List::MoreUtils qw( uniq  );
use Email::Valid;
use namespace::autoclean;

table 'users';

sub u {
  my ( $self ) = @_;
  if (defined $self->username && length($self->username)) {
    ['User','username',$self->username]
  } else {
    ['User','id',$self->id]
  }
}

column id => {
  data_type => 'bigint',
  is_auto_increment => 1,
};
primary_key 'id';

unique_column username => {
  data_type => 'text',
  is_nullable => 1,
};

column nickname => {
  data_type => 'text',
  is_nullable => 1,
};

column password => {
  data_type => 'text',
  is_nullable => 1,
  encode_column => 1,
  encode_class  => 'Crypt::Eksblowfish::Bcrypt',
  encode_args   => { key_nul => 0, cost => 8 },
  encode_check_method => 'check_password',
};

column email_notification_content => {
  data_type => 'int',
  is_nullable => 0,
  default_value => 1,
};

column admin => {
  data_type => 'int',
  is_nullable => 0,
  default_value => 0,
};

column forgotpw_token => {
  data_type => 'text',
  is_nullable => 1,
};

column forgotpw_token_created => {
  data_type => 'timestamp with time zone',
  is_nullable => 1,
};

column notes => {
  data_type => 'text',
  is_nullable => 1,
};

column messages => {
  data_type => 'text',
  is_nullable => 0,
  serializer_class => 'JSON',
  default_value => '[]',
};

__PACKAGE__->add_data_created_updated;

has_many 'url_users', 'PT::DB::Result::UrlUser', 'users_id', {
  cascade_delete => 0,
};
has_many 'comments', 'PT::DB::Result::Comment', 'users_id', {
  cascade_delete => 0,
};
has_many 'events', 'PT::DB::Result::Event', 'users_id', {
  cascade_delete => 0,
};
has_many 'user_authys', 'PT::DB::Result::UserAuthy', 'users_id', {
  cascade_delete => 1,
};
has_many 'user_emails', 'PT::DB::Result::UserEmail', 'users_id', {
  cascade_delete => 1,
};
has_many 'user_facebooks', 'PT::DB::Result::UserFacebook', 'users_id', {
  cascade_delete => 1,
};
has_many 'user_steams', 'PT::DB::Result::UserSteam', 'users_id', {
  cascade_delete => 1,
};
has_many 'user_notifications', 'PT::DB::Result::UserNotification', 'users_id', {
  cascade_delete => 1,
};
has_many 'user_roles', 'PT::DB::Result::UserRole', 'users_id', {
  cascade_delete => 1,
};
has_many 'user_notification_matrixes', 'PT::DB::Result::UserNotificationMatrix', 'users_id', {
  cascade_delete => 0,
};

after insert => sub {
  my ( $self ) = @_;
  $self->add_default_notifications;
};

sub add_default_notifications {
  my ( $self ) = @_;
  return if $self->search_related('user_notifications')->count;
  $self->add_type_notification(qw( replies 2 1 ));
}

sub do {
  my ( $self, $code ) = @_;
  return $self->pt->as($self,$code);
}

# ================================================ EMAIL

sub add_email {
  my ( $self, $email, $primary ) = @_;
  return unless Email::Valid->address($email);
  my $user_email = $self->schema->resultset('UserEmail')->search({
    email => $email,
  })->first;
  if ($user_email) {
    return $user_email->users_id eq $self->id ? $user_email : 0;
  }
  return $self->create_related('user_emails',{
    email => $email,
    $primary ? ( primary => 1 ) : (),
  });
}

sub remove_email {
  my ( $self, $email ) = @_;
  return $self->search_related('user_emails',{
    email => $email,
  })->delete;
}

sub has_validated_email {
  my ( $self, $email ) = @_;
  return $self->search_related('user_emails',{
    validated => 1,
    $email ? ( email => $email ) : (),
  })->count ? 1 : 0;
}

sub email {
  my ( $self ) = @_;
  my $primary = $self->search_related('user_emails',{
    validated => 1,
    primary => 1,
  })->first;
  return $primary if $primary;
  my $secondary = $self->search_related('user_emails',{
    validated => 1,
    primary => 0,
  })->first;
  return $secondary if $secondary;
}

# ================================================= ROLE

sub is {
  my ( $self, $role ) = @_;
  return 1 if $self->admin;
  return 1 if grep { $_ eq $role } @{$self->roles};
  return 0;
}

sub add_role {
  my ( $self, $role ) = @_;
  return 0 if grep { $_ eq $role } @{$self->roles};
  push @{$self->roles}, $role;
  $self->make_column_dirty("roles");
  return 1;
}

sub del_role {
  my ( $self, $role ) = @_;
  return 0 unless grep { $_ eq $role } @{$self->roles};
  my @newroles = grep { $_ ne $role } @{$self->roles};
  $self->roles(\@newroles);
  $self->make_column_dirty("roles");
  return 1;
}

sub undone_notifications_count_resultset {
  my ( $self ) = @_;
  $self->schema->resultset('EventNotificationGroup')->search_rs({
    'user_notification.users_id' => $self->id,
  },{
    prefetch => [qw( user_notification_group ),{
      event_notifications => [qw( user_notification )],
    }],
    cache_for => 45,
  })
}

sub undone_notifications_count {
  my ( $self ) = @_;
  $self->undone_notifications_count_resultset->count;
}

sub undone_notifications {
  my ( $self, $limit ) = @_;
  $self->schema->resultset('EventNotificationGroup')->prefetch_all->search_rs({
    'user_notification.users_id' => $self->id,
  },{
    order_by => { -desc => 'event_notifications.created' },
    cache_for => 45,
    $limit ? ( rows => $limit ) : (),
  });
}

sub unsent_notifications_cycle {
  my ( $self, $cycle ) = @_;
  $self->schema->resultset('EventNotificationGroup')->prefetch_all->search_rs({
    'event_notifications.sent' => 0,
    'user_notification.cycle' => $cycle,
    'user_notification.users_id' => $self->id,
  },{
    order_by => { -desc => 'event_notifications.created' },
  }); 
}

sub profile_picture {
  my ( $self, $size ) = @_;

  # TODO
}

sub last_comments {
  my ( $self, $page, $pagesize ) = @_;
  $self->comments->search({},{
    order_by => { -desc => [ 'me.updated', 'me.created' ] },
    ( ( defined $page and defined $pagesize ) ? (
      page => $page,
      rows => $pagesize,
    ) : () ),
    prefetch => 'user',
  });
}

has user_notification_group_values => (
  isa => 'HashRef',
  is => 'ro',
  lazy_build => 1,
  clearer => 'clear_user_notification_group_values',
);

sub _build_user_notification_group_values {
  my ( $self ) = @_;
  my %user_notification_group_values;
  for ($self->search_related('user_notifications',{
    context_id => undef,
  },{
    join => [qw( user_notification_group )],
  })->all) {
    $user_notification_group_values{$_->user_notification_group->type} = {}
      unless defined $user_notification_group_values{$_->user_notification_group->type};
    my $context_id_key = $_->user_notification_group->with_context_id
      ? '*' : '';
    $user_notification_group_values{$_->user_notification_group->type}->{$context_id_key}
      = { cycle => $_->cycle, xmpp => $_->xmpp };
  }
  return \%user_notification_group_values;
}

sub add_context_notification {
  my ( $self, $type, $context_obj ) = @_;
  my $group_info = $self->user_notification_group_values->{$type}->{'*'};
  if ($group_info->{cycle}) {
    my @user_notification_groups = $self->schema->resultset('UserNotificationGroup')->search({
      context => $context_obj->context_name,
      with_context_id => 1,
      type => $type,
    })->all;
    die "Several notification groups found, cant be..." if scalar @user_notification_groups > 1;
    die "No notification group found!" if scalar @user_notification_groups < 1;
    my $user_notification_group = $user_notification_groups[0];
    return $self->update_or_create_related('user_notifications',{
      user_notification_group_id => $user_notification_group->id,
      xmpp => $group_info->{xmpp} ? 1 : 0,
      cycle => $group_info->{cycle},
      context_id => $context_obj->id,
    },{
      key => 'user_notification_user_notification_group_id_context_id_users_id',
    });
  }
}

sub has_context_notification {
  my ( $self, $type, $context_obj ) = @_;
  my $group_info = $self->user_notification_group_values->{$type}->{'*'};
  my @user_notification_groups = $self->schema->resultset('UserNotificationGroup')->search({
    context => $context_obj->context_name,
    with_context_id => 1,
    type => $type,
  })->all;
  die "Several notification groups found, cant be..." if scalar @user_notification_groups > 1;
  die "No notification group found!" if scalar @user_notification_groups < 1;
  my $user_notification_group = $user_notification_groups[0];
  return $self->search_related('user_notifications',{
    user_notification_group_id => $user_notification_group->id,
    context_id => $context_obj->id,
  })->count;
}

sub delete_context_notification {
  my ( $self, $type, $context_obj ) = @_;
  my $group_info = $self->user_notification_group_values->{$type}->{'*'};
  my @user_notification_groups = $self->schema->resultset('UserNotificationGroup')->search({
    context => $context_obj->context_name,
    with_context_id => 1,
    type => $type,
  })->all;
  die "Several notification groups found, cant be..." if scalar @user_notification_groups > 1;
  die "No notification group found!" if scalar @user_notification_groups < 1;
  my $user_notification_group = $user_notification_groups[0];
  return $self->search_related('user_notifications',{
    user_notification_group_id => $user_notification_group->id,
    context_id => $context_obj->id,
  })->delete;
}

sub add_type_notification {
  my ( $self, $type, $cycle, $with_context_id ) = @_;
  my @user_notification_groups = $self->schema->resultset('UserNotificationGroup')->search({
    with_context_id => $with_context_id ? 1 : 0,
    type => $type,
  })->all;
  die "No notification group found!" if scalar @user_notification_groups < 1;
  for my $user_notification_group (@user_notification_groups) {
    if ($cycle) {
      $self->update_or_create_related('user_notifications',{
        user_notification_group_id => $user_notification_group->id,
        context_id => undef,
        cycle => $cycle,
      },{
        key => 'user_notification_user_notification_group_id_context_id_users_id',
      });
      if ($with_context_id) {
        $self->search_related('user_notifications',{
          user_notification_group_id => $user_notification_group->id,
          context_id => { '!=' => undef },
        })->update({
          cycle => $cycle,
        });
      }
    } else {
      $self->search_related('user_notifications',{
        user_notification_group_id => $user_notification_group->id,
        context_id => undef,
      })->delete;
      if ($with_context_id) {
        $self->search_related('user_notifications',{
          user_notification_group_id => $user_notification_group->id,
          context_id => { '!=' => undef },
        })->delete;
      }
    }
  }
}

# For Catalyst

# Store given by Catalyst
has store => (
  is => 'rw',
);

# Auth Realm given by Catalyst
has auth_realm => (
  is => 'rw',
);

sub supports {{}}

sub for_session {
  return shift->id;
}

sub get_object {
  return shift;
}
 
sub obj {
  my $self = shift;
  return $self->get_object(@_);
}

sub get {
  my ($self, $field) = @_;

  my $object;
  if ($object = $self->get_object and $object->can($field)) {
    return $object->$field();
  } else {
    return undef;
  }
}
### END

no Moose;
__PACKAGE__->meta->make_immutable;
