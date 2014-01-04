#!/usr/bin/env perl
use strict;
#use bigint;
use Math::BigInt try => 'GMP';
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
        #say "Testing $number % $test gives $mod";
        return 0 if ($mod == 0);
    }
    return 1;
}

sub modpow {
    my ($a, $b, $n) = @_;

    return (($a ** $b) % $n);
    return $a->bmodpow($b, $n);
}

sub mr_test {
    # pass in a number to test, and a witness to test against
    my ($number, $witness) = @_;

    say "testing $number against $witness";
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

    my $a = $witness;

    my $x = modpow($a, $d, $number);

    say "first modpow $a ^ $d mod $number is $x";
    if ($x == 1 || $x == $nminus) {
        # this test says it's probably prime
        return 1;
    }
    say "trying ($s - 1) loops?";
    for my $l (1 .. ($s - 1)) {
        say "loop $l";
        my $newx = modpow($x, 2, $number);
        say "modpow $x ^ 2 mod $number is $newx";
        $x = $newx;
        if ($x == 1) {
            # definitely composite
            return 0;
        }
        if ($x == $nminus) {
            # this test says it's probably prime
            return 1;
        }
    }
    # inconclusive result
    return 0;
    
}

 
# print join ", ", grep { is_prime $_,10 }(1..1000);

my @primes = ();
for my $i (1..5000) {
    my $isp = slow_is_prime($i);
    if ($isp) {
        push @primes, "$i\n";
    } else {
        #say mr_test($i, 2) . " for $i";
        if (mr_test($i, 2)) {
            say "liar base 2 found for $i";
        }
    }
}

say @primes;
