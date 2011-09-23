#!./perl

# tests if system calls croak when passed UTF-8 data, print-like
# functions notwithstanding.

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
}

use strict;
use Fcntl ();

plan tests => 5;

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

    # This next test relies on runperl running things through ``
    my $prog = "print length q(\x{e0})";
    my $down = runperl( prog => $prog );
    
    utf8::upgrade($prog);
    my $up   = runperl( prog => $prog );;

    is($up, $down, "`` treats upgarded and downgraded Latin-1 the same");
}

{
    #pp_sysopen

    local $@;  
    eval {
        sysopen my $fh, "\x{30cb}", 0
    };
    like($@, qr/\QWide character in sysopen\E/, "sysopen croaks on non-downgradeable UTF-8");

    my $down = "\x{e0}";
    my $up   = "\x{e0}";
    utf8::upgrade($up);

    open my $latin_file, "+>", $down or die $!;

    sysopen(my $fh1, $up, Fcntl::O_WRONLY|Fcntl::O_APPEND) or die $!;
    print { $fh1 } "1\n";
    close $fh1;
    sysopen(my $fh2, $down, Fcntl::O_WRONLY|Fcntl::O_APPEND) or die $!;
    print { $fh2 } "2\n";
    close $fh2;

    my $file_contents = do { local $/; <$latin_file> };
    close $latin_file;

    is $file_contents, "1\n2\n", "sysopen treats latin-1 the same regardless of UTF-8ness";

    unlink($down);
}
