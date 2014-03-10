package PT::Web;

# ABSTRACT:

use Moose;
use Carp qw( croak );

use Catalyst::Runtime 5.90;

use Catalyst qw/
    ConfigLoader
    Static::Simple
    Session
    +PT::Web::SessionStore
    Session::State::Cookie
    Authentication
    Session::PerUser
    ChainedURI
    Captcha
    StackTrace
    ErrorCatcher
    CustomErrorMessage
    RunAfterRequest
    /;

extends 'Catalyst';

use PT::Config;
use Class::Load ':all';
use Digest::MD5 qw( md5_hex );

use PT::Web::Table;
use PT::Web::FormDBIC;

use namespace::autoclean;

our $VERSION ||= '0.000';

__PACKAGE__->config(
    name                                        => 'PT::Web',
    disable_component_resolution_regex_fallback => 1,
    using_frontend_proxy                        => 1,
    default_view                                => 'Xslate',
    encoding                                    => 'UTF-8',
    stacktrace => { enable => $ENV{PT_ACTIVATE_ERRORCATCHING} || 0, },
    'Plugin::ErrorCatcher' => {
        enable => $ENV{PT_ACTIVATE_ERRORCATCHING} || 0,
        emit_module => 'Catalyst::Plugin::ErrorCatcher::Email',
    },
    'Plugin::ErrorCatcher::Email' => {
        to       => 'torsten@raudss.us',
        from     => $ENV{PT_EMAIL_FROM} || 'noreply@perl.today',
        subject  => '[PT] %p %l CRASH!!!',
        use_tags => 1,
    },
    'Plugin::Static::Simple' => {
        dirs              => ['root'],
        ignore_extensions => [qw/tmpl tt tt2 tx/],
    },
    authentication => {
        default_realm => 'username',
        realms        => {
            username => {
                credential => {
                    class         => 'Password',
                    password_type => 'self_check',
                },
                store => { class => '+PT::Web::Authentication::Store::PT', },
            },
            facebook => {
                credential => {
                    class              => 'Facebook::OAuth2',
                    application_id     => $ENV{PT_FACEBOOK_APP_ID},
                    application_secret => $ENV{PT_FACEBOOK_APP_SECRET},
                },
                store => { class => '+PT::Web::Authentication::Store::PT', },
            },
            twitter => {
                credential => { class => 'Twitter', },
                store => { class => '+PT::Web::Authentication::Store::PT', },
                consumer_key    => $ENV{PT_TWITTER_CONSUMER_KEY},
                consumer_secret => $ENV{PT_TWITTER_CONSUMER_SECRET},
                callback_url    => $ENV{PT_WEB_BASE} . '/my/login_twitter',
            },
        },
    },
    'custom-error-message' => {
        'error-template'  => 'error.tx',
        'content-type'    => 'text/html; charset=utf-8',
        'view-name'       => 'Xslate',
        'response-status' => 500,
    },
    'Plugin::Session' => {
        expires => 21600,

        #    defined $ENV{PT_TMP} ? ( storage => $ENV{PT_TMP} ) : (),
    },
    'Plugin::Captcha' => {
        session_name => 'captcha_string',
        new          => {
            font      => __PACKAGE__->path_to( 'share', 'annifont.ttf' ),
            width     => 200,
            height    => 90,
            ptsize    => 45,
            lines     => 2,
            thickness => 3,
            rndmax    => 3,
        },
        create   => [qw/ttf rect/],
        particle => [3000],
        out      => { force => 'jpeg' }
    },
);

sub pt {    # legacy - keep it
    my ( $c, @args ) = @_;
    return $c->model('PT');
}

sub locate_components {
    my $class  = shift;
    my $config = shift;

    my @paths = qw( ::Model ::M ::View ::V ::Controller ::C );
    my $extra = delete $config->{search_extra} || [];

    unshift @paths, @$extra;

    my @comps = map {
        sort { $a cmp $b } Module::Pluggable::Object->new(
            search_path => [ map { s/^(?=::)/$class/; $_; } ($_) ],
            %$config
            )->plugins
    } @paths;

    return @comps;
}

sub next_form_id {
    my ($c) = @_;
    my $last_id = $c->session->{last_form_id} || int( rand(999_999_999) );
    my $next_id =
        $last_id > 899_999_999
        ? int( rand(899_999_999) )
        : $last_id + int( rand(99_999_999) );
    $c->session->{last_form_id} = $next_id;
    return $next_id;
}

sub set_new_action_token {
    my ($c) = @_;
    $c->session->{action_token} = md5_hex( int( rand(1_000_000) ) );
}

sub check_action_token {
    my ($c) = @_;
    return $c->stash->{action_token_checked}
        if defined $c->stash->{action_token_checked};
    return 0 unless defined $c->req->params->{action_token};
    if ( $c->session->{action_token} eq $c->req->params->{action_token} ) {
        $c->stash->{action_token_checked} = 1;
    }
    else {
        $c->stash->{action_token_checked} = 0;
    }
    $c->set_new_action_token;
    return $c->stash->{action_token_checked};
}

