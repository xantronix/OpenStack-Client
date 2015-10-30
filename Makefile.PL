#
# Copyright (c) 2015, cPanel, Inc.
# All rights reserved.
# http://cpanel.net/
#

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'OpenStack::Client',
    'VERSION_FROM' => 'lib/OpenStack/Client.pm',
    'AUTHOR'       => 'Alexandra Hrefna Hilmisdóttir <xan@cpanel.net>',
    'LICENSE'      => 'mit',
    'ABSTRACT'     => 'A nice and tiny OpenStack API client',

    'BUILD_REQUIRES' => {
        'JSON::XS'       => 0,
        'HTTP::Request'  => 0,
        'LWP::UserAgent' => 0,
        'URI::Encode'    => 0
    }
);
