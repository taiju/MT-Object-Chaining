use strict;
use warnings;

use lib qw(lib extlib);

use Test::More;

use_ok $_ for qw(
    MT::Object::Chaining
    MT::Object::Chaining::Singleton
);

done_testing;

