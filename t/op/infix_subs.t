#!perl

BEGIN {
    chdir 't';
    @INC = '../lib';
    require './test.pl';
}

use warnings;
no warnings 'experimental';
plan 45;

fresh_perl_like q'use warnings; sub foo (@>@);',
        qr/Infix subs are experimental/,
        'infix sub experimental warning';

eval q{ sub foo (@>\[>@]); 1 foo 1 };
like( $@,
      qr/Malformed prototype for main::foo/,
      'infix sub (@>\[>@]) croaks on a malformed proto'
);
        
eval q{ sub wrong4 ($;>@); };
like( $@, qr/Malformed prototype for main::wrong4/, 'Malformed: ($;>@)' );

eval q{ sub wrong5 ($>>$); };
like( $@, qr/Malformed prototype for main::wrong5/, 'Malformed: ($>>$)' );

eval q{ no warnings; sub wrong6 (_>$); };
like( $@, qr/Malformed prototype for main::wrong6/, 'Malformed: (_>$)' );

eval q{ sub wrong7 (>@); };
like( $@, qr/Malformed prototype for main::wrong7/, 'Malformed: (>@)' );

# -------------------- precedence -------------------- #

sub foo ($>$) { return $_[0] + $_[1]; }

my $x = 1 foo 2;
is($x, 3, "my \$x = 1 foo 2 is my \$x = (1 foo 2)");

$x = 1 foo 2 ? 5 : 6;
is($x, 5, "(1 foo 2 ? 5 ? 6) is ((1 foo 2) ? 5 ? 6)");

$x = 2 foo 0 && 5;
is($x, 2, "(2 foo 0 && 1) is (2 foo (0 && 1))");


$x = 2 foo 0 || 5;
is($x, 7, "(2 foo 0 || 5) is (2 foo (0 || 5))");

sub fooz (@>@) {}
my @t = (1, 2, 3 fooz 4, 5, 6);
ok(
    eq_array([1, 2, 5, 6], \@t),
    '(1,2,3 fooz 4,5,6) is (1,2,(3 fooz 4),5,6)'
);

sub bar (@>@) { return @_ }

@t = 1 bar 2;
ok(
   eq_array($t[0], [1]) && eq_array($t[1], [2]),
   '@ prototype always returns an arrayref'
);

@t = 1..10 bar 20...31;

ok(
   eq_array($t[0], [1..10]) && eq_array($t[1], [20...31]),
   "(1..10 bar 20...31) is ((1..10) bar (20...31))"
);

# -------------------- &infix -------------------- #

is(
   &foo(1, 2), 3, "infix sub with leading &"
);

is(
   sub { return &foo }->(5, 15),
   20,
   '&foo skips the prototype'
);

is(
   sub { goto &foo }->(5, 15),
   20,
   'goto &foo works'
);

*doof = \*foo;

is(
   doof(6, 6),
   12,
   '*doof = \\*foo; doof(6,6)'
);

# --------------------  -------------------- #

sub args_are {
    my ($args, $arg1, $arg2) = @_;
    my $caller_sub = (caller(1))[3      ];
    my $proto = prototype( $caller_sub );
    is(ref($args->[0]), $arg1, "First argument of $caller_sub($proto) is a $arg1") if $arg1;
    is(ref($args->[1]), $arg2, "Second argument of  $caller_sub($proto) is a $arg2") if $arg2;    
};

sub list_list (@>@) {
    is(scalar(@_), 2, '@_ is always 2 for infix subs');
    args_are(\@_, ref [], ref []);
    return @_;
}

my $scalar   = "abc";
my @array    = 0..9;
my %hash     = (a=>1);
my $arrayref = \@array;


my @ret = (1, 2, 3) list_list @array;

ok(
   eq_array($ret[0], [1, 2, 3]) && eq_array($ret[1], \@array),
   '@ coerces lists and arrays into arrayrefs'
);

@ret = $arrayref list_list %hash;

ok(
   eq_array($ret[0], [$arrayref]) && eq_array($ret[1], [%hash]),
   ''
);

@ret = 1 list_list $scalar;

ok(
    eq_array($ret[0], [1]),
    '@ prototype in infix subs coerces constants into arrayrefs'
);
ok(
    eq_array($ret[1], ["abc"]),
    '...and scalars as well'
);


sub scalar_scalar ($>$) {
    is(scalar(@_), 2, '@_ is always 2 for infix subs');
    return @_;
}

@ret = 1 scalar_scalar $arrayref;
ok(
    eq_array(\@ret, [ 1, $arrayref ]),
    '$ prototype leaves a scalar in an infix sub'
);

{
no warnings 'void';
@ret = (6,7,5) scalar_scalar @array;
ok(
    eq_array(\@ret, [ 5, 10 ]),
    '$ prototype in infix subs forces scalar context'
);
}

sub scalar_list ($>@) { return @_ }

{
no warnings 'void';
@ret = (4,5,7) scalar_list @array;

ok(
    $ret[0] == 7 && eq_array($ret[1], \@array),
    '$>@ works as expected'
);
}

sub hash_hash (%>%) {
    args_are(\@_, ref {}, ref {});
    return @_;
}

@ret = (1, 2) hash_hash %hash;

ok(
   eq_hash($ret[0], {1=>2}) && eq_hash($ret[1], \%hash),
   "% coerces arguments into hashrefs"
);


sub array_hash (@>%) {
    args_are(\@_, ref [], ref {});
    return @_;
}

@ret = (1, 2, 3, 4) array_hash map { $_ => 1 } qw/a b c d/;

ok(
   eq_hash($ret[1], {map { $_ => 1 } qw/a b c d/}),
   "... array_hash map ... parses & works correctly"
);

sub plus_plus (+>+) { return @_ }

sub dor ($>$) { $_[0] // $_[1] }

# TODO 1 infix { ... } still not implemented on the C level.
sub orelse ($>&) { $_[0] // $_[1]->() }

is(
   undef orelse sub { 11 },
   11,
   'simplistic orelse implementation'
);

# --------------------  -------------------- #

sub zip (@>@) {
   return map { $_[0]->[$_], $_[1]->[$_] } 0..$#{$_[0]}
}

@ret = qw/a b c d/ zip (1, 2, 3, 4);

ok(
   eq_array(\@ret, [qw(a 1 b 2 c 3 d 4)]),
   'qw// infix LIST works'
);

@ret = (1, 2, 3, 4) zip qw/a b c d/;

ok(
   eq_array(\@ret, [qw(1 a 2 b 3 c 4 d)]),
   'LIST infix qw// works'
);

@ret = (-1, @array, 10) zip (keys %hash, 'b'..'k', sub { 'l' }->());

ok(
   eq_array(\@ret, [qw(-1 a 0 b 1 c 2 d 3 e 4 f 5 g 6 h 7 i 8 j 9 k 10 l)]),
   '(complex expr) infix (complex expr) works'
);

