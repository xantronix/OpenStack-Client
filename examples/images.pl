#! /usr/bin/perl

use strict;
use warnings;

use OpenStack::Client::Auth ();

my $auth = OpenStack::Client::Auth->new($ENV{'OS_AUTH_URL'},
    'tenant'   => $ENV{'OS_TENANT_NAME'},
    'username' => $ENV{'OS_USERNAME'},
    'password' => $ENV{'OS_PASSWORD'}
);

my $glance = $auth->service('image');

$glance->each("/v2/images", sub {
    my ($result) = @_;

    foreach my $image (@{$result->{'images'}}) {
        print "$image->{'direct_url'} $image->{'name'}\n";
    }
});
