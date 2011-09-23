#!./perl

# tests if system calls croak when passed UTF-8 data, print-like
# functions notwithstanding.

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
}

use strict;

plan tests => 9;

{
    #pp_backtick

    my $re = qr/\QWide character in quoted execution (``, qx)\E/;

    local $@;  
    eval {
        `\x{30cb}`
    };
    like($@, $re, "`` croaks on non-downgradeable UTF-8");
    
    local $@;
    eval {
        qx!\x{30cb}!
    };
    like($@, $re, "qx() croaks on non-downgradeable UTF-8");

=begin TODO
    my $down = "\x{e0}";
    my $up   = "\x{e0}";
    utf8::upgrade($up);

    local $@;
    eval {
        
    };
    unlike($@, $re, "`` treats latin-1 the same as UTF-8");

    local $@;
    eval {
        
    };
    unlike($@, $re, "qx() treats latin-1 the same as UTF-8");
    
=cut
}
