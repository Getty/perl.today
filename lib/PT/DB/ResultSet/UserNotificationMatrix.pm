package PT::DB::ResultSet::UserNotificationMatrix;

# ABSTRACT: Resultset class for idea entries

use Moose;
extends 'PT::DB::ResultSet';
use namespace::autoclean;

sub prefetch_all {
    my ($self) = @_;
    $self->search_rs(
        {},
        {   prefetch => [
                qw( user ),
                $self->prefetch_context_config(
                    'PT::DB::Result::UserNotificationMatrix',
                    comment_prefetch => $self->prefetch_context_config(
                        'PT::DB::Result::Comment'),
                )
            ],
        }
    );
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
