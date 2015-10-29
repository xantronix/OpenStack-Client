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

foreach my $service ($client->services) {
    print "$service\n";
}
