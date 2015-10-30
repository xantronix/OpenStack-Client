# NAME

OpenStack::Client - A reasonable OpenStack client

# SYNOPSIS

    use OpenStack::Client ();

    my $client = OpenStack::Client->new('http://openstack.foo.bar:5000/v2.0');

    $client->auth(
        'tenant'   => $ENV{'OS_TENANT_NAME'},
        'username' => $ENV{'OS_USERNAME'},
        'password' => $ENV{'OS_PASSWORD'}
    );

    my $glance = $client->service('glance',
        'region' => $ENV{'OS_REGION_NAME'}
    );

# DESCRIPTION

`OpenStack::Client` is a no-frills OpenStack API client which provides generic
access to OpenStack APIs with minimal remote service discovery facilities; with
a minimal client, the key understanding of the remote services are primarily
predicated on an understanding of the authoritative OpenStack API documentation:

    http://developer.openstack.org/api-ref.html

Authorization, authentication, and obtaining clients for various sub-services
such as the OpenStack Compute and Networking APIs is made convenient.  Further,
some small handling of response body data such as obtaining the full resultset
of a paginated response is handled by [OpenStack::Client::Base](https://metacpan.org/pod/OpenStack::Client::Base) for
convenience.

# INSTANTIATION

- `OpenStack::Client->new(_$endpoint_)`

    Create a new OpenStack client interface to the specified Keystone authentication
    and authorization _$endpoint_.

# AUTHORIZING WITH KEYSTONE

- `$client->auth(_%args_)`

    Obtain an authorization token with the OpenStack Keystone service with the
    parameters specified in _%args_.  The following arguments are required:

    - **tenant**

        The OpenStack tenant (project) name

    - **username**

        The OpenStack user name

    - **password**

        The OpenStack password

    When successful, this method will return the Keystone authorization token found
    within the response body, and will allow the `$client->service()` method to
    access the endpoints the client has subsequently gained access to.

    After a successful call to this method, subsequent calls will simply return the
    existing authorization token data.

- `$client->token()`

    Return an authorization token obtained from the last successful Keystone
    authentication.

# CONNECTING TO OPENSTACK SERVICES

- `$client->services()`

    Return a list of service names `$client` is authorized to access.

- `$client->service(_$name_, _%opts_)`

    Obtain a client to the OpenStack service _$name_.  The following values may be
    specified in _%opts_ to help locate the most appropriate endpoint for a given
    service:

    - **uri**

        When specified, use a specific URI to gain access to a named service endpoint.
        This might be useful for non-production development or testing scenarios.

    - **region**

        When specified, attempt to obtain a client for the endpoint for that region.
        When not specified, the a client for the first endpoint found for service
        _$name_ is returned instead.

    - **public**

        When specified (and set to 1), a client is opened for the public endpoint
        corresponding to service _$name_.

        Without this, or any other values specified, a client for the public endpoint is
        returned by default.

    - **internal**

        When specified (and set to 1), a client is opened for the internal endpoint
        corresponding to service _$name_.

    - **admin**

        When specified (and set to 1), a client is opened for the administrative
        endpoint corresponding to service _$name_.

# SEE ALSO

- [OpenStack::Client::Base](https://metacpan.org/pod/OpenStack::Client::Base) - The HTTP interface to a OpenStack service

# AUTHOR

Written by Alexandra Hrefna Hilmisdóttir &lt;xan@cpanel.net>