sub require_action_token {
    my ($c) = @_;
    die "No action token on submit"
        unless defined $c->stash->{action_token_checked};
    die "Invalid action token" unless $c->stash->{action_token_checked};
}

sub pager_init {
    my ( $c, $key, $default_pagesize ) = @_;
    $key                 = $c->action if !$key;
    $default_pagesize    = 20         if !$default_pagesize;
    $c->session->{pager} = {}         if !$c->session->{pager};
    $c->session->{pager}->{$key} = {} if !$c->session->{pager}->{$key};
    if (   $c->req->params->{pagesize}
        && $c->req->params->{pagesize}
        != $c->session->{pager}->{$key}->{pagesize} )
    {
        $c->stash->{page} = 1;
    }
    else {
        $c->stash->{page} =
            $c->req->params->{page} ? $c->req->params->{page} + 0 : 1;
    }
    $c->stash->{pagesize} =
          $c->req->params->{pagesize} ? $c->req->params->{pagesize} + 0
        : $c->session->{pager}->{$key}->{pagesize}
        ? $c->session->{pager}->{$key}->{pagesize}
        : $default_pagesize;
    $c->stash->{pagesize_options} = [qw( 1 5 10 20 40 50 100 )];
    $c->session->{pager}->{$key}->{pagesize} = $c->stash->{pagesize};

    # $c->session->{pager}->{$key}->{page} = $c->stash->{page};
}

sub done {
    my ($c) = @_;
    $c->wiz_done;
}

sub table {
    my ( $c, $resultset, $u, $columns, %args ) = @_;
    my $class =
        defined $args{class}
        ? delete $args{class}
        : "PT::Web::Table";
    return $class->new(
        c         => $c,
        u         => $u,
        resultset => $resultset,
        columns   => $columns,
        %args,
    );
}

sub wiz_die { die "Wizard is running" unless shift->wiz_running }

sub wiz_start {
    my ( $c, $wizard, %options ) = @_;
    $c->log->debug('Wizard has wiz_start') if $c->debug;
    my $class = 'PT::Web::Wizard::' . $wizard;
    $c->session->{'wizard'} = $class->new(%options);
    return $c->wiz->next($c);
}

sub wiz {
    my $c = shift;
    return unless $c->wiz_running;
    return $c->session->{'wizard'};
}

sub wiz_check {
    my $c = shift;
    if ( $c->session->{wizard_finished} ) {
        $c->stash->{wizard_finished} = 1;
        delete $c->session->{wizard_finished};
    }
    return unless $c->wiz_running;
    return unless $c->wiz->can('check');
    return $c->wiz->check($c);
}

sub wiz_post_check {
    my $c = shift;
    return unless $c->wiz_running;
    return unless $c->wiz->can('post_check');
    return $c->wiz->post_check($c);
}

sub wiz_running { defined shift->session->{'wizard'} }

sub wiz_inside {
    my $c = shift;
    return 0 unless $c->wiz_running;
    return $c->wiz->inside;
}

sub wiz_outside {
    my $c = shift;
    return 0 unless $c->wiz_running;
    return $c->wiz->inside ? 0 : 1;
}

sub wiz_step {
    my $c = shift;
    return unless $c->wiz_running;
    return $c->wiz->next_step(1);
}

sub wiz_finished {
    my $c = shift;
    $c->wiz_die;
    $c->session->{wizard_finished} = 1;
    delete $c->session->{'wizard'};
}

sub add_alert {
    my ( $c, $title, $type, $text ) = @_;
    $type                 = 'info' unless defined $type;
    $text                 = ''     unless defined $text;
    $c->session->{alerts} = []     unless defined $c->session->{alerts};
    push @{ $c->session->{alerts} },
        {
        type  => $type,
        title => $title,
        text  => $text,
        };
}

sub pop_alerts {
    my ($c) = @_;
    my @alerts = @{ delete $c->session->{alerts} };
    return \@alerts;
}

sub breadcrumb_start {
    my ( $c, $label, $u ) = @_;
    $c->stash->{breadcrumbs} = [
        {   label => $label,
            defined $u ? ( url => $c->chained_uri( @{$u} ) ) : (),
        }
    ];
}

sub breadcrumb_add {
    my ( $c, $label, $u ) = @_;
    push @{ $c->stash->{breadcrumbs} },
        {
        label => $label,
        defined $u ? ( url => $c->chained_uri( @{$u} ) ) : (),
        };
}

sub form_dbic {
    my ( $c, $object, $field_list, %args ) = @_;
    return PT::Web::FormDBIC->new_via_obj(
        $object, $field_list,
        ctx => $c,
        %args
    );
}

__PACKAGE__->setup();

no Moose;
__PACKAGE__->meta->make_immutable( replace_constructor => 1 );
