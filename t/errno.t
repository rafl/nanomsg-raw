use strict;
use warnings;
use Test::More 0.89;

use NanoMsg::Raw;

my $s = nn_socket(AF_SP, NN_PAIR);
nn_term;
nn_send $s, "foo", 0;

like "$!", qr/Nanomsg library was terminated/,
    '$! contains nanomsg specific errors';

done_testing;
