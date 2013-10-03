#!./perl

BEGIN {
    chdir '..' unless -d 't';
    unshift @INC, 'lib';
}

use strict;
require 't/test.pl';

use Config;
if ( $Config{usecrosscompile} ) {
  skip_all( "Not all files are available during cross-compilation" );
}

my $result = runperl(switches => ['-f', '-Ilib'], 
                     progfile => 'Porting/pod_rules.pl',
                     args     => ['--tap'],
                     nolib    => 1,
                     );

print $result;
