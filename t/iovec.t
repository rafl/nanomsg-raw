use strict;
use warnings;
use Test::More 0.89;

use NanoMsg::Raw;

my $socket_address = 'inproc://a';

my $sb = nn_socket AF_SP, NN_PAIR;
cmp_ok $sb, '>=', 0;
cmp_ok nn_bind($sb, $socket_address), '>=', 0;

my $sc = nn_socket AF_SP, NN_PAIR;
cmp_ok $sc, '>=', 0;
cmp_ok nn_connect($sc, $socket_address), '>=', 0;

my $buf1 = 'ABCDEFGHIJKLMNO';
my $buf2 = 'PQRSTUVWXYZ';

is nn_sendmsg($sc, 0, $buf1, $buf2), 26;

is nn_recvmsg($sb, 0, my $buf3, my $buf4), 26;
is $buf3, $buf1;
is $buf4, $buf2;

is nn_sendmsg($sc, 0, $buf1, $buf2), 26;

my $buf5 = 'x' x 35;
my $buf6 = '';
my $buf7 = 'abc';

is nn_recvmsg($sb, 0, $buf5, $buf6, $buf7), 26;
is $buf5, $buf1 . $buf2;
is $buf6, '';
is $buf7, '';

done_testing;
