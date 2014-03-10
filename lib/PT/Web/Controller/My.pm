package PT::Web::Controller::My;

# ABSTRACT: User related functions web controller class

use Moose;
use namespace::autoclean;

use PT::Config;
use Email::Valid;
use Digest::MD5 qw( md5_hex );
use DateTime;

BEGIN { extends 'Catalyst::Controller'; }

sub base : Chained('/base') : PathPart('my') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    $c->stash->{page_class} = "page-account";
}

sub logout : Chained('base') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{not_last_url} = 1;
    $c->logout;
    $c->delete_session;
    $c->response->redirect( $c->chained_uri( 'Root', 'index' ) );
    return $c->detach;
}

sub finishwizard : Chained('base') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{not_last_url} = 1;
    $c->wiz_finished;
    delete $c->session->{wizard_finished};
    $c->stash->{x} = { ok => 1 };
    $c->forward( $c->view('JSON') );
    return $c->detach;
}

sub requestvalidate : Chained('logged_in') : Args(1) {
    my ( $self, $c, $email ) = @_;

    my $user_email =
        $c->user->search_related( 'user_emails', { email => $email, } )
        ->first;

    my $status = {};

    if ($user_email) {
        if ( $user_email->validated ) {
            $status->{already_validated} = 1;
        }
        else {
            $user_email->request_validation;
        }
    }
    else {
        $status->{no_email_found} = 1;
    }

    $c->response->redirect( $c->chained_uri( 'My', 'account', $status ) );
}

sub emailvalidate : Chained('base') : Args(2) {
    my ( $self, $c, $user_id, $token ) = @_;

    $c->stash->{title}   = 'Email validation';
    $c->stash->{user_id} = $user_id;
    $c->stash->{token}   = $token;

    my $user = $c->pt->rs('User')->find($user_id);

    unless ($user) {
        $c->stash->{no_user} = 1;
        return;
    }

    my @emails =
        $user->search_related( 'user_emails', { token => $token, } )->all;

    unless (@emails) {
        $c->stash->{no_emails_token} = 1;
        return;
    }

    $user->search_related( 'user_emails', { token => $token, } )
        ->update( { token => undef, validated => 1 } );
}

sub logged_out : Chained('base') : PathPart('') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    if ( $c->user ) {
        $c->response->redirect( $c->chained_uri( 'My', 'account' ) );
        return $c->detach;
    }
}

sub register : Chained('logged_out') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{not_last_url} = 1;
    $c->stash->{title}        = 'Create a new account';
    $c->stash->{no_login}     = 1;

    return $c->detach if !$c->req->params->{register};

    $c->stash->{username} = $c->req->params->{username};

    if ( !$c->validate_captcha( $c->req->params->{captcha} ) ) {
        $c->stash->{wrong_captcha} = 1;

        return $c->detach;
    }

    my $error = 0;

    if ( $c->req->params->{repeat_password} ne $c->req->params->{password} ) {
        $c->stash->{password_different} = 1;
        $error = 1;
    }

    if (  !defined $c->req->params->{password}
        or length( $c->req->params->{password} ) < 3 )
    {
        $c->stash->{password_too_short} = 1;
        $error = 1;
    }

    if ( $c->req->params->{email}
        && !Email::Valid->address( $c->req->params->{email} ) )
    {
        $c->stash->{not_valid_email} = 1;
        $error = 1;
    }

    if ( $c->req->params->{username} !~ /^[a-zA-Z0-9_\.]+$/ ) {
        $c->stash->{not_valid_chars} = 1;
        $error = 1;
    }

    return $c->detach if $error;

    my $password = $c->req->params->{password};
    my $username = $c->req->params->{username};
    my $newemail = $c->req->params->{email};

    my $find_user = $c->pt->find_user( 'username', $username );

    if ($find_user) {
        $c->stash->{username_exist} = $username;
        $error = 1;
    }

    return $c->detach if $error;

    $c->pt->db->txn_do(
        sub {

            my $user = $c->pt->create_user($username);

            if ($user) {
                $user->newemail($newemail);
                $user->password($password);
                $user->update;
            }
            else {
                $c->stash->{register_failed} = 1;
                return $c->detach;
            }

        }
    );

    $c->response->redirect(
        $c->chained_uri( 'My', 'login', { register_successful => 1 } ) );
    return $c->detach;
}

sub login_facebook : Chained('base') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{not_last_url} = 1;

    my $user = $c->authenticate( { scope => [qw()], }, 'facebook' );

    $c->detach unless $user;

    my $last_url = $c->session->{last_url};

    $last_url = $c->chained_uri( 'My', 'account' ) unless defined $last_url;
    $c->response->redirect($last_url);
    return $c->detach;
}

sub login_twitter : Chained('base') : Args {
    my ( $self, $c ) = @_;
    $c->stash->{not_last_url} = 1;

    my $user = $c->authenticate( {}, 'twitter' );

    $c->detach unless $user;

    my $last_url = $c->session->{last_url};

    $last_url = $c->chained_uri( 'My', 'account' ) unless defined $last_url;
    $c->response->redirect($last_url);
    return $c->detach;
}

