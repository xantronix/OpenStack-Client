package OpenStack::Client;

use strict;
use warnings;

use JSON::XS ();

use HTTP::Request  ();
use LWP::UserAgent ();

use OpenStack::Client::Base ();

sub new ($%) {
    my ($class, %endpoints) = @_;

    die('No API endpoint "keystone" provided') unless defined $endpoints{'keystone'};

    return bless {
        'access'  => undef,
        'clients' => {
            map {
                $_ => OpenStack::Client::Base->new($endpoints{$_})
            } keys %endpoints
        }
    }, $class;
}

sub service ($$) {
    my ($self, $endpoint) = @_;

    die("No client for service endpoint '$endpoint' found") unless defined $self->{'clients'}->{$endpoint};

    return $self->{'clients'}->{$endpoint};
}

sub auth ($$$) {
    my ($self, %opts) = @_;

    return $self->{'access'} if defined $self->{'access'};

    my $service = $self->service('keystone');

    my $response = $service->request('POST' => '/tokens', [], {
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
    # Associate the access credentials with each endpoint client
    #
    foreach my $name (keys %{$self->{'clients'}}) {
        $self->{'clients'}->{$name}->{'access'} = $access;
    }

    return $self->{'access'} = $access;
}

1;
