#!/usr/bin/env perl
use strict;
use bigint;
use Math::BigInt try => 'GMP';
use Data::Dumper;
use feature 'say';

sub slow_is_prime {
    my ($number) = @_;
    my $max = int(sqrt($number));

    # handle all even numbers (only 2 is an even prime)
    if ($number % 2 == 0) {
        return ($number == 2);
    }
    # handle negatives, zero, one
    if ($number < 3) {
        return 0;
    }

    for my $test (3 .. $max) {
        my $mod = $number % $test;
        return 0 if ($mod == 0);
    }
    return 1;
}

sub modpow {
    my ($a, $b, $n) = @_;

    return (($a ** $b) % $n);
    return $a->bmodpow($b, $n);
}

sub mr_strong_prime {
    # pass in a number to test, and a witness to test against
    my ($number, $witness) = @_;

    # handle all even numbers (only 2 is an even prime)
    if ($number % 2 == 0) {
        return ($number == 2);
    }
    # handle negatives, zero, one
    if ($number < 3) {
        return 0;
    }

    my $nminus = $number - 1;
    my $d = $nminus;
    my $s = 0;

    while ($d % 2 == 0) {
        $d = $d / 2;
        $s = $s + 1;
    }

    #my $a = Math::BigInt->new($witness);
    my $a = $witness;

    my $x = modpow($a, $d, $number);

    if ($x == 1 || $x == $nminus) {
        # prime according to this witness
        return 1;
    }

    for my $l (1 .. ($s - 1)) {
        $x = modpow($x, 2, $number);
        if ($x == 1) {
            # definitely composite
            return 0;
        }
        if ($x == $nminus) {
            # prime according to this witness
            return 1;
        }
    }
    # doesn't act like a prime
    return 0;
    
}

sub fast_is_prime {
    my $int = shift;
    return mr_strong_prime($int, 2) && mr_strong_prime($int, 3);
    return mr_strong_prime($int, 2) && mr_strong_prime($int, 7) && mr_strong_prime($int, 61);
}
 

my @bases = ();
for my $base (2 .. 101) {
    push @bases, Math::BigInt->new($base);
}

my $failure_base = {};

for my $i (2..600) {
    my $isp = fast_is_prime($i);
    if ($isp) {
        for my $w (@bases) {
            warn "FAILURE $w, $i" if (!mr_strong_prime($i, $w));
        }
    } else {
        for my $w (@bases) {
            if (mr_strong_prime($i, $w)) {
                $failure_base->{$w} //= $i;
                say "$w, $i";
            }
        }
    }
}

#say @primes;

#say Dumper $failure_base;
