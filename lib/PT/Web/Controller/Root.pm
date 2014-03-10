package PT::Web::Controller::Root;

# ABSTRACT: Main web controller class

use Moose;
use Path::Class;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config( namespace => '' );

sub base : Chained('/') : PathPart('') : CaptureArgs(0) {
  my ( $self, $c ) = @_;

  if ( my ( $username, $password ) = $c->req->headers->authorization_basic ) {
    unless (
      $c->authenticate(
        { username => $username, password => $password, }, 'users'
      )
        )
    {
      $c->response->status(401);
      $c->response->body("HTTP auth failed: Unauthorized");
      return $c->detach;
    }
  }

  $c->pt->current_user( $c->user ) if $c->user;

  $c->stash->{web_base}        = $c->pt->config->web_base;
  $c->stash->{template_layout} = ['base.tx'];
  $c->stash->{pt_config}       = $c->pt->config;
  $c->stash->{prefix_title}    = 'perl.today';
  $c->stash->{user_counts}     = $c->pt->user_counts;
  $c->stash->{page_class}      = "texture";
  $c->stash->{is_live}         = $c->pt->is_live;
  $c->stash->{is_view}         = $c->pt->is_view;
  $c->stash->{is_dev}          = $c->pt->is_dev;
  $c->stash->{errors}          = [];

  $c->set_new_action_token unless defined $c->session->{action_token};
  $c->check_action_token;
  $c->wiz_check;

  $c->response->headers->header( 'X-Frame-Options' => 'DENY' );

  $c->stash->{action_token} = $c->session->{action_token};
}

sub captcha : Chained('base') : Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{not_last_url} = 1;
  $c->create_captcha();
}

sub media : Chained('base') : Args {
  my ( $self, $c, @args ) = @_;
  $c->stash->{not_last_url} = 1;
  my $filename = join( "/", @args );
  my $mediadir = $c->pt->config->mediadir;
  my $file     = file( $mediadir, $filename );
  unless ( -f $file ) {
    $c->response->status(404);
    $c->response->body("Not found");
    return $c->detach;
  }
  $c->serve_static_file($file);
}

sub thumbnail : Chained('base') : Args {
  my ( $self, $c, @args ) = @_;
  $c->stash->{not_last_url} = 1;
  my $filename = join( "/", @args );
  my $mediadir = $c->pt->config->mediadir;
  my $file     = file( $mediadir, $filename );
  unless ( -f $file ) {
    $c->response->status(404);
    $c->response->body("Not found");
    return $c->detach;
  }
  my $thumbnail_dir = dir( $c->pt->config->mediadir, 'thumbnail' );
  my $thumbnail = file( $thumbnail_dir, $filename );
  unless ( -f $thumbnail ) {
    my $media = $c->pt->rs('Media')->find( { filename => $filename } );
    if ($media) {
      my $dir = $thumbnail->dir;
      $dir->mkpath;
      $media->generate_thumbnail( "100x100", $thumbnail );
    }
    else {
      $c->response->status(404);
      $c->response->body("Not found");
      return $c->detach;
    }
  }
  $c->serve_static_file($thumbnail);
}

sub index : Chained('base') : PathPart('') : Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{not_last_url}  = 1;
  $c->stash->{no_breadcrumb} = 1;
  $c->stash->{title}         = 'Top links on perl.today';
}

sub latest : Chained('base') : Args(0) {
  my ( $self, $c ) = @_;
  $c->stash->{not_last_url}  = 1;
  $c->stash->{no_breadcrumb} = 1;
  $c->stash->{title}         = 'Latest hot links on perl.today';
}

sub default : Chained('base') : PathPart('') : Args {
  my ( $self, $c ) = @_;
  $c->stash->{not_last_url} = 1;
  $c->response->status(404);
}

sub end : ActionClass('RenderView') {
  my ( $self, $c ) = @_;
  my $template = $c->action . '.tx';
  push @{ $c->stash->{template_layout} }, $template;
  $c->session->{last_url} = $c->req->uri unless $c->stash->{not_last_url};
  if ( $c->user ) {
    $c->run_after_request(
      sub {
        $c->pt->reset_current_user;
        $c->pt->envoy->update_own_notifications;
      }
    );
  }

  $c->wiz_post_check;
}

no Moose;
__PACKAGE__->meta->make_immutable;
