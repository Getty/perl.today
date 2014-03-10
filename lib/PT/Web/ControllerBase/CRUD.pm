package PT::Web::ControllerBase::CRUD;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub crud_base : Chained('base') : PathPart('') : CaptureArgs(0) {
    my ( $self, $c ) = @_;
    $c->stash->{object_key} = 'key' unless defined $c->stash->{object_key};
    $c->stash->{object_name_attr} = 'name'
        unless defined $c->stash->{object_name_attr};
    $c->stash->{resultset_order} = { -asc => $c->stash->{object_key} }
        unless defined $c->stash->{resultset_order};
    $c->stash->{crud_captures} = [] unless defined $c->stash->{crud_captures};
    my $crud_controller = ref $self;
    $crud_controller =~ s/^PT::Web::Controller:://;
    $c->stash->{crud_controller} = $crud_controller;
    $c->stash->{crud_url}        = sub {
        my ( $action, $object, @url_args ) = @_;
        $action = 'index' unless $action;
        my $obj_key = $c->stash->{object_key};
        my @args    = (
            $crud_controller, $action,
            @{ $c->stash->{crud_captures} },
            $object ? ( $object->$obj_key() ) : ()
        );
        return $c->chained_uri( @args, @url_args );
    };
}

sub push_crud_template {
    my ( $self, $c ) = @_;
    push @{ $c->stash->{template_layout} }, 'crud/base.tx';
}

sub index : Chained('crud_base') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{heading} = $c->stash->{object_title_list};
    die "no resultset defined" unless defined $c->stash->{resultset};
    $c->stash->{count} = $c->stash->{resultset}->count;
    if ( $c->stash->{count} == 0 ) {
        $c->response->redirect( $c->stash->{crud_url}->('add') );
        return $c->detach;
    }
    $c->stash->{table} = $c->table(
        $c->stash->{resultset}
            ->search_rs( {}, { order_by => $c->stash->{resultset_order}, } ),
        [   $c->stash->{crud_controller}, 'index',
            @{ $c->stash->{crud_captures} }
        ],
        $c->stash->{columns},
        default_pagesize => 15,
        id               => lc( $c->stash->{crud_controller} ) . '_index',
    );
    $self->push_crud_template($c);
}

sub add : Chained('crud_base') : Args(0) {
    my ( $self, $c ) = @_;
    $c->breadcrumb_add(
        'Add',
        [   $c->stash->{crud_controller}, 'add',
            @{ $c->stash->{crud_captures} }
        ]
    );
    $c->stash->{heading} = 'Add ' . $c->stash->{object_name};
    $c->stash->{object} =
          $self->can('new_object')
        ? $self->new_object($c)
        : $c->stash->{resultset}->new_result( {} );
    return $self->form($c);
}

sub item : Chained('crud_base') : PathPart('') : CaptureArgs(1) {
    my ( $self, $c, $key ) = @_;
    $c->stash->{object} =
        $c->stash->{resultset}->find( { $c->stash->{object_key}, $key } );
    my $obj_name_attr = $c->stash->{object_name_attr};
    $c->stash->{heading} =
          $c->stash->{object_title}
        . ' <strong>'
        . $c->stash->{object}->$obj_name_attr
        . '</strong>';
    $c->breadcrumb_add( $c->stash->{object}->$obj_name_attr );
}

sub edit : Chained('item') : Args(0) {
    my ( $self, $c ) = @_;
    my $obj_key = $c->stash->{object_key};
    $c->breadcrumb_add(
        'Edit',
        [   $c->stash->{crud_controller},    'edit',
            @{ $c->stash->{crud_captures} }, $c->stash->{object}->$obj_key
        ]
    );
    return $self->form($c);
}

sub delete : Chained('item') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{crud_delete} = 1;
    if ( $c->req->params->{really_delete} ) {
        $c->stash->{object}->delete;
        $c->response->redirect( $c->stash->{crud_url}->() );
        return $c->detach;
    }
    my $obj_key = $c->stash->{object_key};
    $c->breadcrumb_add(
        'Delete',
        [   $c->stash->{crud_controller},    'delete',
            @{ $c->stash->{crud_captures} }, $c->stash->{object}->$obj_key
        ]
    );
    $self->push_crud_template($c);
}

sub form {
    my ( $self, $c ) = @_;
    $c->stash->{form} = $c->form_dbic(
        $c->stash->{object},
        [   @{ $c->stash->{object}->field_list },
            submit => {
                type                  => 'Submit',
                value                 => 'Save',
                element_wrapper_class => [ 'col-sm-offset-2', 'col-sm-10' ],
                element_class         => [ 'btn', 'btn-default' ],
            },
        ],
    );
    $c->stash->{fif} = $c->stash->{form}->fif;
    $self->push_crud_template($c);
    return
        unless $c->stash->{form}->process(
        item   => $c->stash->{object},
        params => $c->req->parameters,
        );
    $c->response->redirect( $c->stash->{crud_url}->() );
    my $obj_name_attr = $c->stash->{object_name_attr};
    $c->add_alert(
        'Saved '
            . $c->stash->{object_name}
            . ' <strong>'
            . $c->stash->{object}->$obj_name_attr
            . '</strong>',
        'success'
    );

    if ( $self->can('success') ) {
        $self->success( $c, $c->stash->{object} );
    }
    return $c->detach;
}

__PACKAGE__->meta->make_immutable;

1;
