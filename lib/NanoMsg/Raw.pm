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

=head1 DESCRIPTION

=func nn_socket($domain, $protocol)

    my $s = nn_socket(AF_SP, NN_PAIR);
    die nn_errno unless defined $s;

Creates a nanomsg socket with specified C<$domain> and C<$protocol>. Returns a
file descriptor for the newly created socket.

Following domains are defined at the moment:

=for :list
* C<AF_SP>
Standard full-blown SP socket.
* C<AF_SP_RAW>
Raw SP socket. Raw sockets omit the end-to-end functionality found in C<AF_SP>
sockets and thus can be used to implement intermediary devices in SP topologies.

The C<$protocol> parameter defines the type of the socket, which in turn
determines the exact semantics of the socket. See L</Protocols> to get the list
of available protocols and their socket types.

The newly created socket is initially not associated with any endpoints. In
order to establish a message flow at least one endpoint has to be added to the
socket using C<nn_bind> or C<nn_connect>.

Also note that type argument as found in standard C<socket> function is omitted
from C<nn_socket>. All the SP sockets are message-based and thus of
C<SOCK_SEQPACKET> type.

If the function succeeds file descriptor of the new socket is
returned. Otherwise, C<undef> is returned and C<nn_errno> is set to to one of
the values defined below.

=for :list
* C<EAFNOSUPPORT>
Specified address family is not supported.
* C<EINVAL>
Unknown protocol.
* C<EMFILE>
The limit on the total number of open SP sockets or OS limit for file
descriptors has been reached.
* C<ETERM>
The library is terminating.

Note that file descriptors returned by C<nn_socket> function are not standard
file descriptors and will exhibit undefined behaviour when used with system
functions. Moreover, it may happen that a system file descriptor and file
descriptor of an SP socket will incidentally collide (be equal).

=func nn_close($s)

    nn_close($s) or die nn_errno;

Closes the socket C<$s>. Any buffered inbound messages that were not yet
received by the application will be discarded. The library will try to deliver
any outstanding outbound messages for the time specified by C<NN_LINGER> socket
option. The call will block in the meantime.

If the function succeeds, a true value is returned. Otherwise, C<undef> is
returned and C<nn_errno> is set to to one of the values defined below.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<EINTR>
Operation was interrupted by a signal. The socket is not fully closed
yet. Operation can be re-started by calling C<nn_close> again.
    
=func nn_setsockopt($s, $level, $option, $value)

    nn_setsockopt($s, NN_SOL_SOCKET, NN_LINGER, 1000) or die nn_errno;
    nn_setsockopt($s, NN_SOL_SOCKET, NN_SUB_SUBSCRIBE, 'ABC') or die nn_errno;

Sets the C<$value> of the socket option C<$option>. The C<$level> argument
specifies the protocol level at which the option resides. For generic
socket-level options use the C<NN_SOL_SOCKET> level. For socket-type-specific
options use the socket type for the C<$level> argument (e.g. C<NN_SUB>). For
transport-specific options use the ID of the transport as the C<$level> argument
(e.g. C<NN_TCP>).

If the function succeeds a true value is returned. Otherwise, C<undef> is
returned and C<nn_errno> is set to to one of the values defined below.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<ENOPROTOOPT>
The option is unknown at the level indicated.
* C<EINVAL>
The specified option value is invalid.
* C<ETERM>
The library is terminating.

These are the generic socket-level (C<NN_SOL_SOCKET> level) options:

