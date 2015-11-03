package OpenStack::Client;

use strict;
use warnings;

use HTTP::Request  ();
use LWP::UserAgent ();

use JSON::XS    ();
use URI::Encode ();

our $VERSION = 0.0010;

=encoding utf8

=head1 NAME

OpenStack::Client - A cute little client to OpenStack services

=head1 SYNOPSIS

    #
    # First, connect to an API endpoint via the Keystone authorization service
    #
    use OpenStack::Client::Auth ();

    my $auth = OpenStack::Client::Auth->new('http://openstack.foo.bar:5000/v2.0',
        'tenant'   => $ENV{'OS_TENANT_NAME'},
        'username' => $ENV{'OS_USERNAME'},
        'password' => $ENV{'OS_PASSWORD'}
    );

    my $glance = $auth->service('image',
        'region' => $ENV{'OS_REGION_NAME'}
    );

    my @images = $glance->all('/v2/images', 'images');

    #
    # Or, connect directly to an API endpoint by URI
    #
    use OpenStack::Client ();

    my $glance = OpenStack::Client->new('http://glance.foo.bar:9292',
        'token' => {
            'id' => 'foo'
        }
    );

    my @images = $glance->all('/v2/images', 'images');

=head1 DESCRIPTION

C<OpenStack::Client> is a no-frills OpenStack API client which provides generic
access to OpenStack APIs with minimal remote service discovery facilities; with
a minimal client, the key understanding of the remote services are primarily
predicated on an understanding of the authoritative OpenStack API documentation:

    http://developer.openstack.org/api-ref.html

Authorization, authentication, and access to OpenStack services such as the
OpenStack Compute and Networking APIs is made convenient by
L<OpenStack::Client::Auth>.  Further, some small handling of response body data
such as obtaining the full resultset of a paginated response is handled for
convenience.

Ordinarily, a client can be obtained conveniently by using the C<services()>
method on a L<OpenStack::Client::Auth> object.

=head1 INSTANTIATION

=over

=item C<OpenStack::Client-E<gt>new(I<$endpoint>, I<%opts>)>

Create a new C<OpenStack::Client> object connected to the specified
I<$endpoint>.  The following values may be specified in I<%opts>:

=over

=item * B<token>

A token obtained from a L<OpenStack::Client::Auth> object.

=back

=cut

sub new ($%) {
    my ($class, $endpoint, %opts) = @_;

    die('No API endpoint provided') unless $endpoint;

    my $ua = LWP::UserAgent->new(
        'ssl_opts' => {
            'verify_hostname' => 0
        }
    );

    return bless {
        'ua'       => $ua,
        'endpoint' => $endpoint,
        'token'    => $opts{'token'}
    }, $class;
}

=back

=head1 INSTANCE METHODS

These methods are useful for identifying key attributes of an OpenStack service
endpoint client.

=over

=item C<$client-E<gt>endpoint()>

Return the absolute HTTP URI to the endpoint this client provides access to.

=cut

sub endpoint ($) {
    shift->{'endpoint'};
}

=item C<$client-E<gt>token()>

If a token object was specified when creating C<$client>, then return it.

=cut

sub token ($) {
    shift->{'token'};
}

sub uri ($$$) {
    my ($self, $path) = @_;

    return join '/', map {
        s/^\///;
        s/\/$//;
        $_
    } $self->{'endpoint'}, $path;
}

=back

=head1 PERFORMING REMOTE CALLS

=over

=item C<$client-E<gt>call(I<$method>, I<$path>, I<$body>)>

Perform a call to the service endpoint using the HTTP method I<$method>,
accessing the resource I<$path> (relative to the absolute endpoint URI), passing
an arbitrary value in I<$body> that is to be encoded to JSON as a request
body.  This method may return the following:

=over

=item For B<application/json>: A decoded JSON object

=item For other response types: The unmodified response body

=back

In exceptional conditions (such as when the service returns a 4xx or 5xx HTTP
response), the client will C<die()> with the raw text response from the HTTP
service, indicating the nature of the service-side failure to service the
current call.

=cut

