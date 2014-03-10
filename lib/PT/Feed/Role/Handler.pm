use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package PT::Feed::Role::Handler;

# ABSTRACT: A thing that handles a feed

# AUTHORITY

use Moose::Role;

has 'url' => (
  is       => ro =>,
  required => 1,
);

no Moose::Role;

1;

