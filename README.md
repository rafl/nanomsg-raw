# SYNOPSIS

    use NanoMsg::Raw;

    my $sb = nn_socket(AF_SP, NN_PAIR);
    nn_bind($sb, 'inproc://foo');
    nn_send($sb, 'bar');

    my $sc = nn_socket(AF_SP, NN_PAIR);
    nn_connect($sc, 'inproc://foo');
    nn_recv($sc, my $buf);
    is $buf, 'bar';

# WARNING

**nanomsg, the c library this module is based on, is still in beta stage!**

# DESCRIPTION

`NanoMsg::Raw` is a binding to the `nanomsg` C library. The goal of this
module is to provide a very low-level and manual interface to all the
functionality of the nanomsg library. It doesn't intend to provide a convenient
high-level API, integration with event loops, or the like. Those are intended to
be implemented as separate abstractions on top of `NanoMsg::Raw`.

The nanomsg C library is a high-performance implementation of several
"scalability protocols". Scalability protocol's job is to define how multiple
applications communicate to form a single distributed
application. Implementation of following scalability protocols is available at
the moment:

Scalability protocols are layered on top of transport layer in the network
stack. At the moment, nanomsg library supports following transports:

### nn\_socket($domain, $protocol)

    my $s = nn_socket(AF_SP, NN_PAIR);
    die nn_errno unless defined $s;

Creates a nanomsg socket with specified `$domain` and `$protocol`. Returns a
file descriptor for the newly created socket.

Following domains are defined at the moment:

