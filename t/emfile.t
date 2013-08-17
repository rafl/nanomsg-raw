use strict;
use warnings;
use Test::More 0.89;

use NanoMsg::Raw;

# pre-load this module so we can compare with $! later on, once the maximum
# number of open file descriptors of this process has been exceeded and we
# couldn't load any further modules anymore.
use overloading;

my @socks;
while (1) {
    my $s = nn_socket AF_SP, NN_PAIR;
    if (!defined $s) {
        ok $! == EMFILE;
        last;
    }
    push @socks, $s;
}

ok nn_close $_ for @socks;

done_testing;
