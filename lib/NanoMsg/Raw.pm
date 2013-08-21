package NanoMsg::Raw;

use strict;
use warnings;
use XSLoader;
use NanoMsg::Raw::Message;

BEGIN {
    XSLoader::load 'NanoMsg'; # TODO: version
}

use Exporter 'import';

our @EXPORT = (
    _symbols(), 'NN_MSG',
    (map { "nn_$_" } qw(socket close setsockopt getsockopt bind connect shutdown
                        send recv sendmsg recvmsg allocmsg strerror device term errno)),
);

1;
