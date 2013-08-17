use strict;
use warnings;

package NanoMsg::Raw::Message;

use overload '""' => sub { ${ $_[0] } }, fallback => 1;

1;
