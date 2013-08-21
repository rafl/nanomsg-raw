use strict;
use warnings;
use Test::More 0.89;

use NanoMsg::Raw;

# Tests nn_send and nn_recv - without the $flags argument.

my $socket_address = 'inproc://test';

{
    my $sc = nn_socket AF_SP, NN_PAIR;
    ok defined $sc;
    ok defined nn_connect $sc, $socket_address;

    my $sb = nn_socket AF_SP, NN_PAIR;
    ok defined $sb;
    ok defined nn_bind $sb, $socket_address;

    # nn_send and nn_recv - flags defaults to zero
    for (1 .. 100) {
        is nn_send($sc, 'ABC'), 3;
        is nn_recv($sb, my $buf, 256), 3;
        is nn_send($sb, 'DEFG'), 4;
        is nn_recv($sc, $buf, 256), 4;
    }

    # Batch transfer test.
    is nn_send($sc, 'XYZ'), 3 for 1 .. 100;
    is nn_recv($sb, my $buf, 256), 3 for 1 .. 100;

    ok nn_close $_ for $sc, $sb;
}

done_testing;
