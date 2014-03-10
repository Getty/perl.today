package PT::Postman;

# ABSTRACT: Mail functions

use Moose;
use Email::Sender::Simple qw( sendmail );
use Email::Simple;
use Email::Simple::Creator;
use Email::MIME;
use Email::Sender::Transport::SMTP;
use Email::Sender::Transport::Sendmail;
use Email::Sender::Transport::Test;
use Data::Dumper;
use IO::All;

has pt => (
  isa      => 'PT',
  is       => 'ro',
  required => 1,
  weak_ref => 1,
);

has transport => (
  does       => 'Email::Sender::Transport',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_transport {
  my ($self) = @_;
  return Email::Sender::Transport::Test->new
      if $self->pt->config->mail_test;
  return Email::Sender::Transport::Sendmail->new
      unless $self->pt->config->smtp_host;
  my %smtp_args;
  $smtp_args{host}          = $self->pt->config->smtp_host;
  $smtp_args{ssl}           = $self->pt->config->smtp_ssl;
  $smtp_args{sasl_username} = $self->pt->config->smtp_sasl_username
      if $self->pt->config->smtp_sasl_username;
  $smtp_args{sasl_password} = $self->pt->config->smtp_sasl_password
      if $self->pt->config->smtp_sasl_password;
  return Email::Sender::Transport::SMTP->new( {%smtp_args} );
}

sub mail {
  my ( $self, $to, $subject, $body, %extra_headers ) = @_;
  die __PACKAGE__ . "->mail needs to, subject, body"
      unless $body && $subject && $to;
  my $from = $self->pt->config->email_from;
  $from = delete $extra_headers{from} if defined $extra_headers{from};
  $subject =~ s/\n/ /g;
  $subject = '[' . $self->pt->config->email_prefix . '] ' . $subject;
  my $email = Email::Simple->create(
    header => [
      To      => $to,
      From    => $from,
      Subject => $subject,
      %extra_headers,
    ],
    body => $body,
  );
  my @return = sendmail( $email, { transport => $self->transport } );

  if ( $self->pt->config->mail_test && $self->pt->config->mail_test_log ) {
    my @deliveries = $self->transport->deliveries;
    io( $self->pt->config->mail_test_log )->append( Dumper \@deliveries );
  }
  return @return;
}

sub template_mail {
  my ( $self, $to, $subject, $template, $stash, %extra ) = @_;
  my @return;
  $self->pt->force_privacy(
    sub {
      $stash->{email_template} = "email/" . $template . ".tx";
      my $body = $self->pt->xslate->render( 'email/base.tx', $stash );
      @return = $self->html_mail( $to, $subject, $body, %extra );
    }
  );
  return @return;
}

sub html_mail {
  my ( $self, $to, $subject, $body, %extra ) = @_;
  die __PACKAGE__ . "->mail needs to, subject, body"
      unless $body && $subject && $to;
  my $from = $self->pt->config->email_from;
  $from = delete $extra{from} if defined $extra{from};
  $subject =~ s/\n/ /g;
  $subject = '[' . $self->pt->config->email_prefix . '] ' . $subject;
  my @parts =
      defined $extra{parts}
      ? ( @{ delete $extra{parts} } )
      : ();

  my $email = Email::MIME->create(
    attributes => { content_type => 'multipart/alternative', },
    header_str => [
      To      => $to,
      From    => $from,
      Subject => $subject,
      %extra,
    ],
    parts => [
      Email::MIME->create(
        attributes => {
          content_type              => 'text/html; charset="UTF-8"',
          content_transfer_encoding => '8bit',
        },
        body => $body,
      ),
      map { Email::MIME->create( %{$_} ); } @parts
    ],
  );

  my @return = sendmail( $email, { transport => $self->transport } );
  if ( $self->pt->config->mail_test && $self->pt->config->mail_test_log ) {
    my @deliveries = $self->transport->deliveries;
    io( $self->pt->config->mail_test_log )->append( Dumper \@deliveries );
  }
  return @return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
