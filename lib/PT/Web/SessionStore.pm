package PT::Web::SessionStore;
 
use strict;
use warnings;
use base qw/Catalyst::Plugin::Session::Store::DBIC/;

sub session_store_model {
  my ($c, $id) = @_;

  $c->pt->rs('Session',$id);

}

1;