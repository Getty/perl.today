package PT::DB::Result::UserNotificationGroup;

# ABSTRACT:

use Moose;
use MooseX::NonMoose;
extends 'PT::DB::Result';
use DBIx::Class::Candy;
use namespace::autoclean;

table 'user_notification_group';

column id => {
    data_type         => 'bigint',
    is_auto_increment => 1,
};
primary_key 'id';

column type => {
    data_type   => 'text',
    is_nullable => 0,
};

column context => {
    data_type   => 'text',
    is_nullable => 0,
};

column with_context_id => {
    data_type   => 'int',
    is_nullable => 0,
};

column group_context => {
    data_type   => 'text',
    is_nullable => 1,
};

column sub_context => {
    data_type   => 'text',
    is_nullable => 0,
};

column action => {
    data_type   => 'text',
    is_nullable => 0,
};

column priority => {
    data_type   => 'int',
    is_nullable => 0,
};

column email_has_content => {
    data_type     => 'int',
    is_nullable   => 0,
    default_value => 1,
};

__PACKAGE__->add_data_created_updated;

has_many 'user_notifications', 'PT::DB::Result::UserNotification',
    'user_notification_group_id', { cascade_delete => 1, };
has_many 'event_notification_groups',
    'PT::DB::Result::EventNotificationGroup', 'user_notification_group_id',
    { cascade_delete => 1, };

__PACKAGE__->indices(
    user_notification_group_context_idx         => 'context',
    user_notification_group_with_context_id_idx => 'with_context_id',
    user_notification_group_group_context_idx   => 'group_context',
    user_notification_group_sub_context_idx     => 'sub_context',
    user_notification_group_action_idx          => 'action',
    user_notification_group_priority_idx        => 'priority',
);

unique_constraint(
    user_notification_group_unique_key => [
        qw/
            type context with_context_id sub_context action
            /
    ]
);

###############################

sub default_types_def {
    {

        # default key = join(|,context.context_name,context.id)
        # beware: context of the fitting related that is hit by the group type
        # not "the context" of the event itself

        # user replies on a comment
        'replies' => {
            context     => 'PT::DB::Result::Comment',
            context_id  => '*',
            sub_context => 'PT::DB::Result::Comment',
            action      => 'create',
            priority    => 100,
        },

        'comments' => {
            context => [
                qw(
                    )
            ],
            context_id  => ['*'],
            sub_context => 'PT::DB::Result::Comment',
            action      => 'create',
        },

    };
}

sub filter {
    my ($self) = @_;
    return $self->default_types_def->{ $self->type }->{filter};
}

sub group_context_id {
    my ($self) = @_;
    return $self->default_types_def->{ $self->type }->{group_context_id};
}

sub u {
    my ($self) = @_;
    return $self->default_types_def->{ $self->type }->{u};
}

sub icon {
    my ($self) = @_;
    return
        defined $self->default_types_def->{ $self->type }->{icon}
        ? $self->default_types_def->{ $self->type }->{icon}
        : 'default';
}

sub default_types {
    my ($self) = @_;

    my @types;

    for my $type ( keys %{ $self->default_types_def } ) {
        my %def = %{ $self->default_types_def->{$type} };
        my @contexts =
            ref $def{context} eq 'ARRAY'
            ? ( @{ $def{context} } )
            : ( $def{context} );
        for my $context (@contexts) {
            my @context_ids =
                ref $def{context_id} eq 'ARRAY'
                ? ( @{ $def{context_id} } )
                : ( $def{context_id} );
            for my $context_id (@context_ids) {
                my $with_context_id = $context_id eq '*' ? 1 : 0;
                push @types,
                    {
                    type          => $type,
                    context       => $context,
                    group_context => defined $def{group_context}
                    ? $def{group_context}
                    : $context,
                    sub_context     => $def{sub_context},
                    with_context_id => $with_context_id,
                    action          => $def{action},
                    priority        => $def{priority} ? $def{priority}
                    : $with_context_id ? 0
                    : 1,
                    defined $def{email_has_content}
                    ? ( email_has_content => $def{email_has_content} )
                    : (),
                    };
            }
        }
    }

    return @types;

}

no Moose;
__PACKAGE__->meta->make_immutable;
