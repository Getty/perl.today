package PT;

# ABSTRACT: PT.net

use Moose;

use PT::Config;
use PT::DB;
use PT::Envoy;
use PT::Postman;
use PT::Util::DateTime;

use File::Copy;
use IO::All;
use File::Spec;
use File::ShareDir::ProjectDistDir;
use Text::Xslate qw( mark_raw );
use Class::Load qw( load_class );
use POSIX;
use Cache::FileCache;
use Cache::NullCache;
use LWP::UserAgent;
use Carp;
use Data::Dumper;
use namespace::autoclean;

our $VERSION ||= '0.000';

##############################################
# TESTING AND DEVELOPMENT, NOT FOR PRODUCTION
sub deploy_fresh {
  my ($self) = @_;

  die "ARE YOU INSANE????? KILLING LIVE???? GO DING-DING-DING YOURSELF!!!"
      if $self->is_live;

  $self->config->rootdir();
  $self->config->filesdir();
  $self->config->cachedir();

  $self->db->deploy;
  $self->db->resultset('UserNotificationGroup')->update_group_types;
}

####################################################################
#   ____             __ _                       _   _
#  / ___|___  _ __  / _(_) __ _ _   _ _ __ __ _| |_(_) ___  _ __
# | |   / _ \| '_ \| |_| |/ _` | | | | '__/ _` | __| |/ _ \| '_ \
# | |__| (_) | | | |  _| | (_| | |_| | | | (_| | |_| | (_) | | | |
#  \____\___/|_| |_|_| |_|\__, |\__,_|_|  \__,_|\__|_|\___/|_| |_|
#                         |___/

has config => (
  isa        => 'PT::Config',
  is         => 'ro',
  lazy_build => 1,
  handles    => [
    qw(
        is_live
        is_view
        is_dev
        )
  ],
);
sub _build_config { PT::Config->new }
####################################################################