=for :list
* C<NN_LINGER>
Specifies how long the socket should try to send pending outbound messages after
C<nn_close> has been called, in milliseconds. Negative values mean infinite
linger. The type of the option is int. The default value is 1000 (1 second).
* C<NN_SNDBUF>
Size of the send buffer, in bytes. To prevent blocking for messages larger than
the buffer, exactly one message may be buffered in addition to the data in the
send buffer. The type of this option is int. The default value is 128kB.
* C<NN_RCVBUF>
Size of the receive buffer, in bytes. To prevent blocking for messages larger
than the buffer, exactly one message may be buffered in addition to the data in
the receive buffer. The type of this option is int. The default value is 128kB.
* C<NN_SNDTIMEO>
The timeout for send operation on the socket, in milliseconds. If a message
cannot be sent within the specified timeout, an C<EAGAIN> error is
returned. Negative values mean infinite timeout. The type of the option is
int. The default value is -1.
* C<NN_RCVTIMEO>
The timeout for recv operation on the socket, in milliseconds. If a message
cannot be received within the specified timeout, an C<EAGAIN> error is
returned. Negative values mean infinite timeout. The type of the option is
int. The default value is -1.
* C<NN_RECONNECT_IVL>
For connection-based transports such as TCP, this option specifies how long to
wait, in milliseconds, when connection is broken before trying to re-establish
it. Note that actual reconnect interval may be randomised to some extent to
prevent severe reconnection storms. The type of the option is int. The default
value is 100 (0.1 second).
* C<NN_RECONNECT_IVL_MAX>
This option is to be used only in addition to C<NN_RECONNECT_IVL> option. It
specifies maximum reconnection interval. On each reconnect attempt, the previous
interval is doubled until C<NN_RECONNECT_IVL_MAX> is reached. A value of zero
means that no exponential backoff is performed and reconnect interval is based
only on C<NN_RECONNECT_IVL>. If C<NN_RECONNECT_IVL_MAX> is less than
C<NN_RECONNECT_IVL>, it is ignored. The type of the option is int. The default
value is 0.
* C<NN_SNDPRIO>
Sets outbound priority for endpoints subsequently added to the socket. This
option has no effect on socket types that send messages to all the
peers. However, if the socket type sends each message to a single peer (or a
limited set of peers), peers with high priority take precedence over peers with
low priority. The type of the option is int. The highest priority is 1, the
lowest priority is 16. The default value is 8.
* C<NN_IPV4ONLY>
If set to 1, only IPv4 addresses are used. If set to 0, both IPv4 and IPv6
addresses are used. The default value is 1.

=func nn_getsockopt($s, $level, $option)

    my $linger = unpack 'i', nn_getsockopt($s, NN_SOL_SOCKET, NN_LINGER) || die nn_errno;

Retrieves the value for the socket option C<$option>. The C<$level> argument
specifies the protocol level at which the option resides. For generic
socket-level options use the C<NN_SOL_SOCKET> level. For socket-type-specific
options use the socket type for the C<$level> argument (e.g. C<NN_SUB>). For
transport-specific options use ID of the transport as the C<$level> argument
(e.g. C<NN_TCP>).

The function returns a packed string representing the requested socket option,
or C<undef> on error, with one of the following reasons for the error placed in
C<nn_errno>.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<ENOPROTOOPT>
The option is unknown at the C<$level> indicated.
* C<ETERM>
The library is terminating.

Just what is in the packed string depends on C<$level> and C<$option>; see the
list of socket options for details; A common case is that the option is an
integer, in which case the result is a packed integer, which you can decode
using C<unpack> with the C<i> (or C<I>) format.

This function can be used to retrieve the values for all the generic
socket-level (C<NN_SOL_SOCKET>) options documented in C<nn_getsockopt> and also
supports these additional generic socket-level options that can only be
retrieved but not set:

=for :list
* C<NN_DOMAIN>
Returns the domain constant as it was passed to C<nn_socket>.
* C<NN_PROTOCOL>
Returns the protocol constant as it was passed to C<nn_socket>.
* C<NN_SNDFD>
Retrieves a file descriptor that is readable when a message can be sent to the
socket. The descriptor should be used only for polling and never read from or
written to. The type of the option is int. The descriptor becomes invalid and
should not be used any more once the socket is closed. This socket option is not
available for unidirectional recv-only socket types.
* C<NN_RCVFD>
Retrieves a file descriptor that is readable when a message can be received from
the socket. The descriptor should be used only for polling and never read from
or written to. The type of the option is int. The descriptor becomes invalid and
should not be used any more once the socket is closed. This socket option is not
available for unidirectional send-only socket types.

