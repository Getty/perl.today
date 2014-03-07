package PT::Config;
# ABSTRACT: PT main configuration file 

use Moose;
use File::Path qw( make_path );
use File::Spec;
use File::ShareDir::ProjectDistDir;
use Path::Class;
use Catalyst::Utils;

has always_use_default => (
  is => 'ro',
  lazy => 1,
  default => sub { 0 },
);

sub has_conf {
  my ( $name, $env_key, $default ) = @_;
  my $default_ref = ref $default;
  has $name => (
    is => 'ro',
    lazy => 1,
    default => sub {
      my ( $self ) = @_;
      my $result;
      if ($self->always_use_default) {
        if ($default_ref eq 'CODE') {
          $result = $default->(@_);
        } else {
          $result = $default;
        }
      } else {
        if (defined $ENV{$env_key}) {
          $result = $ENV{$env_key};
        } else {
          if ($default_ref eq 'CODE') {
            $result = $default->(@_);
          } else {
            $result = $default;
          }
        }
      }
      return $result;
    },
  );
}

has_conf nid => PT_NID => 1;
has_conf pid => PT_PID => $$;

has_conf rootdir_path => PT_ROOTDIR => $ENV{HOME}.'/pt/';
has_conf no_cache => PT_NOCACHE => 0;

sub rootdir {
  my ( $self ) = @_;
  my $dir = $self->rootdir_path;
  make_path($dir) if !-d $dir;
  return File::Spec->rel2abs( $dir );
}

has_conf web_base => PT_WEB_BASE => 'http://perl.today';

has_conf errorlog => PT_ERRORLOG => sub {
  my ( $self ) = @_;
  return $self->rootdir().'/error.log';
};

has_conf facebook_app_id => $ENV{PT_FACEBOOK_APP_ID}, undef;
has_conf facebook_app_secret => $ENV{PT_FACEBOOK_APP_SECRET}, undef;
has_conf twitter_consumer_key => $ENV{PT_TWITTER_CONSUMER_KEY}, undef;
has_conf twitter_consumer_secret => $ENV{PT_TWITTER_CONSUMER_SECRET}, undef;

has_conf is_live => PT_LIVE => 0;
has_conf is_view => PT_VIEW => 0;

sub is_dev {
  my $self = shift;
  ( $self->is_live || $self->is_view ) ? 1 : 0;
}

has_conf email_from => PT_EMAIL_FROM => sub {
  my $self = shift;
  $self->is_dev ? '"Development perl.today" <noreply@perl.today>' :
    $self->is_view ? '"View perl.today" <noreply@perl.today>'
      : '"perl.today" <noreply@perl.today>'; # is_live
};

has_conf email_prefix => PT_EMAIL_PREFIX => sub {
  my $self = shift;
  $self->is_dev ? '[Dev] perl.today' :
    $self->is_view ? '[View] perl.today' : 'perl.today'; # is_live
};

has_conf mail_test => PT_MAIL_TEST => 0;
has_conf mail_test_log => PT_MAIL_TEST_LOG => '';
has_conf smtp_host => PT_SMTP_HOST => undef;
has_conf smtp_ssl => PT_SMTP_SSL => 0;
has_conf smtp_sasl_username => PT_SMTP_SASL_USERNAME => undef;
has_conf smtp_sasl_password => PT_SMTP_SASL_PASSWORD => undef;

has_conf templatedir => PT_TEMPLATEDIR => sub { dir( Catalyst::Utils::home('PT'), 'templates' )->resolve->absolute->stringify };

has_conf db_dsn => PT_DB_DSN => sub {
  my ( $self ) = @_;
  my $rootdir = $self->rootdir();
  return 'dbi:Pg:dbname='.$self->db_name.';port='.$self->db_port;
};

has_conf db_name => PT_DB_NAME => 'pt';
has_conf db_port => PT_DB_PORT => 17375;
has_conf db_user => PT_DB_USER => '';
has_conf db_password => PT_DB_PASSWORD => '';

has db_params => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my ( $self ) = @_;
    my %vars = (
      quote_char => '"',
      name_sep => '.',
      cursor_class => 'DBIx::Class::Cursor::Cached',
    );
    $vars{pg_enable_utf8} = 1;
    return \%vars;
  },
);

sub filesdir {
  my ( $self ) = @_;
  my $dir = defined $ENV{'PT_FILESDIR'} ? $ENV{'PT_FILESDIR'} : $self->rootdir().'/files/';
  make_path($dir) if !-d $dir;
  return File::Spec->rel2abs( $dir );
}

sub cachedir {
  my ( $self ) = @_;
  my $dir = defined $ENV{'PT_CACHEDIR'} ? $ENV{'PT_CACHEDIR'} : $self->rootdir().'/cache/';
  make_path($dir) if !-d $dir;
  return File::Spec->rel2abs( $dir );
}

sub mediadir {
  my ( $self ) = @_;
  my $dir = defined $ENV{'PT_MEDIADIR'} ? $ENV{'PT_MEDIADIR'} : $self->rootdir().'/media/';
  make_path($dir) if !-d $dir;
  return File::Spec->rel2abs( $dir );
}

sub xslate_cachedir {
  my ( $self ) = @_;
  my $dir = defined $ENV{'PT_CACHEDIR_XSLATE'} ? $ENV{'PT_CACHEDIR_XSLATE'} : $self->cachedir().'/xslate/';
  make_path($dir) if !-d $dir;
  return File::Spec->rel2abs( $dir );
}

1;