package PT::Web::Table::Column;

# ABSTRACT: Abstraction for a column definition in PT::Web::Table

use Moose;

has table => (
    is       => 'ro',
    isa      => 'PT::Web::Table',
    required => 1,
);

has label => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_label',
);

has value_code => (
    is        => 'ro',
    isa       => 'CodeRef',
    predicate => 'has_value_code',
);

has db_col => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_db_col',
);

sub value {
    my ( $self, $row ) = @_;
    if ( $self->has_value_code ) {
        return $self->value_code->( $row, $self->table, $self );
    }
    if ( $self->has_db_col ) {
        my $col_func = $self->db_col;
        return $row->$col_func;
    }
    die "No method to get value";
}

no Moose;
__PACKAGE__->meta->make_immutable;
