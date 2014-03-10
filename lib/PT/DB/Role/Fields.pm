package PT::DB::Role::Fields;

# ABSTRACT: Role for field functions

use Moose::Role;
use URI;
use namespace::autoclean;

sub field_yes_no {
    {   type    => 'Select',
        options => [
            {   value => 1,
                label => 'Yes'
            },
            {   value => 0,
                label => 'No'
            }
        ]
    };
}

sub field_no_yes {
    {   type    => 'Select',
        options => [
            {   value => 0,
                label => 'No'
            },
            {   value => 1,
                label => 'Yes'
            }
        ]
    };
}

sub field_on_off {
    {   type    => 'Select',
        options => [
            {   value => 1,
                label => 'On'
            },
            {   value => 0,
                label => 'Off'
            }
        ]
    };
}

sub field_url {
    {   type     => 'Text',
        required => 1,
        apply    => [
            {   check => sub {
                    my $return = 0;
                    eval {
                        my $u = URI->new( $_[0] );
                        $return =
                            ( $u->scheme eq 'http' || $u->scheme eq 'https' )
                            ? 1
                            : 0;
                    };
                    return $return;
                },
                message => 'Require valid HTTP(S) URL',
            },
            {   transform => sub {
                    my $u     = URI->new( $_[0] );
                    my $url   = $u->canonical->as_string;
                    my @chars = split( //, $url );
                    $url .= '/' unless $chars[-1] eq '/';
                    return $url;
                },
            }
        ]
    };
}

sub field_key {
    {   type     => 'Text',
        required => 1,
        $_[1] ? ( unique => 1 ) : (),
        apply => [
            {   check => qr/^[a-zA-Z0-9_]+$/,
                message =>
                    'Key may only have letters, numbers and underscore',
            },
            {   check   => qr/^[^_]/,
                message => 'Key may not start with underscore',
            },
            {   check   => qr/[^_]$/,
                message => 'Key may not end with underscore',
            },
            { transform => sub { lc( $_[0] ) }, }
        ],
    };
}

1;
