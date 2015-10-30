package OpenStack::Client::Base;

use strict;
use warnings;

use HTTP::Request  ();
use LWP::UserAgent ();

use JSON::XS    ();
use URI::Encode ();

=encoding utf8

=head1 NAME

OpenStack::Client::Base - Base REST JSON service client

=head1 SYNOPSIS

    my $client = OpenStack::Client::Base->new('http://glance.foo.bar:9292',
        'token' => $token
    );

    $client->each('/v2/images', sub {
        my ($result) = @_;

        foreach my $image (@{$result->{'images'}}) {
            print "$image->{'id'} $image->{'name'}\n";
        }
    });

=head1 DESCRIPTION

C<OpenStack::Client::Base> provides the base HTTP client functionality for
communicating with OpenStack services.  This package is also used by
L<OpenStack::Client> for negotiating with the OpenStack Keystone authentication
and authorization endpoint.

If you wish to communicate with any of the OpenStack services you are authorized
for, please use L<OpenStack::Client-E<gt>service()> to obtain an endpoint.

=head1 INSTANTIATION

=over

=item C<OpenStack::Client::Base-E<gt>new(I<$endpoint>, I<%opts>)>

Create a new C<OpenStack::Client::Base> object that is connected to the specified
I<$endpoint>.  This is generally not meant to be called by users of
L<OpenStack::Client> directly.

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

Return the current authentication token object returned by the Keystone service
when originally authenticating via L<OpenStack::Client>.

=cut

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

Perform an HTTP GET request for the resource I<$path>, while passing each
decoded response object to I<$callback> in a single argument.  I<$opts> is taken
to be a HASH reference containing zero or more key-value pairs to be URL encoded
as parameters to the GET request.

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

=back

=head1 AUTHOR

Written by Alexandra Hrefna Hilmisdóttir <xan@cpanel.net>

=cut

1;
