package OpenStack::Client::Type;

use strict;
use warnings;

sub parse ($$) {
    my ($class, $value) = @_;

    my %types;

    my @parts = split /\s*,\s*/, $value;

    foreach my $part (@parts) {
        my ($type, @attributes) = split /\s*;\s*/, $part;

        $types{$type} = {};

        foreach my $attribute (@attributes) {
            my ($name, $value) = split /\s*=\s*/, $attribute;

            $types{$type}->{$name} = $value;
        }
    }

    return bless \%types, $class;
}

1;
