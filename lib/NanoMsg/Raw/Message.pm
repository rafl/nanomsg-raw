use strict;
use warnings;

package NanoMsg::Raw::Message;
# ABSTRACT: Message buffer for NanoMsg::Raw

use overload '""' => sub { ${ $_[0] } }, fallback => 1;

=head1 SYNOPSIS

    use NanoMsg::Raw;

    {
        my $msg = nn_allocmsg(3, 0);
        $msg->copy('foo');
        nn_send($sock, $msg);
    }

    {
        nn_recv($sock, my $buf);
        warn $buf;
    }

=cut

1;