=func nn_bind($s, $addr)

    my $eid = nn_bind($s, 'inproc://test');
    die nn_errno unless defined $eid;

Adds a local endpoint to the socket C<$s>. The endpoint can be then used by other
applications to connect to.

The C<$addr> argument consists of two parts as follows:
C<transport://address>. The C<transport> specifies the underlying transport
protocol to use. The meaning of the C<address> part is specific to the
underlying transport protocol.

See L</Protocols> for a list of available transport protocols.

The maximum length of the C<$addr> parameter is specified by C<NN_SOCKADDR_MAX>
constant.

Note that C<nn_bind> and C<nn_connect> may be called multiple times on the same
socket thus allowing the socket to communicate with multiple heterogeneous
endpoints.

If the function succeeds, an endpoint ID is returned. Endpoint ID can be later
used to remove the endpoint from the socket via C<nn_shutdown> function.

If the function fails, C<undef> is returned and C<nn_errno> is set to to one of
the values defined below.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<EMFILE>
Maximum number of active endpoints was reached.
* C<EINVAL>
The syntax of the supplied address is invalid.
* C<ENAMETOOLONG>
The supplied address is too long.
* C<EPROTONOSUPPORT>
The requested transport protocol is not supported.
* C<EADDRNOTAVAIL>
The requested endpoint is not local.
* C<ENODEV>
Address specifies a nonexistent interface.
* C<EADDRINUSE>
The requested local endpoint is already in use.
* C<ETERM>
The library is terminating.

=func nn_connect($s, $addr)

    my $eid = nn_connect($s, 'inproc://test');
    die nn_errno unless defined $eid;

Adds a remote endpoint to the socket C<$s>. The library would then try to
connect to the specified remote endpoint.

The C<$addr> argument consists of two parts as follows:
C<transport://address>. The C<transport> specifies the underlying transport
protocol to use. The meaning of the C<address> part is specific to the
underlying transport protocol.

See L</Protocols> for a list of available transport protocols.

The maximum length of the C<$addr> parameter is specified by C<NN_SOCKADDR_MAX>
constant.

Note that C<nn_connect> and C<nn_bind> may be called multiple times on the same
socket thus allowing the socket to communicate with multiple heterogeneous
endpoints.

If the function succeeds, an endpoint ID is returned. Endpoint ID can be later
used to remove the endpoint from the socket via C<nn_shutdown> function.

If the function fails, C<undef> is returned and C<nn_errno> is set to to one of
the values defined below.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<EMFILE>
Maximum number of active endpoints was reached.
* C<EINVAL>
The syntax of the supplied address is invalid.
* C<ENAMETOOLONG>
The supplied address is too long.
* C<EPROTONOSUPPORT>
The requested transport protocol is not supported.
* C<ENODEV>
Address specifies a nonexistent interface.
* C<ETERM>
The library is terminating.

=func nn_shutdown($s, $eid)

    nn_shutdown($s, $eid) or die nn_errno;

Removes an endpoint from socket C<$s>. The C<eid> parameter specifies the ID of
the endpoint to remove as returned by prior call to C<nn_bind> or
C<nn_connect>. The library will try to deliver any outstanding outbound messages
to this endpoint for the time specified by the C<NN_LINGER> socket option. The
call will block in the meantime.

If the function succeeds, a true value is returned. Otherwise, C<undef> is
returned and C<nn_errno> is set to to one of the values defined below.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<EINVAL>
The how parameter doesn’t correspond to an active endpoint.
* C<EINTR>
Operation was interrupted by a signal. The endpoint is not fully closed
yet. Operation can be re-started by calling C<nn_shutdown> again.
* C<ETERM>
The library is terminating.

=func nn_send($s, $data, $flags=0)

    my $bytes_sent = nn_send($s, 'foo');
    die nn_errno unless defined $bytes_sent;

This function will send a message containing the provided C<$data> to the socket
C<$s>.

C<$data> can either be anything that can be used as a byte string in perl or a
message buffer instance allocated by C<nn_allocmsg>. In case of a message buffer
instance the instance will be deallocated and invalidated by the C<nn_send>
function. The buffer will be an instance of C<NanoMsg::Raw::Message::Freed>
after the call to C<nn_send>.

