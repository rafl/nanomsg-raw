use strict;
use warnings;
use Test::More 0.89;
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
