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

=func nn_socket($domain, $protocol)

    my $s = nn_socket(AF_SP, NN_PAIR);
    die unless defined $s;

=func nn_close($s)

    nn_close($s) or die;

=func nn_setsockopt($s, $level, $option, $value)

    nn_setsockopt($s, NN_SOL_SOCKET, NN_LINGER, 1000) or die;
    nn_setsockopt($s, NN_SOL_SOCKET, NN_SUB_SUBSCRIBE, 'ABC') or die;

=func nn_getsockopt($s, $leve, $option)

    my $linger = unpack 'I', nn_getsockopt($s, NN_SOL_SOCKET, NN_LINGER) || die;

=func nn_bind($s, $addr)

    my $eid = nn_bind($s, 'inproc://test');
    die unless defined $eid;

=func nn_connect($s, $addr)

    my $eid = nn_connect($s, 'inproc://test');
    die unless defined $eid;

=func nn_shutdown($s, $eid)

    nn_shutdown($s, $eid) or die;

=func nn_send($s, $data, $flags=0)

    my $bytes_sent = nn_send($s, 'foo');
    die if $bytes_sent < 0;

=func nn_recv($s, $data, $length, $flags=0)

    my $bytes_received = nn_recv($s, my $buf, 256);
    die if $bytes_received < 0;

=func nn_sendmsg($s, $flags, $data1, $data2, ..., $dataN)

    my $bytes_sent = nn_sendmsg($s, 0, 'foo', 'bar');
    die if $bytes_sent < 0;

=func nn_recvmsg($s, $flags, $data1 => $len1, $data2 => $len2, ..., $dataN => $lenN)

    my $bytes_received = nn_recvmsg($s, 0, my $buf1 => 256, my $buf2 => 1024);
    die if $bytes_received < 0;

=func nn_allocmsg($size, $type)

    my $msg = nn_allocmsg(3, 0);
    $msg->copy('foo');
    nn_send($s, $msg);

=func nn_device($s1, $s2)

    nn_device($s1, $s2) or die;

=func nn_term()

    nn_term();

=cut

1;
