use strict;
use warnings;

package NanoMsg::Raw::Message;

use overload '""' => 'data', fallback => 1;

1;
