#!/usr/bin/perl -w
use strict;
use vars qw($Needs_Write $Verbose @Changed $TAP);
use File::Compare;
use Symbol;
use Text::Wrap;

# Common functions needed by the regen scripts

$Needs_Write = $^O eq 'cygwin' || $^O eq 'os2' || $^O eq 'MSWin32';

$Verbose = 0;
@ARGV = grep { not($_ eq '-q' and $Verbose = -1) }
  grep { not($_ eq '--tap' and $TAP = 1) }
  grep { not($_ eq '-v' and $Verbose = 1) } @ARGV;

END {
  print STDOUT "Changed: @Changed\n" if @Changed;
}

sub safer_unlink {
  my @names = @_;
  my $cnt = 0;

  my $name;
  foreach $name (@names) {
    next unless -e $name;
    chmod 0777, $name if $Needs_Write;
    ( CORE::unlink($name) and ++$cnt
      or warn "Couldn't unlink $name: $!\n" );
  }
  return $cnt;
}

sub safer_rename_silent {
  my ($from, $to) = @_;

  # Some dosish systems can't rename over an existing file:
  safer_unlink $to;
  chmod 0600, $from if $Needs_Write;
  rename $from, $to;
}

sub rename_if_different {
  my ($from, $to) = @_;

  if ($TAP) {
      my $not = compare($from, $to) ? 'not ' : '';
      print STDOUT $not . "ok - $0 $to\n";
      safer_unlink($from);
      return;
  }
  if (compare($from, $to) == 0) {
      warn "no changes between '$from' & '$to'\n" if $Verbose > 0;
      safer_unlink($from);
      return;
  }
  warn "changed '$from' to '$to'\n" if $Verbose > 0;
  push @Changed, $to unless $Verbose < 0;
  safer_rename_silent($from, $to) or die "renaming $from to $to: $!";
}

# Saf*er*, but not totally safe. And assumes always open for output.
sub safer_open {
    my ($name, $final_name) = @_;
    if (-f $name) {
	unlink $name or die "$name exists but can't unlink: $!";
    }
    my $fh = gensym;
    open $fh, ">$name" or die "Can't create $name: $!";
    *{$fh}->{name} = $name;
    if (defined $final_name) {
	*{$fh}->{final_name} = $final_name;
	*{$fh}->{lang} = ($final_name =~ /\.[ch]$/ ? 'C' : 'Perl');
    }
    binmode $fh;
    $fh;
}

sub safer_close {
    my $fh = shift;
    close $fh or die 'Error closing ' . *{$fh}->{name} . ": $!";
}

sub read_only_top {
    my %args = @_;
    die "Missing language argument" unless defined $args{lang};
    die "Unknown language argument '$args{lang}'"
	unless $args{lang} eq 'Perl' or $args{lang} eq 'C';
    my $style = $args{style} ? " $args{style} " : '   ';

    my $raw = "-*- buffer-read-only: t -*-\n";

    if ($args{file}) {
	$raw .= "\n   $args{file}\n";
    }
    if ($args{copyright}) {
	local $" = ', ';
	local $Text::Wrap::columns = 75;
	$raw .= wrap('   ', '   ', <<"EOM") . "\n";

Copyright (C) @{$args{copyright}} by\0Larry\0Wall\0and\0others

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the README file.
EOM
    }

    $raw .= "!!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!\n";

    if ($args{by}) {
	$raw .= "This file is built by $args{by}";
	if ($args{from}) {
	    my @from = ref $args{from} eq 'ARRAY' ? @{$args{from}} : $args{from};
	    my $last = pop @from;
	    if (@from) {
		$raw .= ' from ' . join (', ', @from) . " and $last";
	    } else {
		$raw .= " from $last";
	    }
	}
	$raw .= ".\n";
    }
    $raw .= "Any changes made here will be lost!\n";
    $raw .= $args{final} if $args{final};

    local $Text::Wrap::columns = 78;
    my $cooked = $args{lang} eq 'Perl'
	? wrap('# ', '# ', $raw) . "\n" : wrap('/* ', $style, $raw) . " */\n\n";
    $cooked =~ tr/\0/ /; # Don't break Larry's name etc
    $cooked =~ s/ +$//mg; # Remove all trailing spaces
    return $cooked;
}

sub read_only_bottom_close_and_rename {
    my $fh = shift;
    my $name = *{$fh}->{name};
    my $lang = *{$fh}->{lang};
    die "No final name specified at open time for $name"
	unless *{$fh}->{final_name};
    print $fh $lang eq 'Perl'
	? "\n# ex: set ro:\n" : "\n/* ex: set ro: */\n";
    safer_close($fh);
    rename_if_different($name, *{$fh}->{final_name});
}

1;
