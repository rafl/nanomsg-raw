package NanoMsg::Raw;
# ABSTRACT: Low-level interface to the nanomsg scalability protocols library

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

=head1 SYNOPSIS

    use NanoMsg::Raw;

    my $sb = nn_socket(AF_SP, NN_PAIR);
    nn_bind($sb, 'inproc://foo');
    nn_send($sb, 'bar');

    my $sc = nn_socket(AF_SP, NN_PAIR);
    nn_connect($sc, 'inproc://foo');
    nn_recv($sc, my $buf);
    is $buf, 'bar';

=func nn_socket($domain, $protocol)

    my $s = nn_socket(AF_SP, NN_PAIR);
    die nn_errno unless defined $s;

=func nn_close($s)

    nn_close($s) or die nn_errno;

=func nn_setsockopt($s, $level, $option, $value)

    nn_setsockopt($s, NN_SOL_SOCKET, NN_LINGER, 1000) or die nn_errno;
    nn_setsockopt($s, NN_SOL_SOCKET, NN_SUB_SUBSCRIBE, 'ABC') or die nn_errno;

=func nn_getsockopt($s, $leve, $option)

    my $linger = unpack 'I', nn_getsockopt($s, NN_SOL_SOCKET, NN_LINGER) || die nn_errno;

=func nn_bind($s, $addr)

    my $eid = nn_bind($s, 'inproc://test');
    die nn_errno unless defined $eid;

=func nn_connect($s, $addr)

    my $eid = nn_connect($s, 'inproc://test');
    die nn_errno unless defined $eid;

=func nn_shutdown($s, $eid)

    nn_shutdown($s, $eid) or die nn_errno;

=func nn_send($s, $data, $flags=0)

    my $bytes_sent = nn_send($s, 'foo');
    die nn_errno unless defined $bytes_sent;

=func nn_recv($s, $data, $length, $flags=0)

    my $bytes_received = nn_recv($s, my $buf, 256);
    die nn_errno unless defined $bytes_received;

=func nn_sendmsg($s, $flags, $data1, $data2, ..., $dataN)

    my $bytes_sent = nn_sendmsg($s, 0, 'foo', 'bar');
    die nn_errno unless defined $bytes_sent;

=func nn_recvmsg($s, $flags, $data1 => $len1, $data2 => $len2, ..., $dataN => $lenN)

    my $bytes_received = nn_recvmsg($s, 0, my $buf1 => 256, my $buf2 => 1024);
    die nn_errno unless defined $bytes_received;

=func nn_allocmsg($size, $type)

    my $msg = nn_allocmsg(3, 0) or die nn_errno;
    $msg->copy('foo');
    nn_send($s, $msg);

=func nn_device($s1, $s2)

    nn_device($s1, $s2) or die;

=func nn_term()

    nn_term();

=cut

1;