Which of the peers the message will be sent to is determined by the particular
socket type.

The C<$flags> argument, which defaults to C<0>, is a combination of the flags
defined below:

=for :list
* C<NN_DONTWAIT>
Specifies that the operation should be performed in non-blocking mode. If the
message cannot be sent straight away, the function will fail with C<nn_errno>
set to C<EAGAIN>.

If the function succeeds, the number of bytes in the message is
returned. Otherwise, a C<undef> is returned and C<nn_errno> is set to to one of
the values defined below.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<ENOTSUP>
The operation is not supported by this socket type.
* C<EFSM>
The operation cannot be performed on this socket at the moment because the
socket is not in the appropriate state. This error may occur with socket types
that switch between several states.
* C<EAGAIN>
Non-blocking mode was requested and the message cannot be sent at the moment.
* C<EINTR>
The operation was interrupted by delivery of a signal before the message was
sent.
* C<ETIMEDOUT>
Individual socket types may define their own specific timeouts. If such timeout
is hit, this error will be returned.
* C<ETERM>
The library is terminating.

=func nn_recv($s, $data, $length=NN_MSG, $flags=0)

    my $bytes_received = nn_recv($s, my $buf, 256);
    die nn_errno unless defined $bytes_received;

Receive a message from the socket C<$s> and store it in the buffer C<$buf>. Any
bytes exceeding the length specified by the C<$length> argument will be
truncated.

Alternatively, C<nn_recv> can allocate a message buffer instance for you. To do
so, set the C<$length> parameter to C<NN_MSG> (the default).

The C<$flags> argument, which defaults to C<0>, is a combination of the flags defined below:

=for :list
* C<NN_DONTWAIT>
Specifies that the operation should be performed in non-blocking mode. If the
message cannot be received straight away, the function will fail with
C<nn_errno> set to C<EAGAIN>.

If the function succeeds number of bytes in the message is returned. Otherwise,
C<undef> is returned and C<nn_errno> is set to to one of the values defined
below.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<ENOTSUP>
The operation is not supported by this socket type.
* C<EFSM>
The operation cannot be performed on this socket at the moment because socket is
not in the appropriate state. This error may occur with socket types that switch
between several states.
* C<EAGAIN>
Non-blocking mode was requested and there’s no message to receive at the moment.
* C<EINTR>
The operation was interrupted by delivery of a signal before the message was
received.
* C<ETIMEDOUT>
Individual socket types may define their own specific timeouts. If such timeout
is hit this error will be returned.
* C<ETERM>
The library is terminating.

=func nn_sendmsg($s, $flags, $data1, $data2, ..., $dataN)

    my $bytes_sent = nn_sendmsg($s, 0, 'foo', 'bar');
    die nn_errno unless defined $bytes_sent;

This function is a fine-grained alternative to C<nn_send>. It allows sending
multiple data buffers that make up a single message without having to create
another temporary buffer to hold the concatenation of the different message
parts.

The scalars containing the data to be sent (C<$data1>, C<$data2>, ...,
C<$dataN>) can either be anything that can be used as a byte string in perl or a
message buffer instance allocated by C<nn_allocmsg>. In case of a message buffer
instance the instance will be deallocated and invalidated by the C<nn_sendmsg>
function. The buffers will be a instances of C<NanoMsg::Raw::Message::Freed>
after the call to C<nn_sendmsg>.

When using message buffer instances, only one buffer may be provided.

To which of the peers will the message be sent to is determined by the
particular socket type.

The C<$flags> argument is a combination of the flags defined below:

=for :list
* C<NN_DONTWAIT>
Specifies that the operation should be performed in non-blocking mode. If the
message cannot be sent straight away, the function will fail with C<nn_errno>
set to C<EAGAIN>.

If the function succeeds number of bytes in the message is returned. Otherwise,
C<undef> is returned and C<nn_errno> is set to to one of the values defined
below.

