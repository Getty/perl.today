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
  $self->add_feeds;

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
  my $base = 28;
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

#######################################################
#  _____ _____ _____ ____  ____
# |  ___| ____| ____|  _ \/ ___|
# | |_  |  _| |  _| | | | \___ \
# |  _| | |___| |___| |_| |___) |
# |_|   |_____|_____|____/|____/
#

sub feeds {
  return (
    { name       => 'jobs.perl.org',
      url        => 'http://jobs.perl.org/rss/standard.rss',
      web_url    => 'http://jobs.perl.org/',
      jobs       => 1,
      feed_class => 'RSS',
    },
    { name       => 'blogs.perl.org',
      url        => 'http://blogs.perl.org/atom.xml',
      web_url    => 'http://blogs.perl.org/',
      feed_class => 'RSS',
    },
    { name       => 'Moose Blog',
      url        => 'http://blog.moose.perl.org/atom.xml',
      web_url    => 'http://blog.moose.perl.org/',
      feed_class => 'RSS',
    },
    { name       => 'Perl NOC',
      url        => 'http://log.perl.org/feeds/posts/default',
      web_url    => 'http://log.perl.org/',
      feed_class => 'RSS',
    },
    { name       => 'Ricardo Signes',
      url        => 'http://rjbs.manxome.org/rubric/entries?format=rss',
      web_url    => 'http://rjbs.manxome.org/',
      feed_class => 'RSS',
    },
    { name       => 'David Golden',
      url        => 'http://www.dagolden.com/index.php/comments/feed/',
      web_url    => 'http://www.dagolden.com/',
      feed_class => 'RSS',
    },
    { name       => 'Perl Hacks',
      url        => 'http://perlhacks.com/feed/',
      web_url    => 'http://perlhacks.com/',
      feed_class => 'RSS',
    },
    { name       => 'Sebastian Kraih',
      url        => 'http://blog.kraih.com/rss',
      web_url    => 'http://blog.kraih.com/',
      feed_class => 'RSS',
    },
    { name       => 'perl.com',
      url        => 'http://www.perl.com/pub/atom.xml',
      web_url    => 'http://www.perl.com/',
      feed_class => 'RSS',
    },
    { name       => 'Rakudo',
      url        => 'http://rakudo.org/feed/',
      web_url    => 'http://rakudo.org/',
      feed_class => 'RSS',
    },
    { name       => '6guts',
      url        => 'http://6guts.wordpress.com/feed/',
      web_url    => 'http://6guts.wordpress.com/',
      feed_class => 'RSS',
    },
    { name       => 'Strangely Consistent',
      url        => 'http://strangelyconsistent.org/blog/feed.atom',
      web_url    => 'http://strangelyconsistent.org/',
      feed_class => 'RSS',
    },
    { name       => 'Perlgeek.de',
      url        => 'http://perlgeek.de/blog-en/index.rss',
      web_url    => 'http://perlgeek.de/blog-en/',
      feed_class => 'RSS',
    },
    { name       => 'mst',
      url        => 'http://shadow.cat/feed/blog/matt-s-trout/',
      web_url    => 'http://shadow.cat/blog/matt-s-trout/',
      feed_class => 'RSS',
    },
    { name       => 'Perl Foundation',
      url        => 'http://news.perlfoundation.org/atom.xml',
      web_url    => 'http://news.perlfoundation.org/',
      feed_class => 'RSS',
    },
    { name       => 'Perlcast',
      url        => 'http://perlcast.com/rss/current.xml',
      web_url    => 'http://perlcast.com/',
      feed_class => 'RSS',
    },
    { name       => 'YAPC::TV',
      url        => 'http://yapc.tv/rss/en/',
      web_url    => 'http://yapc.tv/',
      feed_class => 'RSS',
    },
    { name       => 'Perl Tricks',
      url        => 'http://perltricks.com/feed/rss',
      web_url    => 'http://perltricks.com/',
      feed_class => 'RSS',
    },
    { name       => 'Booking.com dev blog',
      url        => 'http://blog.booking.com/atom.xml',
      web_url    => 'http://blog.booking.com/',
      feed_class => 'RSS',
    },
    { name       => 'Modern Perl Programming',
      url        => 'http://www.modernperlbooks.com/mt/atom.xml',
      web_url    => 'http://www.modernperlbooks.com/',
      feed_class => 'RSS',
    },
    { name       => 'ActiveState',
      url        => 'http://www.activestate.com/taxonomy/term/134/0/feed',
      web_url    => 'http://www.activestate.com/blog/tag/blog-tags/perl',
      feed_class => 'RSS',
    },
    { name       => 'PerlMonks',
      url        => 'http://www.perlmonks.org/?node_id=30175;xmlstyle=rss',
      web_url    => 'http://www.perlmonks.org/',
      feed_class => 'RSS',
    },
    { name       => 'Stack Overflow',
      url        => 'http://www.perlmonks.org/?node_id=30175;xmlstyle=rss',
      web_url    => 'http://www.perlmonks.org/',
      feed_class => 'RSS',
    },
    { name       => '/r/perl',
      url        => 'http://www.reddit.com/r/perl/new/.rss',
      web_url    => 'http://www.reddit.com/r/perl',
      feed_class => 'RSS',
    },
    { name       => 'stackoverflow CAREERS',
      url        => 'http://careers.stackoverflow.com/jobs/feed?tags=perl',
      web_url    => 'http://careers.stackoverflow.com/jobs/tag/perl',
      feed_class => 'RSS',
      jobs       => 1,
    },
    { name       => 'YAPC::Europe Foundation',
      url        => 'http://www.yapceurope.org/feeds/news.rss',
      web_url    => 'http://www.yapceurope.org/',
      feed_class => 'RSS',
    },
  );
}

sub add_feed {
  my ( $self, $context, $context_id, %params ) = @_;
  $self->next_step;
  my $feed = $self->pt->add_feed(%params);
  $self->isa_ok( $feed, 'PT::DB::Result::Feed' );
}

sub add_feeds {
  my ( $self, $context, $context_id ) = @_;
  for my $feed ( $self->feeds ) {
    $self->add_feed( $context, $context_id, %$feed );
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;
