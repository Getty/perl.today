package PT::DB::Result;

# ABSTRACT: Base class for all DBIx::Class Result base classes of the project

use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Core';
use PT;
use Package::Stash;
use URI;
use namespace::autoclean;

use Moose::Util qw/ apply_all_roles /;

__PACKAGE__->load_components(
  qw/
      EncodedColumn
      TimeStamp
      InflateColumn::DateTime
      InflateColumn::Serializer
      Helper::Row::OnColumnChange
      Helper::Row::ProxyResultSetMethod
      +DBICx::Indexing
      Core
      /
);

with qw(
    PT::DB::Role::Fields
);

sub new {
  my $class = shift;
  my $self  = $class->next::method(@_);
  foreach my $col ( $self->result_source->columns ) {
    my $default = $self->result_source->column_info($col)->{default_value};
    $self->set_column( $col, $default )
        if ( defined $default && !defined $self->set_column($col) );
  }
  return $self;
}

sub context_config {
  my ( $class, %opts ) = @_;
  { 'PT::DB::Result::Comment' => {
      relation => 'comment',
      prefetch => [
        qw( user parent ),
        ( $opts{comment_prefetch}
          ? ( $opts{comment_prefetch} )
          : ()
        )
      ],
    },
    'PT::DB::Result::Event' => { relation => 'event', },
  };
}

sub add_context_relations {
  my ($class) = @_;
  $class->add_context_relations_column;
  $class->add_context_relations_role;
  $class->add_context_relations_belongs_to;
}

sub add_context_relations_column {
  my ($class) = @_;
  $class->add_column(
    context => {
      data_type   => 'text',
      is_nullable => 0,
    }
  );
  $class->add_column(
    context_id => {
      data_type   => 'bigint',
      is_nullable => 0,
    }
  );
}

sub add_data_created_updated {
  my ($class) = @_;
  $class->add_column(
    data => {
      data_type        => 'text',
      is_nullable      => 0,
      serializer_class => 'JSON',
      default_value    => '{}',
    }
  );
  $class->add_created_updated;
}

sub add_created_updated {
  my ($class) = @_;
  $class->add_created;
  $class->add_column(
    updated => {
      data_type     => 'timestamp with time zone',
      set_on_create => 1,
      set_on_update => 1,
    }
  );
}

sub add_created {
  my ($class) = @_;
  $class->add_column(
    created => {
      data_type     => 'timestamp with time zone',
      set_on_create => 1,
    }
  );
}

sub add_context_relations_role {
  my ($class) = @_;
  apply_all_roles( $class, 'PT::DB::Role::HasContext' );
}

sub add_context_relations_belongs_to {
  my ($class) = @_;
  for my $context_class (
    sort { $a cmp $b }
    keys %{ $class->context_config }
      )
  {
    next if $context_class eq $class;
    my $config = $class->context_config->{$context_class};
    $class->belongs_to(
      $config->{relation},
      $context_class,
      sub {
        { "$_[0]->{foreign_alias}.id" =>
              { -ident => "$_[0]->{self_alias}.context_id" },
          "$_[0]->{self_alias}.context" => $context_class,
        };
      },
      { join_type => 'left',
        on_delete => 'no action',
      }
    );
  }
}

sub default_result_namespace {'PT::DB::Result'}

sub pt     { shift->result_source->schema->pt }
sub schema { shift->result_source->schema }

sub add_event {
  my ( $self, $action, %args ) = @_;
  return if $self->schema->no_events;
  my %event;
  $event{context}    = ref $self;
  $event{context_id} = $self->id;
  my $users_id;
  if ( $self->can('users_id') ) {
    $users_id = $self->users_id;
  }
  elsif ( $self->can('user') ) {
    $users_id = $self->user->id;
  }
  $users_id = delete $args{users_id} if defined $args{users_id};
  if ($users_id) {
    $event{users_id} = $users_id;
  }
  $event{action} = $action;
  if ( $self->can('event_related') ) {
    $event{related} = [
      $self->event_related,
      defined $args{related} ? @{ delete $args{related} } : ()
    ];
  }
  if ( $args{related} ) {
    $event{related} = [] unless defined $event{related};
    my $related = delete $args{related};
    push @{ $event{related} }, @{$related};
  }
  my @related =
      defined $event{related}
      ? ( @{ delete $event{related} } )
      : ();
  $event{data} = \%args if %args;
  $self->pt->db->txn_do(
    sub {
      my $event_result =
          $self->result_source->schema->resultset('Event')
          ->create( {%event} );
      for (@related) {
        $event_result->create_related(
          'event_relates',
          { context    => $_->[0],
            context_id => $_->[1],
          }
        );
      }
    }
  );
}

sub has_context {
  my ($self) = @_;
  return $self->does('PT::DB::Role::HasContext');
}

sub all_comments {
  my ($self) = @_;
  return $self->schema->resultset('Comment')->search_rs(
    { 'me.context'    => $self->i_context,
      'me.context_id' => $self->i_context_id,
    },
    { order_by => { -desc => [qw( me.updated )] }, }
  );
}

sub title_to_url {
  my $self = shift;
  my $key = substr( lc( $self->title ), 0, 50 );
  $key =~ s/[^a-z0-9]+/-/g;
  $key =~ s/-+/-/g;
  $key =~ s/-$//;
  $key =~ s/^-//;
  return $key || 'url';
}

sub comments {
  my ($self) = @_;
  return $self->schema->resultset('Comment')->search_rs(
    { 'me.context'    => $self->i_context,
      'me.context_id' => $self->i_context_id,
      'me.parent_id'  => undef,
    },
    { order_by => { -desc => [qw( me.updated )] }, }
  )->prefetch_tree;
}

sub context_name {
  my ($self) = @_;
  my $ref = ref $self;
  return $ref;
}

sub i_context { shift->context_name(@_) }

sub i_context_id {
  my ($self) = @_;
  return $self->id;
}

sub belongs_to {
  my ( $self, @args ) = @_;

  $args[3] = {
    is_foreign => 1,
    on_update  => 'cascade',
    on_delete  => 'restrict',
    %{ $args[3] || {} }
  };

  $self->next::method(@args);
}

sub delete {
  my ( $self, @args ) = @_;

  my $context    = $self->context_name;
  my $context_id = $self->id;

  my $result = $self->next::method(@args);

  $self->schema->resultset('Event')->search(
    [ { 'me.context'    => $context,
        'me.context_id' => $context_id,
      },
      { 'event_relates.context'    => $context,
        'event_relates.context_id' => $context_id,
      }
    ],
    { join => [qw( event_relates )], }
  )->delete;

  $self->schema->resultset('Event::Relate')->search(
    { context    => $context,
      context_id => $context_id,
    }
  )->delete;

  $self->schema->resultset('Comment')->search(
    { context    => $context,
      context_id => $context_id,
    }
  )->delete;

  return $result;
}

use overload '""' => sub {
  my $self = shift;
  return ( ref $self ) . ' #' . $self->id;
    },
    fallback => 1;

1;