has http => (
  isa        => 'LWP::UserAgent',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_http {
  my $ua = LWP::UserAgent->new;
  $ua->timeout(30);
  my $agent = ( ref $_[0] ? ref $_[0] : $_[0] ) . '/' . $VERSION;
  $ua->agent($agent);
  return $ua;
}

############################################################
#  ____        _    ____            _
# / ___| _   _| |__/ ___| _   _ ___| |_ ___ _ __ ___  ___
# \___ \| | | | '_ \___ \| | | / __| __/ _ \ '_ ` _ \/ __|
#  ___) | |_| | |_) |__) | |_| \__ \ ||  __/ | | | | \__ \
# |____/ \__,_|_.__/____/ \__, |___/\__\___|_| |_| |_|___/
#                         |___/

# Database (DBIx::Class)
has db => (
  isa        => 'PT::DB',
  is         => 'ro',
  lazy_build => 1,
  handles    => [
    qw(
        without_events
        )
  ],
);
sub _build_db { PT::DB->connect(shift) }
sub resultset { shift->db->resultset(@_) }
sub rs        { shift->resultset(@_) }

# Notification System
has envoy => (
  isa        => 'PT::Envoy',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_envoy { PT::Envoy->new( { pt => shift } ) }

# Mail System
has postman => (
  isa        => 'PT::Postman',
  is         => 'ro',
  lazy_build => 1,
  handles    => [
    qw(
        mail
        )
  ],
);
sub _build_postman { PT::Postman->new( { pt => shift } ) }

has cache => (
  isa        => 'Cache::Cache',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_cache {
  return $_[0]->config->no_cache
      ? Cache::NullCache->new
      : Cache::FileCache->new(
    { namespace  => 'PT',
      cache_root => $_[0]->config->cachedir,
    }
      );
}

##############################
# __  __    _       _
# \ \/ /___| | __ _| |_ ___
#  \  // __| |/ _` | __/ _ \
#  /  \\__ \ | (_| | ||  __/
# /_/\_\___/_|\__,_|\__\___|
# (Templating SubSystem)
#

has xslate => (
  isa        => 'Text::Xslate',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_xslate {
  my $self = shift;
  my $xslate;
  my $obj2dir = sub {
    my $obj = shift;
    my $class = $obj->can('i') ? $obj->i : ref $obj;
    if ( $class =~ m/^PT::DB::Result::(.*)$/ ) {
      my $return = lc($1);
      $return =~ s/::/_/g;
      return $return;
    }
    if ( $class =~ m/^PT::DB::ResultSet::(.*)$/ ) {
      my $return = lc($1);
      $return =~ s/::/_/g;
      return $return . '_rs';
    }
    if ( $class =~ m/^PT::Web::(.*)/ ) {
      my $return = lc($1);
      $return =~ s/::/_/g;
      return $return;
    }
    die "cant include " . $class . " with i-function";
  };
  my $i_template_and_vars = sub {

    my $object = shift;
    my $subtemplate;
    my $no_templatedir;
    my $vars;
    if ( ref $object ) {
      $subtemplate = shift;
      $vars        = shift;
    }
    else {
      $no_templatedir = 1;
      $subtemplate    = $object;
      my $next = shift;
      if ( ref $next eq 'HASH' ) {
        $object = undef;
        $vars   = $next;
      }
      else {
        $object = $next;
        $vars   = shift;
      }
    }
    my $main_object;
    my @objects;
    push @objects, $object if $object;
    if ( ref $object eq 'ARRAY' ) {
      $main_object = $object->[0];
      @objects     = @{$object};
    }
    else {
      $main_object = $object;
    }
    my %current_vars = %{ $xslate->current_vars };
    my $no_caller = delete $vars->{no_caller} ? 1 : 0;
    if ( defined $current_vars{_} && !$no_caller ) {
      $current_vars{caller} = $current_vars{_};
    }
    $current_vars{_} = $main_object;
    my $ref_main_object = ref $main_object;
    if ( $main_object && $ref_main_object ) {
      if ( $main_object->can('meta') ) {
        for my $method ( $main_object->meta->get_all_methods ) {
          if ( $method->name =~ m/^i_(.*)$/ ) {
            my $name     = $1;
            my $var_name = '_' . $name;
            my $func     = 'i_' . $name;
            $current_vars{$var_name} = $main_object->$func;
          }
        }
      }
    }
    my @template = ('i');
    unless ($no_templatedir) {
      push @template, $obj2dir->($main_object);
    }
    push @template, $subtemplate ? $subtemplate : 'label';
    my %new_vars;
    for (@objects) {
      my $obj_dir = $obj2dir->($_);
      if ( defined $new_vars{$obj_dir} ) {
        if ( ref $new_vars{$obj_dir} eq 'ARRAY' ) {
          push @{ $new_vars{$obj_dir} }, $_;
        }
        else {
          $new_vars{$obj_dir} = [ $new_vars{$obj_dir}, $_, ];
        }
      }
      else {
        $new_vars{$obj_dir} = $_;
      }
    }
    for ( keys %new_vars ) {
      $current_vars{$_} = $new_vars{$_};
    }
    if ($vars) {
      for ( keys %{$vars} ) {
        $current_vars{$_} = $vars->{$_};
      }
    }
    return join( '/', @template ) . ".tx", \%current_vars;
  };
  $xslate = Text::Xslate->new(
    { path      => [ $self->config->templatedir ],
      cache_dir => $self->config->xslate_cachedir,
      suffix    => '.tx',
      function  => {

        # Functions to access the main model and some functions specific
        d            => sub {$self},
        cur_user     => sub { $self->current_user },
        has_cur_user => sub { defined $self->current_user ? 1 : 0 },

        # Mark text as raw HTML
        r => sub { mark_raw(@_) },

        # trick function for DBIx::Class::ResultSet
        results => sub {
          my ( $rs, $sorting ) = @_;
          my @results = $rs->all;
          $sorting
              ? [ sort { $b->$sorting <=> $a->$sorting } @results ]
              : [@results];
        },

        # general functions avoiding xslates problems
        call => sub {
          my $thing = shift;
          my $func  = shift;
          $thing->$func(@_);
        },
        callref => sub {
          my $coderef = shift;
          $coderef->(@_);
        },
        call_if => sub {
          my $thing = shift;
          my $func  = shift;
          $thing->$func(@_) if $thing;
        },
        replace => sub {
          my $source = shift;
          my $from   = shift;
          my $to     = shift;
          $source =~ s/$from/$to/g;
          return $source;
        },
        urify => sub { lc( join( '-', split( /\s+/, join( ' ', @_ ) ) ) ) },

        floor => sub { floor( $_[0] ) },
        ceil  => sub { ceil( $_[0] ) },

        # Duration display helper mapped, see PT::Util::DateTime
        dur         => sub { dur(@_) },
        dur_precise => sub { dur_precise(@_) },
        #############################################

        i_template_and_vars => $i_template_and_vars,
        i                   => sub {
          mark_raw( $xslate->render( $i_template_and_vars->(@_) ) );
        },
        i_template => sub {
          my ( $template, $vars ) = $i_template_and_vars->(@_);
          return $template;
        },

        results_event_userlist => sub {
          my %users;
          for ( $_[0]->all ) {
            if ( $_->event->users_id ) {
              unless ( defined $users{ $_->event->users_id } ) {
                $users{ $_->event->users_id } = $_->event->user;
              }
            }
          }
          return [ values %users ];
        },

        style => sub {
          my %style;
          my @styles = @_;
          while (@styles) {
            my $t_style = $self->template_styles->{ shift @styles };
            if ( ref $t_style eq 'HASH' ) {
              $style{$_} = $t_style->{$_} for keys %{$t_style};
            }
            elsif ( ref $t_style eq 'ARRAY' ) {
              unshift @styles, @{$t_style};
            }
          }
          my $return = 'style="';
          $return
              .= $_ . ':'
              . $style{$_}
              . ';'
              for (
            sort { length($a) <=> length($b) }
            keys %style
              );
          $return .= '"';
          return mark_raw($return);
        },

      },
    }
  );
  return $xslate;
}

sub template_styles {
  { 'default'  => { 'font-family' => 'sans-serif', },
    'sub_text' => {
      'font-family' => 'sans-serif',
      'font-size'   => '12px',
    },
    'signoff' => { 'color' => '#999999', },
    'warning' => {
      'font-family' => 'sans-serif',
      'font-style'  => 'normal',
      'font-size'   => '11px',
      'color'       => '#a8a8a8',
    },
    'site_title' => {
      'font-family' => 'sans-serif',
      'position'    => 'relative',
      'text-align'  => 'left',
      'line-height' => '1',
      'margin'      => '0',
    },
    'site_maintitle' => {
      'font-weight' => 'bold',
      'font-size'   => '21px',
      'padding-top' => '10px',
      'left'        => '-1px',
    },
    'green' => {
      'font-style' => 'normal',
      'color'      => '#48af04',
    },
    'site_subtitle' => {
      'font-weight'    => 'normal',
      'color'          => '#a0a0a0',
      'padding-top'    => '4px',
      'padding-bottom' => '7px',
      'font-size'      => '12px',
    },
    'msg_body' => {
      'border'        => '1px solid #d7d7d7',
      'border-radius' => '5px',
      'max-width'     => '800px',
    },
    'msg_header' => {
      'width'            => '100%',
      'background-color' => '#f1f1f1',
      'border-bottom'    => '1px solid #d7d7d7',
      'border-radius'    => '5px 5px 0 0',
    },
    'msg_title' => {
      'font-family' => 'sans-serif',
      'font-weight' => 'normal',
      'font-size'   => '28px',
      'color'       => '#a0a0a0',
      'margin'      => '0',
      'padding'     => '9px 0',
    },
    'msg_content' => {
      'font-family'      => 'sans-serif',
      'padding'          => '10px 0',
      'background-color' => '#ffffff',
    },
    'msg_notification' => {
      'font-family'      => 'sans-serif',
      'padding'          => '0',
      'background-color' => '#ffffff',
    },
    'notification' => {
      'padding'       => '10px 0',
      'font-family'   => 'sans-serif',
      'width'         => '100%',
      'border-bottom' => '1px solid #d7d7d7',
    },
    'notification_text' => {
      'font-family' => 'sans-serif',
      'font-size'   => '14px',
    },
    'notification_icon' => {
      'width'   => '40px',
      'height'  => '40px',
      'outline' => 'none',
      'border'  => 'none',
    },
    'notification_count' => {
      'padding'          => '5px 0',
      'background-color' => '#fbfbfb',
      'font-family'      => 'sans-serif',
      'width'            => '100%',
      'border-bottom'    => '1px solid #d7d7d7',
    },
    'notification_count_text' => {
      'margin'      => '0',
      'padding-top' => '4px',
      'color'       => '#a0a0a0',
      'font-weight' => 'bold',
      'font-size',  => '16px',
    },
    'button' => {
      'font-family'      => 'sans-serif',
      'font-size'        => '14px',
      'border-radius'    => '3px',
      'display'          => 'block',
      'padding'          => '0 12px',
      'height'           => '28px',
      'line-height'      => '28px',
      'text-align'       => 'center',
      'text-decoration'  => 'none',
      'color'            => '#d7d7d7',
      'background-color' => '#ffffff',
      'border'           => '1px solid #d7d7d7',
      'white-space'      => 'nowrap',
    },
    'button_blue' => {
      'color'        => '#4b8df8',
      'border-color' => '#4b8df8',
    },
    'button_green' => {
      'color'        => '#48af04',
      'border-color' => '#48af04',
    },
    'view_link' => {
      'color'           => '#d7d7d7',
      'font-size'       => '60px',
      'display'         => 'block',
      'text-align'      => 'right',
      'text-decoration' => 'none',
      'line-height'     => '35px',
      'height'          => '40px',
      'overflow'        => 'visible',
    },
    'hr' => {
      'border'     => 'none',
      'height'     => '0',
      'border-top' => '1px solid #eee',
      'margin'     => '14px auto',
    },
    'quote' => {
      'border'            => '1px solid #d7d7d7',
      'border-left-width' => '6px',
      'background-color'  => '#ffffff',
      'margin-right'      => '60px',
      'margin-top'        => '-2px',
      'padding'           => '14px',
    },
    'quote_self'   => { 'border-color' => '#48af04', },
    'quote_indent' => { 'margin-left'  => '6px', },
  };
}

##############################

has current_user => (
  isa       => 'PT::DB::Result::User',
  is        => 'rw',
  clearer   => 'reset_current_user',
  predicate => 'has_current_user',
);

sub as {
  my ( $self, $user, $code ) = @_;
  die "as need user or undef"
      unless !defined $user || $user->isa('PT::DB::Result::User');
  die "as need coderef" unless ref $code eq 'CODE';
  my $previous_current_user = $self->current_user;
  $user
      ? $self->current_user($user)
      : $self->reset_current_user;
  eval { $code->(); };
  $previous_current_user
      ? $self->current_user($previous_current_user)
      : $self->reset_current_user;
  croak $@ if $@;
  return;
}

sub errorlog {
  my ( $self, @data ) = @_;
  io( $self->config->errorlog )->append( Dumper( \@data ) );
}

sub delete_user {
  my ( $self, $user ) = @_;

  # TODO
  return 1;
}

sub create_user {
  my ( $self, $username ) = @_;

  die "username is required for a new user"
      unless defined $username && length($username);

  return $self->db->resultset('User')->create( { username => $username, } );
}

sub find_user {
  my ( $self, $method, $username ) = @_;

  return unless $username && $method;

  my $func = 'find_by_' . $method;

  die "Unknown method " . $method . " for fetching account!"
      unless $self->db->resultset('User')->can($func);

  return $self->db->resultset('User')->$func($username);
}

sub user_counts {
  my ($self) = @_;

  return $self->cache->get('pt_user_counts')
      if defined $self->cache->get('pt_user_counts');

  my %counts;
  $counts{db} = $self->db->resultset('User')->search( {} )->count;

  $self->cache->set( 'pt_user_counts', \%counts, "1 hour" );

  return \%counts;
}

sub add_feed {
  my ( $self, %params ) = @_;
  return $self->db->resultset('Feed')->create( \%params );
}

sub add_feed_uri {
  my ( $self, %params ) = @_;
}
#
# ======== Misc ====================
#

no Moose;
__PACKAGE__->meta->make_immutable;
