package OpenStack::Client::Auth;

use strict;
use warnings;

use OpenStack::Client ();

=encoding utf8

=head1 NAME

OpenStack::Client::Auth - OpenStack Keystone authentication and authorization

=head1 SYNOPSIS

    use OpenStack::Client::Auth ();

    my $auth = OpenStack::Client::Auth->new('http://openstack.foo.bar:5000/v2.0',
        'tenant'   => $ENV{'OS_TENANT_NAME'},
        'username' => $ENV{'OS_USERNAME'},
        'password' => $ENV{'OS_PASSWORD'}
    );

    my $glance = $auth->service('image',
        'region' => $ENV{'OS_REGION_NAME'}
    );

=head1 DESCRIPTION

C<OpenStack::Client::Auth> provides an interface for obtaining authorization
to access other OpenStack cloud services.

=head1 AUTHORIZING WITH KEYSTONE

=over

=item C<OpenStack::Client::Auth-E<gt>new(I<$endpoint>, I<%args>)>

Contact the OpenStack Keystone API at the address provided in I<$endpoint>, and
obtain an authorization token and set of endpoints for which the client is
allowed to access.  Credentials are specified in I<%args>; the following named
values are required:

=over

=item * B<tenant>

The OpenStack tenant (project) name

=item * B<username>

The OpenStack user name

=item * B<password>

The OpenStack password

=back

When successful, this method will return an object containing the following:

=over

=item * response

The full decoded JSON authorization response from Keystone

=item * services

A hash containing services the client has authorization to

=item * clients

An initially empty hash that would contain L<OpenStack::Client> objects obtained
for any requested OpenStack services

=back

=cut

sub new ($$%) {
    my ($class, $endpoint, %args) = @_;

    die('No OpenStack authentication endpoint provided') unless defined $endpoint;
    die('No OpenStack tenant name provided in "tenant"') unless defined $args{'tenant'};
    die('No OpenStack username provided in "username"')  unless defined $args{'username'};
    die('No OpenStack password provided in "password"')  unless defined $args{'password'};

    my $client = OpenStack::Client->new($endpoint);

    my $response = $client->call('POST' => '/tokens', {
        'auth' => {
            'tenantName'          => $args{'tenant'},
            'passwordCredentials' => {
                'username' => $args{'username'},
                'password' => $args{'password'}
            }
        }
    });

    unless (defined $response->{'access'}->{'token'}->{'id'}) {
        die('No token found in response');
    }

    return bless {
        'response' => $response,
        'clients'  => {},
        'services' => {
            map {
                $_->{'type'} => $_->{'endpoints'}
            } @{$response->{'access'}->{'serviceCatalog'}}
        }
    }, $class;
}

=back

=head1 RETRIEVING RESPONSE

=over

=item C<$auth-E<gt>response()>

Return the full decoded response from the Keystone API.

=cut

sub response ($) {
    shift->{'response'};
}

=back

=head1 ACCESSING AUTHORIZATION DATA

=over

=item C<$auth-E<gt>access()>

Return the service access data stored in the current object.

=cut

sub access ($) {
    shift->{'response'}->{'access'};
}

=back

=head1 ACCESSING TOKEN DATA

=over

=item C<$auth-E<gt>token()>

Return the authorization token data stored in the current object.

=cut

sub token ($) {
    shift->{'response'}->{'access'}->{'token'};
}

=back

=head1 OBTAINING LIST OF SERVICES AUTHORIZED

=over

=item C<$auth-E<gt>services()>

Return a list of service types the OpenStack user is authorized to access.

=cut

sub services ($) {
    sort keys %{shift->{'services'}};
}

=back

=head1 ACCESSING SERVICES AUTHORIZED

=over

=item C<$auth-E<gt>service(I<$type>, I<%opts>)>

Obtain a client to the OpenStack service I<$type>, where I<$type> is usually
one of:

=over

=item * B<compute>

=item * B<ec2>

=item * B<identity>

=item * B<image>

=item * B<network>

=item * B<volumev2>

=back

The following values may be specified in I<%opts> to help locate the most
appropriate endpoint for a given service:

=over

=item * B<uri>

When specified, use a specific URI to gain access to a named service endpoint.
This might be useful for non-production development or testing scenarios.

=item * B<id>

When specified, attempt to obtain a client for the very endpoint indicated by
that identifier.

=item * B<region>

When specified, attempt to obtain a client for the endpoint for that region.
When not specified, the a client for the first endpoint found for service
I<$type> is returned instead.

=item * B<public>

When specified (and set to 1), a client is opened for the public endpoint
corresponding to service I<$type>.

Without this, or any other values specified, a client for the public endpoint is
returned by default.

=item * B<internal>

When specified (and set to 1), a client is opened for the internal endpoint
corresponding to service I<$type>.

=item * B<admin>

When specified (and set to 1), a client is opened for the administrative
endpoint corresponding to service I<$type>.

=back

=cut

sub service ($$%) {
    my ($self, $type, %opts) = @_;

    $opts{'public'}   ||= 1;
    $opts{'internal'} ||= 0;
    $opts{'admin'}    ||= 0;

    die("No service type '$type' found") unless defined $self->{'services'}->{$type};

    if (defined $self->{'clients'}->{$type}) {
        return  $self->{'clients'}->{$type};
    }

    if (defined $opts{'uri'}) {
        return $self->{'clients'}->{$type} = OpenStack::Client->new($opts{'uri'},
            'token' => $self->token
        );
    }

    if (!$opts{'public'} && !$opts{'internal'} && !$opts{'admin'}) {
        die('Neither "public", "internal" or "admin" specified in options');
    }

    foreach my $service (@{$self->{'services'}->{$type}}) {
        next if defined $opts{'id'}     && $service->{'id'}     ne $opts{'id'};
        next if defined $opts{'region'} && $service->{'region'} ne $opts{'region'};

        my $uri;

        $uri = $service->{'publicURL'}   if $opts{'public'};
        $uri = $service->{'internalURL'} if $opts{'internal'};
        $uri = $service->{'adminURL'}    if $opts{'admin'};

        return $self->{'clients'}->{$type} = OpenStack::Client->new($uri,
            'token' => $self->token
        );
    }

    die("Could not find appropriate endpoint for service type '$type'");
}

=back

=head1 AUTHOR

Written by Alexandra Hrefna Hilmisdóttir <xan@cpanel.net>

=cut

1;