sub login : Chained('logged_out') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{not_last_url} = 1;
    $c->stash->{title}        = 'Login';

    $c->stash->{no_userbox}          = 1;
    $c->stash->{register_successful} = $c->req->params->{register_successful};

    my $last_url = $c->session->{last_url};

    if (    my $username = $c->req->params->{username}
        and my $password = $c->req->params->{password} )
    {
        if ($c->authenticate(
                {   username => $username,
                    password => $password,
                },
                'username'
            )
            )
        {
            $c->set_new_action_token;
            $last_url = $c->chained_uri( 'My', 'account' )
                unless defined $last_url;
            $c->response->redirect($last_url);
            return $c->detach;
        }
        else {
            $c->stash->{login_failed} = 1;
        }
    }
    $c->stash->{username} = $c->req->params->{username};
}

sub forgotpw : Chained('logged_out') : Args(0) {
    my ( $self, $c ) = @_;

    return $c->detach if !$c->req->params->{requestpw};

    $c->require_action_token;

    $c->stash->{forgotpw_email} = $c->req->params->{email};
    my $user = $c->pt->find_user( 'email', $c->req->params->{email} );
    if ( !$user ) {
        $c->stash->{no_user_found} = 1;
        return;
    }

    my $token = md5_hex( int( rand(999_999_999) ) );
    $user->forgotpw_token($token);
    $user->update;

    $c->stash->{forgotpw_link} =
        $c->chained_uri( 'My', 'forgotpw_tokencheck',
        $user->lowercase_username, $token );

    $user->do(
        sub {
            $c->pt->postman->template_mail(
                $c->stash->{forgotpw_email},
                'Reset password for ' . $user->nickname,
                'forgotpw', $c->stash,
            );
        }
    );

    $c->stash->{sentok} = 1;
}

sub resetpw : Chained('logged_out') : Args(2) {
    my ( $self, $c, $user_id, $token ) = @_;

    $c->stash->{title}       = 'Reset password';
    $c->stash->{user_id}     = $user_id;
    $c->stash->{check_token} = $token;

    my $user = $c->pt->rs('User')->find($user_id);

    return unless $user;
    unless ( $user->forgotpw_token
        && $c->stash->{check_token} eq $user->forgotpw_token )
    {
        $c->stash->{invalid_token} = 1;
        return $c->detach;
    }
    return if !$c->req->params->{reset_password};

    my $error = 0;

    if ( $c->req->params->{repeat_password} ne $c->req->params->{password} ) {
        $c->stash->{password_different} = 1;
        $error = 1;
    }

    if (  !defined $c->req->params->{password}
        or length( $c->req->params->{password} ) < 5 )
    {
        $c->stash->{password_too_short} = 1;
        $error = 1;
    }

    return if $error;

    my $newpass = $c->req->params->{password};
    $user->forgotpw_token(undef);
    $user->password($newpass);
    $user->update;

    return unless $user->has_validated_email;

    $c->pt->postman->template_mail( $user->email, 'New password for you',
        'newpw', $c->stash, );

    $c->stash->{resetok} = 1;
}

sub logged_in : Chained('base') : PathPart('') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    $c->stash->{title} = 'My Account';
    if ( !$c->user ) {
        $c->response->redirect( $c->chained_uri( 'My', 'login' ) );
        return $c->detach;
    }
}

sub account : Chained('logged_in') : Args(0) {
    my ( $self, $c ) = @_;
}

sub email : Chained('logged_in') : Args(0) {
    my ( $self, $c, ) = @_;

    $c->stash->{title} = 'Email';

    # TODO

    $c->response->redirect( $c->chained_uri( 'My', 'account' ) );
    return $c->detach;
}

sub delete : Chained('logged_in') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{title} = 'Delete your account';

    return $c->detach unless $c->req->params->{delete_profile};

    $c->require_action_token;

    if ( !$c->validate_captcha( $c->req->params->{captcha} ) ) {
        $c->stash->{wrong_captcha} = 1;
        return $c->detach;
    }

    if ( $c->req->params->{delete_profile} ) {
        $c->user->deleted(1);
        $c->user->update;
        $c->logout;
        $c->response->redirect( $c->chained_uri( 'Root', 'index' ) );
        return $c->detach;
    }
}

sub nickname : Chained('logged_in') : Args(0) {
    my ( $self, $c ) = @_;

    return unless $c->req->params->{change_nickname};

    $c->require_action_token;

    if ( $c->req->params->{new_nickname} ne $c->user->nickname ) {
        $c->user->nickname( $c->req->params->{new_nickname} );
        $c->user->update;
        $c->response->redirect(
            $c->chained_uri( 'My', 'account', { nickname_changed => 1 } ) );
        return $c->detach;
    }

    return;
}

sub changepw : Chained('logged_in') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{title} = 'Change password';

    return unless $c->req->params->{changepw};

    $c->require_action_token;

    my $error = 0;

    if ( !$c->user->check_password( $c->req->params->{old_password} ) ) {
        $c->stash->{old_password_wrong} = 1;
        $error = 1;
    }

    if ( $c->req->params->{repeat_password} ne $c->req->params->{password} ) {
        $c->stash->{password_different} = 1;
        $error = 1;
    }

    if (  !defined $c->req->params->{password}
        or length( $c->req->params->{password} ) < 5 )
    {
        $c->stash->{password_too_short} = 1;
        $error = 1;
    }

    return if $error;

    my $newpass = $c->req->params->{password};
    $c->pt->update_password( $c->user->username, $newpass );

    if ( $c->user->has_email ) {
        $c->stash->{newpw_username} = $c->user->username;
        $c->pt->postman->template_mail( $c->user->email,
            'New password for ' . $c->user->username,
            'newpw', $c->stash, );
    }

    $c->stash->{changeok} = 1;
}

no Moose;
__PACKAGE__->meta->make_immutable;