=for :list
* C<EBADF>
The provided socket is invalid.
* C<ENOTSUP>
The operation is not supported by this socket type.
* C<EFSM>
The operation cannot be performed on this socket at the moment because socket is
not in the appropriate state. This error may occur with socket types that switch
between several states.
* C<EAGAIN>
Non-blocking mode was requested and the message cannot be sent at the moment.
* C<EINTR>
The operation was interrupted by delivery of a signal before the message was
sent.
* C<ETIMEDOUT>
Individual socket types may define their own specific timeouts. If such timeout
is hit this error will be returned.
* C<ETERM>
The library is terminating.

In the future, C<nn_sendmsg> might allow for sending along additional control
data.

=func nn_recvmsg($s, $flags, $data1 => $len1, $data2 => $len2, ..., $dataN => $lenN)

    my $bytes_received = nn_recvmsg($s, 0, my $buf1 => 256, my $buf2 => 1024);
    die nn_errno unless defined $bytes_received;

=func nn_allocmsg($size, $type)

    my $msg = nn_allocmsg(3, 0) or die nn_errno;
    $msg->copy('foo');
    nn_send($s, $msg);

Allocate a message of the specified C<$size> to be sent in zero-copy
fashion. The content of the message is undefined after allocation and it should
be filled in by the user. While C<nn_send> and C<nn_sendmsg> allow to send
arbitrary buffers, buffers allocated using C<nn_allocmsg> can be more efficient
for large messages as they allow for using zero-copy techniques.

The C<$type> parameter specifies type of allocation mechanism to use. Zero is
the default one. However, individual transport mechanisms may define their own
allocation mechanisms, such as allocating in shared memory or allocating a
memory block pinned down to a physical memory address. Such allocation, when
used with the transport that defines them, should be more efficient than the
default allocation mechanism.

If the function succeeds a newly allocated message buffer instance (an object
instance of the class L<NanoMsg::Raw::Message>) is returned. Otherwise, C<undef>
is returned and C<nn_errno> is set to to one of the values defined below.

=for :list
* C<EINVAL>
Supplied allocation type is invalid.
* C<ENOMEM>
Not enough memory to allocate the message.

=func nn_errno()

Returns value of C<errno> after the last call to any nanomsg function in the
current thread. This function can be used in the same way the C<$!> global
variable is be used for many other system and library calls.

The return value can be used in numeric context, for example to compare it with
error code constants such as C<EAGAIN>, or in a string context, to retrieve a
textual message describing the error.

=func nn_device($s1, $s2)

    nn_device($s1, $s2) or die;

Starts a device to forward messages between two sockets. If both sockets are
valid, the C<nn_device> function loops and sends and messages received from
C<$s1> to C<$s2> and vice versa. If only one socket is valid and the other is
C<undef>, C<nn_device> works in a loopback mode — it loops and sends any
messages received from the socket back to itself.

The function loops until it hits an error. In such case it returns C<undef> and
sets C<nn_errno> to one of the values defined below.

=for :list
* C<EBADF>
One of the provided sockets is invalid.
* C<EINVAL>
Either one of the socket is not an C<AF_SP_RAW> socket; or the two sockets don’t
belong to the same protocol; or the directionality of the sockets doesn’t fit
(e.g. attempt to join two SINK sockets to form a device).
* C<EINTR>
The operation was interrupted by delivery of a signal.
* C<ETERM>
The library is terminating.

=func nn_term()

    nn_term();

To help with shutdown of multi-threaded programs the C<nn_term> function is
provided. It informs all the open sockets that process termination is underway.

If a socket is blocked inside a blocking function, such as C<nn_recv>, it will
be unblocked and the C<ETERM> error will be returned to the user. Similarly, any
subsequent attempt to invoke a socket function other than C<nn_close> after
C<nn_term> was called will result in an C<ETERM> error.

If waiting for C<NN_SNDFD> or C<NN_RCVFD> using a polling function, such as
C<poll> or C<select>, the call will unblock with both C<NN_SNDFD> and
C<NN_RCVFD> signaled.

=cut

1;
