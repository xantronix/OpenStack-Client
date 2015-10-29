#! /usr/bin/perl

use strict;
use warnings;

use OpenStack::Client ();

my $client = OpenStack::Client->new($ENV{'OS_AUTH_URL'});

$client->auth(
    'tenant'   => $ENV{'OS_TENANT_NAME'},
    'username' => $ENV{'OS_USERNAME'},
    'password' => $ENV{'OS_PASSWORD'}
);

my $glance = $client->service('glance');

$glance->each("/v2/images", sub {
    my ($result) = @_;

    foreach my $image (@{$result->{'images'}}) {
        print "$image->{'direct_url'} $image->{'name'}\n";
    }
});