sub call ($$$$) {
    my ($self, $method, $path, $body) = @_;

    my $request = HTTP::Request->new(
        $method => $self->uri($path)
    );

    my @headers = (
        'Accept'          => 'application/json, text/plain',
        'Accept-Encoding' => 'identity, gzip, deflate, compress',
        'Content-Type'    => 'application/json'
    );

    push @headers, (
        'X-Auth-Token' => $self->{'token'}->{'id'}
    ) if defined $self->{'token'}->{'id'};

    my $count = scalar @headers;

    die('Uneven number of header elements') if $count % 2 != 0;

    for (my $i=0; $i<$count; $i+=2) {
        my $name  = $headers[$i];
        my $value = $headers[$i+1];

        $request->header($name => $value);
    }

    $request->content(JSON::XS::encode_json($body)) if defined $body;

    my $response = $self->{'ua'}->request($request);
    my $type     = $response->header('Content-Type');

    if ($response->code =~ /^2\d{2}$/) {
        die("Unexpected response type $type") unless lc $type =~ qr{^application/json}i;

        return JSON::XS::decode_json($response->decoded_content);
    }

    if ($response->code =~ /^[45]\d{2}$/) {
        die($response->decoded_content);
    }

    return $response->message;
}

=item C<$client-E<gt>get(I<$path>, I<%opts>)>

Perform an HTTP GET request for resource I<$path>.  The keys and values
specified in I<%opts> will be URL encoded and appended to I<$path> when forming
the request.  Response bodies are decoded as per C<$client-E<gt>call()>.

=cut

sub get ($$%) {
    my ($self, $path, %opts) = @_;

    my $params;

    foreach my $name (sort keys %opts) {
        my $value = $opts{$name};

        $params .= "&" if defined $params;

        $params .= sprintf "%s=%s", map {
            URI::Encode::uri_encode($_)
        } $name, $value;
    }

    if (defined $params) {
        #
        # $path might already have request parameters; if so, just append
        # subsequent values with a & rather than ?.
        #
        if ($path =~ /\?/) {
            $path .= "&$params"
        } else {
            $path .= "?$params";
        }
    }

    return $self->call('GET' => $path);
}

=item C<$client-E<gt>each(I<$path>, I<$opts>, I<$callback>)>

=item C<$client-E<gt>each(I<$path>, I<$callback>)>

Perform an HTTP GET request for the resource I<$path>, while passing each
decoded response object to I<$callback> in a single argument.  I<$opts> is taken
to be a HASH reference containing zero or more key-value pairs to be URL encoded
as parameters to each GET request made.

=cut

sub each ($$@) {
    my ($self, $path, @args) = @_;

    my $opts = {};
    my $callback;

    if (scalar @args == 2) {
        ($opts, $callback) = @args;
    } elsif (scalar @args == 1) {
        ($callback) = @args;
    } else {
        die('Invalid number of arguments');
    }

    while (defined $path) {
        my $result = $self->get($path, %{$opts});

        $callback->($result);

        $path = $result->{'next'};
    }

    return;
}

=item C<$client-E<gt>every(I<$path>, I<$attribute>, I<$opts>, I<$callback>)>

=item C<$client-E<gt>every(I<$path>, I<$attribute>, I<$callback>)>

Perform a series of HTTP GET request for the resource I<$path>, decoding the
result set and passing each value within each physical JSON response object's
attribute named I<$attribute>, to the callback I<$callback> as a single
argument.  I<$opts> is taken to be a HASH reference containing zero or more
key-value pairs to be URL encoded as parameters to each GET request made.

=cut

sub every ($$$@) {
    my ($self, $path, $attribute, @args) = @_;

    my $opts = {};
    my $callback;

    if (scalar @args == 2) {
        ($opts, $callback) = @args;
    } elsif (scalar @args == 1) {
        ($callback) = @args;
    } else {
        die('Invalid number of arguments');
    }

    while (defined $path) {
        my $result = $self->get($path, %{$opts});

        unless (defined $result->{$attribute}) {
            die("Response from $path does not contain attribute '$attribute'");
        }

        foreach my $item (@{$result->{$attribute}}) {
            $callback->($item);
        }

        $path = $result->{'next'};
    }

    return;
}

=item C<$client-E<gt>all(I<$path>, I<$attribute>, I<$opts>)>

=item C<$client-E<gt>all(I<$path>, I<$attribute>)>

Perform a series of HTTP GET requests for the resource I<$path>, decoding the
result set and returning a list of all items found within each response body's
attribute named I<$attribute>.  I<$opts> is taken to be a HASH reference
containing zero or more key-value pairs to be URL encoded as parameters to each
GET request made.

=cut

sub all ($$$@) {
    my ($self, $path, $attribute, $opts) = @_;

    my @items;

    $self->every($path, $attribute, $opts, sub {
        my ($item) = @_;

        push @items, $item;
    });

    return @items;
}

=back

=head1 SEE ALSO

=over

=item L<OpenStack::Client::Auth>

The OpenStack Keystone authentication and authorization interface

=back

=head1 AUTHOR

Written by Alexandra Hrefna Hilmisdóttir <xan@cpanel.net>

=cut

1;
