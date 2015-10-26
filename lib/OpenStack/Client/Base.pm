package OpenStack::Client::Base;

use strict;
use warnings;

use HTTP::Request  ();
use LWP::UserAgent ();

use POSIX    ();
use JSON::XS ();

sub new ($%) {
    my ($class, $endpoint, %opts) = @_;

    die('No API endpoint provided') unless $endpoint;

    $opts{'access'} ||= {};

    my $ua = LWP::UserAgent->new(
        'ssl_opts' => {
            'verify_hostname' => 0
        }
    );

    return bless {
        'ua'       => $ua,
        'endpoint' => $endpoint,
        'access'   => $opts{'access'}
    }, $class;
}

sub uri ($$$) {
    my ($self, $path) = @_;

    return join '/', map {
        s/^\///;
        s/\/$//;
        $_
    } $self->{'endpoint'}, $path;
}

sub request ($$$$$) {
    my ($self, $method, $path, $headers, $body) = @_;

    $headers ||= [];

    my $request = HTTP::Request->new(
        $method => $self->uri($path)
    );

    push @{$headers}, (
        'Accept'       => 'application/json',
        'Content-Type' => 'application/json'
    );

    if (defined $self->{'access'}->{'token'}->{'id'}) {
        push @{$headers}, (
            'X-Auth-Token' => $self->{'access'}->{'token'}->{'id'}
        )
    }

    my $count = scalar @{$headers};

    die('Uneven number of header elements') if $count % 2 != 0;

    for (my $i=0; $i<$count; $i+=2) {
        my $name  = $headers->[$i];
        my $value = $headers->[$i+1];

        $request->header($name => $value);
    }

    if (defined $body) {
        $request->content(JSON::XS::encode_json($body));
    }

    my $response = $self->{'ua'}->request($request);

    my $type = $response->header('Content-Type');

    if ($response->code =~ /^2\d{2}$/) {
        die("Unexpected response type $type") unless lc $type eq 'application/json';

        return JSON::XS::decode_json($response->decoded_content);
    }

    if ($response->code =~ /^[45]\d{2}$/) {
        die($response->decoded_content);
    }

    return $response->message;
}

1;
