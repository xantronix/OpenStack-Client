#! /usr/bin/perl

use strict;
use warnings;

use OpenStack::Client ();

use Test::More qw(no_plan);

package Test::OpenStack::Client::Mock;

sub new ($%) {
    my ($class, %opts) = @_;

    return bless {
        'opts'     => \%opts,
        'requests' => []
    }, $class;
}

sub request ($$) {
    my ($self, $request) = @_;

    push @{$self->{'requests'}}, $request;
}

package Test::OpenStack::Client::Mock::Request;

sub new ($%) {
    my ($class, %args) = @_;

    return bless {
        'args'    => \%args,
        'headers' => {},
        'content' => undef
    }, $class;
}

sub header ($$$) {
    my ($self, $name, $value) = @_;

    $self->{'headers'}->{lc $name} = $value;

    return;
}

sub content ($@) {
    my ($self, $value) = @_;

    if (defined $value) {
        $self->{'content'} = $value;
    }

    return $self->{'content'};
}

package main;

$OpenStack::Client::HTTP_UA      = 'Test::OpenStack::Client::Mock';
$OpenStack::Client::HTTP_REQUEST = 'Test::OpenStack::Client::Mock::Request';
