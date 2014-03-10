package PT::Test::Database;

# ABSTRACT:
#
# BE SURE YOU SAVE THIS FILE AS UTF-8 WITHOUT BYTE ORDER MARK (BOM)
#
######################################################################

use Moose;
use utf8;
use File::ShareDir::ProjectDistDir;
use Data::Printer;

use PT;
use PT::DB;
use PT::Config;
use DateTime::Format::RSS;

has _pt => (
  is       => 'ro',
  required => 1,
);
sub pt { shift->_pt(@_) }

sub db { shift->_pt->db(@_) }

sub xmpp { shift->_pt->xmpp(@_) }

has test => (
  is       => 'ro',
  isa      => 'Bool',
  required => 1,
);

has init => (
  is        => 'ro',
  predicate => 'has_init',
);

has progress => (
  is        => 'ro',
  predicate => 'has_progress',
);

# cache
has c => (
  isa     => 'HashRef',
  is      => 'rw',
  default => sub {
    { users => {}, };
  },
);

sub BUILDARGS {
  my ( $class, $pt, $test, $init, $progress ) = @_;
  my %options;
  $options{_pt}      = $pt;
  $options{test}     = $test;
  $options{init}     = $init if $init;
  $options{progress} = $progress if $progress;
  return \%options;
}

sub for_test {
  my ( $class, $tempdir ) = @_;
  my $pt = PT->new(
    { config => PT::Config->new(
        always_use_default => 1,
        rootdir_path       => $tempdir,
        mail_test          => 1,
      )
    }
  );
  return $class->new( $pt, 1 );
}

sub deploy {
  my ($self) = @_;
  $self->pt->deploy_fresh;
  $self->init->( $self->step_count ) if $self->has_init;
  $self->add_users;

  # TODO
  # $self->add_threads;
  # $self->add_comments;
  # $self->add_blogs;
  $self->update_notifications;
}

sub update_notifications {
  my ($self) = @_;
  $self->pt->rs('Event')->result_class->meta->add_after_method_modifier(
    'notify',
    sub {
      $self->next_step;
    }
  );
  $self->pt->envoy->update_all_notifications;
}

has current_step => (
  is      => 'rw',
  default => sub {0},
);

sub next_step {
  my ($self) = @_;
  return unless $self->has_progress;
  my $step = $self->current_step + 1;
  warn "Step no. " . $step . " is higher as step_count " . $self->step_count
      if $step > $self->step_count;
  $self->progress->($step);
  $self->current_step($step);
}

sub step_count {
  my ($self) = @_;
  my $base = 2;
  return $base unless $self->test;
}

sub isa_ok { ::isa_ok( $_[0], $_[1] ) if shift->test }
sub is { ::is( $_[0], $_[1], $_[2] ) if shift->test }

#############################
#  _   _ ___  ___ _ __ ___
# | | | / __|/ _ \ '__/ __|
# | |_| \__ \  __/ |  \__ \
#  \__,_|___/\___|_|  |___/

sub users {
  {};
}

sub add_users {
  my ($self) = @_;
  my $admin = $self->pt->create_user('Admin');
  $self->isa_ok( $admin, 'PT::DB::Result::User' );
  $admin->password('testme');
  $admin->admin(1);
  $admin->notes('Testuser, admin');
  $admin->update;
  $self->next_step;
  $self->c->{users}->{admin} = $admin;
  $self->next_step;

  for ( sort keys %{ $self->users } ) {
    my $data     = $self->users->{$_};
    my $username = $_;
    my $pw       = delete $data->{pw};
    my @notifications =
        defined $data->{notifications}
        ? ( @{ delete $data->{notifications} } )
        : ();
    my $user = $self->pt->create_user( $username, $pw );
    $self->next_step;
    $user->$_( $data->{$_} ) for ( keys %{$data} );
    $user->update;
    $self->c->{users}->{ $user->lc_username } = $user;

    for (@notifications) {
      $user->add_type_notification( @{$_} );
      $self->next_step;
    }
    $self->isa_ok( $user, 'PT::DB::Result::User' );
    $self->next_step;
  }
  for ( sort keys %{ $self->users } ) {
    my $user = $self->pt->find_user($_);
    $self->is( $user->username, $_, 'Checking username of ' . $_ );
    $self->isa_ok( $user, 'PT::DB::Result::User' );
    $self->next_step;
  }
}

sub _replace_email {
  my $email = $_[0];
  $email =~ s/@/ at /;
  return $email;
}

#####################################################
#                                           _
#   ___ ___  _ __ ___  _ __ ___   ___ _ __ | |_ ___
#  / __/ _ \| '_ ` _ \| '_ ` _ \ / _ \ '_ \| __/ __|
# | (_| (_) | | | | | | | | | | |  __/ | | | |_\__ \
#  \___\___/|_| |_| |_|_| |_| |_|\___|_| |_|\__|___/

sub add_comments {
  my ( $self, $context, $context_id, @comments ) = @_;
  while (@comments) {
    my $username = shift @comments;
    my $text     = shift @comments;
    my @sub_comments;
    if ( ref $text eq 'ARRAY' ) {
      @sub_comments = @{$text};
      $text         = shift @sub_comments;
    }
    my $user = $self->c->{users}->{$username};
    my $comment =
        $self->pt->add_comment( $context, $context_id, $user, $text );
    $self->next_step;
    $self->isa_ok( $comment, 'PT::DB::Result::Comment' );
    if ( scalar @sub_comments > 0 ) {
      $self->add_comments( 'PT::DB::Result::Comment', $comment->id,
        @sub_comments );
    }
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;
