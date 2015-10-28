package OpenStack::Client;

use strict;
use warnings;

use JSON::XS ();

use HTTP::Request  ();
use LWP::UserAgent ();

use OpenStack::Client::Base ();

sub new ($%) {
    my ($class, $endpoint, %opts) = @_;

    die('No API authentication endpoint provided') unless $endpoint;

    return bless {
        'endpoints' => {},
        'clients'   => {},
        'token'     => undef,
        'auth'      => OpenStack::Client::Base->new($endpoint)
    }, $class;
}

sub service ($$%) {
    my ($self, $name, %opts) = @_;

    die('Not authenticated') unless defined $self->{'token'};

    $opts{'public'}   ||= 1;
    $opts{'internal'} ||= 0;
    $opts{'admin'}    ||= 0;

    die("No service endpoint '$name' found") unless defined $self->{'endpoints'}->{$name};

    if (defined $self->{'clients'}->{$name}) {
        return  $self->{'clients'}->{$name};
    }

    if (defined $opts{'uri'}) {
        return $self->{'clients'}->{$name} = OpenStack::Client::Base->new($opts{'uri'},
            'token' => $self->{'token'}
        );
    }

    if (!$opts{'public'} && !$opts{'internal'} && !$opts{'admin'}) {
        die('Neither "public", "internal" or "admin" specified in options');
    }

    foreach my $endpoint (@{$self->{'endpoints'}->{$name}}) {
        if (defined $opts{'region'} && $endpoint->{'region'} ne $opts{'region'}) {
            next;
        }

        my $uri;

        $uri = $endpoint->{'publicURL'}   if $opts{'public'};
        $uri = $endpoint->{'internalURL'} if $opts{'internal'};
        $uri = $endpoint->{'adminURL'}    if $opts{'admin'};

        return $self->{'clients'}->{$name} = OpenStack::Client::Base->new($uri,
            'token' => $self->{'token'}
        );
    }

    die("Could not find endpoint '$name'");
}

sub services ($) {
    return sort keys %{$self->{'endpoints'}};
}

sub token ($) {
    my ($self) = @_;

    die('Not authenticated') unless defined $self->{'token'};

    return $self->{'token'};
}

sub tenant ($) {
    shift->token->{'tenant'};
}

sub auth ($$$) {
    my ($self, %opts) = @_;

    return $self->{'token'} if defined $self->{'token'};

    my $auth = $self->{'auth'};

    my $response = $auth->call('POST' => '/tokens', {
        'auth' => {
            'tenantName'          => $opts{'tenant'},
            'passwordCredentials' => {
                'username' => $opts{'username'},
                'password' => $opts{'password'}
            }
        }
    });

    my $access = $response->{'access'};

    die('No token found in response') unless defined $access->{'token'}->{'id'};

    #
    # Create a new client object for each endpoint listed in the service
    # catalog, and store the token alongside
    #
    foreach my $service (@{$access->{'serviceCatalog'}}) {
        my $name = $service->{'name'};

        $self->{'endpoints'}->{$name} = $service->{'endpoints'};
    }

    return $self->{'token'} = $access->{'token'};
}

1;
