package OpenStack::Client;

use strict;
use warnings;

use OpenStack::Client::Base ();

our $VERSION = 0.0001;

=encoding utf8

=head1 NAME

OpenStack::Client - A reasonable OpenStack client

=head1 SYNOPSIS

    my $client = OpenStack::Client->new('http://openstack.foo.bar:5000/v2.0');

    $client->auth(
        'tenant'   => $ENV{'OS_TENANT_NAME'},
        'username' => $ENV{'OS_USERNAME'},
        'password' => $ENV{'OS_PASSWORD'}
    );

    my $glance = $client->service('glance',
        'region' => $ENV{'OS_REGION_NAME'}
    );

=head1 DESCRIPTION

C<OpenStack::Client> is a no-frills OpenStack API client which provides generic
access to OpenStack APIs with minimal remote service discovery facilities; with
a minimal client, the key understanding of the remote services are primarily
predicated on an understanding of the authoritative OpenStack API documentation:

    http://developer.openstack.org/api-ref.html

Authorization, authentication, and obtaining clients for various sub-services
such as the OpenStack Compute and Networking APIs is made convenient.  Further,
some small handling of response body data such as obtaining the full resultset
of a paginated response is handled by L<OpenStack::Client::Base> for
convenience.

=head1 INSTANTIATION

=over

=item C<OpenStack::Client-E<gt>new(I<$endpoint>)>

Create a new OpenStack client interface to the specified Keystone authentication
and authorization I<$endpoint>.

=cut

sub new ($%) {
    my ($class, $endpoint) = @_;

    die('No API authentication endpoint provided') unless $endpoint;

    return bless {
        'endpoints' => {},
        'clients'   => {},
        'token'     => undef,
        'auth'      => OpenStack::Client::Base->new($endpoint)
    }, $class;
}

=back

=head1 AUTHORIZING WITH KEYSTONE

=over

=item C<$client-E<gt>auth(I<%args>)>

Obtain an authorization token with the OpenStack Keystone service with the
parameters specified in I<%args>.  The following arguments are required:

=over

=item * B<tenant>

The OpenStack tenant (project) name

=item * B<username>

The OpenStack user name

=item * B<password>

The OpenStack password

=back

When successful, this method will return the Keystone authorization token found
within the response body, and will allow the C<$client-E<gt>service()> method to
access the endpoints the client has subsequently gained access to.

After a successful call to this method, subsequent calls will simply return the
existing authorization token data.

=cut

sub auth ($%) {
    my ($self, %args) = @_;

    die('No OpenStack tenant name provided in "tenant"') unless defined $args{'tenant'};
    die('No OpenStack username provided in "username"')  unless defined $args{'username'};
    die('No OpenSTack password provided in "password"')  unless defined $args{'password'};

    return $self->{'token'} if defined $self->{'token'};

    my $auth = $self->{'auth'};

    my $response = $auth->call('POST' => '/tokens', {
        'auth' => {
            'tenantName'          => $args{'tenant'},
            'passwordCredentials' => {
                'username' => $args{'username'},
                'password' => $args{'password'}
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

=item C<$client-E<gt>token()>

Return an authorization token obtained from the last successful Keystone
authentication.

=cut

sub token ($) {
    my ($self) = @_;

    die('Not authenticated') unless defined $self->{'token'};

    return $self->{'token'};
}

=back

=head1 CONNECTING TO OPENSTACK SERVICES

=over

=item C<$client-E<gt>services()>

Return a list of service names C<$client> is authorized to access.

=cut

sub services ($) {
    return sort keys %{shift->{'endpoints'}};
}

=item C<$client-E<gt>service(I<$name>, I<%opts>)>

Obtain a client to the OpenStack service I<$name>.  The following values may be
specified in I<%opts> to help locate the most appropriate endpoint for a given
service:

=over

=item * B<region>

When specified, attempt to obtain a client for the endpoint for that region.
When not specified, the a client for the first endpoint found for service
I<$name> is returned instead.

=item * B<public>

When specified (and set to 1), a client is opened for the public endpoint
corresponding to service I<$name>.

Without this, or any other values specified, a client for the public endpoint is
returned by default.

=item * B<internal>

When specified (and set to 1), a client is opened for the internal endpoint
corresponding to service I<$name>.

=item * B<admin>

When specified (and set to 1), a client is opened for the administrative
endpoint corresponding to service I<$name>.

=back

=cut

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

=back

=head1 SEE ALSO

=over

=item * L<OpenStack::Client::Base> - The HTTP interface to a OpenStack service

=back

=head1 AUTHOR

Written by Alexandra Hrefna Hilmisdóttir <xan@cpanel.net>

=cut

1;
