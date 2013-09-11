#!./perl -w

# Tests for the command-line switches

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require "./test.pl";

    skip_all_without_perlio();
    skip_all_if_miniperl('-C and $ENV{PERL_UNICODE} are disabled on miniperl');
}

plan(tests => 23);

my $r;

my $tmpfile = tempfile();
my $scriptfile = tempfile();

my $b = pack("C*", unpack("U0C*", pack("U",256)));

$r = runperl( switches => [ '-CO', '-w' ],
	      prog     => 'print chr(256)',
              stderr   => 1 );
like( $r, qr/^$b(?:\r?\n)?$/s, '-CO: no warning on UTF-8 output' );

SKIP: {
    if (exists $ENV{PERL_UNICODE} &&
	($ENV{PERL_UNICODE} eq "" || $ENV{PERL_UNICODE} =~ /[SO]/)) {
	skip(qq[cannot test with PERL_UNICODE "" or /[SO]/], 1);
    }
    $r = runperl( switches => [ '-CI', '-w' ],
		  prog     => 'print ord(<STDIN>)',
		  stderr   => 1,
		  stdin    => $b );
    like( $r, qr/^256(?:\r?\n)?$/s, '-CI: read in UTF-8 input' );
}

$r = runperl( switches => [ '-CE', '-w' ],
	      prog     => 'warn chr(256), qq(\n)',
              stderr   => 1 );
like( $r, qr/^$b(?:\r?\n)?$/s, '-CE: UTF-8 stderr' );

$r = runperl( switches => [ '-Co', '-w' ],
	      prog     => "open(F, q(>$tmpfile)); print F chr(256); close F",
              stderr   => 1 );
like( $r, qr/^$/s, '-Co: auto-UTF-8 open for output' );

$r = runperl( switches => [ '-Ci', '-w' ],
	      prog     => "open(F, q(<$tmpfile)); print ord(<F>); close F",
              stderr   => 1 );
like( $r, qr/^256(?:\r?\n)?$/s, '-Ci: auto-UTF-8 open for input' );

open(S, ">$scriptfile") or die("open $scriptfile: $!");
print S "open(F, q(<$tmpfile)); print ord(<F>); close F";
close S;

$r = runperl( switches => [ '-Ci', '-w' ],
	      progfile => $scriptfile,
              stderr   => 1 );
like( $r, qr/^256(?:\r?\n)?$/s, '-Ci: auto-UTF-8 open for input affects the current file' );

$r = runperl( switches => [ '-Ci', '-w' ],
	      prog     => "do q($scriptfile)",
              stderr   => 1 );
unlike( $r, qr/^256(?:\r?\n)?$/s, '-Ci: auto-UTF-8 open for input has file scope' );

$r = runperl( switches => [ '-CA', '-w' ],
	      prog     => 'print ord shift',
              stderr   => 1,
              args     => [ chr(256) ] );
like( $r, qr/^256(?:\r?\n)?$/s, '-CA: @ARGV' );

$r = runperl( switches => [ '-CS', '-w' ],
	      progs    => [ '#!perl -CS', 'print chr(256)'],
              stderr   => 1, );
like( $r, qr/^$b(?:\r?\n)?$/s, '#!perl -C' );

$r = runperl( switches => [ '-CS' ],
	      progs    => [ '#!perl -CS -w', 'print chr(256), !!$^W'],
              stderr   => 1, );
like( $r, qr/^${b}1(?:\r?\n)?$/s, '#!perl -C followed by another switch' );

$r = runperl( switches => [ '-CS' ],
	      progs    => [ '#!perl -C7 -w', 'print chr(256), !!$^W'],
              stderr   => 1, );
like(
  $r, qr/^${b}1(?:\r?\n)?$/s,
 '#!perl -C<num> followed by another switch'
);

$r = runperl( switches => [ '-CA', '-w' ],
	      progs    => [ '#!perl -CS', 'print chr(256)' ],
              stderr   => 1, );
like( $r, qr/^Too late for "-CS" option at -e line 1\.$/s,
      '#!perl -C with different -C on command line' );

SKIP: {
    if (exists $ENV{PERL_UNICODE} && $ENV{PERL_UNICODE} =~ /S/) {
	skip(qq[cannot test with PERL_UNICODE including "S"], 1);
    }
    $r = runperl( switches => [ '-w' ],
                  progs    => [ '#!perl -CS', 'print chr(256)' ],
                  stderr   => 1, );
    like( $r, qr/^Too late for "-CS" option at -e line 1\.$/s,
          '#!perl -C but not command line' );
}

SKIP: {
    skip("Cannot test without Encode", 10) unless eval { require Encode };
    
    # Okay, this is pretty nasty. runperl basically does a
    # perl -e 'print qq($stdin)', so we hijack that to print
    # the contents of $scriptfile
    my $stdin = <<"EOS";
); binmode STDOUT; open S, q{<}, q{$scriptfile} or die qq{open $scriptfile: \$!}; print STDOUT <S>; close S; (
EOS
    
    my $script_body = <<"EOS";
        warn q{line 1};
        binmode STDERR, q{:utf8};
        warn q{\x{30cd}};
        warn q{\x{1F42A}};
        warn q{line 5};
EOS

    my $expect = <<"EOF";
line 1 at - line 1.
\x{30cd} at - line 3.
\x{1F42A} at - line 4.
line 5 at - line 5.
EOF
    
    my $bom = "\x{FEFF}";
    for my $endianness (qw(LE BE)) {
        for my $BOM ( "", $bom ) {
            for my $switch ( '', '-CS' ) {
                my $script  = $BOM . $script_body;
                
                open(S, ">:raw", $scriptfile) or die("open $scriptfile: $!");
                print S Encode::encode("UTF-16$endianness", $script);
                close S;

                $r = runperl(
                    switches => [ $switch ],
                    stdin    => $stdin,
                    stderr   => 1,
                );
                
                utf8::decode($r);
                
                is($r, $expect, "cat utf | perl $switch with UTF16-$endianness, " . ($BOM ? '' : 'no ') . "bom");
            }
        }
    }
    
    open(S, ">:raw", $scriptfile) or die("open $scriptfile: $!");
    print S Encode::encode("UTF-8", $bom . 'use utf8;' . $script_body);
    close S;
    
    for my $switch ( '', '-CS' ) {
        $r = runperl(
            switches => [ $switch ],
            stdin    => $stdin,
            stderr   => 1,
        );
    
        utf8::decode($r);

        is($r, $expect, "cat utf | perl $switch with UTF-8, bom");
    }
}