The `$protocol` parameter defines the type of the socket, which in turn
determines the exact semantics of the socket. See ["Protocols"](#protocols) to get the list
of available protocols and their socket types.

The newly created socket is initially not associated with any endpoints. In
order to establish a message flow at least one endpoint has to be added to the
socket using `nn_bind` or `nn_connect`.

Also note that type argument as found in standard `socket` function is omitted
from `nn_socket`. All the SP sockets are message-based and thus of
`SOCK_SEQPACKET` type.

If the function succeeds file descriptor of the new socket is
returned. Otherwise, `undef` is returned and `nn_errno` is set to to one of
the values defined below.

Note that file descriptors returned by `nn_socket` function are not standard
file descriptors and will exhibit undefined behaviour when used with system
functions. Moreover, it may happen that a system file descriptor and file
descriptor of an SP socket will incidentally collide (be equal).

### nn\_close($s)

    nn_close($s) or die nn_errno;

Closes the socket `$s`. Any buffered inbound messages that were not yet
received by the application will be discarded. The library will try to deliver
any outstanding outbound messages for the time specified by `NN_LINGER` socket
option. The call will block in the meantime.

If the function succeeds, a true value is returned. Otherwise, `undef` is
returned and `nn_errno` is set to to one of the values defined below.

### nn\_setsockopt($s, $level, $option, $value)

    nn_setsockopt($s, NN_SOL_SOCKET, NN_LINGER, 1000) or die nn_errno;
    nn_setsockopt($s, NN_SOL_SOCKET, NN_SUB_SUBSCRIBE, 'ABC') or die nn_errno;

Sets the `$value` of the socket option `$option`. The `$level` argument
specifies the protocol level at which the option resides. For generic
socket-level options use the `NN_SOL_SOCKET` level. For socket-type-specific
options use the socket type for the `$level` argument (e.g. `NN_SUB`). For
transport-specific options use the ID of the transport as the `$level` argument
(e.g. `NN_TCP`).

If the function succeeds a true value is returned. Otherwise, `undef` is
returned and `nn_errno` is set to to one of the values defined below.

These are the generic socket-level (`NN_SOL_SOCKET` level) options:

### nn\_getsockopt($s, $level, $option)

    my $linger = unpack 'i', nn_getsockopt($s, NN_SOL_SOCKET, NN_LINGER) || die nn_errno;

Retrieves the value for the socket option `$option`. The `$level` argument
specifies the protocol level at which the option resides. For generic
socket-level options use the `NN_SOL_SOCKET` level. For socket-type-specific
options use the socket type for the `$level` argument (e.g. `NN_SUB`). For
transport-specific options use ID of the transport as the `$level` argument
(e.g. `NN_TCP`).

The function returns a packed string representing the requested socket option,
or `undef` on error, with one of the following reasons for the error placed in
`nn_errno`.

Just what is in the packed string depends on `$level` and `$option`; see the
list of socket options for details; A common case is that the option is an
integer, in which case the result is a packed integer, which you can decode
using `unpack` with the `i` (or `I`) format.

This function can be used to retrieve the values for all the generic
socket-level (`NN_SOL_SOCKET`) options documented in `nn_getsockopt` and also
supports these additional generic socket-level options that can only be
retrieved but not set:

### nn\_bind($s, $addr)

    my $eid = nn_bind($s, 'inproc://test');
    die nn_errno unless defined $eid;

Adds a local endpoint to the socket `$s`. The endpoint can be then used by other
applications to connect to.

The `$addr` argument consists of two parts as follows:
`transport://address`. The `transport` specifies the underlying transport
protocol to use. The meaning of the `address` part is specific to the
underlying transport protocol.

See ["Transports"](#transports) for a list of available transport protocols.

The maximum length of the `$addr` parameter is specified by `NN_SOCKADDR_MAX`
constant.

Note that `nn_bind` and `nn_connect` may be called multiple times on the same
socket thus allowing the socket to communicate with multiple heterogeneous
endpoints.

If the function succeeds, an endpoint ID is returned. Endpoint ID can be later
used to remove the endpoint from the socket via `nn_shutdown` function.

If the function fails, `undef` is returned and `nn_errno` is set to to one of
the values defined below.

### nn\_connect($s, $addr)

    my $eid = nn_connect($s, 'inproc://test');
    die nn_errno unless defined $eid;

Adds a remote endpoint to the socket `$s`. The library would then try to
connect to the specified remote endpoint.

The `$addr` argument consists of two parts as follows:
`transport://address`. The `transport` specifies the underlying transport
protocol to use. The meaning of the `address` part is specific to the
underlying transport protocol.

See ["Protocols"](#protocols) for a list of available transport protocols.

The maximum length of the `$addr` parameter is specified by `NN_SOCKADDR_MAX`
constant.

Note that `nn_connect` and `nn_bind` may be called multiple times on the same
socket thus allowing the socket to communicate with multiple heterogeneous
endpoints.

If the function succeeds, an endpoint ID is returned. Endpoint ID can be later
used to remove the endpoint from the socket via `nn_shutdown` function.

If the function fails, `undef` is returned and `nn_errno` is set to to one of
the values defined below.

### nn\_shutdown($s, $eid)

    nn_shutdown($s, $eid) or die nn_errno;

Removes an endpoint from socket `$s`. The `eid` parameter specifies the ID of
the endpoint to remove as returned by prior call to `nn_bind` or
`nn_connect`.

The `nn_shutdown` call will return immediately. However, the library will try
to deliver any outstanding outbound messages to the endpoint for the time
specified by the `NN_LINGER` socket option.

If the function succeeds, a true value is returned. Otherwise, `undef` is
returned and `nn_errno` is set to to one of the values defined below.

### nn\_send($s, $data, $flags=0)

    my $bytes_sent = nn_send($s, 'foo');
    die nn_errno unless defined $bytes_sent;

This function will send a message containing the provided `$data` to the socket
`$s`.

`$data` can either be anything that can be used as a byte string in perl or a
message buffer instance allocated by `nn_allocmsg`. In case of a message buffer
instance the instance will be deallocated and invalidated by the `nn_send`
function. The buffer will be an instance of `NanoMsg::Raw::Message::Freed`
after the call to `nn_send`.

Which of the peers the message will be sent to is determined by the particular
socket type.

The `$flags` argument, which defaults to `0`, is a combination of the flags
defined below:

If the function succeeds, the number of bytes in the message is
returned. Otherwise, a `undef` is returned and `nn_errno` is set to to one of
the values defined below.

### nn\_recv($s, $data, $length=NN\_MSG, $flags=0)

    my $bytes_received = nn_recv($s, my $buf, 256);
    die nn_errno unless defined $bytes_received;

Receive a message from the socket `$s` and store it in the buffer `$buf`. Any
bytes exceeding the length specified by the `$length` argument will be
truncated.

Alternatively, `nn_recv` can allocate a message buffer instance for you. To do
so, set the `$length` parameter to `NN_MSG` (the default).

The `$flags` argument, which defaults to `0`, is a combination of the flags
defined below:

If the function succeeds number of bytes in the message is returned. Otherwise,
`undef` is returned and `nn_errno` is set to to one of the values defined
below.

### nn\_sendmsg($s, $flags, $data1, $data2, ..., $dataN)

    my $bytes_sent = nn_sendmsg($s, 0, 'foo', 'bar');
    die nn_errno unless defined $bytes_sent;

This function is a fine-grained alternative to `nn_send`. It allows sending
multiple data buffers that make up a single message without having to create
another temporary buffer to hold the concatenation of the different message
parts.

The scalars containing the data to be sent (`$data1`, `$data2`, ...,
`$dataN`) can either be anything that can be used as a byte string in perl or a
message buffer instance allocated by `nn_allocmsg`. In case of a message buffer
instance the instance will be deallocated and invalidated by the `nn_sendmsg`
function. The buffers will be a instances of `NanoMsg::Raw::Message::Freed`
after the call to `nn_sendmsg`.

When using message buffer instances, only one buffer may be provided.

To which of the peers will the message be sent to is determined by the
particular socket type.

The `$flags` argument is a combination of the flags defined below:

If the function succeeds number of bytes in the message is returned. Otherwise,
`undef` is returned and `nn_errno` is set to to one of the values defined
below.

In the future, `nn_sendmsg` might allow for sending along additional control
data.

### nn\_recvmsg($s, $flags, $data1 => $len1, $data2 => $len2, ..., $dataN => $lenN)

    my $bytes_received = nn_recvmsg($s, 0, my $buf1 => 256, my $buf2 => 1024);
    die nn_errno unless defined $bytes_received;

This function is a fine-grained alternative to `nn_recv`. It allows receiving a
single message into multiple data buffers of different sizes, eliminating the
need to create copies of part of the received message in some cases.

The scalars in which to receive the message data (`$buf1`, `$buf2`, ...,
`$bufN`) will be filled with as many bytes of data as is specified by the
length parameter following them in the argument list (`$len1`, `$len2`, ...,
`$lenN`).

Alternatively, `nn_recvmsg` can allocate a message buffer instance for you. To
do so, set the length parameter of a buffer to to `NN_MSG`. In this case, only
one receive buffer can be provided.

The `$flags` argument is a combination of the flags defined below:

In the future, `nn_recvmsg` might allow for receiving additional control data.

### nn\_allocmsg($size, $type)

    my $msg = nn_allocmsg(3, 0) or die nn_errno;
    $msg->copy('foo');
    nn_send($s, $msg);

Allocate a message of the specified `$size` to be sent in zero-copy
fashion. The content of the message is undefined after allocation and it should
be filled in by the user. While `nn_send` and `nn_sendmsg` allow to send
arbitrary buffers, buffers allocated using `nn_allocmsg` can be more efficient
for large messages as they allow for using zero-copy techniques.

The `$type` parameter specifies type of allocation mechanism to use. Zero is
the default one. However, individual transport mechanisms may define their own
allocation mechanisms, such as allocating in shared memory or allocating a
memory block pinned down to a physical memory address. Such allocation, when
used with the transport that defines them, should be more efficient than the
default allocation mechanism.

If the function succeeds a newly allocated message buffer instance (an object
instance of the class [NanoMsg::Raw::Message](https://metacpan.org/pod/NanoMsg::Raw::Message)) is returned. Otherwise, `undef`
is returned and `nn_errno` is set to to one of the values defined below.

### nn\_errno()

Returns value of `errno` after the last call to any nanomsg function in the
current thread. This function can be used in the same way the `$!` global
variable is be used for many other system and library calls.

The return value can be used in numeric context, for example to compare it with
error code constants such as `EAGAIN`, or in a string context, to retrieve a
textual message describing the error.

### nn\_strerror($errno)

Returns a textual representation of the error described by the nummeric
`$errno` provided. It shouldn't normally be necessary to ever call this
function, as using `nn_errno` in string context is basically equivalent to
`nn_strerror(nn_errno)`.

### nn\_device($s1, $s2)

    nn_device($s1, $s2) or die;

Starts a device to forward messages between two sockets. If both sockets are
valid, the `nn_device` function loops and sends and messages received from
`$s1` to `$s2` and vice versa. If only one socket is valid and the other is
`undef`, `nn_device` works in a loopback mode — it loops and sends any
messages received from the socket back to itself.

The function loops until it hits an error. In such case it returns `undef` and
sets `nn_errno` to one of the values defined below.

### nn\_term()

    nn_term();

To help with shutdown of multi-threaded programs the `nn_term` function is
provided. It informs all the open sockets that process termination is underway.

If a socket is blocked inside a blocking function, such as `nn_recv`, it will
be unblocked and the `ETERM` error will be returned to the user. Similarly, any
subsequent attempt to invoke a socket function other than `nn_close` after
`nn_term` was called will result in an `ETERM` error.

If waiting for `NN_SNDFD` or `NN_RCVFD` using a polling function, such as
`poll` or `select`, the call will unblock with both `NN_SNDFD` and
`NN_RCVFD` signaled.

The `nn_term` function itself is non-blocking.

# Protocols

## One-to-one protocol

Pair protocol is the simplest and least scalable scalability protocol. It allows
scaling by breaking the application in exactly two pieces. For example, if a
monolithic application handles both accounting and agenda of HR department, it
can be split into two applications (accounting vs. HR) that are run on two
separate servers. These applications can then communicate via PAIR sockets.

The downside of this protocol is that its scaling properties are very
limited. Splitting the application into two pieces allows to scale to two
servers. To add the third server to the cluster, application has to be split
once more, say be separating HR functionality into hiring module and salary
computation module. Whenever possible, try to use one of the more scalable
protocols instead.

### Socket Types

### Socket Options

No protocol-specific socket options are defined at the moment.

## Request/reply protocol

This protocol is used to distribute the workload among multiple stateless workers.

### Socket Types

### Socket Options

## Publish/subscribe protocol

Broadcasts messages to multiple destinations.

### Socket Types

### Socket Options

## Survey protocol

Allows to broadcast a survey to multiple locations and gather the responses.

### Socket Types

### Socket Options

## Pipeline protocol

Fair queues messages from the previous processing step and load balances them
among instances of the next processing step.

### Socket Types

### Socket Options

No protocol-specific socket options are defined at the moment.

## Message bus protocol

Broadcasts messages from any node to all other nodes in the topology. The socket
should never receives messages that it sent itself.

This pattern scales only to local level (within a single machine or within a
single LAN). Trying to scale it further can result in overloading individual
nodes with messages.

**WARNING**: For bus topology to function correctly, the user is responsible for
ensuring that path from each node to any other node exists within the topology.

Raw (`AF_SP_RAW`) BUS socket never send the message to the peer it was received
from.

### Socket Types

### Socket Options

There are no options defined at the moment.

# Transports

## In-process transport

The in-process transport allows to send messages between threads or modules inside a
process. In-process address is an arbitrary case-sensitive string preceded by
`inproc://` protocol specifier. All in-process addresses are visible from any
module within the process. They are not visible from outside of the process.

The overall buffer size for an inproc connection is determined by the
`NN_RCVBUF` socket option on the receiving end of the connection. The
`NN_SNDBUF` socket option is ignored. In addition to the buffer, one message of
arbitrary size will fit into the buffer. That way, even messages larger than the
buffer can be transfered via inproc connection.

This transport's ID is `NN_INPROC`.

## Inter-process transport

The inter-process transport allows for sending messages between processes within
a single box. The implementation uses native IPC mechanism provided by the local
operating system and the IPC addresses are thus OS-specific.

On POSIX-compliant systems, UNIX domain sockets are used and IPC addresses are
file references. Note that both relative (`ipc://test.ipc`) and absolute
(`ipc:///tmp/test.ipc`) paths may be used. Also note that access rights on the
IPC files must be set in such a way that the appropriate applications can
actually use them.

On Windows, named pipes are used for IPC. IPC address is an arbitrary
case-insensitive string containing any character except for
backslash. Internally, address `ipc://test` means that named pipe
`\\.\pipe\test` will be used.

This transport's ID is `NN_IPC`.

## TCP transport

The TCP transport allows for passing message over the network using simple
reliable one-to-one connections. TCP is the most widely used transport protocol,
it is virtually ubiquitous and thus the transport of choice for communication
over the network.

When binding a TCP socket address of the form `tcp://interface:port` should be
used. Port is the TCP port number to use. Interface is one of the following
(optionally placed within square brackets):

When connecting a TCP socket address of the form `tcp://interface;address:port`
should be used. Port is the TCP port number to use. Interface is optional and
specifies which local network interface to use. If not specified, OS will select
an appropriate interface itself. If specified it can be one of the following
(optionally placed within square brackets):

Finally, address specifies the remote address to connect to. It can be one of
the following (optionally placed within square brackets):

This transport's ID is `NN_TCP`.

### Socket Options

# Constants

In addition to all the error constants and `NN_` constants used in the
documentation of the individual functions, protocols, and transports, the
following constants are available:

# SEE ALSO

