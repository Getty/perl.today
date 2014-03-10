package PT::Web::Table;

# ABSTRACT:

use Moose;
use PT::Web::Table::Column;
use List::MoreUtils qw( natatime );
use Digest::MD5 qw( md5_base64 );
use namespace::autoclean;

has c => (
    is       => 'ro',
    isa      => 'PT::Web',
    required => 1,
    weak_ref => 1,
);

has u => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 1,
);

sub table_params {
    my ($self) = @_;
    (   $self->page > 1 ? ( $self->key_page, $self->page ) : (),

        # $self->sorting ne $self->default_sorting
        #   ? ( $self->key_sort, $self->sorting )
        #   : (),
    );
}

sub u_page {
    my ( $self, $page ) = @_;
    return [ @{ $self->u }, { $self->table_params, $self->key_page, $page } ];
}

sub u_pagesize {
    my ( $self, $pagesize ) = @_;
    return [
        @{ $self->u },
        { $self->table_params, $self->key_pagesize, $pagesize }
    ];
}

# sub u_sort {
#   my ( $self, $sort ) = @_;
#   return [@{$self->u},{ $self->table_params, $self->key_sort, $sort }];
# }

has resultset => (
    is       => 'ro',
    isa      => 'DBIx::Class::ResultSet',
    required => 1,
);
sub resultset_search { shift->resultset->search( {} ) }

has columns_config => (
    is       => 'ro',
    isa      => 'ArrayRef[Str|Undef|HashRef|ArrayRef|CodeRef]',
    required => 1,
    init_arg => 'columns',
);

has cols => (
    is      => 'ro',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my @cc = @{ $self->columns_config };
        my $it = natatime 2, @cc;
        my @cols;
        while ( my ( $label, $def ) = $it->() ) {
            if ( !ref $def ) {
                push @cols, $self->_new_col( $label, db_col => $def );
            }
            elsif ( ref $def eq 'HASH' ) {
                push @cols, $self->_new_col( $label, %{$def} );
            }
            elsif ( ref $def eq 'CODE' ) {
                push @cols, $self->_new_col( $label, value_code => $def );
            }
            elsif ( ref $def eq 'ARRAY' ) {
                my $size = scalar @{$def};
                if ( $size == 2 ) {
                    push @cols,
                        $self->_new_col(
                        $label,
                        db_col     => $def->[0],
                        value_code => $def->[1],
                        );
                }
                else {
                    die __PACKAGE__ . " unknown column def array size";
                }
            }
            elsif ( ref $def eq 'PT::Web::Table::Column' ) {
                push @cols, $def;
            }
            else {
                die __PACKAGE__ . " cant handle column def";
            }
        }
        return \@cols;
    },
);

sub _new_col {
    my ( $self, $label, %args ) = @_;
    return PT::Web::Table::Column->new(
        table => $self,
        defined $label ? ( label => $label ) : (),
        %args,
    );
}

has page => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->c->req->param( $self->key_page ) || 1;
    },
);

has default_pagesize => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    default => sub {20},
);

has pagesizes => (
    is      => 'ro',
    isa     => 'ArrayRef[Int]',
    lazy    => 1,
    default => sub {
        [   qw(
                5
                10
                20
                50
                )
        ];
    },
);

has pagesize => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $pagesize =
               $self->c->req->param( $self->key_pagesize )
            || $self->c->session->{ $self->key_pagesize }
            || $self->default_pagesize;
        $self->c->session->{ $self->key_pagesize } = $pagesize;
        return $self->c->session->{ $self->key_pagesize };
    },
);

has paged_rs => (
    is      => 'ro',
    isa     => 'DBIx::Class::ResultSet',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        $self->resultset->search(
            {},
            {   page => $self->page,
                rows => $self->pagesize,

                # $self->sorting
                #   ? ( order_by => $self->order_by )
                #   : (),
            }
        );
    },
);

has key_sort => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        $self->key . '_sort';
    },
);

has key_page => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { $_[0]->key . '_page_' . $_[0]->pagesize },
);

has key_pagesize => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { 'tablepagesize_' . md5_base64( $_[0]->id_pagesize ) },
);

has key => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub { 'table_' . md5_base64( $_[0]->id ) },
);

has id_pagesize => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my @id_pagesize;
        for my $part_u ( @{ $self->u } ) {
            if ( ref $part_u eq '' ) {
                push @id_pagesize, $part_u;
            }
            elsif ( ref $part_u eq 'HASH' ) {
                for ( sort { $a cmp $b } keys %{$part_u} ) {
                    push @id_pagesize, $_;
                    push @id_pagesize, $part_u->{$_};
                }
            }
        }
        return join( '|', @id_pagesize );
    },
);

has id => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my ($self)               = @_;
        my $rs_as_query          = $self->resultset_search->as_query;
        my $arrayref_rs_as_query = ${$rs_as_query};
        my @as_query             = @{$arrayref_rs_as_query};
        my $id                   = "";
        for my $qp (@as_query) {
            if ( ref $qp eq 'HASH' ) {
                for ( sort { $a cmp $b } keys %{$qp} ) {
                    $id .= $_;
                    $id .= $qp->{$_};
                }
            }
            elsif ( ref $qp eq '' ) {
                $id .= "$qp";
            }
            elsif ( ref $qp eq 'ARRAY' ) {
                push @as_query, @{$qp};
            }
            else {
                die __PACKAGE__
                    . " cant use a specific part of as_query for this resultset (it is a "
                    . ( ref $qp ) . ")";
            }
        }
        return $id;
    },
);

has pager_pages => (
    is      => 'ro',
    isa     => 'ArrayRef[Int|Undef]',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my @p;
        for ( 1 .. $self->last_page ) {
            if ($_ == $self->first_page
                || (   $_ >= $self->current_page - 4
                    && $_ <= $self->current_page + 4 )
                || $_ == $self->last_page
                )
            {
                push @p, $_;
            }
            else {
                push @p, undef if defined $p[-1];
            }
        }
        return \@p;
    },
);

has data_page => (
    is      => 'ro',
    isa     => 'Data::Page',
    lazy    => 1,
    default => sub { shift->paged_rs->pager },
    handles => [
        qw(
            total_entries
            entries_per_page
            current_page
            first_page
            last_page
            first
            last
            previous_page
            next_page
            splice
            skipped
            )
    ],

    # change_entries_per_page - i think i dont want this
);

no Moose;
__PACKAGE__->meta->make_immutable;
