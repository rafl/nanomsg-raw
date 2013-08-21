use strict;
use warnings;
use Test::More 0.89;

BEGIN {
    use Config;
    plan skip_all => "Perl not compiled with 'useithreads'"
        unless $Config{'useithreads'};
}

use Test::SharedFork;

use threads;

use NanoMsg::Raw;

{
    my $msg = nn_allocmsg 3, 0;
    $msg->copy('foo');
    our $foo = ${ $msg };

    threads->create(sub {
        is $msg, 'foo';
        $msg->copy('bar');
        is $msg, 'bar';
    })->join;

    is $msg, 'foo';
}

END {
    pass 'made it into the end phase';
    is our $foo, 'foo';
    done_testing;
}

{
    my $socket_address = 'inproc://a';

    my @threads = do {
        my $sb = nn_socket(AF_SP, NN_PAIR);
        ok defined $sb;
        ok defined nn_bind($sb, $socket_address);

        map {
            threads->create(sub {
                nn_recv($sb, my $buf, 3, 0);
            });
        } 0 .. 1;
    };

    sleep 1;

    my $sc = nn_socket(AF_SP, NN_PAIR);
    ok defined $sc;
    ok defined nn_connect($sc, $socket_address);

    is nn_send($sc, 'foo', 0), 3;
    is nn_send($sc, 'foo', 0), 3;
    is_deeply [map { $_->join } @threads], [3, 3];
}
