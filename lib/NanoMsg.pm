package NanoMsg;

use strict;
use warnings;
use XSLoader;

BEGIN {
    XSLoader::load __PACKAGE__; # TODO: version
}

use Exporter 'import';

our @EXPORT = (
    (map { "nn_$_" } qw(socket close setsockopt getsockopt bind connect shutdown
                       send recv device term)),
    qw(AF_SP NN_PAIR),
);

1;
