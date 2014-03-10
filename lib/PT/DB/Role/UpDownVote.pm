package PT::DB::Role::UpDownVote;

# ABSTRACT: A role for classes which uses the context / context_id concept

use Moose::Role;

requires qw( id );

sub vote {
  my ( $self, $user, $up_or_down ) = @_;
  my $value      = $up_or_down ? 1 : -1;
  my $context    = $self->i_context;
  my $context_id = $self->i_context_id;
  $self->schema->resultset('Vote')->update_or_create(
    { users_id   => $user->id,
      context    => $context,
      context_id => $context_id,
      vote       => $value,
    },
    { key => 'vote_users_id_context_context_id', }
  );
}

sub upvote {
  my ( $self, $user ) = @_;
  $self->vote( $user, 1 );
}

sub downvote {
  my ( $self, $user ) = @_;
  $self->vote( $user, 0 );
}

sub unvote {
  my ( $self, $user ) = @_;
  my $context    = $self->i_context;
  my $context_id = $self->i_context_id;
  $self->schema->resultset('Vote')->search(
    { users_id   => $user->id,
      context    => $context,
      context_id => $context_id,
    }
  )->delete;
}

1;
