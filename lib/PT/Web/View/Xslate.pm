package PT::Web::View::Xslate;

# ABSTRACT: Using the PT Xslate component as view

use Moose;
extends 'Catalyst::View::Xslate';

use PT::Util::DateTime ();

#
# WARNING: Configuration of Text::Xslate itself happens in PT->xslate
#
#########################################################################

__PACKAGE__->config(
    encode_body    => 0,
    expose_methods => [
        qw(
            next_template
            link
            u
            cu
            l
            dur
            dur_precise
            )
    ],
);

sub pt { shift->_app->pt }

sub _build_xslate {
    my ($self) = @_;
    return $self->pt->xslate;
}

sub process {
    my $self = shift;
    my $c    = shift;
    $c->stash->{template_layout} ||= [];
    my @layouts =
        ( @{ $c->stash->{template_layout} }, $c->stash->{template} );
    $c->stash->{LAYOUTS}  = \@layouts;
    $c->stash->{template} = shift @layouts;
    return $self->next::method( $c, @_ );
}

sub next_template {
    my ( $self, $c ) = @_;
    my @layouts = @{ $c->stash->{LAYOUTS} };
    my $return  = shift @layouts;
    $c->stash->{LAYOUTS} = \@layouts;
    return $return;
}

sub link {
    my $self   = shift;
    my $c      = shift;
    my $object = shift;
    $self->u( $c, $object->u, @_ );
}

# url
sub u {
    my $self = shift;
    my $c    = shift;
    my @args;
    for (@_) {
        if ( ref $_ eq 'ARRAY' ) {
            push @args, @{$_};
        }
        else {
            push @args, $_;
        }
    }
    return $c->chained_uri(@args);
}

# current url
sub cu {
    my $self = shift;
    my $c    = shift;
    return [ $c->current_chained_uri(@_) ];
}

# localize
sub l { shift; shift->localize(@_) }

# legacy, use dur() in template not $dur()
sub dur { my ( $self, $c, $date ) = @_; PT::Util::DateTime::dur($date); }

sub dur_precise {
    my ( $self, $c, $date ) = @_;
    PT::Util::DateTime::dur_precise($date);
}

no Moose;
__PACKAGE__->meta->make_immutable;
