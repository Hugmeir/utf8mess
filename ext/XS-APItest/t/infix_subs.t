use warnings;
use strict;

use Test::More tests => 2;
use XS::APItest qw(xs_infix);

my $ret = 1 xs_infix 2;
is($ret, 3, 'XS infix subs work');

{
    no warnings 'void';
    $ret = (1, 3, 2) xs_infix qw/7 8 8 8 9/;
    is($ret, 11, 'XS infix subs work');
}
