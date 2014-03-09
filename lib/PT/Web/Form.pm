package PT::Web::Form;

use Moose;
extends 'HTML::FormHandler';
use List::MoreUtils qw( natatime );
use JSON::MaybeXS;

with qw(
  HTML::FormHandler::Widget::Theme::Bootstrap3
);

has '+field_name_space' => ( default => sub { 'PT::Web::Field' } );
has '+widget_wrapper' => ( default => sub { 'Bootstrap3' } );
has '+is_html5'  => ( default => 1 );

sub pt { $_[0]->ctx->pt }

sub new_via_obj {
  my ( $class, $obj, $field_list, %args ) = @_;
  my @new_field_list;
  my $it = natatime 2, @{$field_list};
  while (my ( $field, $def ) = $it->()) {
    push @new_field_list, $field, {
      element_wrapper_class => ['col-sm-10'],
      label_class => ['col-sm-2'],
      %{$def},
    };
  }
  $class->new(
    field_list => \@new_field_list,
    init_object => $obj,
    %args,
  );
}

sub inflate_json {
  my ( $self, $value ) = @_;
  use DDP; p($value);
  my $json = JSON::MaybeXS->new->convert_blessed(1)->utf8(1)->pretty(1);
  return $json->decode($value);
}

sub deflate_json {
  my ( $self, $value ) = @_;
  use DDP; p($value);
  my $json = JSON::MaybeXS->new->convert_blessed(1)->utf8(1)->pretty(1);
  return $json->encode($value);
}

no Moose;
__PACKAGE__->meta->make_immutable;
