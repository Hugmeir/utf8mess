#!./perl -w

# Checks if the parser automatically handles UTF-16
# and UTF-32 (LE/BE, with and without a BOM), and
# explicit-BOM UTF-8. 99% of the world rightfully
# doesn't use an explicit UTF-8 BOM, so that case gets
# handled by an explicit 'use utf8', which the rest of
# the utf8 tests check for)

# TODO doesn't actually check for UTF-32 yet.

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
    skip_all_without_perlio();
    # FIXME - UTF-8 can be tested without Encode or full perl
    skip_all_without_dynamic_extension('Encode');
}

print "1..4016\n";
my $test = 0;

my %templates = (
		 'UTF-8'    => 'C0U',
		 'UTF-16BE' => 'n',
		 'UTF-16LE' => 'v',
		);

sub bytes_to_utf {
    my ($enc, $content, $do_bom) = @_;
    my $template = $templates{$enc};
    die "Unsupported encoding $enc" unless $template;
    my @chars = unpack "U*", $content;
    if ($enc ne 'UTF-8') {
	# Make surrogate pairs
	my @remember_that_utf_16_is_variable_length;
	foreach my $ord (@chars) {
	    if ($ord < 0x10000) {
		push @remember_that_utf_16_is_variable_length,
		    $ord;
	    } else {
		$ord -= 0x10000;
		push @remember_that_utf_16_is_variable_length,
		    (0xD800 | ($ord >> 10)), (0xDC00 | ($ord & 0x3FF));
	    }
	}
	@chars = @remember_that_utf_16_is_variable_length;
    }
    return pack "$template*", ($do_bom ? 0xFEFF : ()), @chars;
}

sub test {
    my ($enc, $write, $expect, $bom, $nl, $name) = @_;
    open my $fh, ">", "utf$$.pl" or die "utf.pl: $!";
    binmode $fh;
    print $fh bytes_to_utf($enc, $write . ($nl ? "\n" : ''), $bom);
    close $fh or die $!;
    my $got = do "./utf$$.pl";
    $test = $test + 1;
    if (!defined $got) {
        print "not ok $test # $enc $bom $nl $name; got undef, \$@ is $@\n";
    } elsif ($got ne $expect) {
	print "not ok $test # $enc $bom $nl $name; got '$got'\n";
    } else {
	print "ok $test # $enc $bom $nl $name\n";
    }
}

for my $bom (0, 1) {
    for my $enc (qw(UTF-16LE UTF-16BE UTF-8)) {
	for my $nl (1, 0) {
	    for my $value (123, 1234, 12345) {
		test($enc, $value, $value, $bom, $nl, $value);
		# This has the unfortunate side effect of causing an infinite
		# loop without the bug fix it corresponds to:
		test($enc, "($value)", $value, $bom, $nl, "($value)");
	    }
	    next if $enc eq 'UTF-8';
	    # Arguably a bug that currently string literals from UTF-8 file
	    # handles are not implicitly "use utf8", but don't FIXME that
	    # right now, as here we're testing the input filter itself.

	    for my $expect ("N", "\xFF", "\x{100}", "\x{010a}", "\x{0a23}",
			    "\x{10000}", "\x{64321}", "\x{10FFFD}",
			    "\x{1000a}", # 0xD800 0xDC0A
			    "\x{12800}", # 0xD80A 0xDC00
			   ) {
		# A space so that the UTF-16 heuristic triggers - " '" gives two
		# characters of ASCII.
		my $write = " '$expect'";
		my $name = 'chrs ' . join ', ', map {ord $_} split '', $expect;
		test($enc, $write, $expect, $bom, $nl, $name);
	    }

	    # This is designed to try to trip over the end of the buffer,
	    # with similar results to U-1000A and U-12800 above.
	    for my $pad (2 .. 162) {
		for my $chr ("\x{10000}", "\x{1000a}", "\x{12800}") {
		    my $padding = ' ' x $pad;
		    # Need 4 octets that were from 2 ASCII characters to trigger
		    # the heuristic that detects UTF-16 without a BOM. For
		    # UTF-16BE, one space and the newline will do, as the
		    # newline's high octet comes first. But for UTF-16LE, a
		    # newline is "\n\0", so it doesn't trigger it.
		    test($enc, "  \n$padding'$chr'", $chr, $bom, $nl,
			 sprintf "'\\x{%x}' with $pad spaces before it", ord $chr);
		}
	    }
	}
    }
}

END {
    1 while unlink "utf$$.pl";
}
