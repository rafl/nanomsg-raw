package NanoMsg::Raw;

use strict;
use warnings;
use XSLoader;

BEGIN {
    XSLoader::load 'NanoMsg'; # TODO: version
}

use Exporter 'import';

our @EXPORT = (
    _symbols(),
    (map { "nn_$_" } qw(socket close setsockopt getsockopt bind connect shutdown
                        send recv strerror device term)),
);

1;
