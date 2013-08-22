use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME      => 'NanoMsg::Raw',
    LIBS      => '-lnanomsg',
    PREREQ_PM => {
        'Test::More'       => '0.89',
        'Test::TCP'        => 0,
        'Test::Fatal'      => 0,
        'Test::SharedFork' => 0,
    }
);
