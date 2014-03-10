package PT::DB::ResultSet::EventNotificationGroup;

# ABSTRACT: Resultset class for comment entries

use Moose;
extends 'PT::DB::ResultSet';
use namespace::autoclean;

sub prefetch_all {
    my ($self) = @_;
    $self->search_rs(
        {},
        {   prefetch => [
                qw( user_notification_group ),
                {   event_notifications => [
                        qw( user_notification ),
                        {   event => [
                                qw( user ),
                                {   %{  $self->prefetch_context_config(
                                            'PT::DB::Result::Event')
                                    },
                                    event_relates =>
                                        $self->prefetch_context_config(
                                        'PT::DB::Result::EventRelate'),
                                }
                            ],
                        }
                    ],
                }
            ],
        }
    );
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
